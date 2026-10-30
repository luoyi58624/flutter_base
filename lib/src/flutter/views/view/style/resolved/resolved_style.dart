import 'package:equatable/equatable.dart' show Equatable;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show CustomClipper;
import 'package:flutter/services.dart' show MouseCursor;

import '../style.dart';
import '../dimension.dart';

/// 文本相关继承字段组（25 个字段）。
@immutable
class InheritedText with Equatable {
  /// 创建实例。
  const InheritedText({
    this.color,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.fontFamily,
    this.fontFamilyFallback,
    this.lineHeight,
    this.letterSpacing,
    this.wordSpacing,
    this.fontFeatures,
    this.fontVariations,
    this.textAlign,
    this.textBaseline,
    this.leadingDistribution,
    this.textShadow,
    this.textGradient,
    this.decoration,
    this.decorationColor,
    this.decorationStyle,
    this.decorationThickness,
    this.textBackgroundColor,
    this.softWrap,
    this.overflow,
    this.maxLines,
  });

  /// CSS 文本初值。
  ///
  /// leadingDistribution 初值取 `even`：CSS line-height 的多余空间按半行距
  /// 均分到字形上下（half-leading），Flutter 默认的 proportional 会把大头
  /// 压在字形上方，字形在行盒里偏下——选区带/文本背景等铺满行盒的绘制
  /// 看起来整体偏上。可被 `ElStyle(leadingDistribution: .proportional)` 覆盖。
  static const InheritedText initial = InheritedText(
    color: Color(0xff000000),
    fontSize: 15,
    lineHeight: 1.2,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 从父节点文本组构造子节点的继承起点。
  ///
  /// [InheritedText] 是性能上的 group，不代表组内所有字段都按 CSS 继承。
  /// decoration / textBackgroundColor / softWrap / overflow / maxLines 必须回到
  /// initial；其余字段保留父值。父节点没有声明这些非继承字段时，直接复用父引用，
  /// 保持常见继承路径的 identical 快路径。
  static InheritedText fromInheritedParent(InheritedText? parent) {
    if (parent == null) return initial;
    if (parent._nonInheritedFieldsAreInitial) return parent;
    return InheritedText(
      color: parent.color,
      fontSize: parent.fontSize,
      fontWeight: parent.fontWeight,
      fontStyle: parent.fontStyle,
      fontFamily: parent.fontFamily,
      fontFamilyFallback: parent.fontFamilyFallback,
      lineHeight: parent.lineHeight,
      letterSpacing: parent.letterSpacing,
      wordSpacing: parent.wordSpacing,
      fontFeatures: parent.fontFeatures,
      fontVariations: parent.fontVariations,
      textAlign: parent.textAlign,
      textBaseline: parent.textBaseline,
      leadingDistribution: parent.leadingDistribution,
      textShadow: parent.textShadow,
      textGradient: parent.textGradient,
      decorationColor: parent.decorationColor,
      decorationStyle: parent.decorationStyle,
      decorationThickness: parent.decorationThickness,
      decoration: initial.decoration,
      textBackgroundColor: initial.textBackgroundColor,
      softWrap: initial.softWrap,
      overflow: initial.overflow,
      maxLines: initial.maxLines,
    );
  }

  bool get _nonInheritedFieldsAreInitial =>
      decoration == initial.decoration &&
      textBackgroundColor == initial.textBackgroundColor &&
      softWrap == initial.softWrap &&
      overflow == initial.overflow &&
      maxLines == initial.maxLines;

  /// 文本色。CSS 继承。
  final Color? color;

  /// 字号。CSS 继承。
  final double? fontSize;

  /// 字重。CSS 继承。保持强类型（`fontWeight: .w500` 点简写依赖类型上下文）。
  final FontWeight? fontWeight;

  /// 字形。CSS 继承。
  final FontStyle? fontStyle;

  /// 字体族。CSS 继承。
  final String? fontFamily;

  /// 字体回退。CSS 继承。
  final List<String>? fontFamilyFallback;

  /// 行高倍数。CSS 继承。
  final double? lineHeight;

  /// 字符间距。CSS 继承。
  final double? letterSpacing;

  /// 单词间距。CSS 继承。
  final double? wordSpacing;

  /// OpenType 字体特性。CSS 继承。
  final List<FontFeature>? fontFeatures;

  /// Variable Font 可变轴值。CSS 继承。
  /// 保留声明值，最终文字样式不额外调整轴值。
  final List<FontVariation>? fontVariations;

  /// 文本对齐。CSS 继承。
  final TextAlign? textAlign;

  /// 文本基线（alphabetic / ideographic）。CSS 继承。
  final TextBaseline? textBaseline;

  /// 行高 leading 上下分布策略。CSS 继承。
  final TextLeadingDistribution? leadingDistribution;

  /// 文本阴影列表。CSS 继承。
  final List<Shadow>? textShadow;

  /// 文字渐变（CSS `background-clip: text` 等价，一等字段替代 ShaderMask /
  /// foreground 手工方案）。按 color
  /// 族口径继承（rich inline 子段与嵌套 El 文本延续渐变）。
  final Gradient? textGradient;

  /// 文本装饰。CSS 不继承。
  final TextDecoration? decoration;

  /// 装饰线颜色。CSS 继承。
  final Color? decorationColor;

  /// 装饰线样式。CSS 继承。
  final TextDecorationStyle? decorationStyle;

  /// 装饰线粗细。CSS 继承。
  final double? decorationThickness;

  /// 文本背景色。CSS 不继承。
  final Color? textBackgroundColor;

  /// 是否允许软换行。CSS 不继承。
  final bool? softWrap;

  /// 文本溢出策略。CSS 不继承。
  final TextOverflow? overflow;

  /// 最大行数。CSS 不继承。
  final int? maxLines;

  /// 字段值参与结构相等，列表按元素比较。
  @override
  List<Object?> get props => [
    color,
    fontSize,
    fontWeight,
    fontStyle,
    fontFamily,
    fontFamilyFallback,
    lineHeight,
    letterSpacing,
    wordSpacing,
    fontFeatures,
    fontVariations,
    textAlign,
    textBaseline,
    leadingDistribution,
    textShadow,
    textGradient,
    decoration,
    decorationColor,
    decorationStyle,
    decorationThickness,
    textBackgroundColor,
    softWrap,
    overflow,
    maxLines,
  ];
}

/// 非文本继承字段组（5 个字段）：textDirection / cursor / pointerEvents /
/// iconSize / iconColor。
@immutable
class InheritedBox with Equatable {
  /// 创建实例。
  const InheritedBox({this.textDirection, this.cursor, this.pointerEvents, this.iconSize, this.iconColor});

