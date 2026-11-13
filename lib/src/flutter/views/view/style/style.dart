import 'dart:math' as math;
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../../../dart.dart';

part 'style.g.dart';
part 'shadow.dart';
part 'shadow/contact.dart';
part 'shadow/floating.dart';
part 'shadow/glow.dart';
part 'shadow/inset.dart';
part 'shadow/material.dart';
part 'shadow/uniform.dart';
part '../text/text_options.dart';

/// ElView 的声明式样式。
@ElModelGenerator.copy(generateProps: true)
@immutable
class ElStyle with Equatable {
  /// 创建样式。
  const ElStyle({
    this.vars,
    this.textOptions,
    // 常用文本样式
    this.color,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.fontFamily,
    this.fontFamilyFallback,
    this.lineHeight,
    this.letterSpacing,
    this.wordSpacing,
    this.fontFeatureSettings,
    this.textAlign,
    this.textShadow,
    this.textGradient,
    this.textDecorationLine,
    this.textDecorationColor,
    this.textDecorationStyle,
    this.textDecorationThickness,
    this.textBackgroundColor,
    this.fontVariationSettings,
    this.softWrap,
    this.textOverflow,
    this.maxLines,
    // InheritedBox (5)
    this.direction,
    this.cursor,
    this.pointerEvents,
    this.iconSize,
    this.iconColor,
    this.userSelect,
    // Box (26)
    this.width,
    this.height,
    this.widthFactor,
    this.heightFactor,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.alignment,
    this.border,
    this.borderRadius,
    this.clipPath,
    this.boxShadow,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.opacity,
    this.transform,
    this.transformOrigin,
    this.clipBehavior,
    this.gradient,
    this.backgroundImage,
    this.outline,
    this.aspectRatio,
    this.filter,
    this.backdropFilter,
    // Responsive breakpoint variants (5) — 优先级低于全部交互变体
    this.xs,
    this.sm,
    this.md,
    this.lg,
    this.xl,
    // State variants (9)
    this.onHover,
    this.onTap,
    this.onFocus,
    this.onFocusVisible,
    this.onFocusWithin,
    this.onDisabled,
    this.onSelection,
    this.onDark,
    // Transitions
    this.transition,
    // Keyframe animation
    this.animation,
    // Enter starting style
    this.starting,
  }) : assert(
         clipPath == null || borderRadius == null,
         '裁剪/圆角字段互斥：声明 clipPath 时，borderRadius 会被忽略 '
         '（优先级 clipPath > borderRadius）',
       );

  /// 合并实际样式值，后声明的非空字段覆盖当前字段。
  ElStyle merge([ElStyle? other]) => other == null ? this : ElStyleExt(this).merge(other);

  /// 后代可读取的变量，按 key 继承并由当前层及命中变体覆盖，键遵循 Map 的相等规则。
  @ElFieldGenerator(useMerge: true)
  final Map<Object, Object>? vars;

  /// 仅作用于当前文本的高级配置，不继承且不接受状态、断点、入场或关键帧变体。
  final ElTextOptions? textOptions;

  /// 文本色。继承字段。
  final Color? color;

  /// 字号。继承字段。
  final double? fontSize;

  /// 字重。继承字段。保持强类型 `FontWeight?`——不做 var 槽，否则
  /// `fontWeight: .w500` 点简写失去类型上下文。
  final FontWeight? fontWeight;

  /// 字形（斜体）。继承字段。
  final FontStyle? fontStyle;

  /// 字体族。继承字段。
  final String? fontFamily;

  /// 字体回退族列表。继承字段。
  final List<String>? fontFamilyFallback;

  /// OpenType 字体特性（CSS `font-feature-settings`，如 `tnum` / `liga` / `smcp`）。
  /// 继承字段。
  final List<FontFeature>? fontFeatureSettings;

  /// 装饰线颜色（CSS `text-decoration-color`，独立于文字色）。继承字段。
  ///
  final Color? textDecorationColor;

  /// 装饰线样式（CSS `text-decoration-style`，实线/虚线/波浪线等）。继承字段。
  final TextDecorationStyle? textDecorationStyle;

  /// 装饰线粗细（CSS `text-decoration-thickness`）。继承字段。
  final double? textDecorationThickness;

  /// 可变字体轴设置（CSS `font-variation-settings`，如 `wght` / `wdth` / `slnt`）。继承字段。
  /// 按 Flutter 规则原样传递，显式 wght 覆盖 fontWeight；空列表清除继承轴。
  final List<FontVariation>? fontVariationSettings;

  /// 行高倍数。继承字段。
  final double? lineHeight;

  /// 字符间距。继承字段。
  final double? letterSpacing;

  /// 单词间距。继承字段。
  final double? wordSpacing;

  /// 文本对齐。继承字段。
  final TextAlign? textAlign;

  /// 文本阴影。继承字段。
  final List<Shadow>? textShadow;

  /// 文字渐变（CSS `background-clip: text` + 渐变背景的一等等价）。继承字段。
  /// 字形绘制段蒙渐变，选中高亮/换色不受影响。
  final Gradient? textGradient;

  /// 文本装饰线类型（CSS `text-decoration-line`）。非继承字段。
  final TextDecoration? textDecorationLine;

  /// 文本背景色。非继承字段。
  final Color? textBackgroundColor;

  /// 软换行。非继承字段。
  final bool? softWrap;

  /// 文本溢出策略（CSS `text-overflow` 的 Flutter 子集）。非继承字段。
  final TextOverflow? textOverflow;

  /// 最大行数。非继承字段。
  final int? maxLines;

  /// 文本方向（CSS `direction`，LTR / RTL）。继承字段。
  final TextDirection? direction;

  /// 鼠标光标。继承字段。
  final MouseCursor? cursor;

  /// 指针命中行为（CSS `pointer-events` 子集，见 [ElPointerEvents]）。继承字段：
  /// [ElPointerEvents.none] 使节点自身与非 El 内容对指针透明（命中穿透到下层），
  /// El 后代显式声明 [ElPointerEvents.auto] 可局部重新启用。
  final ElPointerEvents? pointerEvents;

  /// 图标字号。继承字段。
  final double? iconSize;

  /// 图标颜色。继承字段。
  final Color? iconColor;

  /// 选中文本行为（CSS `user-select` 子集，见 [ElUserSelect]）。只由
  /// [ElSelectionView] / 参与者的选区注册逻辑读取，不进入 cascade；
  /// 自下而上**最近显式声明**生效（auto / 未声明继续向上，text / all
  /// 抵消祖先 none，all 原子整选）。
  final ElUserSelect? userSelect;

  /// 节点宽度。
  final Object? width;

  /// 节点高度。接受形态同 [width]；**auto 决策流程相同**（轴对调，百分比
  /// 参照 containing 可用高度）。
  final Object? height;

  /// auto 宽度相对自然盒宽度的系数，作用等同 Flutter Align.widthFactor。
  final double? widthFactor;

  /// auto 高度相对自然盒高度的系数，作用等同 Flutter Align.heightFactor。
  final double? heightFactor;

  /// 节点背景色（CSS `background-color`）。
  final Color? backgroundColor;

  /// 原生内边距，支持物理边和逻辑边，按当前文字方向解析。
  final EdgeInsetsGeometry? padding;

  /// 外边距。Layout 影响。形态同 [padding]（支持负值边）。
  final EdgeInsetsGeometry? margin;

  /// 单 child 在节点内容区内的对齐（Flutter `Container.alignment` 语义）。
  /// 子对齐。null = 贴左上（不显式撑满父）。
  /// 多子对齐请用外层 Flutter `Row` / `Column` / `Stack`。
  final AlignmentGeometry? alignment;

  /// 边框。**仅绘制，永不参与布局**（2026-07-04 用户裁决——同 [outline]，
  /// 只是允许精确绘制具体某条边）。不占 content 空间、不进 intrinsic、不影响
  /// 子/兄弟位置；hover/tap 改边框粗细不会引起周围元素平移。
  final ElBorder? border;

  /// 圆角。Paint-only。
  final BorderRadiusGeometry? borderRadius;

  /// 裁剪路径（CSS `clip-path`，由 Flutter 的 CustomClipper 提供形状）。Paint-only。
  final CustomClipper<Path>? clipPath;

  /// 盒阴影列表。Paint-only。
  final List<BoxShadow>? boxShadow;

  /// 最小宽度约束。形态同 [width]（数值或百分比）。
  /// [width] 为 auto 时：抬高盒宽下限，也会抬高传给 child 的 minWidth。
  final Object? minWidth;

  /// 最大宽度约束。形态同 [width]。auto 时：cap 盒宽上限（优先级高于 hug）。
  final Object? maxWidth;

  /// 最小高度约束。形态同 [width]。Layout 影响。
  final Object? minHeight;

  /// 最大高度约束。形态同 [width]。Layout 影响。
  final Object? maxHeight;

  /// 透明度（0~1）。Paint-only。
  final double? opacity;

  /// 视觉变换。Paint-only。
  final ElTransform? transform;

  /// 变换原点对齐（CSS `transform-origin`）。Paint-only。
  final AlignmentGeometry? transformOrigin;

  /// 裁剪行为。Paint-only。
  final Clip? clipBehavior;

  /// 渐变背景。Paint-only。Paint 顺序：backgroundColor < backgroundImage < gradient（CSS 短手默认）。
  ///
  final Gradient? gradient;

  /// 背景图（CSS `background-image`，含 fit/alignment/repeat）。Paint-only。Paint 顺序：在 backgroundColor 之上、
  /// gradient 之下。
  final DecorationImage? backgroundImage;

  /// 描边（CSS outline）。Paint-only。**永远不影响 layout**（与 border 的唯一区别）。
  ///
  /// [ElOutline] 聚合 outlineWidth / outlineColor / gradient / outlineOffset 四个属性。
  /// 自动支持 null ↔ value 平滑过渡（width / color alpha / offset 同时从 0 渐入）
  /// 与自适应圆角外推算法（解决小圆角 + 大 offset 时变胶囊的失真）。
  final ElOutline? outline;

  /// 宽高比（width÷height）。Layout 影响 —— 与 width/height/min-max 协同。
  ///
  final double? aspectRatio;

  /// 自身滤镜（CSS `filter`）。Paint-only。
  final ElFilter? filter;

  /// backdrop filter（毛玻璃 / 背景模糊，CSS `backdrop-filter`）。Paint-only。
  final ElFilter? backdropFilter;

