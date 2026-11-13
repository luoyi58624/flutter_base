import 'package:flutter/widgets.dart';

import '../../../../flutter/widgets/popup/arrow.dart' show PopupArrow;
import '../../internal.dart';

/// 桌面提示沿用 Element 深色外观：悬停 waitDuration 后淡入，指针移到提示上保持打开，
/// 离开目标与提示 100 毫秒后淡出；触摸点击切换开闭。暗色模式下反转为浅底深字。
Widget tooltipBuilder(BuildContext context, ElTooltip c) => ElPopup(
  trigger: const {.hover},
  hoverIntent: ElHoverIntent(openDelay: c.waitDuration),
  anchor: ElOverlayAnchor(placement: c.placement, offset: c.arrow ? 10 : 6),
  disabled: c.disabled,
  event: c.event,
  builder: (context) {
    final t = context.elTheme;
    final panel = ElView(
      style: ElStyle(
        maxWidth: 360,
        padding: const .symmetric(horizontal: 11, vertical: 5),
        borderRadius: .circular(t.radiusSm),
        backgroundColor: t.textColor,
        color: t.bgColor,
        iconColor: t.bgColor,
        fontSize: 12,
        lineHeight: 20 / 12,
      ).merge(c.style),
      child: c.content,
    );
    return ElOverlayTransition(
      duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? .zero : const Duration(milliseconds: 150),
      builder: (context, animation) => FadeTransition(
        opacity: animation,
        child: c.arrow ? PopupArrow(color: c.style?.backgroundColor ?? t.textColor, size: 5, child: panel) : panel,
      ),
    );
  },
  child: Semantics(tooltip: c.content is String ? c.content as String : null, child: c.child),
);
