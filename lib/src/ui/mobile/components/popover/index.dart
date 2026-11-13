import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../../../flutter/widgets/popup/arrow.dart' show PopupArrow, popupOrigin;

/// 移动弹出卡片：大圆角浮起卡片，从箭头处缩放淡入；默认点击切换，不附带悬停。
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
        minWidth: 160,
        maxWidth: c.width == null ? 320 : null,
        padding: const .all(16),
        borderRadius: .circular(16),
        border: .all(borderColor: t.borderColor),
        backgroundColor: t.cardColor,
        color: t.textRegular,
        fontSize: 14,
        lineHeight: 1.5,
      ).withShadow(level: ElLevelType.lg.shadow(context)).merge(c.style),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          if (c.title != null)
            ElView(
              style: ElStyle(fontSize: 16, fontWeight: .w600, color: t.textColor),
              child: c.title,
            ),
          Flexible(
            child: SingleChildScrollView(primary: false, child: ElView(child: c.content)),
          ),
        ],
      ),
    );
    return ElOverlayTransition(
      duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? .zero : const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 150),
      builder: (context, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation.drive(Tween(begin: .92, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic))),
          alignment: popupOrigin(context),
          child: c.showArrow
              ? PopupArrow(
                  color: c.style?.backgroundColor ?? t.cardColor,
                  borderColor: t.borderColor,
                  inset: 20,
                  child: panel,
                )
              : panel,
        ),
      ),
    );
  },
  child: c.child,
);
