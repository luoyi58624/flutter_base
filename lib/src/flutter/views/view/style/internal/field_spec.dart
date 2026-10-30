import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show CustomClipper;
import 'package:flutter/services.dart' show MouseCursor;

import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter_base/src/flutter/utils/internal/bit_mask.dart';
import 'package:flutter_base/src/flutter/views/view/style/dimension.dart';
import '../resolved/resolved_style.dart';
import '../resolved/builder.dart';

/// 从已提交样式读取字段。
typedef FieldReader = Object? Function(ResolvedStyle style);

/// 写字段到 builder（cascade 内部用）。
typedef FieldWriter = void Function(ResolvedStyleBuilder builder, Object? value);

/// 字段插值器。约定：每个 lerper 自行处理 null 视觉端点；isDiscrete 强制 step。
typedef FieldLerper = Object? Function(Object? from, Object? to, double t);

/// 单个可动画字段的完整元数据。
///
/// 集中字段行为；字段 ID 与分组由其所在元数据表确定。
/// cascade / 动画 / damage 路由都查同一张表，避免多处 switch。
typedef FieldSpec = ({
  /// 从声明样式读取原值，和解析后的读取共用字段表。
  Object? Function(ElStyle) declaration,

  /// 读当前值。
  FieldReader read,

  /// 写到 builder。
  FieldWriter write,

  /// 插值函数。
  FieldLerper lerp,

  /// 变化是否需要重新布局，和继承属性独立。
  bool affectsLayout,

  /// 变化是否需要重新绘制，和布局属性独立。
  bool affectsPaint,

  /// CSS 是否继承。注意 inheritedText group 内不是所有字段都继承。
  bool isInherited,

  /// 是否离散字段（枚举/bool/字符串等不能 lerp）。
  bool isDiscrete,
});

// ============================================================================
// lerp helpers
// ============================================================================

// 保留静态函数入口供常量元数据引用；统一 identity 早退、类型转换和原插值器的 null 规则。
@pragma('vm:prefer-inline')
Object? _typedLerp<T>(T? Function(T?, T?, double) lerp, Object? from, Object? to, double t) =>
    identical(from, to) ? from : lerp(from as T?, to as T?, t);

Object? _numericLerp(Object? from, Object? to, double t, double? fallback) {
  if (from == null && to == null) return null;
  if (from is! num? || to is! num? || (fallback == null && (from == null || to == null))) {
    return lerpStep(from, to, t);
  }
  return ui.lerpDouble(from?.toDouble() ?? fallback!, to?.toDouble() ?? fallback!, t);
}

/// 离散字段（含单侧 null）的兜底插值：以 t=0.5 为阈值 step。
Object? lerpStep(Object? from, Object? to, double t) {
  if (identical(from, to)) return from;
  return t < 0.5 ? from : to;
}

/// 颜色字段插值（color / decorationColor / textBackgroundColor / bgColor）。
Object? lerpColor(Object? from, Object? to, double t) => _typedLerp(lerpColorPremul, from, to, t);

/// 通用 double 插值（fontSize / lineHeight / decorationThickness / aspectRatio）。
Object? lerpDoubleValue(Object? from, Object? to, double t) => _numericLerp(from, to, t, null);

/// double 字段插值（initial value 为 0 的字段）：letterSpacing / wordSpacing /
/// outlineOffset。
Object? lerpDoubleZero(Object? from, Object? to, double t) => _numericLerp(from, to, t, 0);

/// opacity 字段插值。
Object? lerpOpacityValue(Object? from, Object? to, double t) => _numericLerp(from, to, t, 1);

/// 尺寸 factor 字段插值。
///
/// ElView 的 auto 轴默认 hug 自然盒，几何上等价 factor=1；因此
/// widthFactor / heightFactor 的单侧 null 用 1.0 替换后线性插值，变体进入
/// 与退出都不会在 null 端瞬跳。
Object? lerpFactorValue(Object? from, Object? to, double t) => lerpOpacityValue(from, to, t);

