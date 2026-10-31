import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show WidgetSpan;
import '../style/style.dart';
import '../style/resolved/resolved_style.dart';

/// 将组件实际声明转换为稀疏文本样式。
TextStyle elStyleToTextStyle(ElStyle? s) => inheritedTextToTextStyle(
  InheritedText(
    color: s?.color,
    fontSize: s?.fontSize,
    fontWeight: s?.fontWeight,
    fontStyle: s?.fontStyle,
    fontFamily: s?.fontFamily,
    fontFamilyFallback: s?.fontFamilyFallback,
    lineHeight: s?.lineHeight,
    leadingDistribution: s?.leadingDistribution,
    letterSpacing: s?.letterSpacing,
    wordSpacing: s?.wordSpacing,
    fontFeatureSettings: s?.fontFeatureSettings,
    fontVariationSettings: s?.fontVariationSettings,
    textBaseline: s?.textBaseline,
    textDecorationLine: s?.textDecorationLine,
    textDecorationColor: s?.textDecorationColor,
    textDecorationStyle: s?.textDecorationStyle,
    textDecorationThickness: s?.textDecorationThickness,
    textBackgroundColor: s?.textBackgroundColor,
    textShadow: s?.textShadow,
  ),
);

/// ElView、表格与编辑器共用继承样式映射。
TextStyle inheritedTextToTextStyle(InheritedText s) => TextStyle(
  color: s.color,
  fontSize: s.fontSize,
  fontWeight: s.fontWeight,
  fontStyle: s.fontStyle,
  fontFamily: s.fontFamily,
  fontFamilyFallback: s.fontFamilyFallback,
  height: s.lineHeight,
  leadingDistribution: s.leadingDistribution,
  letterSpacing: s.letterSpacing,
  wordSpacing: s.wordSpacing,
  fontFeatures: s.fontFeatureSettings,
  fontVariations: s.fontVariationSettings,
  textBaseline: s.textBaseline,
  decoration: s.textDecorationLine,
  decorationColor: s.textDecorationColor,
  decorationStyle: s.textDecorationStyle,
  decorationThickness: s.textDecorationThickness,
  backgroundColor: s.textBackgroundColor,
  shadows: s.textShadow,
);

/// span 按 Flutter 规则合并样式；系统粗体作用于根样式，显式轴值保持原样。
InlineSpan resolveTextSpan(
  InlineSpan span,
  TextStyle parent, {
  bool bold = false,
  Color? selected,
  bool overlay = false,
}) {
  final base = bold ? parent.merge(const TextStyle(fontWeight: FontWeight.bold)) : parent;
  final style = base.merge(span.style);
  final output = overlay ? selectedTextStyleForColor(style, selected) : style;
  if (span is WidgetSpan) {
    return WidgetSpan(child: span.child, alignment: span.alignment, baseline: span.baseline, style: output);
  }
  if (span is! TextSpan) return span;
  return TextSpan(
    text: span.text,
    style: output,
    children: span.children
        ?.map((child) => resolveTextSpan(child, style, selected: selected, overlay: overlay))
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
