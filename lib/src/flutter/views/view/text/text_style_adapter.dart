import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show WidgetSpan;

import '../style/style.dart';
import '../style/resolved/resolved_style.dart';

/// 将组件实际声明转换为稀疏文本样式。
TextStyle elStyleToTextStyle(ElStyle? s) => TextStyle(
  color: s?.color,
  fontSize: s?.fontSize,
  fontWeight: s?.fontWeight,
  fontStyle: s?.fontStyle,
  fontFamily: s?.fontFamily,
  fontFamilyFallback: s?.fontFamilyFallback,
  height: s?.lineHeight,
  leadingDistribution: s?.textOptions?.leadingDistribution,
  letterSpacing: s?.letterSpacing,
  wordSpacing: s?.wordSpacing,
  fontFeatures: s?.fontFeatureSettings,
  fontVariations: s?.fontVariationSettings,
  textBaseline: s?.textOptions?.textBaseline,
  decoration: s?.textDecorationLine,
  decorationColor: s?.textDecorationColor,
  decorationStyle: s?.textDecorationStyle,
  decorationThickness: s?.textDecorationThickness,
  backgroundColor: s?.textBackgroundColor,
  shadows: s?.textShadow,
);

/// 合并常用继承样式与当前文本的局部配置。
TextStyle inheritedTextToTextStyle(InheritedText s, {ElTextOptions? options}) => TextStyle(
  color: s.color,
  fontSize: s.fontSize,
  fontWeight: s.fontWeight,
  fontStyle: s.fontStyle,
  fontFamily: s.fontFamily,
  fontFamilyFallback: s.fontFamilyFallback,
  height: s.lineHeight,
  leadingDistribution: options?.leadingDistribution ?? TextLeadingDistribution.even,
  letterSpacing: s.letterSpacing,
  wordSpacing: s.wordSpacing,
  fontFeatures: s.fontFeatureSettings,
  fontVariations: s.fontVariationSettings,
  textBaseline: options?.textBaseline,
  decoration: s.textDecorationLine,
  decorationColor: s.textDecorationColor,
  decorationStyle: s.textDecorationStyle,
  decorationThickness: s.textDecorationThickness,
  backgroundColor: s.textBackgroundColor,
  shadows: s.textShadow,
);

/// span 按 Flutter 规则合并样式，粗体覆盖根字重，间距覆盖普通文本节点。
InlineSpan resolveTextSpan(
  InlineSpan span,
  TextStyle parent, {
  bool bold = false,
  TextStyle? spacing,
  Color? selected,
  bool overlay = false,
}) {
  var style = parent.merge(span.style);
  if (bold) style = style.copyWith(fontWeight: FontWeight.bold);
  final textSpacing = spacing != null && span.runtimeType == TextSpan ? spacing : null;
  if (textSpacing != null) style = style.merge(textSpacing);
  final output = overlay ? selectedTextStyleForColor(style, selected) : style;
  if (span is WidgetSpan) {
    return WidgetSpan(child: span.child, alignment: span.alignment, baseline: span.baseline, style: output);
  }
  if (span is! TextSpan) return span;
  return TextSpan(
    text: span.text,
    style: output,
    children: span.children
        ?.map((child) => resolveTextSpan(child, style, spacing: textSpacing, selected: selected, overlay: overlay))
        .toList(),
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    semanticsIdentifier: span.semanticsIdentifier,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}

/// 选中覆盖层只清除背景、替换字色，保留完整排版样式。
TextStyle selectedTextStyleForColor(TextStyle style, Color? color) => style.copyWith(
  foreground: color == null ? style.foreground : (Paint()..color = color),
  background: Paint()..color = const Color(0x00000000),
);

/// 编辑器与只读文本共用选中覆盖层的样式变换。
InlineSpan buildSelectionOverlaySpan(InlineSpan span, {Color? textColor}) =>
    resolveTextSpan(span, const TextStyle(), selected: textColor, overlay: true);
