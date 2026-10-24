import 'dart:math' as math;
import 'dart:ui' show ColorSpace, lerpDouble;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/dart.dart';

import '../layout/box_layout.dart';
import 'resolved/filter.dart';
import 'resolved/layout.dart';
import 'resolved/outline.dart';
import 'resolved/transform.dart';

part 'index.g.dart';

part 'lerp.dart';

part 'style_engine.dart';

part 'fields.dart';

/// 不可变的盒模型样式；宽高包含 padding，不包含 margin。
@immutable
@ElModelGenerator.copy()
class ElStyle with Equatable {
  /// 创建样式，集合参数应保持不可变。
  const ElStyle({
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.widthFactor,
    this.heightFactor,
    this.aspectRatio,
    this.backgroundColor,
    this.backgroundImage,
    this.gradient,
    this.boxShadow,
    this.opacity,
    this.transform,
    this.transformAlignment,
    this.filter,
    this.backdropFilter,
    this.padding,
    this.margin,
    this.alignment,
    this.border,
    this.outline,
    this.borderRadius,
    this.clipper,
    this.clipBehavior,
    this.transitions,
  });

  /// 逻辑像素数值或百分比字符串；null 表示自动宽度。
  final Object? width;

  /// 逻辑像素数值或百分比字符串；null 表示自动高度。
  final Object? height;

  /// 最小视觉盒宽度，数值或百分比，包含 padding；null 为零，maxWidth 冲突优先。
  final Object? minWidth;

  /// 最大视觉盒宽度，数值或百分比，包含 padding；null 表示不增加上限。
  final Object? maxWidth;

  /// 最小视觉盒高度，数值或百分比，包含 padding；null 为零，maxHeight 冲突优先。
  final Object? minHeight;

  /// 最大视觉盒高度，数值或百分比，包含 padding；null 表示不增加上限。
  final Object? maxHeight;

  /// 非负有限的自然盒宽度倍数，包含 padding；null 等同于 1，显式宽度优先。
  final num? widthFactor;

  /// 非负有限的自然盒高度倍数，包含 padding；null 等同于 1，显式高度优先。
  final num? heightFactor;

  /// 正有限的视觉盒宽高比；双显式轴或有效 auto 倍数优先，null 表示不用比例。
  final num? aspectRatio;

  /// 背景色，覆盖内容和 padding；null 表示不绘制。
  final Color? backgroundColor;

  /// 官方背景图片，位于背景色之上、渐变之下，不占布局；null 表示不绘制。
  final DecorationImage? backgroundImage;

  /// 覆盖背景色与背景图的原生渐变；null 表示不绘制，使用当前文字方向解析几何。
  final Gradient? gradient;

  /// 按声明顺序绘制的阴影，支持 ElBoxShadow.inset；不占布局或扩大命中范围。
  final List<BoxShadow>? boxShadow;

  /// 背景滤镜、装饰与 child 的整组透明度，限制在 0～1；null 为 1，零值不绘制或命中。
  final num? opacity;

  /// 整组视觉变换，不占布局；null 表示不变换，平移单位为逻辑像素。
  final ElTransform? transform;

  /// 变换原点，优先于 transform.origin；缺省回退内部原点或视觉盒中心。
  final AlignmentGeometry? transformAlignment;

  /// 作用于全部装饰与 child 的自身滤镜，不占布局，模糊允许向盒外扩散。
  final ElFilter? filter;

  /// 仅处理盒后方画面的背景滤镜，采样范围按当前盒形状裁剪，不裁掉装饰。
  final ElFilter? backdropFilter;

  /// 非负有限内边距，支持方向性边距；null 等同于零。
  final EdgeInsetsGeometry? padding;

  /// 非负有限外边距，背景不覆盖此区域；null 等同于零。
  final EdgeInsetsGeometry? margin;

  /// child 在内容区内的对齐；非空在无有效倍数的有界 auto 轴撑满，null 关闭对齐。
  final AlignmentGeometry? alignment;

  /// 原生 Border 或 BorderDirectional，仅覆盖绘制、不占布局；null 表示无边框。
  /// 粗细必须非负且有限，strokeAlign 必须有限；零宽 solid 保留原生 hairline。
  final BoxBorder? border;

  /// 盒外轮廓，仅绘制、不占布局；偏移可将其移入盒内，null 表示不绘制。
  final ElOutline? outline;

