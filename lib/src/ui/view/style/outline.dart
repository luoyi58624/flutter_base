part of 'index.dart';

/// 绘制在盒边界外的轮廓，仅参与绘制，不占用布局空间。
@immutable
@ElModelGenerator(copyWith: true, generateProps: true)
class ElOutline with Equatable {
  /// 创建轮廓，零宽度表示不绘制。
  const ElOutline({
    this.width = 0,
    this.color = const Color(0xFF000000),
    this.gradient,
    this.offset = 0,
  });

  /// 非负有限的描边粗细，零宽度不绘制 hairline。
  final num width;

  /// 纯色轮廓，gradient 非空时被覆盖。
  final Color color;

  /// 渐变轮廓，方向性几何跟随当前文字方向。
  final Gradient? gradient;

  /// 与盒边界的有限距离；正值向外扩展，负值向内收缩。
  final num offset;

  @override
  List<Object?> get props => _props;
}

OutlineStyle _parseOutline(ElOutline value, TextDirection direction) {
  assert(
    value.width >= 0 && value.width.isFinite && value.offset.isFinite,
    'outline 的 width 必须非负且有限，offset 必须有限',
  );
  return (
    width: value.width.toDouble(),
    offset: value.offset.toDouble(),
    color: value.gradient == null ? value.color : const Color(0x00000000),
    gradient: value.gradient,
    gradientOpacity: value.gradient == null ? 0 : 1,
    direction: direction,
  );
}

bool _mixedOutline(OutlineStyle? value) =>
    value?.gradient != null &&
    (value!.color.a > 0 || value.gradientOpacity != 1);

OutlineStyle? _outlineLerp(OutlineStyle? from, OutlineStyle? to, double t) {
  if (from == to) return from;
  var a = from?.gradient;
  var b = to?.gradient;
  final mixed =
      _mixedOutline(from) ||
      _mixedOutline(to) ||
      (a != null && to != null && b == null) ||
      (b != null && from != null && a == null);
  Gradient? gradient;
  double opacity;
  Color color;
  if (mixed) {
    // 同色 shader 未必覆盖全域，独立贡献兼容 decal / focal，也能接续中断。
    gradient = a != null && b != null ? Gradient.lerp(a, b, t) : a ?? b;
    opacity = lerpDouble(
      a == null ? 0 : from!.gradientOpacity,
      b == null ? 0 : to!.gradientOpacity,
      t,
    )!.clamp(0.0, 1.0);
    color = _colorLerp(from?.color, to?.color, t) as Color;
  } else if (a != null || b != null) {
    a ??= b!.scale(0);
    b ??= a.scale(0);
    gradient = Gradient.lerp(a, b, t);
    opacity = 1;
    color = const Color(0x00000000);
  } else {
    gradient = null;
    opacity = 0;
    color = _colorLerp(from?.color, to?.color, t) as Color;
  }
  return (
    width: math.max(0.0, lerpDouble(from?.width ?? 0, to?.width ?? 0, t)!),
    offset: lerpDouble(from?.offset ?? 0, to?.offset ?? 0, t)!,
    color: color,
    gradient: gradient,
    gradientOpacity: opacity,
    direction: to?.direction ?? from!.direction,
  );
}
