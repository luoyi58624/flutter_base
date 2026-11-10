import 'package:flutter/widgets.dart';

import '../../../../flutter/commons/theme/index.dart' show ElLevelTypeExt, ElThemeContextExt;
import '../../../../flutter/components/card/index.dart' show ElCard;
import '../../../../flutter/views/view/style/style.dart' show ElStyle, ElTransform, ElTransition;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../internal/common.dart';
import '../loading/index.dart';

/// 移动端卡片保留整卡按压反馈，内容和外观由公共声明提供。
Widget cardBuilder(BuildContext context, ElCard component) {
  final theme = context.elTheme;
  final interactive = component.onTap != null || component.event?.onTap != null;
  final enabled = interactive && !component.loading && component.event?.disabled != true;
  final style = ElStyle(
    width: '100%',
    backgroundColor: theme.cardColor,
    borderRadius: .circular(26),
    boxShadow: component.shadowLevel?.shadow(context),
    padding: const .fromLTRB(23, 25, 23, 26),
    userSelect: interactive ? .none : null,
    transition: reducedMotion(context)
        ? const []
        : const [ElTransition.all(Duration(milliseconds: 150), Curves.easeOut)],
    onTap: enabled ? ElStyle(backgroundColor: theme.cardPressColor, transform: ElTransform.scale(.96)) : null,
  ).merge(component.style);
  final content = Stack(
    alignment: .center,
    children: [
      ExcludeFocus(
        excluding: component.loading,
        child: TickerMode(
          enabled: !component.loading,
          child: Offstage(
            offstage: component.loading,
            child: Column(mainAxisSize: .min, crossAxisAlignment: .stretch, children: [?component.child]),
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
          delayTouchDown: component.event?.config?.delayTouchDown ?? Duration.zero,
          delayTouchUp: component.event?.config?.delayTouchUp ?? const Duration(milliseconds: 100),
          onActivate: (_) => component.onTap?.call(),
          child: content,
        )
      : ElView(style: style, event: component.event, child: content);
}
