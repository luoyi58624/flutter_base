part of 'index.dart';

/// 供自身与背景滤镜共用的不可变数值声明，各分量按固定顺序组合。
@immutable
@ElModelGenerator(copyWith: true, generateProps: true)
class ElFilter with Equatable {
  /// 创建滤镜，blur 短手与 blurX、blurY 不能同时声明。
  const ElFilter({
    this.blur,
    this.blurX,
    this.blurY,
    this.saturate,
    this.brightness,
    this.contrast,
    this.grayscale,
    this.sepia,
    this.invert,
    this.hueRotate,
    this.opacity,
  }) : assert(blur == null || (blurX == null && blurY == null));

  /// 不改变视觉的共享滤镜声明。
  static const identity = ElFilter();

  /// 双轴高斯模糊 sigma，单位为逻辑像素，默认零。
  final num? blur;

  /// 水平方向高斯模糊 sigma，默认零。
  final num? blurX;

  /// 垂直方向高斯模糊 sigma，默认零。
  final num? blurY;

  /// 非负饱和度，默认一，零为完全去色。
  final num? saturate;

  /// 非负亮度倍数，默认一。
  final num? brightness;

  /// 非负对比度倍数，默认一。
  final num? contrast;

  /// 灰度比例，限制在零到一，默认零。
  final num? grayscale;

  /// 褐色比例，限制在零到一，默认零。
  final num? sepia;

  /// 反相比例，限制在零到一，默认零。
  final num? invert;

  /// 色相旋转角度，单位为度，完整圈数参与动画。
  final num? hueRotate;

  /// 滤镜内透明度，限制在零到一，默认一。
  final num? opacity;

  /// 规范后的有效分量是否都不改变视觉，包括整圈色相旋转。
  bool get isIdentity => _isIdentityFilter(_parseFilter(this));

  /// 逐分量平滑插值，空端以恒等值补位并支持模糊短手与双轴之间切换。
  static ElFilter? lerp(ElFilter? a, ElFilter? b, double t) {
    if (identical(a, b) || t == 0) return a;
    if (t == 1) return b;
    final value = _filterLerp(
      a == null ? null : _parseFilter(a),
      b == null ? null : _parseFilter(b),
      t,
    );
    return value == null
        ? null
        : ElFilter(
            blurX: value.blurX,
            blurY: value.blurY,
            saturate: value.saturate,
            brightness: value.brightness,
            contrast: value.contrast,
            grayscale: value.grayscale,
            sepia: value.sepia,
            invert: value.invert,
            hueRotate: value.hueRotate,
            opacity: value.opacity,
          );
  }

  @override
  List<Object?> get props => _props;

  @override
  String toString() {
    final values = <String>[
      if (blur != null) 'blur: $blur',
      if (blurX != null) 'blurX: $blurX',
      if (blurY != null) 'blurY: $blurY',
      if (saturate != null) 'saturate: $saturate',
      if (brightness != null) 'brightness: $brightness',
      if (contrast != null) 'contrast: $contrast',
      if (grayscale != null) 'grayscale: $grayscale',
      if (sepia != null) 'sepia: $sepia',
      if (invert != null) 'invert: $invert',
      if (hueRotate != null) 'hueRotate: $hueRotate',
      if (opacity != null) 'opacity: $opacity',
    ];
    return 'ElFilter(${values.join(', ')})';
  }
}

double _filterFinite(num? value, double fallback) {
  final number = value?.toDouble() ?? fallback;
  return number.isFinite && number.abs() <= 3.4028234663852886e38
      ? number
      : fallback;
}

double _filterPositive(num? value, [double fallback = 0]) =>
    math.max(0, _filterFinite(value, fallback));

double _filterUnit(num? value, double fallback) =>
    _filterFinite(value, fallback).clamp(0.0, 1.0);

double _filterHue(num? value) {
  final number = value?.toDouble() ?? 0;
  return number.isFinite ? number : 0;
}

FilterStyle _parseFilter(ElFilter value) => (
  blurX: _filterPositive(value.blur ?? value.blurX),
  blurY: _filterPositive(value.blur ?? value.blurY),
  saturate: _filterPositive(value.saturate, 1),
  brightness: _filterPositive(value.brightness, 1),
  contrast: _filterPositive(value.contrast, 1),
  grayscale: _filterUnit(value.grayscale, 0),
  sepia: _filterUnit(value.sepia, 0),
  invert: _filterUnit(value.invert, 0),
  hueRotate: _filterHue(value.hueRotate),
  opacity: _filterUnit(value.opacity, 1),
);

FilterStyle? _filterLerp(FilterStyle? from, FilterStyle? to, double t) {
  if (from == to || t == 0) return from;
  if (t == 1) return to;
  final a = from ?? identityFilterStyle, b = to ?? identityFilterStyle;
  double mix(double x, double y) => x == y ? x : x * (1 - t) + y * t;
  return (
    blurX: _filterPositive(mix(a.blurX, b.blurX)),
    blurY: _filterPositive(mix(a.blurY, b.blurY)),
    saturate: _filterPositive(mix(a.saturate, b.saturate), 1),
    brightness: _filterPositive(mix(a.brightness, b.brightness), 1),
    contrast: _filterPositive(mix(a.contrast, b.contrast), 1),
    grayscale: _filterUnit(mix(a.grayscale, b.grayscale), 0),
    sepia: _filterUnit(mix(a.sepia, b.sepia), 0),
    invert: _filterUnit(mix(a.invert, b.invert), 0),
    hueRotate: _filterHue(mix(a.hueRotate, b.hueRotate)),
    opacity: _filterUnit(mix(a.opacity, b.opacity), 1),
  );
}

bool _isIdentityFilter(FilterStyle? value) =>
    value == null ||
    (value.blurX == 0 &&
        value.blurY == 0 &&
        value.saturate == 1 &&
        value.brightness == 1 &&
        value.contrast == 1 &&
        value.grayscale == 0 &&
        value.sepia == 0 &&
        value.invert == 0 &&
        value.hueRotate % 360 == 0 &&
        value.opacity == 1);