  /// 响应式：处于极小布局（<=320）时生效。
  final ElStyle? xs;

  /// 响应式：处于移动端布局（<=640）时生效。见 [xs] 优先级说明。
  final ElStyle? sm;

  /// 响应式：处于平板布局（<=1024）时生效。见 [xs] 优先级说明。
  final ElStyle? md;

  /// 响应式：处于桌面布局（<=1920）时生效。见 [xs] 优先级说明。
  final ElStyle? lg;

  /// 响应式：处于超大桌面布局（<=2560）时生效。见 [xs] 优先级说明。
  final ElStyle? xl;

  /// 鼠标悬停状态变体。
  final ElStyle? onHover;

  /// 主键按下期间的 tap 状态变体。
  final ElStyle? onTap;

  /// 节点获取焦点状态变体。
  final ElStyle? onFocus;

  /// 键盘导航焦点变体：Tab 或实际键盘换焦开启，鼠标或触摸按下收起。
  /// 方向键单纯用于滚动或编辑时不会开启。
  /// 普通文字输入、程序聚焦与生命周期恢复不会自行开启；同一 View 内的
  /// 后续焦点转移沿用导航状态。焦点环声明在这里，优先级紧邻 [onFocus] 之上。
  final ElStyle? onFocusVisible;

  /// 节点或后代获取焦点状态变体。
  final ElStyle? onFocusWithin;

  /// 禁用状态变体。
  final ElStyle? onDisabled;

  /// **选区伪类**（对齐 CSS `::selection`）：内容被文本选区选中时的 overlay 样式。
  final ElStyle? onSelection;

  /// 暗色主题状态变体。
  final ElStyle? onDark;

  /// 字段过渡声明列表。同字段后定义的覆盖前定义的。
  ///
  /// **整体替换**（CSS `transition` 单条声明口径）：merge 后表非 null 即整表
  /// 覆前表,勿加 useMerge。
  final List<ElTransition>? transition;

  /// 关键帧动画声明列表（CSS `animation` + `@keyframes` 等价物，见 [ElAnimation]）。
  ///
  /// **整体替换**（同 [transition]）：变体声明的表按 longhand 覆盖语义整表替换
  /// base 表（如 `onHover: ElStyle(animation: [])` 在 hover 时停掉全部动画）。
  /// 同字段被多条动画覆盖时靠后者胜出（CSS `animation-name` 列表序）。
  /// 动画驱动的字段变化不触发 transition（CSS 口径）。
  final List<ElAnimation>? animation;

  /// 入场起始样式（CSS `@starting-style` 等价物）。
  final ElStyle? starting;

  @override
  List<Object?> get props => _props;
}

/// [ElTransform] 的来源函数标记，供 [ElTransform.lerp] 走 CSS 函数插值口径。
///
/// CSS 对同类 transform 函数按参数插值（rotate 插角度、skew 插角度），只有
/// 函数不兼容时才退化到矩阵插值；纯矩阵插值表达不了 ≥180° 的旋转（元素过零
/// 塌缩），0→2π 更是首尾同矩阵直接静止。构造时把函数种类与原始参数留档，
/// lerp 端点同类即可按参数插值。
enum _TransformFn {
  /// 手写矩阵 / perspective / 无法归类：只能矩阵插值。
  matrix,

  /// identity：作为任意函数的中性端点参与插值。
  identity,

  /// translate3d(x, y, z)：参数 a/b/c。
  translate,

  /// scale3d(x, y, z)：参数 a/b/c。
  scale,

  /// rotate3d(axisX, axisY, axisZ, angle)：参数 a/b/c 为归一化轴，d 为弧度。
  rotate,

  /// skew(xRadians, yRadians)：参数 a/b。
  skew,
}

/// 来源函数的四个参数，按同一条记录传递。
typedef _TransformParameters = (double, double, double, double);

/// 视觉变换表达式。
///
/// 用于 `ElStyle(transform: ...)`，支持 CSS transform 便捷构造和点简写
/// `const .scale(...)` / `const .translate(...)`。内部渲染时会转换为 [Matrix4]，
/// 并与 `transformOrigin` 或 [origin] 一起组成最终 paint / hit-test 矩阵。
@immutable
final class ElTransform {
  /// 矩阵与来源参数分开保存，旋转过渡保留原始角度。
  const ElTransform._data(this._matrix, this.origin, this._fn, this._parameters);

  /// 创建 CSS `matrix(a, b, c, d, tx, ty)` 二维矩阵变换。
  const ElTransform.matrix(double a, double b, double c, double d, double tx, double ty, {AlignmentGeometry? origin})
    : this._data((a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1), origin, .matrix, (0, 0, 0, 0));