/// EdgeInsetsGeometry 字段插值（padding / margin）。
Object? lerpEdgeInsetsValue(Object? from, Object? to, double t) => _typedLerp(EdgeInsetsGeometry.lerp, from, to, t);

/// ElBorder 字段插值。
Object? lerpBorderValue(Object? from, Object? to, double t) => _typedLerp(ElBorder.lerp, from, to, t);

/// ElOutline 聚合字段插值。
Object? lerpOutline(Object? from, Object? to, double t) => _typedLerp(ElOutline.lerp, from, to, t);

/// ElFilter 聚合字段插值。
///
/// **空值语义**：null 视觉等价 [ElFilter.identity]（blur=0、saturate=1 等
/// CSS 恒等默认值），单侧 null 替换为 identity 后各分量平滑渐入 / 渐出。
/// 完成态由 driver 写回原 to（含 null），避免 committed style 残留 identity。
Object? lerpFilter(Object? from, Object? to, double t) => _typedLerp(ElFilter.lerp, from, to, t);

/// BoxShadow 列表插值。
Object? lerpBoxShadowListValue(Object? from, Object? to, double t) => _typedLerp(ElBoxShadow.lerpList, from, to, t);

/// 文本阴影按预乘 alpha 插值，列表长度差按原生 scale 规则渐入渐出。
///
/// color 分量覆盖为 [lerpColorPremul]（预乘 alpha，同 [ElBoxShadow.lerp] 口径）；
/// 几何分量（offset / blur）与列表长度差的 scale 渐入渐出沿用 Flutter 语义。
Object? lerpShadowListValue(Object? from, Object? to, double t) {
  if (identical(from, to)) return from;
  final a = (from as List<Shadow>?) ?? const <Shadow>[];
  final b = (to as List<Shadow>?) ?? const <Shadow>[];
  final common = a.length < b.length ? a.length : b.length;
  return <Shadow>[
    for (var i = 0; i < common; i++)
      Shadow(
        color: lerpColorPremul(a[i].color, b[i].color, t)!,
        offset: Offset.lerp(a[i].offset, b[i].offset, t)!,
        blurRadius: ui.lerpDouble(a[i].blurRadius, b[i].blurRadius, t)!,
      ),
    for (var i = common; i < a.length; i++) a[i].scale(1 - t),
    for (var i = common; i < b.length; i++) b[i].scale(t),
  ];
}

/// FontWeight 插值。
Object? lerpFontWeightValue(Object? from, Object? to, double t) => _typedLerp(FontWeight.lerp, from, to, t);

/// 渐变插值，缺失端点时使用离散切换。
Object? lerpGradientValue(Object? from, Object? to, double t) => _typedLerp(Gradient.lerp, from, to, t);

/// AlignmentGeometry 字段插值（alignment / transformAlignment）。
Object? lerpAlignment(Object? from, Object? to, double t) {
  if (identical(from, to)) return from;
  if (from == null || to == null) return lerpStep(from, to, t);
  return AlignmentGeometry.lerp(from as AlignmentGeometry, to as AlignmentGeometry, t);
}

/// ElTransform 字段插值。
///
/// transform 的 null 视觉等价 identity；单侧 null 时按 identity scale 参与插值，
/// 让 `null -> scale/translate` 和 `transform -> null` 都连续过渡。动画完成态
/// 仍由 driver 写回原始 target（可能为 null），避免 committed style 永久保留
/// identity transform。
Object? lerpTransform(Object? from, Object? to, double t) => _typedLerp(ElTransform.lerp, from, to, t);

/// BorderRadiusGeometry 字段插值。
Object? lerpBorderRadiusValue(Object? from, Object? to, double t) => _typedLerp(BorderRadiusGeometry.lerp, from, to, t);