  /// 非负有限的背景与边框圆角，支持方向性圆角；有效 clipper 存在时让位。
  final BorderRadiusGeometry? borderRadius;

  /// 裁剪全部视觉的自定义路径；默认抗锯齿，显式 Clip.none 禁用此路径。
  final CustomClipper<Path>? clipper;

  /// 裁剪方式；未指定时自定义路径用 antiAlias，普通盒不裁剪，切换不参与过渡。
  final Clip? clipBehavior;

  /// 过渡声明，合并时整体替换；同一属性由最后一条匹配声明决定。
  final List<ElTransition>? transitions;

  @override
  List<Object?> get props => _props;
}

/// 可过渡的样式属性。
enum ElTransitionField {
  /// 宽度，支持数值、百分比与自动尺寸过渡。
  width,

  /// 高度，支持数值、百分比与自动尺寸过渡。
  height,

  /// 背景色，采用预乘 alpha 插值。
  backgroundColor,

  /// 内边距，null 按零插值。
  padding,

  /// 外边距，null 按零插值。
  margin,

  /// 背景圆角，null 按零插值，仅触发重绘。
  borderRadius,

  /// 自然盒宽度倍数，null 按 1 插值，负过冲夹到零。
  widthFactor,

  /// 自然盒高度倍数，null 按 1 插值，负过冲夹到零。
  heightFactor,

  /// 边框，逐边过渡粗细、预乘 alpha 颜色与描边位置。
  border,

  /// 轮廓粗细、偏移、颜色与渐变，不影响布局。
  outline,

  /// 最小宽度，数值与百分比插值；null 在中点切换。
  minWidth,

  /// 最大宽度，数值与百分比插值；null 在中点切换。
  maxWidth,

  /// 最小高度，数值与百分比插值；null 在中点切换。
  minHeight,

  /// 最大高度，数值与百分比插值；null 在中点切换。
  maxHeight,

  /// 视觉盒宽高比，null 在中点切换，仅正有限数值有效。
  aspectRatio,

  /// 背景渐变，沿原生 Gradient.lerp 规则插值。
  gradient,

  /// 内外阴影的几何与预乘 alpha 颜色，null 平滑退去。
  boxShadow,

  /// 整组透明度，null 按 1 插值，过冲限制在 0～1。
  opacity,

  /// 整组视觉变换，同类函数按参数插值，其他组合逐矩阵分量插值。
  transform,

  /// 变换原点，null 连续回退到当前变换的内部原点或盒中心。
  transformAlignment,

  /// 自身滤镜，各分量从各自恒等值连续过渡。
  filter,

  /// 背景滤镜，各分量从各自恒等值连续过渡。
  backdropFilter,

  /// 内容对齐，两个非空值平滑插值，单侧 null 在中点切换布局模式。
  alignment,

  /// 背景图片，沿官方 DecorationImage.lerp 混合，null 平滑淡入淡出。
  backgroundImage,
}

/// 指定属性的时间过渡，时长和延迟均不得为负。
@immutable
@ElModelGenerator(generateProps: true)
class ElTransition with Equatable {
  /// 创建过渡配置，省略 field 表示全部属性。
  const ElTransition({
    this.field,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOutCubic,
    this.delay = Duration.zero,
  });

  /// 过渡全部属性。
  const ElTransition.all([
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
    this.delay = Duration.zero,
  ]) : field = null;

  /// 过渡指定属性。
  const ElTransition.field(
    ElTransitionField this.field, [
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
    this.delay = Duration.zero,
  ]);

  /// 属性，null 表示全部属性。
  final ElTransitionField? field;

  /// 过渡时长；零时长仍会等待 delay。
  final Duration duration;

  /// 缓动曲线；允许过冲，由具体属性处理有效值边界。
  final Curve curve;

  /// 开始过渡前的等待时间。
  final Duration delay;

  @override
  List<Object?> get props => _props;
}

/// 绘制在盒边界外的轮廓，仅参与绘制，不占用布局空间。
@immutable
@ElModelGenerator(copyWith: true, generateProps: true)
class ElOutline with Equatable {
  /// 创建轮廓，零宽度表示不绘制。
  const ElOutline({this.width = 0, this.color = const Color(0xFF000000), this.gradient, this.offset = 0});

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
  assert(value.width >= 0 && value.width.isFinite && value.offset.isFinite, 'outline 的 width 必须非负且有限，offset 必须有限');
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
    value?.gradient != null && (value!.color.a > 0 || value.gradientOpacity != 1);

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

/// 可与原生 BoxShadow 混用的盒阴影，支持裁在背景之上的内阴影。
@immutable
class ElBoxShadow extends BoxShadow {
  /// 创建阴影；inset 为 true 时绘制在背景之后、内容之前。
  const ElBoxShadow({
    super.color,
    super.offset,
    super.blurRadius,
    super.spreadRadius,
    super.blurStyle,
    this.inset = false,
  });