  /// 创建 CSS `matrix3d(...)` 三维矩阵变换。
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
  }) : this._data(
         (m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23, m30, m31, m32, m33),
         origin,
         .matrix,
         (0, 0, 0, 0),
       );

  /// 创建 identity 变换。
  const ElTransform.identity()
    : this._data((1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1), null, .identity, (0, 0, 0, 0));

  /// 创建 CSS `translate(x[, y[, z]])` 平移变换。
  const ElTransform.translate(double x, [double? y, double? z]) : this.translate3d(x, y ?? 0.0, z ?? 0.0);

  /// 创建 CSS `translateX(x)` 平移变换。
  const ElTransform.translateX(double x) : this.translate3d(x, 0.0, 0.0);

  /// 创建 CSS `translateY(y)` 平移变换。
  const ElTransform.translateY(double y) : this.translate3d(0.0, y, 0.0);

  /// 创建 CSS `translateZ(z)` 平移变换。
  const ElTransform.translateZ(double z) : this.translate3d(0.0, 0.0, z);

  /// 创建 CSS `translate3d(x, y, z)` 平移变换。
  const ElTransform.translate3d(double x, double y, double z)
    : this._data((1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1), null, .translate, (x, y, z, 0));

  /// 创建 CSS `scale(x[, y[, z]])` 缩放变换。
  ///
  /// 只传 [x] 时 x/y 轴同缩放；传 [y] 时分别表示 x/y 轴缩放；传 [z] 时
  /// 同时写入 Matrix4 的 z 轴缩放分量。需要设置原点时使用 `.alignment(...)`
  /// 链式设置。
  const ElTransform.scale(double x, [double? y, double? z]) : this.scale3d(x, y ?? x, z ?? 1.0);

  /// 创建 CSS `scaleX(x)` 缩放变换。
  const ElTransform.scaleX(double x) : this.scale3d(x, 1.0, 1.0);

  /// 创建 CSS `scaleY(y)` 缩放变换。
  const ElTransform.scaleY(double y) : this.scale3d(1.0, y, 1.0);

  /// 创建 CSS `scaleZ(z)` 缩放变换。
  const ElTransform.scaleZ(double z) : this.scale3d(1.0, 1.0, z);

  /// 创建 CSS `scale3d(x, y, z)` 缩放变换。
  const ElTransform.scale3d(double x, double y, double z)
    : this._data((x, 0, 0, 0, 0, y, 0, 0, 0, 0, z, 0, 0, 0, 0, 1), null, .scale, (x, y, z, 0));

  /// 创建 CSS `rotate(angle)` / `rotateZ(angle)` 旋转变换，角度单位为弧度。
  factory ElTransform.rotate(double radians) {
    return ElTransform.rotateZ(radians);
  }

  /// 创建 CSS `rotateX(angle)` 旋转变换，角度单位为弧度。
  factory ElTransform.rotateX(double radians) => ElTransform.rotate3d(1, 0, 0, radians);

  /// 创建 CSS `rotateY(angle)` 旋转变换，角度单位为弧度。
  factory ElTransform.rotateY(double radians) => ElTransform.rotate3d(0, 1, 0, radians);

  /// 创建 CSS `rotateZ(angle)` 旋转变换，角度单位为弧度。
  factory ElTransform.rotateZ(double radians) => ElTransform.rotate3d(0, 0, 1, radians);

  /// 创建 CSS `rotate3d(x, y, z, angle)` 旋转变换，角度单位为弧度。
  factory ElTransform.rotate3d(double x, double y, double z, double radians) {
    final length = math.sqrt(x * x + y * y + z * z);
    // < 1e-12：除以极小 length 会让 nx/ny/nz 变成 ±Inf / NaN，污染后续矩阵分量
    if (length < 1e-12) return const ElTransform.identity();
    final nx = x / length;
    final ny = y / length;
    final nz = z / length;
    final c = math.cos(radians);
    final s = math.sin(radians);
    final oneMinusC = 1.0 - c;
    return ElTransform._data(
      (
        c + nx * nx * oneMinusC,
        ny * nx * oneMinusC + nz * s,
        nz * nx * oneMinusC - ny * s,
        0,
        nx * ny * oneMinusC - nz * s,
        c + ny * ny * oneMinusC,
        nz * ny * oneMinusC + nx * s,
        0,
        nx * nz * oneMinusC + ny * s,
        ny * nz * oneMinusC - nx * s,
        c + nz * nz * oneMinusC,
        0,
        0,
        0,
        0,
        1,
      ),
      null,
      .rotate,
      (nx, ny, nz, radians),
    );
  }

  /// 创建 CSS `skew(xAngle[, yAngle])` 倾斜变换，角度单位为弧度。
  factory ElTransform.skew(double xRadians, [double yRadians = 0.0]) {
    return ElTransform._data(
      (1, math.tan(yRadians), 0, 0, math.tan(xRadians), 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1),
      null,
      .skew,
      (xRadians, yRadians, 0, 0),
    );
  }

  /// 创建 CSS `skewX(angle)` 倾斜变换，角度单位为弧度。
  factory ElTransform.skewX(double radians) {
    return ElTransform.skew(radians);
  }

  /// 创建 CSS `skewY(angle)` 倾斜变换，角度单位为弧度。
  factory ElTransform.skewY(double radians) {
    return ElTransform.skew(0.0, radians);
  }

  /// 创建 CSS `perspective(depth)` 透视变换。
  const ElTransform.perspective(double depth)
    : this.matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -1.0 / depth, 0, 0, 0, 1);

  /// 从 [Matrix4] 的完整 4x4 分量创建变换。
  ///
  /// 读取 `Matrix4.storage` 的 16 个分量，避免丢失 3D / perspective 信息。
  factory ElTransform.matrix4(Matrix4 matrix, {AlignmentGeometry? origin}) {
    final values = matrix.storage;
    return ElTransform.matrix3d(
      values[0],
      values[1],
      values[2],
      values[3],
      values[4],
      values[5],
      values[6],
      values[7],
      values[8],
      values[9],
      values[10],
      values[11],
      values[12],
      values[13],
      values[14],
      values[15],
      origin: origin,
    );
  }

  /// 变换原点；未指定时由样式的 `transformOrigin` 或中心点决定。
  final AlignmentGeometry? origin;

  final (
    double,
    double,
    double,
    double,
    double,
    double,
    double,
    double,
    double,
    double,
    double,
    double,
    double,
    double,
    double,
    double,
  )
  _matrix;
  final _TransformFn _fn;
  final _TransformParameters _parameters;

  /// 创建带新变换原点的副本。
  ElTransform alignment(AlignmentGeometry value) => ElTransform._data(_matrix, value, _fn, _parameters);

  /// 转换为 Flutter 绘制矩阵。
  Matrix4 toMatrix4() {
    return Matrix4(
      _matrix.$1,
      _matrix.$2,
      _matrix.$3,
      _matrix.$4,
      _matrix.$5,
      _matrix.$6,
      _matrix.$7,
      _matrix.$8,
      _matrix.$9,
      _matrix.$10,
      _matrix.$11,
      _matrix.$12,
      _matrix.$13,
      _matrix.$14,
      _matrix.$15,
      _matrix.$16,
    );
  }

  /// 在两个变换间插值。
  static ElTransform? lerp(ElTransform? start, ElTransform? end, double t) {
    if (identical(start, end) || t <= 0.0) return start;
    if (t >= 1.0) return end;
    final effectiveStart = start ?? const ElTransform.identity();
    final effectiveEnd = end ?? const ElTransform.identity();
    final origin = t < 0.5 ? start?.origin : end?.origin;
    final byFn = _lerpByFn(effectiveStart, effectiveEnd, t, origin);
    if (byFn != null) return byFn;
    return ElTransform.matrix3d(
      lerpDouble(effectiveStart._matrix.$1, effectiveEnd._matrix.$1, t)!,
      lerpDouble(effectiveStart._matrix.$2, effectiveEnd._matrix.$2, t)!,
      lerpDouble(effectiveStart._matrix.$3, effectiveEnd._matrix.$3, t)!,
      lerpDouble(effectiveStart._matrix.$4, effectiveEnd._matrix.$4, t)!,
      lerpDouble(effectiveStart._matrix.$5, effectiveEnd._matrix.$5, t)!,
      lerpDouble(effectiveStart._matrix.$6, effectiveEnd._matrix.$6, t)!,
      lerpDouble(effectiveStart._matrix.$7, effectiveEnd._matrix.$7, t)!,
      lerpDouble(effectiveStart._matrix.$8, effectiveEnd._matrix.$8, t)!,
      lerpDouble(effectiveStart._matrix.$9, effectiveEnd._matrix.$9, t)!,
      lerpDouble(effectiveStart._matrix.$10, effectiveEnd._matrix.$10, t)!,
      lerpDouble(effectiveStart._matrix.$11, effectiveEnd._matrix.$11, t)!,
      lerpDouble(effectiveStart._matrix.$12, effectiveEnd._matrix.$12, t)!,
      lerpDouble(effectiveStart._matrix.$13, effectiveEnd._matrix.$13, t)!,
      lerpDouble(effectiveStart._matrix.$14, effectiveEnd._matrix.$14, t)!,
      lerpDouble(effectiveStart._matrix.$15, effectiveEnd._matrix.$15, t)!,
      lerpDouble(effectiveStart._matrix.$16, effectiveEnd._matrix.$16, t)!,
      origin: origin,
    );
  }

  /// rotate 轴向量比对容差（构造侧已归一化，仅吸收浮点噪声）。
  static const double _axisEpsilon = 1e-9;

  /// 同类来源函数按参数插值；不可按函数插值时返回 null，调用方回退矩阵插值。
  static ElTransform? _lerpByFn(ElTransform start, ElTransform end, double t, AlignmentGeometry? origin) {
    final sFn = start._fn;
    final eFn = end._fn;
    if (sFn == _TransformFn.matrix || eFn == _TransformFn.matrix) return null;
    ElTransform? result;
    if (sFn == _TransformFn.identity && eFn == _TransformFn.identity) {
      result = const ElTransform.identity();
    } else if (sFn == eFn || sFn == _TransformFn.identity || eFn == _TransformFn.identity) {
      final fn = sFn == _TransformFn.identity ? eFn : sFn;
      // identity 端以对侧函数的中性参数补位（CSS `none ↔ 函数` 同口径）。
      final from = sFn == _TransformFn.identity ? _neutralParamsOf(fn, end) : start._parameters;
      final to = eFn == _TransformFn.identity ? _neutralParamsOf(fn, start) : end._parameters;
      result = switch (fn) {
        _TransformFn.translate => ElTransform.translate3d(
          lerpDouble(from.$1, to.$1, t)!,
          lerpDouble(from.$2, to.$2, t)!,
          lerpDouble(from.$3, to.$3, t)!,
        ),
        _TransformFn.scale => ElTransform.scale3d(
          lerpDouble(from.$1, to.$1, t)!,
          lerpDouble(from.$2, to.$2, t)!,
          lerpDouble(from.$3, to.$3, t)!,
        ),
        _TransformFn.skew => ElTransform.skew(lerpDouble(from.$1, to.$1, t)!, lerpDouble(from.$2, to.$2, t)!),
        _TransformFn.rotate => _lerpRotate(from, to, t),
        // 不可达：identity 组合已在上方分支处理，matrix 已提前返回。
        _TransformFn.identity || _TransformFn.matrix => null,
      };
    }
    if (result == null) return null;
    return origin == null ? result : result.alignment(origin);
  }

  /// 来源函数的中性参数（CSS 中性元素）：translate 全 0、scale 全 1、skew
  /// 全 0、rotate 取对侧 [other] 的轴 + 零角。
  static _TransformParameters _neutralParamsOf(_TransformFn fn, ElTransform other) {
    return switch (fn) {
      _TransformFn.scale => (1.0, 1.0, 1.0, 0.0),
      _TransformFn.rotate => (other._parameters.$1, other._parameters.$2, other._parameters.$3, 0.0),
      _ => (0.0, 0.0, 0.0, 0.0),
    };
  }

  /// rotate 角度插值：零角端点轴任意（取对侧轴），否则轴一致才可插角度，
  /// 轴不同返回 null 回退矩阵插值。
  static ElTransform? _lerpRotate(_TransformParameters from, _TransformParameters to, double t) {
    final _TransformParameters axis;
    if (from.$4 == 0.0) {
      axis = to;
    } else if (to.$4 == 0.0 ||
        ((from.$1 - to.$1).abs() <= _axisEpsilon &&
            (from.$2 - to.$2).abs() <= _axisEpsilon &&
            (from.$3 - to.$3).abs() <= _axisEpsilon)) {
      axis = from;
    } else {
      return null;
    }
    return ElTransform.rotate3d(axis.$1, axis.$2, axis.$3, lerpDouble(from.$4, to.$4, t)!);
  }

  @override
  bool operator ==(Object other) => other is ElTransform && other._matrix == _matrix && other.origin == origin;

  @override
  int get hashCode => Object.hash(_matrix, origin);
}

// ============================================================================
// 状态变体
// ============================================================================

// ============================================================================
// 字段过渡（动画字段 + 过渡声明）
// ============================================================================

/// 所有可动画字段的 ID 枚举。
enum ElTransitionField {
  // ===== Group: 常用文本样式 =====

  /// 文本色。
  color,

  /// 字号。
  fontSize,

  /// 字重。
  fontWeight,

  /// 字形（斜体）。
  fontStyle,

  /// 字体族。
  fontFamily,

  /// 行高（[TextStyle.height] 倍数）。
  lineHeight,

  /// 字符间距。
  letterSpacing,

  /// 单词间距。
  wordSpacing,

  /// 文本对齐。
  textAlign,

  /// 文本阴影列表。
  textShadow,

  textGradient,

  /// 文本装饰（下划线 / 中划线 等）。
  textDecorationLine,

  /// 装饰线颜色（独立于文字色）。
  textDecorationColor,

  /// 装饰线样式（实线/虚线/波浪线等）。
  textDecorationStyle,

  /// 装饰线粗细（相对 fontSize 的倍数）。
  textDecorationThickness,

  /// 字体回退族列表（fontFamily 失败时按序尝试）。
  fontFamilyFallback,

  /// OpenType 字体特性（`tnum`/`liga`/`smcp` 等）。
  fontFeatureSettings,

  /// 文本背景色（vs `backgroundColor` 是节点背景）。
  textBackgroundColor,

  /// 是否允许软换行。
  softWrap,

  /// 文本溢出策略。
  textOverflow,

  /// 最大行数。
  maxLines,

  /// Variable Font 的可变轴（`wght` / `wdth` 等）。继承字段。
  fontVariationSettings,

  // ===== Group: InheritedBox (5) =====

  /// 文本方向（LTR / RTL）。
  direction,

  /// 鼠标光标。
  cursor,

  /// 指针命中行为（离散字段，不参与过渡）。
  pointerEvents,

  /// 图标字号（独立于文本字号通道，图标 glyph 专用）。
  iconSize,

  /// 图标颜色（独立于文字色通道，图标 glyph 专用）。
  iconColor,

  // ===== Group: Box (26) =====

  /// 节点宽度（像素）。
  width,

  /// 节点高度（像素）。
  height,

  /// auto 宽度相对自然盒宽度的系数。Layout 影响。
  widthFactor,

  /// auto 高度相对自然盒高度的系数。Layout 影响。
  heightFactor,

  /// 节点背景色。
  backgroundColor,

  /// 内边距。Layout 影响（待 layout 接入）。
  padding,

  /// 外边距。Layout 影响（待 layout 接入）。
  margin,

  /// 单 child 在容器内的对齐（Flutter `Container.alignment` 语义）。Layout 影响。
  alignment,

  /// 边框。Paint-only（2026-07-04 用户裁决：border 仅绘制，不参与布局）。
  border,

  /// 圆角。Paint-only（不影响 box 尺寸）。[BorderRadiusGeometry]
  /// 自研类型，吸收旧 round / circle 枚举值（独立 transition 通道随之消失，
  /// 单 borderRadius 通道 last-wins，计划 §0.7 用户知情接受）。
  borderRadius,