double? parseNumericDoubleSlot(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  assert(false, "double 字段只接受 num / null；拒绝 ${v.runtimeType}: $v");
  return null;
}

int? parseNumericIntSlot(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  assert(false, "int 字段只接受 int / null；拒绝 ${v.runtimeType}: $v");
  return null;
}

/// 长度字段插值（width / height / minWidth / maxWidth / minHeight / maxHeight）。
Object? lerpLengthValue(Object? from, Object? to, double t) {
  if (from == null || to == null) return lerpStep(from, to, t);
  final a = from is ElDimension ? from : ElDimension.parse(from);
  final b = to is ElDimension ? to : ElDimension.parse(to);
  if (a == null || b == null) return lerpStep(from, to, t);
  return ElDimension.lerp(a, b, t);
}

// 字段表只在库初始化时构建，级联与动画复用同一组读写函数。
FieldSpec _field(
  Object? Function(ElStyle) declaration,
  FieldReader read,
  FieldWriter write,
  FieldLerper lerp, {
  bool layout = false,
  bool paint = false,
  bool inherited = false,
  bool discrete = false,
}) => (
  declaration: declaration,
  read: read,
  write: write,
  lerp: lerp,
  affectsLayout: layout,
  affectsPaint: paint,
  isInherited: inherited,
  isDiscrete: discrete,
);