  /// 是否绘制内阴影，内阴影始终裁在盒子的圆角边界内。
  final bool inset;

  /// 复制阴影，并替换指定的颜色、几何或内外类型。
  @override
  ElBoxShadow copyWith({
    Color? color,
    Offset? offset,
    double? blurRadius,
    double? spreadRadius,
    BlurStyle? blurStyle,
    bool? inset,
  }) => ElBoxShadow(
    color: color ?? this.color,
    offset: offset ?? this.offset,
    blurRadius: blurRadius ?? this.blurRadius,
    spreadRadius: spreadRadius ?? this.spreadRadius,
    blurStyle: blurStyle ?? this.blurStyle,
    inset: inset ?? this.inset,
  );

  /// 按非负有限倍数缩放几何，保留颜色和内外类型。
  @override
  ElBoxShadow scale(double factor) {
    assert(factor >= 0 && factor.isFinite, '阴影缩放倍数必须非负且有限');
    return copyWith(offset: offset * factor, blurRadius: blurRadius * factor, spreadRadius: spreadRadius * factor);
  }

  /// 预乘颜色插值；缺省端淡出并缩小，内外切换经过透明中点。
  static ElBoxShadow? lerp(BoxShadow? a, BoxShadow? b, double t) {
    if (a == b) return a == null ? null : _asElShadow(a);
    final from = a == null ? null : _asElShadow(a);
    final to = b == null ? null : _asElShadow(b);
    if (from != null && to != null && from.inset != to.inset) {
      // 不把正在显示的阴影瞬间翻到另一侧，也不为中断动画追加列表项。
      return t < 0.5 ? lerp(from, null, t * 2) : lerp(null, to, t * 2 - 1);
    }
    final reference = to ?? from!;
    return ElBoxShadow(
      color: _colorLerp(from?.color, to?.color, t) as Color,
      offset: Offset.lerp(from?.offset ?? Offset.zero, to?.offset ?? Offset.zero, t)!,
      blurRadius: math.max(0.0, lerpDouble(from?.blurRadius ?? 0, to?.blurRadius ?? 0, t)!),
      spreadRadius: lerpDouble(from?.spreadRadius ?? 0, to?.spreadRadius ?? 0, t)!,
      blurStyle: t < 0.5 ? (from?.blurStyle ?? reference.blurStyle) : (to?.blurStyle ?? reference.blurStyle),
      inset: reference.inset,
    );
  }

  /// 逐项插值阴影；多出的项目通过透明零几何端点进入或退出。
  static List<ElBoxShadow>? lerpList(List<BoxShadow>? a, List<BoxShadow>? b, double t) {
    if (a == null && b == null) return null;
    final length = math.max(a?.length ?? 0, b?.length ?? 0);
    if (length == 0) return null;
    return List<ElBoxShadow>.generate(
      length,
      (i) => lerp(i < (a?.length ?? 0) ? a![i] : null, i < (b?.length ?? 0) ? b![i] : null, t)!,
      growable: false,
    );
  }

  @override
  bool operator ==(Object other) => other is ElBoxShadow && super == other && inset == other.inset;

  @override
  int get hashCode => Object.hash(super.hashCode, inset);

  @override
  String toString() => '${super.toString()}, inset: $inset';
}

ElBoxShadow _asElShadow(BoxShadow value) => value is ElBoxShadow
    ? value
    : ElBoxShadow(
        color: value.color,
        offset: value.offset,
        blurRadius: value.blurRadius,
        spreadRadius: value.spreadRadius,
        blurStyle: value.blurStyle,
      );

List<ElBoxShadow>? _parseShadows(List<BoxShadow> value) {
  if (value.isEmpty) return null;
  assert(
    value.every(
      (s) =>
          s.offset.dx.isFinite &&
          s.offset.dy.isFinite &&
          s.blurRadius >= 0 &&
          s.blurRadius.isFinite &&
          s.spreadRadius.isFinite &&
          s.color.a.isFinite &&
          s.color.r.isFinite &&
          s.color.g.isFinite &&
          s.color.b.isFinite,
    ),
    '阴影的偏移、扩展、颜色必须有限，模糊半径必须非负且有限',
  );
  return List<ElBoxShadow>.unmodifiable(value.map(_asElShadow));
}

List<ElBoxShadow>? _shadowsLerp(List<ElBoxShadow>? from, List<ElBoxShadow>? to, double t) =>
    ElBoxShadow.lerpList(from, to, t);

bool _hasVisibleShadows(List<ElBoxShadow>? value) => value?.any((shadow) => shadow.color.a > 0) ?? false;

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
    final value = _filterLerp(a == null ? null : _parseFilter(a), b == null ? null : _parseFilter(b), t);
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
  return number.isFinite && number.abs() <= 3.4028234663852886e38 ? number : fallback;
}

