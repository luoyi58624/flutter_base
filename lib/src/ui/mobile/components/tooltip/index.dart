import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../flutter.dart';
import '../../../../flutter/widgets/popup/arrow.dart' show PopupArrow;

/// 移动提示：点击切换、长按打开，打开后 showDuration 自动关闭；目标所在区域滚动时关闭。移动端没有悬停触发。
Widget tooltipBuilder(BuildContext context, ElTooltip c) => _Tooltip(c);

class _Tooltip extends HookWidget {
  const _Tooltip(this.c);
  final ElTooltip c;

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(ElPopupController.new);
    final timer = useRef<Timer?>(null);
    useEffect(
      () => () {
        timer.value?.cancel();
        controller.dispose();
      },
      const [],
    );
    final base = c.event ?? const ElEvent();
    return ElPopup(
      controller: controller,
      anchor: ElOverlayAnchor(placement: c.placement, offset: c.arrow ? 10 : 6),
      disabled: c.disabled,
      closeOnScroll: true,
      onOpenChanged: (open) {
        timer.value?.cancel();
        if (open) timer.value = Timer(c.showDuration, controller.close);
      },
      event: base.copyWith(
        onLongPress: (ElEventDetails e) {
          base.onLongPress?.call(e);
          if (!e.defaultPrevented && !c.disabled) controller.open();
        },
      ),
      builder: (context) {
        final t = context.elTheme;
        final panel = ElView(
          style: ElStyle(
            maxWidth: 280,
            padding: const .symmetric(horizontal: 14, vertical: 10),
            borderRadius: .circular(12),
            backgroundColor: t.cardColor,
            color: t.textColor,
            border: .all(borderColor: t.borderColor),
            fontSize: 12,
            lineHeight: 1.6,
          ).withShadow(level: ElLevelType.lg.shadow(context)).merge(c.style),
          child: c.content,
        );
        return ElOverlayTransition(
          duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? .zero : const Duration(milliseconds: 200),
          builder: (context, animation) => FadeTransition(
            opacity: animation,
            child: c.arrow
                ? PopupArrow(
                    color: c.style?.backgroundColor ?? t.cardColor,
                    borderColor: t.borderColor,
                    size: 5,
                    inset: 16,
                    child: panel,
                  )
                : panel,
          ),
        );
      },
      child: Semantics(tooltip: c.content is String ? c.content as String : null, child: c.child),
    );
  }
}