  /// 自定义裁剪形状（[CustomClipper]\<Path\>）。Paint-only，lerp = step。
  clipPath,

  /// 盒阴影列表。Paint-only。
  boxShadow,

  /// 最小宽度约束。Layout 影响。
  minWidth,

  /// 最大宽度约束。Layout 影响。
  maxWidth,

  /// 最小高度约束。Layout 影响。
  minHeight,

  /// 最大高度约束。Layout 影响。
  maxHeight,

  /// 透明度（0~1）。Paint-only。
  opacity,

  /// 变换矩阵。Paint-only。
  transform,

  /// 变换原点对齐。Paint-only。
  transformOrigin,

  /// 裁剪行为。Paint-only。
  clipBehavior,

  /// 渐变背景（线性 / 径向 / 扫描）。Paint-only。在 backgroundImage 之上、children 之下。
  gradient,

  /// 背景图（DecorationImage 含 image/fit/alignment/repeat）。Paint-only。
  /// 在 backgroundColor 之上、gradient 之下。
  backgroundImage,

  /// 描边（[ElOutline] 聚合：outlineWidth / outlineColor / gradient / outlineOffset）。
  /// Paint-only。**永远不影响 layout**。
  outline,

  /// 宽高比（width÷height）。Layout 影响 —— 与 width/height/min-max 协同。
  aspectRatio,

  /// 自身滤镜（[ElFilter] 聚合：blur / saturate / brightness / contrast /
  /// grayscale / sepia / invert / hueRotate / opacity）。Paint-only。
  /// 作用于节点全部视觉，模糊溢出边界不裁剪。
  filter,

  /// backdrop filter（毛玻璃 / 背景模糊，[ElFilter] 聚合）。Paint-only。
  /// 默认按节点视觉边界裁剪滤镜区域，且不影响 shadow / border / outline。
  backdropFilter,
}

/// 字段过渡声明。`ElStyle.transition` 的元素类型。
@immutable
class ElTransition {
  /// 单字段过渡。
  const ElTransition.field(
    ElTransitionField field, [
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.ease,
    this.delay = Duration.zero,
  ]) : _fieldsSet = const <ElTransitionField>{},
       _singleField = field;

  /// 多字段过渡。入参须为 Set 以保证 O(1) 命中（const Set literal `{...}` 即可）。
  const ElTransition.fields(
    Set<ElTransitionField> fields, [
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.ease,
    this.delay = Duration.zero,
  ]) : _fieldsSet = fields,
       _singleField = null;

  /// 所有字段过渡。
  const ElTransition.all([
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.ease,
    this.delay = Duration.zero,
  ]) : _fieldsSet = null,
       _singleField = null;

  /// 过渡时长。
  final Duration duration;

  /// 缓动曲线。
  final Curve curve;

  /// 延迟。
  final Duration delay;

  /// 适用的字段集（仅 [ElTransition.fields] 用到，公开为 Iterable 以兼容旧 API）。
  Iterable<ElTransitionField> get fields => _fieldsSet ?? const <ElTransitionField>{};

  // null 集合表示 all；单字段另存枚举，避免为它创建 Set。
  final Set<ElTransitionField>? _fieldsSet;
  final ElTransitionField? _singleField;

  /// 是否覆盖某字段。
  bool covers(ElTransitionField field) =>
      _fieldsSet == null || (_singleField == null ? _fieldsSet.contains(field) : _singleField == field);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ElTransition) return false;
    return duration == other.duration &&
        curve == other.curve &&
        delay == other.delay &&
        _singleField == other._singleField &&
        setEquals(_fieldsSet, other._fieldsSet);
  }

  @override
  int get hashCode => Object.hash(
    duration,
    curve,
    delay,
    _singleField,
    _fieldsSet == null ? null : Object.hashAllUnordered(_fieldsSet),
  );
}

/// CSS `animation-direction`。
enum ElAnimationDirection {
  /// 每次迭代都从 0% 播到 100%。
  normal,

  /// 每次迭代都从 100% 播到 0%。
  reverse,

  /// 奇偶迭代交替正反（第 0 次正向）。
  alternate,

  /// 奇偶迭代交替反正（第 0 次反向）。
  alternateReverse,
}

/// CSS `animation-fill-mode`。
enum ElAnimationFillMode {
  /// delay 期与结束后都不施加关键帧样式（回落 base）。
  none,

  /// 结束后停在最后一帧（按 direction / iterationCount 映射的终点进度）。
  forwards,

  /// delay 期提前施加第一帧（按 direction 映射的起点进度）。
  backwards,

  /// [forwards] + [backwards]。
  both,
}

/// 关键帧动画声明。`ElStyle.animation` 的元素类型 —— CSS `animation` 简写 +
/// `@keyframes` 的合体（无命名层，keyframes 直接内联）。
@immutable
class ElAnimation {
  /// 创建关键帧动画声明。
  const ElAnimation({
    required this.keyframes,
    required this.animationDuration,
    this.animationTimingFunction = Curves.ease,
    this.animationDelay = Duration.zero,
    this.animationIterationCount = 1,
    this.animationDirection = ElAnimationDirection.normal,
    this.animationFillMode = ElAnimationFillMode.none,
    this.animationPlayState = false,
  }) : assert(animationIterationCount >= 0, 'animationIterationCount 不能为负');

  /// 关键帧表：offset 百分比整数（0..100）→ 样式帧。表本身即 CSS `@keyframes` 块。
  ///
  /// 帧的**身份锚**：rebuild 时 runner 按「keyframes 相等」判定是否同一动画
  /// （等价 CSS 的 animation-name 不变）——仅改 timing 参数（animationDuration / animationPlayState
  /// 等）原地更新不重启；keyframes 变了才视为新动画从头播。
  final Map<int, ElStyle> keyframes;

  /// 单次迭代时长（CSS `animation-duration`）。
  final Duration animationDuration;

  /// 逐段缓动（CSS `animation-timing-function`，默认 ease）。
  final Curve animationTimingFunction;

  /// 起播延迟（CSS `animation-delay`）。
  final Duration animationDelay;

  /// 迭代次数（CSS `animation-iteration-count`）：可为小数；`double.infinity`
  /// = 无限循环。默认 1。
  final double animationIterationCount;

  /// 播放方向（CSS `animation-direction`）。
  final ElAnimationDirection animationDirection;

  /// 填充模式（CSS `animation-fill-mode`）。
  final ElAnimationFillMode animationFillMode;

  /// 播放状态（CSS `animation-play-state`）：true 为 paused，false 为 running。
  final bool animationPlayState;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ElAnimation) return false;
    return animationDuration == other.animationDuration &&
        animationTimingFunction == other.animationTimingFunction &&
        animationDelay == other.animationDelay &&
        animationIterationCount == other.animationIterationCount &&
        animationDirection == other.animationDirection &&
        animationFillMode == other.animationFillMode &&
        animationPlayState == other.animationPlayState &&
        keyframesEqual(keyframes, other.keyframes);
  }

  @override
  int get hashCode => Object.hash(
    animationDuration,
    animationTimingFunction,
    animationDelay,
    animationIterationCount,
    animationDirection,
    animationFillMode,
    animationPlayState,
    Object.hashAllUnordered(keyframes.keys),
  );

  /// keyframes 表逐项相等（offset 集合 + 每帧 ElStyle ==）。
  ///
  /// runner 用它做「同一动画」判定（保时钟不重启），公开是因为白盒测试与
  /// runner 不在同一 library。
  static bool keyframesEqual(Map<int, ElStyle> a, Map<int, ElStyle> b) => mapEquals(a, b);
}

/// CSS `user-select` 的体验适配子集（`contain` 不支持：需要拖拽端点钳制，暂无场景）。
///
/// 非继承字段：参与者自下而上找**最近的显式声明**（[auto] / 未声明继续向上），
/// 由它决定可选性；[text] / [all] 一旦定住，更外层的 [none] 不再屏蔽
/// （局部重新开启，对齐 CSS `user-select` 非继承解析）。
enum ElUserSelect {
  /// 跟随最近祖先的显式声明；整链无声明时可选中。行为等价于不声明，
  /// 用于在 copyWith / merge 合成里显式复位掉合入的 [none]。
  auto,

  /// 节点及其后代参与字符选中，并抵消祖先的 [none]（局部重新开启）。
  text,

  /// 节点及其后代不参与 ElSelectionView 字符选中。
  none,

  /// 整体选择快捷行为：移动端长按、桌面或触摸双击命中时选中整个作用域；
  /// 普通鼠标拖选保持字符级精度，不会仅因经过该子树就扩成全选。桌面单击只
  /// 清空现有选区，后续第三击无操作。嵌套声明取最近者：子树内更近的
  /// [text] / [none] / [all] 声明会把自己的子树从本作用域挖走。
  all,
}

/// CSS `pointer-events` 的盒模型子集（SVG 专属值不支持）。
enum ElPointerEvents {
  /// 正常参与命中。显式声明可抵消祖先的 [none]（局部重新启用）。
  auto,

  /// 节点及其后代对指针透明（命中穿透），后代显式 [auto] 除外。
  none,
}

// ============================================================================
// Public style value types migrated from 'border.dart'.
// ============================================================================

/// 边框线型（CSS `border-style` 常用子集）。
///
/// 替代 Flutter [BorderStyle]（只有 solid/none，装不下虚线）。dashed / dotted
/// 的分段几何在 paint plan 构建期（样式真变时）一次派生为 dash [Path]，每帧
/// 只发一条 drawPath——线型不改变边框的几何/布局语义（border 恒 paint-only）。
enum ElBorderStyle {
  /// 实线（默认）。
  solid,

  /// 虚线：dash ≈ 3×width、间隔 ≈ 3×width，按周长（闭环）/段长（单边）微调
  /// 整数段数避免接缝与断头。
  dashed,

  /// 点线：圆点直径 = width、中心距 ≈ 2×width（round cap 成圆）。
  dotted,

  /// 不绘制。
  none,
}

/// 自研边框单边值类型（[ElBorder] 的组成单元）。
@immutable
class ElBorderSide {
  /// 创建单边。
  const ElBorderSide({
    this.borderWidth = 1.0,
    this.borderColor = const Color(0xFF000000),
    this.borderStyle = ElBorderStyle.solid,
  });

  /// 无边 sentinel（borderStyle = none，paint 跳过）。
  static const ElBorderSide none = ElBorderSide(borderWidth: 0.0, borderStyle: ElBorderStyle.none);