double _filterPositive(num? value, [double fallback = 0]) => math.max(0, _filterFinite(value, fallback));

double _filterUnit(num? value, double fallback) => _filterFinite(value, fallback).clamp(0.0, 1.0);

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

// 保留函数来源才能让完整圈旋转及动画中断继续按角度插值。
enum _TransformKind { matrix, identity, translate, scale, rotate, skew, perspective }

/// 不可变的视觉变换，平移使用逻辑像素，旋转和倾斜使用弧度。
@immutable
final class ElTransform {
  const ElTransform._(
    this._kind,
    this.origin, [
    this._a = 0,
    this._b = 0,
    this._c = 0,
    this._d = 0,
    this._e = 0,
    this._f = 0,
    this._g = 0,
    this._h = 0,
    this._i = 0,
    this._j = 0,
    this._k = 0,
    this._l = 0,
    this._m = 0,
    this._n = 0,
    this._o = 0,
    this._p = 0,
  ]);

  /// 创建 CSS matrix(a, b, c, d, tx, ty) 对应的二维变换。
  const ElTransform.matrix(double a, double b, double c, double d, double tx, double ty, {AlignmentGeometry? origin})
    : this.matrix3d(a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1, origin: origin);

  /// 按 Matrix4 列主序创建完整的三维矩阵变换。
  const ElTransform.matrix3d(
    double m00,
    double m01,
    double m02,
    double m03,
    double m10,
    double m11,
    double m12,
    double m13,
    double m20,
    double m21,
    double m22,
    double m23,
    double m30,
    double m31,
    double m32,
    double m33, {
    AlignmentGeometry? origin,
  }) : this._(.matrix, origin, m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23, m30, m31, m32, m33);

  /// 复制外部 Matrix4 的全部分量，之后不受原矩阵修改影响。
  factory ElTransform.matrix4(Matrix4 matrix, {AlignmentGeometry? origin}) {
    final v = matrix.storage;
    return ElTransform.matrix3d(
      v[0],
      v[1],
      v[2],
      v[3],
      v[4],
      v[5],
      v[6],
      v[7],
      v[8],
      v[9],
      v[10],
      v[11],
      v[12],
      v[13],
      v[14],
      v[15],
      origin: origin,
    );
  }

  /// 创建不改变视觉的单位变换。
  const ElTransform.identity() : this._(.identity, null);

  /// 按逻辑像素平移，未指定的 y 和 z 轴位移为零。
  const ElTransform.translate(double x, [double? y, double? z]) : this.translate3d(x, y ?? 0, z ?? 0);

  /// 沿 x 轴按逻辑像素平移。
  const ElTransform.translateX(double x) : this.translate3d(x, 0, 0);

  /// 沿 y 轴按逻辑像素平移。
  const ElTransform.translateY(double y) : this.translate3d(0, y, 0);

  /// 沿 z 轴按逻辑像素平移。
  const ElTransform.translateZ(double z) : this.translate3d(0, 0, z);

  /// 分别指定三个轴的逻辑像素位移。
  const ElTransform.translate3d(double x, double y, double z) : this._(.translate, null, x, y, z);

  /// 缩放三个轴，未指定 y 时与 x 相同，未指定 z 时为一。
  const ElTransform.scale(double x, [double? y, double? z]) : this.scale3d(x, y ?? x, z ?? 1);

  /// 仅缩放 x 轴。
  const ElTransform.scaleX(double x) : this.scale3d(x, 1, 1);

  /// 仅缩放 y 轴。
  const ElTransform.scaleY(double y) : this.scale3d(1, y, 1);

  /// 仅缩放 z 轴。
  const ElTransform.scaleZ(double z) : this.scale3d(1, 1, z);

