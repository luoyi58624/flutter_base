import 'package:flutter/widgets.dart';

import '../../../../flutter/components/tokens.dart' show ElLevelTypeExt, ElThemeContextExt;
import '../../../../flutter/components/card/index.dart' show ElCard;
import '../../../../flutter/views/view/style/style.dart' show ElShadowStyleExt, ElStyle, ElTransform;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../internal/common.dart';
import '../loading/index.dart';

/// 移动端卡片保留整卡按压反馈，内容和外观由公共声明提供。
Widget cardBuilder(BuildContext context, ElCard component) {
  final theme = context.elTheme;
  final interactive = component.onTap != null || component.event?.onTap != null;
  final enabled = interactive && !component.loading && component.event?.disabled != true;
  final level = component.shadowLevel?.shadow(context);
  final baseStyle = ElStyle(
    width: '100%',
    backgroundColor: theme.cardColor,
    borderRadius: .circular(20),
    padding: const .all(16),
    userSelect: interactive ? .none : null,
    transition: enabled ? pressTransitions(theme) : null,
    onTap: enabled
        ? ElStyle(backgroundColor: theme.cardPressColor, transform: ElTransform.scale(theme.cardPressScale))
        : null,
  );
  final style = (level == null ? baseStyle : baseStyle.withShadow(level: level)).merge(component.style);
  final content = Stack(
    alignment: .center,
    children: [
      ExcludeFocus(
        excluding: component.loading,
        child: TickerMode(
          enabled: !component.loading,
          child: Offstage(
            offstage: component.loading,
            // 卡片不额外建立纵向 Flex，保留传给内嵌滚动区域的有限高度。
            child: SizedBox(width: double.infinity, child: component.child),
          ),
        ),
      ),
      if (component.loading) const Loading(),
    ],
  );
  return interactive
      ? ActionView(
          style: style,
          event: component.event,
          blocked: component.loading,
          excludeChildSemantics: false,
          ignoreDescendantAction: true,
          repeatEnter: false,
          trackTouchPress: true,
          delayTouchDown: component.event?.delayTouchDown ?? Duration.zero,
          delayTouchUp: component.event?.delayTouchUp ?? const Duration(milliseconds: 100),
          onActivate: (_) => component.onTap?.call(),
          child: content,
        )
      : ElView(style: style, event: component.event, child: content);
}