  /// 边宽。
  final double? borderWidth;

  /// 边色。直接使用 Color 值。
  final Color? borderColor;

  /// 边样式。[ElBorderStyle.none] = 不绘制。
  final ElBorderStyle borderStyle;

  /// 消费点解析边宽到像素。
  double resolveWidth() => borderWidth ?? 0;

  /// 副本。
  ElBorderSide copyWith({double? borderWidth, Color? borderColor, ElBorderStyle? borderStyle}) {
    return ElBorderSide(
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      borderStyle: borderStyle ?? this.borderStyle,
    );
  }

  static ElBorderSide lerp(ElBorderSide a, ElBorderSide b, double t) {
    if (identical(a, b)) return a;
    return ElBorderSide(
      borderWidth: a.borderWidth != null && b.borderWidth != null
          ? lerpDouble(a.borderWidth, b.borderWidth, t)
          : (t < 0.5 ? a.borderWidth : b.borderWidth),
      borderColor: a.borderColor != null && b.borderColor != null
          ? lerpColorPremul(a.borderColor, b.borderColor, t)
          : (t < 0.5 ? a.borderColor : b.borderColor),
      borderStyle: t < 0.5 ? a.borderStyle : b.borderStyle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElBorderSide &&
        other.borderWidth == borderWidth &&
        other.borderColor == borderColor &&
        other.borderStyle == borderStyle;
  }

  @override
  int get hashCode => Object.hash(ElBorderSide, borderWidth, borderColor, borderStyle);

  @override
  String toString() =>
      'ElBorderSide(borderWidth: $borderWidth, borderColor: $borderColor, borderStyle: ${borderStyle.name})';
}

/// 边框相对视觉盒的绘制位置，始终不占布局空间。
enum ElBorderAlign {
  /// 完全落盒内（默认）：外缘贴盒边缘、带宽向盒内铺。CSS/Element 观感，
  /// 且绝不会被紧贴的后绘制兄弟背景盖掉（2026-07-16 裁决改默认的动因）。
  inside,

  /// 骑盒边缘中心线：半宽出盒。出盒部分可能被紧贴的后绘制兄弟盖掉，
  /// 慎用于与邻居零间距的布局。
  center,

  /// 完全落盒外：内缘贴盒边缘、带宽向盒外铺（outline 观感）。同样可能
  /// 被后绘制兄弟盖掉。
  outside,
}

/// 四边独立或统一声明的边框，支持实线、虚线和点线。
@immutable
class ElBorder {
  /// 四边独立声明。未传的边为 [ElBorderSide.none]。
  const ElBorder.only({
    ElBorderSide borderTop = ElBorderSide.none,
    ElBorderSide borderRight = ElBorderSide.none,
    ElBorderSide borderBottom = ElBorderSide.none,
    ElBorderSide borderLeft = ElBorderSide.none,
    ElBorderAlign align = ElBorderAlign.inside,
  }) : this._((borderTop, borderRight, borderBottom, borderLeft), null, align);

  /// 四边统一声明；保存原始值，让构造保持 const。
  const ElBorder.all({
    double? borderWidth = 1.0,
    Color? borderColor = const Color(0xFF000000),
    ElBorderStyle borderStyle = ElBorderStyle.solid,
    ElBorderAlign align = ElBorderAlign.inside,
  }) : this._(null, (borderWidth, borderColor, borderStyle), align);

  /// 从单边构造四边统一边框。
  const ElBorder.fromSide(ElBorderSide side, {ElBorderAlign align = ElBorderAlign.inside})
    : this._((side, side, side, side), null, align);

  /// 对称声明：horizontal = borderTop+borderBottom，vertical = borderLeft+borderRight（对齐
  /// [Border.symmetric] 语义）。
  const ElBorder.symmetric({
    ElBorderSide horizontal = ElBorderSide.none,
    ElBorderSide vertical = ElBorderSide.none,
    ElBorderAlign align = ElBorderAlign.inside,
  }) : this._((horizontal, vertical, horizontal, vertical), null, align);

  const ElBorder._(this._sides, this._uniform, this.align);

  final (ElBorderSide, ElBorderSide, ElBorderSide, ElBorderSide)? _sides;
  final (double?, Color?, ElBorderStyle)? _uniform;
  static final _uniformSides = Expando<ElBorderSide>();

  /// 摆位（inside / center / outside），整框统一，默认 inside。
  final ElBorderAlign align;

  ElBorderSide get _uniformSide => _uniformSides[this] ??= ElBorderSide(
    borderWidth: _uniform!.$1,
    borderColor: _uniform.$2,
    borderStyle: _uniform.$3,
  );

  /// 上边。
  ElBorderSide get borderTop => _sides?.$1 ?? _uniformSide;

  /// 右边。
  ElBorderSide get borderRight => _sides?.$2 ?? _uniformSide;

  /// 下边。
  ElBorderSide get borderBottom => _sides?.$3 ?? _uniformSide;

  /// 左边。
  ElBorderSide get borderLeft => _sides?.$4 ?? _uniformSide;

  /// 四边等值（paint uniform 快路径判据，对齐 [Border.isUniform] 心智）。
  bool get isUniform =>
      _sides == null || (borderTop == borderRight && borderTop == borderBottom && borderTop == borderLeft);

  Border? resolveToFlutterBorder() {
    BorderSide sideOf(ElBorderSide s) {
      if (s.borderStyle == ElBorderStyle.none) return BorderSide.none;
      final c = s.borderColor;
      return BorderSide(width: s.resolveWidth(), color: c ?? const Color(0xFF000000));
    }

    return Border(
      top: sideOf(borderTop),
      right: sideOf(borderRight),
      bottom: sideOf(borderBottom),
      left: sideOf(borderLeft),
    );
  }

  /// 副本。
  ElBorder copyWith({
    ElBorderSide? borderTop,
    ElBorderSide? borderRight,
    ElBorderSide? borderBottom,
    ElBorderSide? borderLeft,
    ElBorderAlign? align,
  }) {
    return ElBorder.only(
      borderTop: borderTop ?? this.borderTop,
      borderRight: borderRight ?? this.borderRight,
      borderBottom: borderBottom ?? this.borderBottom,
      borderLeft: borderLeft ?? this.borderLeft,
      align: align ?? this.align,
    );
  }

  /// 值级插值：null 侧 step（多 side 场景无通用零值替换，沿用旧
  /// `lerpBorderValue` 的 step 兜底口径，完成态由 driver 写回）；align 是
  /// 离散枚举，step。
  static ElBorder? lerp(ElBorder? a, ElBorder? b, double t) {
    if (identical(a, b)) return a;
    if (a == null || b == null) return t < 0.5 ? a : b;
    return ElBorder.only(
      borderTop: ElBorderSide.lerp(a.borderTop, b.borderTop, t),
      borderRight: ElBorderSide.lerp(a.borderRight, b.borderRight, t),
      borderBottom: ElBorderSide.lerp(a.borderBottom, b.borderBottom, t),
      borderLeft: ElBorderSide.lerp(a.borderLeft, b.borderLeft, t),
      align: t < 0.5 ? a.align : b.align,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ElBorder) return false;
    if (other.align != align) return false;
    // 同为统一边框时直接比较原始值。
    if (_sides == null && other._sides == null) {
      return _uniform == other._uniform;
    }
    return other.borderTop == borderTop &&
        other.borderRight == borderRight &&
        other.borderBottom == borderBottom &&
        other.borderLeft == borderLeft;
  }

  @override
  int get hashCode => Object.hash(ElBorder, borderTop, borderRight, borderBottom, borderLeft, align);

  @override
  String toString() =>
      'ElBorder(borderTop: $borderTop, borderRight: $borderRight, borderBottom: $borderBottom, borderLeft: $borderLeft, align: $align)';
}

// ============================================================================
// Public borderStyle value types migrated from 'clipPath.dart'.
// ============================================================================

/// ElView 自定义裁剪形状预设集。
abstract class ElClipper extends CustomClipper<Path> {
  /// 创建可扩展的视图裁剪器。
  const ElClipper();

  /// 三角形。[pointTo] 顶点朝向，对边为底边。
  const factory ElClipper.triangle({AxisDirection pointTo}) = _ShapeClipper.triangle;

  /// 箭头形（带方向的指示形）。
  ///
  /// [pointTo] 朝向；[headRatio] 箭头三角段占的比例 `[0, 1]`，剩余为矩形杆部。
  const factory ElClipper.arrow({AxisDirection pointTo, double headRatio}) = _ShapeClipper.arrow;

  /// 菱形（4 个边中点连成）。
  const factory ElClipper.diamond() = _ShapeClipper.diamond;

  /// 平行四边形。
  ///
  /// [skew] 顶/底两边水平偏移比 `[-1, 1]`：正 = 右倾（顶边右移），负 = 左倾。
  const factory ElClipper.parallelogram({double skew}) = _ShapeClipper.parallelogram;

  /// 等腰梯形。
  ///
  /// [topRatio] 顶边相对底边的比例 `[0, 1]`：0 = 三角形，1 = 矩形。
  const factory ElClipper.trapezoid({double topRatio}) = _ShapeClipper.trapezoid;

  /// 星形。
  ///
  /// [points] 角数（≥3）；[innerRatio] 内顶点距中心相对外顶点距中心 `[0, 1]`。
  /// 中心 = box 中心，外半径 = `min(borderWidth, height) / 2`。
  const factory ElClipper.star({int points, double innerRatio}) = _ShapeClipper.star;

  /// 正多边形（中心对称 n 边形）。
  ///
  /// [sides] 边数（≥3）；[rotation] 起始角偏移（弧度）。
  /// `rotation = 0` 时第一个顶点在右（数学约定），`-π/2` 时在上。
  const factory ElClipper.polygon({int sides, double rotation}) = _ShapeClipper.polygon;
}

enum _ClipShape { triangle, arrow, diamond, parallelogram, trapezoid, star, polygon }

class _ShapeClipper extends ElClipper {
  const _ShapeClipper._(this.shape, {this.direction = AxisDirection.right, this.count = 0, this.parameter = 0});
  const _ShapeClipper.triangle({AxisDirection pointTo = AxisDirection.up}) : this._(.triangle, direction: pointTo);
  const _ShapeClipper.arrow({AxisDirection pointTo = AxisDirection.right, double headRatio = 0.3})
    : this._(.arrow, direction: pointTo, parameter: headRatio);
  const _ShapeClipper.diamond() : this._(.diamond);
  const _ShapeClipper.parallelogram({double skew = 0.2}) : this._(.parallelogram, parameter: skew);
  const _ShapeClipper.trapezoid({double topRatio = 0.6}) : this._(.trapezoid, parameter: topRatio);
  const _ShapeClipper.star({int points = 5, double innerRatio = 0.4})
    : this._(.star, count: points, parameter: innerRatio);
  const _ShapeClipper.polygon({int sides = 6, double rotation = 0})
    : this._(.polygon, count: sides, parameter: rotation);

