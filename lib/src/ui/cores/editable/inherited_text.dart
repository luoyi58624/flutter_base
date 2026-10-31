import 'package:flutter/painting.dart';
import '../../../flutter/views/view/style/resolved/resolved_style.dart';

/// 将宿主已解析的文字样式送入编辑排版，不注册 Widget 构建依赖。
TextStyle editableInheritedTextStyle(ResolvedStyle resolved, Color? currentColor) {
  final text = resolved.inheritedText;
  return TextStyle(
    color: currentColor,
    fontSize: (text.fontSize as num?)?.toDouble(),
    fontWeight: text.fontWeight,
    fontStyle: text.fontStyle,
    fontFamily: text.fontFamily,
    fontFamilyFallback: text.fontFamilyFallback,
    height: (text.lineHeight as num?)?.toDouble(),
    leadingDistribution: text.leadingDistribution,
    letterSpacing: (text.letterSpacing as num?)?.toDouble(),
    wordSpacing: (text.wordSpacing as num?)?.toDouble(),
    textBaseline: text.textBaseline,
    fontFeatures: text.fontFeatureSettings,
    fontVariations: text.fontVariationSettings,
    decoration: text.textDecorationLine,
    decorationColor: text.textDecorationColor,
    decorationStyle: text.textDecorationStyle,
    decorationThickness: (text.textDecorationThickness as num?)?.toDouble(),
    backgroundColor: text.textBackgroundColor,
    shadows: text.textShadow,
  );
}