final _inheritedTextSpecs = <ElTransitionField, FieldSpec>{
  ElTransitionField.color: _field(
    (s) => s.color,
    (s) => s.inheritedText.color,
    (b, v) => b.writeColor(v as Color?),
    lerpColor,
    paint: true,
    inherited: true,
  ),
  ElTransitionField.fontSize: _field(
    (s) => s.fontSize,
    (s) => s.inheritedText.fontSize,
    (b, v) => b.writeFontSize(parseNumericDoubleSlot(v)),
    lerpDoubleValue,
    layout: true,
    inherited: true,
  ),
  ElTransitionField.fontWeight: _field(
    (s) => s.fontWeight,
    (s) => s.inheritedText.fontWeight,
    (b, v) => b.writeFontWeight(v as FontWeight?),
    lerpFontWeightValue,
    layout: true,
    inherited: true,
  ),
  ElTransitionField.fontStyle: _field(
    (s) => s.fontStyle,
    (s) => s.inheritedText.fontStyle,
    (b, v) => b.writeFontStyle(v as FontStyle?),
    lerpStep,
    layout: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.fontFamily: _field(
    (s) => s.fontFamily,
    (s) => s.inheritedText.fontFamily,
    (b, v) => b.writeFontFamily(v as String?),
    lerpStep,
    layout: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.fontFamilyFallback: _field(
    (s) => s.fontFamilyFallback,
    (s) => s.inheritedText.fontFamilyFallback,
    (b, v) => b.writeFontFamilyFallback(v as List<String>?),
    lerpStep,
    layout: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.lineHeight: _field(
    (s) => s.lineHeight,
    (s) => s.inheritedText.lineHeight,
    (b, v) => b.writeLineHeight(parseNumericDoubleSlot(v)),
    lerpDoubleValue,
    layout: true,
    inherited: true,
  ),
  ElTransitionField.letterSpacing: _field(
    (s) => s.letterSpacing,
    (s) => s.inheritedText.letterSpacing,
    (b, v) => b.writeLetterSpacing(parseNumericDoubleSlot(v)),
    lerpDoubleZero,
    layout: true,
    inherited: true,
  ),
  ElTransitionField.wordSpacing: _field(
    (s) => s.wordSpacing,
    (s) => s.inheritedText.wordSpacing,
    (b, v) => b.writeWordSpacing(parseNumericDoubleSlot(v)),
    lerpDoubleZero,
    layout: true,
    inherited: true,
  ),
  ElTransitionField.fontFeatures: _field(
    (s) => s.fontFeatures,
    (s) => s.inheritedText.fontFeatures,
    (b, v) => b.writeFontFeatures(v as List<FontFeature>?),
    lerpStep,
    layout: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.fontVariations: _field(
    (s) => s.fontVariations,
    (s) => s.inheritedText.fontVariations,
    (b, v) => b.writeFontVariations(v as List<FontVariation>?),
    lerpStep,
    layout: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.textAlign: _field(
    (s) => s.textAlign,
    (s) => s.inheritedText.textAlign,
    (b, v) => b.writeTextAlign(v as TextAlign?),
    lerpStep,
    layout: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.textBaseline: _field(
    (s) => s.textBaseline,
    (s) => s.inheritedText.textBaseline,
    (b, v) => b.writeTextBaseline(v as TextBaseline?),
    lerpStep,
    layout: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.leadingDistribution: _field(
    (s) => s.leadingDistribution,
    (s) => s.inheritedText.leadingDistribution,
    (b, v) => b.writeLeadingDistribution(v as TextLeadingDistribution?),
    lerpStep,
    layout: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.textShadow: _field(
    (s) => s.textShadow,
    (s) => s.inheritedText.textShadow,
    (b, v) => b.writeTextShadow(v as List<Shadow>?),
    lerpShadowListValue,
    paint: true,
    inherited: true,
  ),
  ElTransitionField.textGradient: _field(
    (s) => s.textGradient,
    (s) => s.inheritedText.textGradient,
    (b, v) => b.writeTextGradient(v as Gradient?),
    lerpGradientValue,
    paint: true,
    inherited: true,
  ),
  ElTransitionField.decoration: _field(
    (s) => s.decoration,
    (s) => s.inheritedText.decoration,
    (b, v) => b.writeDecoration(v as TextDecoration?),
    lerpStep,
    paint: true,
    discrete: true,
  ),
  ElTransitionField.decorationColor: _field(
    (s) => s.decorationColor,
    (s) => s.inheritedText.decorationColor,
    (b, v) => b.writeDecorationColor(v as Color?),
    lerpColor,
    paint: true,
    inherited: true,
  ),
  ElTransitionField.decorationStyle: _field(
    (s) => s.decorationStyle,
    (s) => s.inheritedText.decorationStyle,
    (b, v) => b.writeDecorationStyle(v as TextDecorationStyle?),
    lerpStep,
    paint: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.decorationThickness: _field(
    (s) => s.decorationThickness,
    (s) => s.inheritedText.decorationThickness,
    (b, v) => b.writeDecorationThickness(parseNumericDoubleSlot(v)),
    lerpDoubleValue,
    paint: true,
    inherited: true,
  ),
  ElTransitionField.textBackgroundColor: _field(
    (s) => s.textBackgroundColor,
    (s) => s.inheritedText.textBackgroundColor,
    (b, v) => b.writeTextBackgroundColor(v as Color?),
    lerpColor,
    paint: true,
  ),
  ElTransitionField.softWrap: _field(
    (s) => s.softWrap,
    (s) => s.inheritedText.softWrap,
    (b, v) => b.writeSoftWrap(v as bool?),
    lerpStep,
    layout: true,
    discrete: true,
  ),
  ElTransitionField.overflow: _field(
    (s) => s.overflow,
    (s) => s.inheritedText.overflow,
    (b, v) => b.writeOverflow(v as TextOverflow?),
    lerpStep,
    layout: true,
    paint: true,
    discrete: true,
  ),
  ElTransitionField.maxLines: _field(
    (s) => s.maxLines,
    (s) => s.inheritedText.maxLines,
    (b, v) => b.writeMaxLines(parseNumericIntSlot(v)),
    lerpStep,
    layout: true,
    discrete: true,
  ),
};

final _inheritedBoxSpecs = <ElTransitionField, FieldSpec>{
  ElTransitionField.textDirection: _field(
    (s) => s.textDirection,
    (s) => s.inheritedBox.textDirection,
    (b, v) => b.writeTextDirection(v as TextDirection?),
    lerpStep,
    layout: true,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.cursor: _field(
    (s) => s.cursor,
    (s) => s.inheritedBox.cursor,
    (b, v) => b.writeCursor(v as MouseCursor?),
    lerpStep,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.pointerEvents: _field(
    (s) => s.pointerEvents,
    (s) => s.inheritedBox.pointerEvents,
    (b, v) => b.writePointerEvents(v as ElPointerEvents?),
    lerpStep,
    inherited: true,
    discrete: true,
  ),
  ElTransitionField.iconSize: _field(
    (s) => s.iconSize,
    (s) => s.inheritedBox.iconSize,
    (b, v) => b.writeIconSize(parseNumericDoubleSlot(v)),
    lerpDoubleValue,
    layout: true,
    inherited: true,
  ),
  ElTransitionField.iconColor: _field(
    (s) => s.iconColor,
    (s) => s.inheritedBox.iconColor,
    (b, v) => b.writeIconColor(v as Color?),
    lerpColor,
    paint: true,
    inherited: true,
  ),
};

final _boxSpecs = <ElTransitionField, FieldSpec>{
  ElTransitionField.width: _field(
    (s) => s.width,
    (s) => s.box.width,
    (b, v) => b.writeWidth(ElDimension.parse(v)),
    lerpLengthValue,
    layout: true,
  ),
  ElTransitionField.height: _field(
    (s) => s.height,
    (s) => s.box.height,
    (b, v) => b.writeHeight(ElDimension.parse(v)),
    lerpLengthValue,
    layout: true,
  ),
  ElTransitionField.widthFactor: _field(
    (s) => s.widthFactor,
    (s) => s.box.widthFactor,
    (b, v) => b.writeWidthFactor(parseNumericDoubleSlot(v)),
    lerpFactorValue,
    layout: true,
  ),
  ElTransitionField.heightFactor: _field(
    (s) => s.heightFactor,
    (s) => s.box.heightFactor,
    (b, v) => b.writeHeightFactor(parseNumericDoubleSlot(v)),
    lerpFactorValue,
    layout: true,
  ),
  ElTransitionField.bgColor: _field(
    (s) => s.bgColor,
    (s) => s.box.bgColor,
    (b, v) => b.writeBgColor(v as Color?),
    lerpColor,
    paint: true,
  ),
  ElTransitionField.padding: _field(
    (s) => s.padding,
    (s) => s.box.padding,
    (b, v) => b.writePadding(v as EdgeInsetsGeometry?),
    lerpEdgeInsetsValue,
    layout: true,
  ),
  ElTransitionField.margin: _field(
    (s) => s.margin,
    (s) => s.box.margin,
    (b, v) => b.writeMargin(v as EdgeInsetsGeometry?),
    lerpEdgeInsetsValue,
    layout: true,
  ),
  ElTransitionField.alignment: _field(
    (s) => s.alignment,
    (s) => s.box.alignment,
    (b, v) => b.writeAlignment(v as AlignmentGeometry?),
    lerpAlignment,
    layout: true,
  ),
  ElTransitionField.border: _field(
    (s) => s.border,
    (s) => s.box.border,
    (b, v) => b.writeBorder(v as ElBorder?),
    lerpBorderValue,
    paint: true,
  ),
  ElTransitionField.borderRadius: _field(
    (s) => s.borderRadius,
    (s) => s.box.borderRadius,
    (b, v) => b.writeBorderRadius(v as BorderRadiusGeometry?),
    lerpBorderRadiusValue,
    paint: true,
  ),
  ElTransitionField.clipper: _field(
    (s) => s.clipper,
    (s) => s.box.clipper,
    (b, v) => b.writeClipper(v as CustomClipper<Path>?),
    lerpStep,
    paint: true,
    discrete: true,
  ),
  ElTransitionField.boxShadow: _field(
    (s) => s.boxShadow,
    (s) => s.box.boxShadow,
    (b, v) => b.writeBoxShadow(v as List<BoxShadow>?),
    lerpBoxShadowListValue,
    paint: true,
  ),
  ElTransitionField.minWidth: _field(
    (s) => s.minWidth,
    (s) => s.box.minWidth,
    (b, v) => b.writeMinWidth(ElDimension.parse(v)),
    lerpLengthValue,
    layout: true,
  ),
  ElTransitionField.maxWidth: _field(
    (s) => s.maxWidth,
    (s) => s.box.maxWidth,
    (b, v) => b.writeMaxWidth(ElDimension.parse(v)),
    lerpLengthValue,
    layout: true,
  ),
  ElTransitionField.minHeight: _field(
    (s) => s.minHeight,
    (s) => s.box.minHeight,
    (b, v) => b.writeMinHeight(ElDimension.parse(v)),
    lerpLengthValue,
    layout: true,
  ),
  ElTransitionField.maxHeight: _field(
    (s) => s.maxHeight,
    (s) => s.box.maxHeight,
    (b, v) => b.writeMaxHeight(ElDimension.parse(v)),
    lerpLengthValue,
    layout: true,
  ),
  ElTransitionField.opacity: _field(
    (s) => s.opacity,
    (s) => s.box.opacity,
    (b, v) => b.writeOpacity(parseNumericDoubleSlot(v)),
    lerpOpacityValue,
    paint: true,
  ),
  ElTransitionField.transform: _field(
    (s) => s.transform,
    (s) => s.box.transform,
    (b, v) => b.writeTransform(v as ElTransform?),
    lerpTransform,
    paint: true,
  ),
  ElTransitionField.transformAlignment: _field(
    (s) => s.transformAlignment,
    (s) => s.box.transformAlignment,
    (b, v) => b.writeTransformAlignment(v as AlignmentGeometry?),
    lerpAlignment,
    paint: true,
  ),
  ElTransitionField.clipBehavior: _field(
    (s) => s.clipBehavior,
    (s) => s.box.clipBehavior,
    (b, v) => b.writeClipBehavior(v as Clip?),
    lerpStep,
    paint: true,
    discrete: true,
  ),
  ElTransitionField.gradient: _field(
    (s) => s.gradient,
    (s) => s.box.gradient,
    (b, v) => b.writeGradient(v as Gradient?),
    lerpGradientValue,
    paint: true,
  ),
  ElTransitionField.bgImage: _field(
    (s) => s.bgImage,
    (s) => s.box.bgImage,
    (b, v) => b.writeBgImage(v as DecorationImage?),
    lerpStep,
    paint: true,
    discrete: true,
  ),
  ElTransitionField.outline: _field(
    (s) => s.outline,
    (s) => s.box.outline,
    (b, v) => b.writeOutline(v as ElOutline?),
    lerpOutline,
    paint: true,
  ),
  ElTransitionField.aspectRatio: _field(
    (s) => s.aspectRatio,
    (s) => s.box.aspectRatio,
    (b, v) => b.writeAspectRatio(parseNumericDoubleSlot(v)),
    lerpDoubleValue,
    layout: true,
  ),
  ElTransitionField.filter: _field(
    (s) => s.filter,
    (s) => s.box.filter,
    (b, v) => b.writeFilter(v as ElFilter?),
    lerpFilter,
    paint: true,
  ),
  ElTransitionField.backdropFilter: _field(
    (s) => s.backdropFilter,
    (s) => s.box.backdropFilter,
    (b, v) => b.writeBackdropFilter(v as ElFilter?),
    lerpFilter,
    paint: true,
  ),
};

/// 全部字段的声明、解析读写、插值与损伤规则。
final fieldSpecs = <ElTransitionField, FieldSpec>{..._inheritedTextSpecs, ..._inheritedBoxSpecs, ..._boxSpecs};

/// 内部 index 查表——按 `ElTransitionField.values.index` 直查 spec。
final List<FieldSpec?> _fieldSpecByIndex = List<FieldSpec?>.generate(
  ElTransitionField.values.length,
  (i) => fieldSpecs[ElTransitionField.values[i]],
  growable: false,
);

/// 热路径 spec 查询——`ElTransitionField` → [FieldSpec] 常数级 index 直查。
@pragma('vm:prefer-inline')
FieldSpec fieldSpecOf(ElTransitionField f) {
  final spec = _fieldSpecByIndex[f.index];
  assert(spec != null, 'fieldSpecOf($f): spec-less field 不应进 cascade/damage/driver 路径。');
  return spec!;
}

/// 所有继承字段的集合（isInherited = true）。
Set<ElTransitionField> get inheritedFields => inheritedFieldsMask.fields.toSet();

/// 组字段位图 —— bit i 置 1 ⇔ `ElTransitionField.values[i]` 属于该组。
final FieldMask inheritedTextGroupMask = fieldsMask(_inheritedTextSpecs.keys);
final FieldMask inheritedBoxGroupMask = fieldsMask(_inheritedBoxSpecs.keys);
final FieldMask boxGroupMask = fieldsMask(_boxSpecs.keys);

/// 所有继承字段（`FieldSpec.isInherited = true`）的位图。
final FieldMask inheritedFieldsMask = _fieldsMaskWhere((s) => s.isInherited);

/// 所有影响布局的字段位图。
final FieldMask layoutAffectingMask = _fieldsMaskWhere((s) => s.affectsLayout);

/// 所有影响绘制的字段位图。
final FieldMask paintAffectingMask = _fieldsMaskWhere((s) => s.affectsPaint);

/// 影响溢出命中边界（ElOverflowHitBounds）的 **paint-only** 字段位图。
///
/// transform / transformAlignment 变化不触发 relayout（paintOnlyDamage），但
/// 会改变节点暴露给父级的命中边界映射——[DamageRouter.route] 命中此 mask 时
/// 额外走 `markHitBoundsDirty`（layout 字段无需入位：performLayout 入口已标脏）。
final FieldMask hitBoundsAffectingPaintOnlyMask = maskOr(
  maskBit(ElTransitionField.transform.index),
  maskBit(ElTransitionField.transformAlignment.index),
);

/// 影响「文本排版」的字段位图（inheritedText / inheritedBox 两组内 damage
/// 含 layout 位的字段）。
final FieldMask textLayoutAffectingMask = maskAnd(
  maskOr(inheritedTextGroupMask, inheritedBoxGroupMask),
  layoutAffectingMask,
);

FieldMask _fieldsMaskWhere(bool Function(FieldSpec) predicate) {
  var m = FieldMask.empty;
  for (final entry in fieldSpecs.entries) {
    if (predicate(entry.value)) m = maskSetBit(m, entry.key.index);
  }
  return m;
}

/// 无效的自然尺寸倍数视为未声明。
double? validStyleFactor(double? value) {
  final valid = value == null || value.isFinite && value >= 0;
  assert(valid, '尺寸因子必须是非负有限数。');
  return valid ? value : null;
}

/// 字段集合折叠为跨平台安全位图。
FieldMask fieldsMask(Iterable<ElTransitionField> fields) =>
    fields.fold(FieldMask.empty, (mask, field) => maskSetBit(mask, field.index));

/// 按字段顺序读取位图，避免内部传播往返构造 Set。
extension StyleFieldMask on FieldMask {
  /// 枚举已设置的字段。
  Iterable<ElTransitionField> get fields sync* {
    var remaining = this;
    while (remaining.isNotEmpty) {
      final index = maskLowestIndex(remaining);
      yield ElTransitionField.values[index];
      remaining = maskClearBit(remaining, index);
    }
  }
}