  final _ClipShape shape;
  final AxisDirection direction;
  final int count;
  final double parameter;
  static final _unitPaths = Expando<Path>();

  Path _buildUnitPath() {
    final p = parameter.clamp(0.0, 1.0);
    final skew = parameter.clamp(-1.0, 1.0);
    final vertices = switch (shape) {
      _ClipShape.triangle => [const Offset(0, 0), const Offset(1, 0.5), const Offset(0, 1)],
      _ClipShape.arrow => [
        const Offset(0, 1 / 3),
        Offset(1 - p, 1 / 3),
        Offset(1 - p, 0),
        const Offset(1, 0.5),
        Offset(1 - p, 1),
        Offset(1 - p, 2 / 3),
        const Offset(0, 2 / 3),
      ],
      _ClipShape.diamond => [const Offset(0.5, 0), const Offset(1, 0.5), const Offset(0.5, 1), const Offset(0, 0.5)],
      _ClipShape.parallelogram => [
        Offset(math.max(0.0, skew), 0),
        Offset(math.min(1.0, 1 + skew), 0),
        Offset(math.min(1.0, 1 - skew), 1),
        Offset(math.max(0.0, -skew), 1),
      ],
      _ClipShape.trapezoid => [Offset((1 - p) / 2, 0), Offset((1 + p) / 2, 0), const Offset(1, 1), const Offset(0, 1)],
      _ClipShape.star || _ClipShape.polygon => _radialVertices(p),
    };
    return Path()..addPolygon([
      for (final point in vertices)
        if (shape == _ClipShape.triangle || shape == _ClipShape.arrow)
          switch (direction) {
            AxisDirection.right => point,
            AxisDirection.left => Offset(1 - point.dx, point.dy),
            AxisDirection.down => Offset(point.dy, point.dx),
            AxisDirection.up => Offset(point.dy, 1 - point.dx),
          }
        else
          point,
    ], true);
  }

  List<Offset> _radialVertices(double innerRatio) {
    final star = shape == _ClipShape.star;
    final n = math.max(3, count) * (star ? 2 : 1);
    final rotation = star ? -math.pi / 2 : parameter;
    return [
      for (var i = 0; i < n; i++)
        Offset.fromDirection(rotation + i * 2 * math.pi / n, star && i.isOdd ? innerRatio / 2 : 0.5) +
            const Offset(0.5, 0.5),
    ];
  }

  @override
  Path getClip(Size size) {
    final radial = shape == _ClipShape.star || shape == _ClipShape.polygon;
    final w = radial ? size.shortestSide : size.width;
    final h = radial ? size.shortestSide : size.height;
    final matrix = Matrix4.diagonal3Values(w, h, 1)..setTranslationRaw((size.width - w) / 2, (size.height - h) / 2, 0);
    // 缓存单位路径，每次返回新路径，防止调用方修改缓存。
    return (_unitPaths[this] ??= _buildUnitPath()).transform(matrix.storage);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => this != old;

  @override
  bool operator ==(Object other) =>
      other is _ShapeClipper &&
      (shape, direction, count, parameter) == (other.shape, other.direction, other.count, other.parameter);

  @override
  int get hashCode => Object.hash(shape, direction, count, parameter);
}

// ============================================================================
// Public style value types migrated from 'outline.dart'.
// ============================================================================

/// CSS `outline` 的归一化值类型 —— 把"描边宽度 / 颜色 / 渐变 / offset"
/// 四个属性聚合到一个 immutable 值上，单字段过渡共享同一条 driver。
@immutable
class ElOutline {
  /// 创建。所有字段都有合理默认值，最少声明 `ElOutline(outlineColor: ..., outlineWidth: ...)`。
  const ElOutline({
    this.outlineWidth = 0,
    this.outlineColor = const Color(0xFF000000),
    this.gradient,
    this.outlineOffset = 0,
  });

  /// 视觉零值 —— 完全等价"未声明 outline"。
  ///
  /// **作用**：[lerp] 在单侧 null 时把 null 替换成 [zero]，让 outlineWidth / outlineColor alpha
  /// 都从 0 平滑过渡到目标值（避免硬切）。
  static const ElOutline zero = ElOutline(outlineWidth: 0, outlineColor: Color(0x00000000));

  /// 描边宽度。`num`。解析后 `outlineWidth <= 0` 时 paint pipeline 早退
  /// （零开销）。
  final double? outlineWidth;

  /// 描边纯色。直接使用 Color 值。
  /// 当 [gradient] 非 null 时被忽略。
  final Color? outlineColor;

  /// 渐变描边。非 null 时 paint 走 `Paint.shader`，覆盖 [outlineColor]。
  ///
  /// 典型用法：彩虹 ring / 品牌渐变 focus 高亮。
  final Gradient? gradient;

  /// 描边与 box 边界的距离（CSS `outline-offset` 对应）。`num`。
  final double? outlineOffset;

  /// 消费点解析 [outlineWidth] 到像素。
  double resolveWidth() => outlineWidth ?? 0;

  /// 消费点解析 [outlineOffset] 到像素。未声明时使用 0。
  double resolveOffset() => outlineOffset ?? 0;

  /// 副本工厂（手写 copyWith，不依赖 generator）。
  ElOutline copyWith({double? outlineWidth, Color? outlineColor, Object? gradient = _sentinel, double? outlineOffset}) {
    return ElOutline(
      outlineWidth: outlineWidth ?? this.outlineWidth,
      outlineColor: outlineColor ?? this.outlineColor,
      gradient: identical(gradient, _sentinel) ? this.gradient : gradient as Gradient?,
      outlineOffset: outlineOffset ?? this.outlineOffset,
    );
  }

  static double? _lerpNumSlot(double? a, double? b, double t) {
    if (a != null && b != null) return lerpDouble(a, b, t);
    return t < 0.5 ? a : b;
  }

  static Color? _lerpColorSlot(Color? a, Color? b, double t) {
    if (a != null && b != null) return lerpColorPremul(a, b, t)!;
    return t < 0.5 ? a : b;
  }

  /// 平滑插值。
  static ElOutline? lerp(ElOutline? a, ElOutline? b, double t) {
    if (identical(a, b)) return a;
    if (a == null && b == null) return null;
    final from = a ?? zero;
    final to = b ?? zero;
    return ElOutline(
      outlineWidth: _lerpNumSlot(from.outlineWidth, to.outlineWidth, t),
      outlineColor: _lerpColorSlot(from.outlineColor, to.outlineColor, t),
      gradient: Gradient.lerp(from.gradient, to.gradient, t),
      outlineOffset: _lerpNumSlot(from.outlineOffset, to.outlineOffset, t),
    );
  }

  /// 自适应圆角外推算法 —— 根据 box 的 borderRadius 计算 outline ring 的圆角。
  BorderRadius extrudeRadius(BorderRadius boxRadius, {required double resolvedWidth, required double resolvedOffset}) {
    final r = boxRadius.resolve(TextDirection.ltr);
    final d = _extrusionDistance(resolvedWidth, resolvedOffset);
    if (d == 0) return boxRadius;
    Radius shift(Radius v) {
      final newX = _adaptiveExtrude(v.x, d);
      final newY = _adaptiveExtrude(v.y, d);
      return Radius.elliptical(newX, newY);
    }

    return BorderRadius.only(
      topLeft: shift(r.topLeft),
      topRight: shift(r.topRight),
      bottomLeft: shift(r.bottomLeft),
      bottomRight: shift(r.bottomRight),
    );
  }

  /// ring 中心相对 box 外缘的距离。
  double _extrusionDistance(double w, double o) => o + w / 2;

  static double _adaptiveExtrude(double r, double d) {
    if (r <= 0) return 0;
    // 自适应衰减：r 越小越压抑增量，r 越大越接近 CSS 标准 (r+d)
    final blend = r / (r + d.abs() / 2);
    return r + d * blend;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElOutline &&
        outlineWidth == other.outlineWidth &&
        outlineColor == other.outlineColor &&
        gradient == other.gradient &&
        outlineOffset == other.outlineOffset;
  }

  @override
  int get hashCode => Object.hash(outlineWidth, outlineColor, gradient, outlineOffset);

  @override
  String toString() =>
      'ElOutline(outlineWidth: $outlineWidth, outlineColor: $outlineColor, gradient: $gradient, outlineOffset: $outlineOffset)';
}

/// 滤镜聚合值对象 —— CSS `filter` / `backdrop-filter` 的 ElView 对应。
@immutable
class ElFilter {
  /// 创建。全字段可选，只声明需要的分量。
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
  }) : assert(
         blur == null || (blurX == null && blurY == null),
         'blur 与 blurX/blurY 互斥：blur 是各向同性短手，声明 blur 时不能再声明 blurX/blurY。',
       );

  /// 恒等滤镜 —— 视觉上完全等价"未声明 filter"。
  ///
  /// **作用**：[lerp] 在单侧 null 时把 null 替换成 [identity]，让所有分量
  /// 从恒等值平滑过渡到目标值（模糊渐入、饱和度渐变），避免硬切。
  static const ElFilter identity = ElFilter();

  /// 高斯模糊 —— CSS `blur(x)`，数值即 stdDeviation（sigma），**与 CSS
  /// 像素值一一对应，零换算**。`num`。
  final double? blur;

  /// 水平方向模糊 sigma（各向异性进阶用法）。`num`。
  final double? blurX;

  /// 垂直方向模糊 sigma。`num`。
  final double? blurY;

  /// 饱和度 —— CSS `saturate(x)`。1 = 不变，0 = 完全去饱和，>1 过饱和。
  /// `num`。
  final double? saturate;

  /// 亮度 —— CSS `brightness(x)`。1 = 不变，0 = 全黑，>1 提亮。
  /// `num`。
  final double? brightness;

  /// 对比度 —— CSS `contrast(x)`。1 = 不变，0 = 全灰。`num`。
  final double? contrast;