  /// 全 null 初值（iconSize / iconColor 除外——图标 glyph 有独立默认，
  /// 不回落文本通道）。
  static const InheritedBox initial = InheritedBox(iconSize: 24, iconColor: Color(0xff909399));

  /// 文本方向（LTR / RTL）。CSS 继承。
  final TextDirection? textDirection;

  /// 鼠标光标。CSS 继承。
  final MouseCursor? cursor;

  /// 指针命中行为（CSS `pointer-events` 子集）。CSS 继承；hitTest 期实时读取，
  /// 无 layout / paint damage（变化所在帧结束后 MouseTracker 重命中即生效）。
  final ElPointerEvents? pointerEvents;

  /// 图标字号。CSS 继承。
  final double? iconSize;

  /// 图标颜色。CSS 继承。
  final Color? iconColor;

  /// 字段值参与结构相等，列表按元素比较。
  @override
  List<Object?> get props => [textDirection, cursor, pointerEvents, iconSize, iconColor];
}

/// 非继承字段组（27 个字段）：盒模型 + 装饰 + 约束几何 + transform + 视觉补全。
@immutable
class Box with Equatable {
  /// 创建实例。
  const Box({
    this.width,
    this.height,
    this.widthFactor,
    this.heightFactor,
    this.bgColor,
    this.padding,
    this.margin,
    this.alignment,
    this.border,
    this.borderRadius,
    this.clipper,
    this.boxShadow,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.opacity,
    this.transform,
    this.transformAlignment,
    this.clipBehavior,
    this.gradient,
    this.bgImage,
    this.outline,
    this.aspectRatio,
    this.filter,
    this.backdropFilter,
  });

  /// 全 null 初值。
  static const Box initial = Box();

  /// 内容宽度（像素）。
  final ElDimension? width;

  /// 内容高度（像素）。
  final ElDimension? height;

  /// auto 宽度相对自然盒宽的系数；
  final double? widthFactor;

  /// auto 高度相对自然盒高的系数；
  final double? heightFactor;

