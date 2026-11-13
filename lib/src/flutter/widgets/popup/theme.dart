import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

import '../../views/view/render/render_view.dart' show ViewStateRenderAccess;
import '../../views/view/style/resolved/resolved_style.dart' show InheritedText;
import '../../views/view/style/style.dart';
import '../../views/view/style/style_context.dart' show StyleDependencyScope;
import '../../views/view/view.dart';

/// 保存命令式弹层的局部外观，使其可随目标 Overlay 独立存活。
@internal
final class PopupTheme {
  PopupTheme._(this._themes, this._style, this._mode, this._breakpoint, this._direction);

  final List<InheritedTheme> _themes;
  final ElStyle? _style;
  final ElThemeMode? _mode;
  final ElBreakpoint? _breakpoint;
  final TextDirection? _direction;

  /// 捕获到宿主的共同祖先为止，避免保留已解析样式对应的源 RenderObject。
  factory PopupTheme.capture(BuildContext context, {required BuildContext to}) {
    final themes = <InheritedTheme>[];
    final capturedTypes = <Type>{};
    context.visitAncestorElements((ancestor) {
      if (identical(ancestor, to)) return false;
      final widget = ancestor.widget;
      if (widget is InheritedTheme && widget is! StyleDependencyScope && capturedTypes.add(widget.runtimeType)) {
        themes.add(widget);
      }
      return true;
    });
    final view = StyleDependencyScope.maybeHostOf(context);
    final direction = Directionality.maybeOf(context);
    if (view == null || identical(view, StyleDependencyScope.maybeHostOf(to))) {
      return PopupTheme._(themes, null, null, null, direction);
    }
    final resolved = view.committedResolvedStyle;
    final text = InheritedText.fromInheritedParent(resolved.inheritedText);
    final box = resolved.inheritedBox;
    return PopupTheme._(
      themes,
      ElStyle(
        vars: view.internalVars,
        color: text.color,
        fontSize: text.fontSize,
        fontWeight: text.fontWeight,
        fontStyle: text.fontStyle,
        fontFamily: text.fontFamily,
        fontFamilyFallback: text.fontFamilyFallback,
        lineHeight: text.lineHeight,
        letterSpacing: text.letterSpacing,
        wordSpacing: text.wordSpacing,
        fontFeatureSettings: text.fontFeatureSettings,
        fontVariationSettings: text.fontVariationSettings,
        textAlign: text.textAlign,
        textShadow: text.textShadow,
        textGradient: text.textGradient,
        textDecorationColor: text.textDecorationColor,
        textDecorationStyle: text.textDecorationStyle,
        textDecorationThickness: text.textDecorationThickness,
        direction: box.direction,
        iconColor: box.iconColor,
        iconSize: box.iconSize,
      ),
      view.resolvedThemeMode,
      view.effectiveBreakpoint,
      direction,
    );
  }

  /// 在目标 Overlay 复建视觉作用域，保留宿主的窗口尺寸与键盘信息。
  Widget wrap(Widget child) => Builder(
    builder: (context) {
      var wrapped = child;
      if (_style case final style?) {
        wrapped = ElView(style: style, themeMode: _mode, breakpoint: _breakpoint, child: wrapped);
      }
      if (_direction case final direction?) {
        wrapped = Directionality(textDirection: direction, child: wrapped);
      }
      for (final theme in _themes) {
        wrapped = theme.wrap(context, wrapped);
      }
      return wrapped;
    },
  );
}