  /// 灰度 —— CSS `grayscale(x)`。0 = 不变，1 = 完全灰度。`num`。
  final double? grayscale;

  /// 褐色 —— CSS `sepia(x)`。0 = 不变，1 = 完全褐色。`num`。
  final double? sepia;

  /// 反相 —— CSS `invert(x)`。0 = 不变，1 = 完全反相。`num`。
  final double? invert;

  /// 色相旋转 —— CSS `hue-rotate(xdeg)`，单位**度**。0 = 不变。
  /// `num`。
  final double? hueRotate;

  /// 滤镜内透明度 —— CSS `opacity(x)` 滤镜函数。1 = 不变。`num`。
  final double? opacity;

  /// 是否所有分量都未声明（恒等滤镜，消费点可跳过 layer）。
  bool get isIdentity =>
      blur == null &&
      blurX == null &&
      blurY == null &&
      saturate == null &&
      brightness == null &&
      contrast == null &&
      grayscale == null &&
      sepia == null &&
      invert == null &&
      hueRotate == null &&
      opacity == null;

  /// 副本工厂（手写 copyWith，不依赖 generator）。
  ElFilter copyWith({
    double? blur,
    double? blurX,
    double? blurY,
    double? saturate,
    double? brightness,
    double? contrast,
    double? grayscale,
    double? sepia,
    double? invert,
    double? hueRotate,
    double? opacity,
  }) {
    return ElFilter(
      blur: blur ?? this.blur,
      blurX: blurX ?? this.blurX,
      blurY: blurY ?? this.blurY,
      saturate: saturate ?? this.saturate,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      grayscale: grayscale ?? this.grayscale,
      sepia: sepia ?? this.sepia,
      invert: invert ?? this.invert,
      hueRotate: hueRotate ?? this.hueRotate,
      opacity: opacity ?? this.opacity,
    );
  }

  static double? _lerpSlot(double? a, double? b, double t, double fallback) =>
      a == null && b == null ? null : lerpDouble(a ?? fallback, b ?? fallback, t);

  /// 平滑插值。
  ///
  /// **空值语义**：单侧 null 用 [identity] 替换 —— 每个分量从各自的 CSS
  /// 恒等默认值（blur 0 / saturate 1 / grayscale 0…）渐入 / 渐出，视觉连续。
  /// 完成态由 driver 写回原 to（含 null），committed 层不残留 identity。
  static ElFilter? lerp(ElFilter? a, ElFilter? b, double t) {
    if (identical(a, b)) return a;
    if (a == null && b == null) return null;
    final from = a ?? identity;
    final to = b ?? identity;
    return ElFilter(
      blur: _lerpSlot(from.blur, to.blur, t, 0),
      blurX: _lerpSlot(from.blurX, to.blurX, t, 0),
      blurY: _lerpSlot(from.blurY, to.blurY, t, 0),
      saturate: _lerpSlot(from.saturate, to.saturate, t, 1),
      brightness: _lerpSlot(from.brightness, to.brightness, t, 1),
      contrast: _lerpSlot(from.contrast, to.contrast, t, 1),
      grayscale: _lerpSlot(from.grayscale, to.grayscale, t, 0),
      sepia: _lerpSlot(from.sepia, to.sepia, t, 0),
      invert: _lerpSlot(from.invert, to.invert, t, 0),
      hueRotate: _lerpSlot(from.hueRotate, to.hueRotate, t, 0),
      opacity: _lerpSlot(from.opacity, to.opacity, t, 1),
    );
  }

  /// 消费点解析：折算成 `dart:ui` [ImageFilter]（blur 与颜色矩阵按需
  /// compose），恒等滤镜返回 null（跳过 layer，零开销）。
  ImageFilter? resolveToImageFilter() {
    final sx = blur ?? blurX ?? 0;
    final sy = blur ?? blurY ?? 0;
    final ImageFilter? blurFilter = (sx > 0 || sy > 0) ? ImageFilter.blur(sigmaX: sx, sigmaY: sy) : null;

    final matrix = _composeColorMatrix();
    final ImageFilter? colorFilter = matrix == null ? null : ColorFilter.matrix(matrix);

    if (blurFilter == null) return colorFilter;
    if (colorFilter == null) return blurFilter;
    // 先做颜色变换、再模糊（CSS filter 链从左到右 = compose inner→outer；
    // 顺序固定，用户不接触 compose）。
    return ImageFilter.compose(outer: blurFilter, inner: colorFilter);
  }

