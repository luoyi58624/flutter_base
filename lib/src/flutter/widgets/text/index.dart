import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter/widgets.dart';

import '../../views/view/semantics/semantics.dart';
import '../../views/view/style/style.dart';
import '../../views/view/view.dart';

/// 继承 Flutter 的默认文字样式，并使用 [ElView] 绘制文字和选区。
class ElText extends Text {
  /// 显示普通文本。
  const ElText(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    @Deprecated('请使用 textScaler。') super.textScaleFactor,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  /// 显示可包含文字样式和内联组件的富文本。
  const ElText.rich(
    super.textSpan, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    @Deprecated('请使用 textScaler。') super.textScaleFactor,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  }) : super.rich();

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    final effectiveStyle = defaults.style.merge(style);
    // ignore: deprecated_member_use
    final scaleFactor = textScaleFactor;
    final direction = textDirection ?? Directionality.of(context);
    final background = selectionColor ?? DefaultSelectionStyle.of(context).selectionColor;
    return ElView(
      locale: locale ?? Localizations.maybeLocaleOf(context),
      textScaler: textScaler ?? (scaleFactor == null ? null : TextScaler.linear(scaleFactor)),
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis ?? defaults.textWidthBasis,
      textHeightBehavior:
          textHeightBehavior ?? defaults.textHeightBehavior ?? DefaultTextHeightBehavior.maybeOf(context),
      style: ElStyle(
        direction: direction,
        textAlign: textAlign ?? defaults.textAlign ?? TextAlign.start,
        textOverflow: overflow ?? effectiveStyle.overflow ?? defaults.overflow,
        softWrap: softWrap ?? defaults.softWrap,
        maxLines: maxLines ?? defaults.maxLines,
        onSelection: background == null ? null : ElStyle(backgroundColor: background),
      ),
      semantics: semanticsLabel == null && semanticsIdentifier == null
          ? null
          : ElSemantics(
              properties: SemanticsProperties(
                label: semanticsLabel,
                identifier: semanticsIdentifier,
                textDirection: direction,
              ),
            ),
      // 保留 TextStyle 的画笔和富文本样式，并以 DefaultTextStyle 为继承起点。
      child: TextSpan(
        text: data,
        children: textSpan == null ? null : [textSpan!],
        style: effectiveStyle.copyWith(inherit: false),
        locale: locale,
      ),
    );
  }
}