  /// 节点背景色。Paint 顺序:最底。
  final Color? bgColor;

  /// 内边距。
  final EdgeInsetsGeometry? padding;

  /// 外边距。形态同 [padding]。
  final EdgeInsetsGeometry? margin;

  /// 单 child 在节点内容区内的对齐（Flutter `Container.alignment` 语义）。
  final AlignmentGeometry? alignment;

  /// 边框。
  final ElBorder? border;

  /// 圆角。
  final BorderRadiusGeometry? borderRadius;

  /// 自定义裁剪形状。Paint-only，lerp = step（跟 Flutter `ClipPath` 一致）。
  final CustomClipper<Path>? clipper;

  /// 盒阴影列表。Paint-only。
  final List<BoxShadow>? boxShadow;

  /// 最小宽度约束。
  final ElDimension? minWidth;

  /// 最大宽度约束。
  final ElDimension? maxWidth;

  /// 最小高度约束。
  final ElDimension? minHeight;

  /// 最大高度约束。
  final ElDimension? maxHeight;

  /// 透明度（0~1）。Paint-only。
  final double? opacity;

  /// 视觉变换。Paint-only。
  final ElTransform? transform;

  /// 变换原点对齐（CSS `transform-origin`）。Paint-only。
  final AlignmentGeometry? transformAlignment;

  /// 裁剪行为。Paint-only。
  final Clip? clipBehavior;

  /// 渐变背景。Paint-only。Paint 顺序：在 bgImage 之上。
  ///
  final Gradient? gradient;

  /// 背景图（含 fit/alignment/repeat）。Paint-only。Paint 顺序：在 bgColor 之上、gradient 之下。
  final DecorationImage? bgImage;

  /// 描边（CSS outline 聚合：width / color / gradient / offset / position）。
  /// Paint-only。**永远不占 layout**。
  ///
  /// **lerp**：[ElOutline.lerp] 处理 null ↔ value 平滑过渡 ——
  /// width / color alpha / offset 都从 0 渐入 / 渐出（[ElOutline.zero] 替换 null 侧）。
  final ElOutline? outline;

  /// 宽高比（width÷height）。Layout。
  final double? aspectRatio;

  /// 自身滤镜（CSS `filter`）。Paint-only。
  final ElFilter? filter;

  /// backdrop filter（背景模糊，[ElFilter] 聚合）。Paint-only。
  ///
  /// paint 阶段默认按节点视觉边界裁剪滤镜区域；该裁剪独立于 [clipBehavior]，
  /// 不会裁掉 shadow / border / outline。lerp 同 [filter]。
  final ElFilter? backdropFilter;

  /// 字段值参与结构相等，列表按元素比较。
  @override
  List<Object?> get props => [
    width,
    height,
    widthFactor,
    heightFactor,
    bgColor,
    padding,
    margin,
    alignment,
    border,
    borderRadius,
    clipper,
    boxShadow,
    minWidth,
    maxWidth,
    minHeight,
    maxHeight,
    opacity,
    transform,
    transformAlignment,
    clipBehavior,
    gradient,
    bgImage,
    outline,
    aspectRatio,
    filter,
    backdropFilter,
  ];
}

/// 级联结果：继承字段共享父级引用，盒字段始终属于当前节点。
@immutable
class ResolvedStyle {
  const ResolvedStyle({required this.inheritedText, required this.inheritedBox, required this.box});

  /// 根节点的默认样式。
  static const initial = ResolvedStyle(
    inheritedText: InheritedText.initial,
    inheritedBox: InheritedBox.initial,
    box: Box.initial,
  );

  /// 文本继承字段。
  final InheritedText inheritedText;

  /// 光标、方向与图标等继承字段。
  final InheritedBox inheritedBox;

  /// 当前节点的盒模型与装饰字段。
  final Box box;

  /// 替换已发生变化的字段组。
  ResolvedStyle copyWith({InheritedText? inheritedText, InheritedBox? inheritedBox, Box? box}) => ResolvedStyle(
    inheritedText: inheritedText ?? this.inheritedText,
    inheritedBox: inheritedBox ?? this.inheritedBox,
    box: box ?? this.box,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedStyle &&
          inheritedText == other.inheritedText &&
          inheritedBox == other.inheritedBox &&
          box == other.box;
  @override
  int get hashCode => Object.hash(inheritedText, inheritedBox, box);
}