  /// 按 CSS Filter Effects 规范矩阵合成颜色滤镜（全恒等 → null）。
  ///
  /// 各函数的 4×5 矩阵定义见 <https://www.w3.org/TR/filter-effects-1/>；
  /// 多分量同时声明时按固定顺序左乘合成为单个矩阵（一次 ColorFilter，
  /// 不叠 layer）。
  List<double>? _composeColorMatrix() {
    final saturate = this.saturate ?? 1.0;
    final brightness = this.brightness ?? 1.0;
    final contrast = this.contrast ?? 1.0;
    final grayscale = this.grayscale ?? 0.0;
    final sepia = this.sepia ?? 0.0;
    final invert = this.invert ?? 0.0;
    final hueRotate = this.hueRotate ?? 0.0;
    final opacity = this.opacity ?? 1.0;
    List<double>? m;
    void mul(List<double> next) => m = m == null ? next : _multiplyColorMatrix(next, m!);
    // RGB 等比缩放/偏移和独立 alpha 缩放共用仿射矩阵，合成顺序保持不变。
    void affine(double rgb, double offset, {double alpha = 1}) => mul(<double>[
      rgb, 0, 0, 0, offset, //
      0, rgb, 0, 0, offset,
      0, 0, rgb, 0, offset,
      0, 0, 0, alpha, 0,
    ]);

    if (grayscale != 0) {
      final g = 1 - grayscale.clamp(0.0, 1.0);
      mul(<double>[
        0.2126 + 0.7874 * g, 0.7152 - 0.7152 * g, 0.0722 - 0.0722 * g, 0, 0, //
        0.2126 - 0.2126 * g, 0.7152 + 0.2848 * g, 0.0722 - 0.0722 * g, 0, 0,
        0.2126 - 0.2126 * g, 0.7152 - 0.7152 * g, 0.0722 + 0.9278 * g, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    if (sepia != 0) {
      final s = 1 - sepia.clamp(0.0, 1.0);
      mul(<double>[
        0.393 + 0.607 * s, 0.769 - 0.769 * s, 0.189 - 0.189 * s, 0, 0, //
        0.349 - 0.349 * s, 0.686 + 0.314 * s, 0.168 - 0.168 * s, 0, 0,
        0.272 - 0.272 * s, 0.534 - 0.534 * s, 0.131 + 0.869 * s, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    if (saturate != 1) {
      final s = saturate;
      mul(<double>[
        0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
        0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
        0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    if (hueRotate != 0) {
      final rad = hueRotate * math.pi / 180;
      final c = math.cos(rad);
      final s = math.sin(rad);
      mul(<double>[
        0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0, //
        0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0,
        0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    if (invert != 0) {
      final i = invert.clamp(0.0, 1.0);
      affine(1 - 2 * i, i * 255);
    }
    if (brightness != 1) affine(brightness < 0 ? 0 : brightness, 0);
    if (contrast != 1) {
      final c = contrast < 0 ? 0.0 : contrast;
      affine(c, (1 - c) / 2 * 255);
    }
    if (opacity != 1) affine(1, 0, alpha: opacity.clamp(0.0, 1.0));
    return m;
  }

  /// 4×5 颜色矩阵乘法：`a × b`（先应用 b、再应用 a）。
  static List<double> _multiplyColorMatrix(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var v = 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[row * 5 + k] * b[k * 5 + col];
        }
        if (col == 4) v += a[row * 5 + 4];
        out[row * 5 + col] = v;
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElFilter &&
        blur == other.blur &&
        blurX == other.blurX &&
        blurY == other.blurY &&
        saturate == other.saturate &&
        brightness == other.brightness &&
        contrast == other.contrast &&
        grayscale == other.grayscale &&
        sepia == other.sepia &&
        invert == other.invert &&
        hueRotate == other.hueRotate &&
        opacity == other.opacity;
  }

  @override
  int get hashCode =>
      Object.hash(blur, blurX, blurY, saturate, brightness, contrast, grayscale, sepia, invert, hueRotate, opacity);

  @override
  String toString() {
    final parts = <String>[
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
    return 'ElFilter(${parts.join(', ')})';
  }
}

/// 支持 CSS `box-shadow: inset` 的 [BoxShadow] 兼容扩展。
///
/// 可直接放入 [ElStyle.boxShadow] 的 `List<BoxShadow>`，因此既有 Flutter
/// [BoxShadow] 调用无需迁移。`inset: true` 时阴影在盒子背景之上、内容之前
/// 绘制，并严格裁剪到当前盒子的圆角边界内。
@immutable
class ElBoxShadow extends BoxShadow {
  /// 创建盒阴影，inset 控制绘制在盒内或盒外。
  const ElBoxShadow({
    super.color,
    super.offset,
    super.blurRadius,
    super.spreadRadius,
    super.blurStyle,
    this.inset = false,
  });

  /// 是否按 CSS inset shadow 语义绘制。
  final bool inset;

  /// 按当前背景生成画笔，供绘制器解析扩展阴影的自适应颜色。
  @internal
  Paint toPaintWithBackground(Color? backgroundColor) => toPaint();

  @override
  ElBoxShadow copyWith({
    Color? color,
    Offset? offset,
    double? blurRadius,
    double? spreadRadius,
    BlurStyle? blurStyle,
    bool? inset,
  }) {
    return ElBoxShadow(
      color: color ?? this.color,
      offset: offset ?? this.offset,
      blurRadius: blurRadius ?? this.blurRadius,
      spreadRadius: spreadRadius ?? this.spreadRadius,
      blurStyle: blurStyle ?? this.blurStyle,
      inset: inset ?? this.inset,
    );
  }

  @override
  ElBoxShadow scale(double factor) {
    return ElBoxShadow(
      color: color,
      offset: offset * factor,
      blurRadius: blurRadius * factor,
      spreadRadius: spreadRadius * factor,
      blurStyle: blurStyle,
      inset: inset,
    );
  }

  /// 对 [BoxShadow] 和 [ElBoxShadow] 都适用的插值；inset 是离散属性，动画中点切换。
  ///
  /// color 分量覆盖为 [lerpColorPremul]（预乘 alpha）：阴影色几乎总是半透明，
  /// Flutter [BoxShadow.lerp] 的直通道插值在 alpha 差异大的两端间会产生偏暗
  /// 中间帧。几何分量（offset / blur / spread）沿用 Flutter 插值。
  static BoxShadow? lerp(BoxShadow? a, BoxShadow? b, double t) {
    if (identical(a, b)) return a;
    if (a is _PresetBoxShadow || b is _PresetBoxShadow) return _PresetBoxShadow.interpolate(a, b, t);
    final shadow = BoxShadow.lerp(a, b, t);
    if (shadow == null) return null;
    // 单侧 null 时 Flutter 走 scale（几何缩放、色不变），双侧非 null 才有
    // 直通道颜色插值需要覆盖。
    final color = (a != null && b != null) ? lerpColorPremul(a.color, b.color, t)! : shadow.color;
    if (a is! ElBoxShadow && b is! ElBoxShadow) {
      return BoxShadow(
        color: color,
        offset: shadow.offset,
        blurRadius: shadow.blurRadius,
        spreadRadius: shadow.spreadRadius,
        blurStyle: shadow.blurStyle,
      );
    }
    final inset = switch ((a, b)) {
      (ElBoxShadow a, null) => a.inset,
      (null, ElBoxShadow b) => b.inset,
      (ElBoxShadow a, ElBoxShadow b) => t < 0.5 ? a.inset : b.inset,
      (ElBoxShadow a, _) => t < 0.5 ? a.inset : false,
      (_, ElBoxShadow b) => t < 0.5 ? false : b.inset,
      _ => false,
    };
    return ElBoxShadow(
      color: color,
      offset: shadow.offset,
      blurRadius: shadow.blurRadius,
      spreadRadius: shadow.spreadRadius,
      blurStyle: shadow.blurStyle,
      inset: inset,
    );
  }

  /// 保留 [ElBoxShadow.inset] 的阴影列表插值。
  static List<BoxShadow>? lerpList(List<BoxShadow>? a, List<BoxShadow>? b, double t) {
    if (identical(a, b)) return a;
    a ??= const <BoxShadow>[];
    b ??= const <BoxShadow>[];
    final commonLength = math.min(a.length, b.length);
    return <BoxShadow>[
      for (var i = 0; i < commonLength; i++) lerp(a[i], b[i], t)!,
      for (var i = commonLength; i < a.length; i++) a[i].scale(1 - t),
      for (var i = commonLength; i < b.length; i++) b[i].scale(t),
    ];
  }

  @override
  bool operator ==(Object other) => other is ElBoxShadow && super == other && inset == other.inset;

  @override
  int get hashCode => Object.hash(super.hashCode, inset);

  @override
  String toString() => '${super.toString()}, inset: $inset';
}

const Object _sentinel = Object();

// ============================================================================
// Public style value types migrated from 'el_breakpoint.dart'.
// ============================================================================

/// ElView 响应式断点声明。
class ElBreakpoint {
  /// 创建响应式断点及尺寸基准声明。
  const ElBreakpoint({this.xs, this.sm, this.md, this.lg, this.xl, this.inheritSize});

  /// 是否继承祖先的响应式尺寸基准；false 以当前视图宽度供自身及后代使用，true 或 null 沿用祖先或窗口。
  final bool? inheritSize;

  /// xs 档最大宽度上界。null = 继承祖先声明；整条链未声明 → [defaultXs]。
  final double? xs;

  /// sm 档最大宽度上界。null = 继承祖先声明；整条链未声明 → [defaultSm]。
  final double? sm;

  /// md 档最大宽度上界。null = 继承祖先声明；整条链未声明 → [defaultMd]。
  final double? md;

  /// lg 档最大宽度上界。null = 继承祖先声明；整条链未声明 → [defaultLg]。
  final double? lg;

  /// xl 档最大宽度上界。null = 继承祖先声明；整条链未声明 → [defaultXl]。
  final double? xl;

  /// xs 兜底默认值。
  static const double defaultXs = 320;

  /// sm 兜底默认值。
  static const double defaultSm = 640;

  /// md 兜底默认值。
  static const double defaultMd = 1024;

  /// lg 兜底默认值。
  static const double defaultLg = 1920;

  /// xl 兜底默认值。
  static const double defaultXl = 2560;

  /// 消费端读 effective 上界（合并后仍为 null → 静态 default）。
  double get xsOrDefault => xs ?? defaultXs;

  /// 消费端读 effective 上界。
  double get smOrDefault => sm ?? defaultSm;

  /// 消费端读 effective 上界。
  double get mdOrDefault => md ?? defaultMd;

  /// 消费端读 effective 上界。
  double get lgOrDefault => lg ?? defaultLg;

  /// 消费端读 effective 上界。
  double get xlOrDefault => xl ?? defaultXl;

  /// 逐属性合并：本节点非 null 胜出，null 落到 [ancestor]。
  ElBreakpoint mergeAncestor(ElBreakpoint ancestor) {
    if (identical(this, ancestor)) return this;
    final a = xs ?? ancestor.xs;
    final b = sm ?? ancestor.sm;
    final c = md ?? ancestor.md;
    final d = lg ?? ancestor.lg;
    final e = xl ?? ancestor.xl;
    final inherit = inheritSize ?? ancestor.inheritSize;
    if (identical(a, xs) &&
        identical(b, sm) &&
        identical(c, md) &&
        identical(d, lg) &&
        identical(e, xl) &&
        inherit == inheritSize) {
      return this;
    }
    if (xs == null && sm == null && md == null && lg == null && xl == null && inheritSize == null) return ancestor;
    return ElBreakpoint(xs: a, sm: b, md: c, lg: d, xl: e, inheritSize: inherit);
  }

  /// 拷贝并覆盖指定字段。传 null 保持原值（想清空需另行显式构造）。
  ElBreakpoint copyWith({double? xs, double? sm, double? md, double? lg, double? xl, bool? inheritSize}) =>
      ElBreakpoint(
        xs: xs ?? this.xs,
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        xl: xl ?? this.xl,
        inheritSize: inheritSize ?? this.inheritSize,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ElBreakpoint) return false;
    return xs == other.xs &&
        sm == other.sm &&
        md == other.md &&
        lg == other.lg &&
        xl == other.xl &&
        inheritSize == other.inheritSize;
  }

  @override
  int get hashCode => Object.hash(xs, sm, md, lg, xl, inheritSize);

  @override
  String toString() => 'ElBreakpoint(xs: $xs, sm: $sm, md: $md, lg: $lg, xl: $xl, inheritSize: $inheritSize)';
}

// ============================================================================
// Public style value types migrated from 'el_theme_mode.dart'.
// ============================================================================

/// ElView 主题声明：brightness 覆盖 + 主题切换过渡参数。
class ElThemeMode {
  /// 创建。三字段全部可空，交给消费端按祖先合并 + 兜底默认解析。
  const ElThemeMode({this.brightness, this.duration, this.curve});

  /// 明暗模式覆盖。null = 继承祖先 effective brightness（无声明则 light 兜底）。
  final Brightness? brightness;

  /// dark 切换统一过渡时长。null = 继承祖先声明；整条链未声明 → 消费端
  /// 兜底 [defaultDuration]。
  final Duration? duration;

  /// dark 切换统一过渡曲线。null = 继承祖先声明；整条链未声明 → 消费端
  /// 兜底 [defaultCurve]。
  final Curve? curve;

  /// duration 兜底默认值：整条祖先链无人声明时使用。
  static const Duration defaultDuration = Duration(milliseconds: 200);

  /// curve 兜底默认值：整条祖先链无人声明时使用。
  static const Curve defaultCurve = Curves.linear;

  /// 逐属性合并：本节点非 null 胜出，null 落到 [ancestor]。
  ///
  /// 例：`ElThemeMode(brightness: dark).mergeAncestor(ElThemeMode(duration: 500ms))`
  /// = `ElThemeMode(brightness: dark, duration: 500ms, curve: null)`——curve 继续
  /// 为 null，消费端向再上层祖先或最终兜底默认值追溯。
  ElThemeMode mergeAncestor(ElThemeMode ancestor) {
    // 三字段都相等则借用 identity（避免无效实例扩散）。
    if (identical(this, ancestor)) return this;
    final b = brightness ?? ancestor.brightness;
    final d = duration ?? ancestor.duration;
    final c = curve ?? ancestor.curve;
    // 所有字段都取自 this（ancestor 无补充）→ 直接返回 this。
    if (identical(b, brightness) && identical(d, duration) && identical(c, curve)) {
      return this;
    }
    // 所有字段都来自 ancestor（this 全 null）→ 直接返回 ancestor。
    if (brightness == null && duration == null && curve == null) return ancestor;
    return ElThemeMode(brightness: b, duration: d, curve: c);
  }

  /// 拷贝并覆盖指定字段。传 null 保持原值（想清空需另行显式构造）。
  ElThemeMode copyWith({Brightness? brightness, Duration? duration, Curve? curve}) => ElThemeMode(
    brightness: brightness ?? this.brightness,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ElThemeMode) return false;
    return brightness == other.brightness && duration == other.duration && curve == other.curve;
  }

  @override
  int get hashCode => Object.hash(brightness, duration, curve);

  @override
  String toString() => 'ElThemeMode(brightness: $brightness, duration: $duration, curve: $curve)';
}

/// CSS 对齐的预乘 alpha（premultiplied alpha）颜色插值。
Color? lerpColorPremul(Color? a, Color? b, double t) {
  if (a == null && b == null) return null;
  a ??= b!.withValues(alpha: 0.0);
  b ??= a.withValues(alpha: 0.0);
  if (identical(a, b)) return a;
  if (a.colorSpace != b.colorSpace) return Color.lerp(a, b, t);
  final wa = a.a * (1.0 - t);
  final wb = b.a * t;
  final alpha = wa + wb;
  if (alpha <= 0.0) return Color.lerp(a, b, t);
  return Color.from(
    alpha: alpha.clamp(0.0, 1.0),
    red: ((a.r * wa + b.r * wb) / alpha).clamp(0.0, 1.0),
    green: ((a.g * wa + b.g * wb) / alpha).clamp(0.0, 1.0),
    blue: ((a.b * wa + b.b * wb) / alpha).clamp(0.0, 1.0),
    colorSpace: a.colorSpace,
  );
}