  /// 分别指定三个轴的缩放系数。
  const ElTransform.scale3d(double x, double y, double z) : this._(.scale, null, x, y, z);

  /// 围绕 z 轴旋转，角度使用弧度且保留完整圈数。
  const ElTransform.rotate(double radians) : this.rotateZ(radians);

  /// 围绕 x 轴按弧度旋转。
  const ElTransform.rotateX(double radians) : this._(.rotate, null, 1, 0, 0, radians);

  /// 围绕 y 轴按弧度旋转。
  const ElTransform.rotateY(double radians) : this._(.rotate, null, 0, 1, 0, radians);

  /// 围绕 z 轴按弧度旋转。
  const ElTransform.rotateZ(double radians) : this._(.rotate, null, 0, 0, 1, radians);

  /// 围绕归一化三维轴按弧度旋转，近零轴等同单位变换。
  factory ElTransform.rotate3d(double x, double y, double z, double radians) {
    if (!x.isFinite || !y.isFinite || !z.isFinite || !radians.isFinite) {
      return const ElTransform.matrix3d(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    }
    final scale = math.max(x.abs(), math.max(y.abs(), z.abs()));
    if (scale == 0) return const ElTransform.identity();
    // 先缩到单位数量级，避免有限的大轴分量在平方求长时溢出。
    final nx = x / scale, ny = y / scale, nz = z / scale;
    final length = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (scale < 1e-12 && scale * length < 1e-12) {
      return const ElTransform.identity();
    }
    return ElTransform._(.rotate, null, nx / length, ny / length, nz / length, radians);
  }

  /// 按弧度分别指定 x 和 y 轴的倾斜角。
  const ElTransform.skew(double xRadians, [double yRadians = 0]) : this._(.skew, null, xRadians, yRadians);

  /// 按弧度指定 x 轴倾斜角。
  const ElTransform.skewX(double radians) : this.skew(radians);

  /// 按弧度指定 y 轴倾斜角。
  const ElTransform.skewY(double radians) : this.skew(0, radians);

  /// 指定透视深度，无效深度由绘制执行器过滤。
  const ElTransform.perspective(double depth) : this._(.perspective, null, depth);

  final _TransformKind _kind;

  // 简单函数只使用前四槽保存参数，原始矩阵才使用全部十六槽。
  final double _a, _b, _c, _d, _e, _f, _g, _h;
  final double _i, _j, _k, _l, _m, _n, _o, _p;

  /// 视觉盒内的变换原点，样式 transformAlignment 优先，未指定时使用中心。
  final AlignmentGeometry? origin;

  /// 创建带指定原点且保留函数来源的副本。
  ElTransform alignment(AlignmentGeometry value) =>
      ElTransform._(_kind, value, _a, _b, _c, _d, _e, _f, _g, _h, _i, _j, _k, _l, _m, _n, _o, _p);

  /// 每次创建独立矩阵，调用者修改结果不会影响变换声明。
  Matrix4 toMatrix4() {
    switch (_kind) {
      case .matrix:
        return Matrix4(_a, _b, _c, _d, _e, _f, _g, _h, _i, _j, _k, _l, _m, _n, _o, _p);
      case .identity:
        return Matrix4.identity();
      case .translate:
        return Matrix4.translationValues(_a, _b, _c);
      case .scale:
        return Matrix4.diagonal3Values(_a, _b, _c);
      case .rotate:
        if (!_d.isFinite) return Matrix4.zero();
        final c = math.cos(_d), s = math.sin(_d), t = 1 - c;
        return Matrix4(
          c + _a * _a * t,
          _b * _a * t + _c * s,
          _c * _a * t - _b * s,
          0,
          _a * _b * t - _c * s,
          c + _b * _b * t,
          _c * _b * t + _a * s,
          0,
          _a * _c * t + _b * s,
          _b * _c * t - _a * s,
          c + _c * _c * t,
          0,
          0,
          0,
          0,
          1,
        );
      case .skew:
        if (!_a.isFinite || !_b.isFinite) return Matrix4.zero();
        return Matrix4(1, math.tan(_b), 0, 0, math.tan(_a), 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
      case .perspective:
        if (!_a.isFinite || _a == 0) return Matrix4.zero();
        return Matrix4.identity()..setEntry(3, 2, -1 / _a);
    }
  }

  /// 同类函数插参数，其他变换逐矩阵分量插值，null 以单位变换补位。
  static ElTransform? lerp(ElTransform? start, ElTransform? end, double t) {
    if (identical(start, end) || t == 0) return start;
    if (t == 1) return end;
    final a = start ?? const ElTransform.identity();
    final b = end ?? const ElTransform.identity();
    final AlignmentGeometry? pivot;
    if (a._kind == .identity && b._kind != .identity) {
      pivot = b.origin;
    } else if (b._kind == .identity && a._kind != .identity) {
      pivot = a.origin;
    } else {
      pivot = a.origin == null && b.origin == null
          ? null
          : AlignmentGeometry.lerp(a.origin ?? Alignment.center, b.origin ?? Alignment.center, t);
    }
    final result = _lerpFunction(a, b, t);
    if (result != null) return pivot == null ? result : result.alignment(pivot);
    final av = a.toMatrix4().storage, bv = b.toMatrix4().storage;
    return ElTransform.matrix3d(
      _mix(av[0], bv[0], t),
      _mix(av[1], bv[1], t),
      _mix(av[2], bv[2], t),
      _mix(av[3], bv[3], t),
      _mix(av[4], bv[4], t),
      _mix(av[5], bv[5], t),
      _mix(av[6], bv[6], t),
      _mix(av[7], bv[7], t),
      _mix(av[8], bv[8], t),
      _mix(av[9], bv[9], t),
      _mix(av[10], bv[10], t),
      _mix(av[11], bv[11], t),
      _mix(av[12], bv[12], t),
      _mix(av[13], bv[13], t),
      _mix(av[14], bv[14], t),
      _mix(av[15], bv[15], t),
      origin: pivot,
    );
  }

  static double _mix(double a, double b, double t) => a == b ? a : a * (1 - t) + b * t;

  static (double, double, double, double) _neutral(_TransformKind kind, ElTransform other) => switch (kind) {
    .scale => (1, 1, 1, 0),
    .rotate => (other._a, other._b, other._c, 0),
    _ => (0, 0, 0, 0),
  };

  static ElTransform? _lerpFunction(ElTransform a, ElTransform b, double t) {
    final kind = a._kind == .identity ? b._kind : a._kind;
    if (kind == .matrix || kind == .perspective) return null;
    if (a._kind != b._kind && a._kind != .identity && b._kind != .identity) {
      return null;
    }
    final (ax, ay, az, angleA) = a._kind == .identity ? _neutral(kind, b) : (a._a, a._b, a._c, a._d);
    final (bx, by, bz, angleB) = b._kind == .identity ? _neutral(kind, a) : (b._a, b._b, b._c, b._d);
    return switch (kind) {
      .identity => const ElTransform.identity(),
      .translate => ElTransform.translate3d(_mix(ax, bx, t), _mix(ay, by, t), _mix(az, bz, t)),
      .scale => ElTransform.scale3d(_mix(ax, bx, t), _mix(ay, by, t), _mix(az, bz, t)),
      .skew => ElTransform.skew(_mix(ax, bx, t), _mix(ay, by, t)),
      .rotate => _lerpRotation(ax, ay, az, angleA, bx, by, bz, angleB, t),
      .matrix || .perspective => null,
    };
  }

  static ElTransform? _lerpRotation(
    double ax,
    double ay,
    double az,
    double angleA,
    double bx,
    double by,
    double bz,
    double angleB,
    double t,
  ) {
    if (angleA == 0) {
      return ElTransform.rotate3d(bx, by, bz, _mix(angleA, angleB, t));
    }
    if (angleB == 0 || ((ax - bx).abs() <= 1e-9 && (ay - by).abs() <= 1e-9 && (az - bz).abs() <= 1e-9)) {
      return ElTransform.rotate3d(ax, ay, az, _mix(angleA, angleB, t));
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElTransform &&
          _kind == other._kind &&
          origin == other.origin &&
          _a == other._a &&
          _b == other._b &&
          _c == other._c &&
          _d == other._d &&
          _e == other._e &&
          _f == other._f &&
          _g == other._g &&
          _h == other._h &&
          _i == other._i &&
          _j == other._j &&
          _k == other._k &&
          _l == other._l &&
          _m == other._m &&
          _n == other._n &&
          _o == other._o &&
          _p == other._p;

  @override
  int get hashCode => Object.hash(_kind, origin, _a, _b, _c, _d, _e, _f, _g, _h, _i, _j, _k, _l, _m, _n, _o, _p);
}
