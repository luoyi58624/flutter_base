import 'package:flutter/widgets.dart';

import '../../../../flutter/widgets/popup/arrow.dart' show PopupArrow;
import '../../internal.dart';

/// 桌面弹出卡片沿用 Element 外观：白底浅边框、4 圆角、12 内边距、最小宽 150，标题 16 号；进退场 150 毫秒淡入淡出。
Widget popoverBuilder(BuildContext context, ElPopover c) => ElPopup(
  controller: c.controller,
  trigger: c.trigger,
  hoverIntent: c.hoverIntent,
  anchor: ElOverlayAnchor(placement: c.placement, offset: c.showArrow ? 12 : 8),
  disabled: c.disabled,
  onOpenChanged: c.onOpenChanged,
  event: c.event,
  builder: (context) {
    final t = context.elTheme;
    final panel = ElView(
      style: ElStyle(
        width: c.width,
        minWidth: 150,
        maxWidth: c.width == null ? 400 : null,
        padding: const .all(12),
        borderRadius: .circular(t.radiusSm),
        border: .all(borderColor: t.borderColorLight),
        backgroundColor: t.cardColor,
        color: t.textRegular,
        fontSize: 14,
        lineHeight: 1.4,
      ).withShadow(level: ElLevelType.sm.shadow(context)).merge(c.style),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          if (c.title != null)
            ElView(
              style: ElStyle(fontSize: 16, lineHeight: 1.5, color: t.textColor),
              child: c.title,
            ),
          Flexible(
            child: SingleChildScrollView(primary: false, child: ElView(child: c.content)),
          ),
        ],
      ),
    );
    return ElOverlayTransition(
      duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? .zero : const Duration(milliseconds: 150),
      builder: (context, animation) => FadeTransition(
        opacity: animation,
        child: c.showArrow
            ? PopupArrow(color: c.style?.backgroundColor ?? t.cardColor, borderColor: t.borderColorLight, child: panel)
            : panel,
      ),
    );
  },
  child: c.child,
);
