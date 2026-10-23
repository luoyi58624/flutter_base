part of 'index.dart';

// record 自带值比较，避免在每帧热路径构造 Equatable.props 集合。
typedef StyleLength = ({double px, double ratio, bool relative});
StyleLength styleLength(double px, [double ratio = 0, bool relative = false]) =>
    (px: px, ratio: ratio, relative: relative);

StyleLength? _parseLength(Object? value) {
  if (value == null) return null;
  final text = value is String ? value.trim() : null;
  final percent = text?.endsWith('%') ?? false;
  final number = value is num
      ? value.toDouble()
      : text == null
      ? null
      : double.tryParse(percent ? text.substring(0, text.length - 1) : text);
  if (number == null || !number.isFinite) return null;
  return percent ? styleLength(0, number / 100, true) : styleLength(number);
}

/// 保留旧版 px + percent 混合表示，每次布局按当前参照求值。
extension StyleLengthValue on StyleLength {
  double? resolve(double available) => relative && !available.isFinite
      ? null
      : math.max(0.0, px + (relative ? available * ratio : 0));
}

Object? _lengthLerp(Object? from, Object? to, double t) {
  if (from == null || to == null) return t < 0.5 ? from : to;
  final a = from as StyleLength;
  final b = to as StyleLength;
  return styleLength(
    lerpDouble(a.px, b.px, t)!,
    lerpDouble(a.ratio, b.ratio, t)!,
    a.relative || b.relative,
  );
}

double? _parseFactor(num value) {
  assert(value >= 0 && value.isFinite, '尺寸倍数必须非负且有限');
  return value == 1 ? null : value.toDouble();
}

Object? _factorLerp(Object? from, Object? to, double t) {
  final value = math.max(
    0.0,
    lerpDouble(from as double? ?? 1, to as double? ?? 1, t)!,
  );
  return value == 1 ? null : value;
}

EdgeInsets? _resolveInsets(EdgeInsetsGeometry value, TextDirection direction) {
  final result = value.resolve(direction);
  assert(
    [
      result.left,
      result.top,
      result.right,
      result.bottom,
    ].every((v) => v >= 0 && v.isFinite),
  );
  return result == EdgeInsets.zero ? null : result;
}

Object? _insetsLerp(Object? from, Object? to, double t) {
  var value = EdgeInsets.lerp(
    from as EdgeInsets? ?? EdgeInsets.zero,
    to as EdgeInsets? ?? EdgeInsets.zero,
    t,
  )!;
  if (!value.isNonNegative) {
    value = EdgeInsets.fromLTRB(
      math.max(0, value.left),
      math.max(0, value.top),
      math.max(0, value.right),
      math.max(0, value.bottom),
    );
  }
  return value == EdgeInsets.zero ? null : value;
}

BorderRadius? _resolveRadius(
  BorderRadiusGeometry value,
  TextDirection direction,
) {
  final result = value.resolve(direction);
  assert(
    [
      result.topLeft,
      result.topRight,
      result.bottomLeft,
      result.bottomRight,
    ].every((r) => r.x >= 0 && r.y >= 0 && r.x.isFinite && r.y.isFinite),
    'borderRadius 必须非负且有限',
  );
  return _normalizeRadius(result);
}

// 轨道保留退化椭圆的另一轴，否则两个方角端点之间的圆角动画会丢失。
Radius _clampCorner(Radius radius) => radius.x >= 0 && radius.y >= 0
    ? radius
    : Radius.elliptical(math.max(0, radius.x), math.max(0, radius.y));

bool _isRectRadius(BorderRadius value) =>
    (value.topLeft.x == 0 || value.topLeft.y == 0) &&
    (value.topRight.x == 0 || value.topRight.y == 0) &&
    (value.bottomLeft.x == 0 || value.bottomLeft.y == 0) &&
    (value.bottomRight.x == 0 || value.bottomRight.y == 0);

BorderRadius? _normalizeRadius(BorderRadius value) {
  final topLeft = _clampCorner(value.topLeft);
  final topRight = _clampCorner(value.topRight);
  final bottomLeft = _clampCorner(value.bottomLeft);
  final bottomRight = _clampCorner(value.bottomRight);
  if (topLeft == Radius.zero &&
      topRight == Radius.zero &&
      bottomLeft == Radius.zero &&
      bottomRight == Radius.zero) {
    return null;
  }
  if (topLeft == value.topLeft &&
      topRight == value.topRight &&
      bottomLeft == value.bottomLeft &&
      bottomRight == value.bottomRight) {
    return value;
  }
  return BorderRadius.only(
    topLeft: topLeft,
    topRight: topRight,
    bottomLeft: bottomLeft,
    bottomRight: bottomRight,
  );
}

Object? _radiusLerp(Object? from, Object? to, double t) => _normalizeRadius(
  BorderRadius.lerp(
    from as BorderRadius? ?? BorderRadius.zero,
    to as BorderRadius? ?? BorderRadius.zero,
    t,
  )!,
);

/// 沿用旧版预乘 alpha，透明端点的隐藏 RGB 不污染中间帧。
Object? _colorLerp(Object? from, Object? to, double t) {
  var a = from as Color?;
  var b = to as Color?;
  if (a == null && b == null) return null;
  a ??= b!.withValues(alpha: 0);
  b ??= a.withValues(alpha: 0);
  final space = a.colorSpace == b.colorSpace
      ? a.colorSpace
      : ColorSpace.extendedSRGB;
  if (a.colorSpace != b.colorSpace) {
    a = a.withValues(colorSpace: ColorSpace.extendedSRGB);
    b = b.withValues(colorSpace: ColorSpace.extendedSRGB);
  }
  final wa = a.a * (1 - t), wb = b.a * t;
  final alpha = wa + wb;
  if (alpha <= 0) return a.withValues(alpha: 0);
  // 跨色域转换后的扩展 sRGB 通道可以超出 0..1，裁剪会使终点跳色。
  final min = space == ColorSpace.extendedSRGB ? double.negativeInfinity : 0.0;
  final max = space == ColorSpace.extendedSRGB ? double.infinity : 1.0;
  return Color.from(
    alpha: alpha.clamp(0, 1),
    red: ((a.r * wa + b.r * wb) / alpha).clamp(min, max),
    green: ((a.g * wa + b.g * wb) / alpha).clamp(min, max),
    blue: ((a.b * wa + b.b * wb) / alpha).clamp(min, max),
    colorSpace: space,
  );
}
