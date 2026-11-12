import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../flutter.dart';

/// 提示复用 Portal 与事件入口，只有等待开关使用本地定时器。
Widget tooltipBuilder(BuildContext context, ElTooltip c) => _Tooltip(c);

class _Tooltip extends HookWidget {
  const _Tooltip(this.c);
  final ElTooltip c;
  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(ElPortalController.new);
    final timer = useRef<Timer?>(null);
    useEffect(
      () => () {
        timer.value?.cancel();
        controller.dispose();
      },
      [],
    );
    useEffect(() {
      if (c.disabled) {
        timer.value?.cancel();
        controller.close();
      }
      return null;
    }, [c.disabled]);
    void closeLater() {
      timer.value?.cancel();
      timer.value = Timer(const Duration(milliseconds: 180), controller.close);
    }

    void show(ElEventDetails event, ElEventHandler? handler) {
      handler?.call(event);
      if (event.defaultPrevented || c.disabled) return;
      timer.value?.cancel();
      controller.open();
      timer.value = Timer(c.showDuration, controller.close);
    }

    final base = c.event ?? const ElEvent();
    return ElPortal(
      controller: controller,
      anchor: ElOverlayAnchor(placement: c.placement, offset: 9),
      closeOnScroll: true,
      closeWhenUnlinked: true,
      overlayBuilder: (context) {
        final geometry = ElPortal.geometryOf(context);
        final panel = ElView(
          event: ElEvent(onPointerEnter: (_) => timer.value?.cancel(), onPointerExit: (_) => closeLater()),
          style: ElStyle(
            maxWidth: 280,
            padding: const .symmetric(horizontal: 14, vertical: 10),
            borderRadius: .circular(12),
            backgroundColor: context.elTheme.cardColor,
            color: context.elTheme.textColor,
            boxShadow: context.elTheme.shadowLg,
            border: .all(borderColor: context.elTheme.borderColor),
            fontSize: 12,
            lineHeight: 1.6,
          ).merge(c.style),
          child: c.content,
        );
        if (!c.arrow || geometry == null) return panel;
        final side = geometry.placement.side;
        final vertical = axisDirectionToAxis(side) == Axis.vertical;
        final target = geometry.arrowTarget;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            panel,
            Positioned(
              left: vertical
                  ? target.dx.clamp(14, geometry.overlayRect.width - 14) - 5
                  : side == .right
                  ? -5
                  : null,
              right: side == .left ? -5 : null,
              top: !vertical
                  ? target.dy.clamp(14, geometry.overlayRect.height - 14) - 5
                  : side == .down
                  ? -5
                  : null,
              bottom: side == .up ? -5 : null,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: .78539816339,
                  child: ElView(
                    style: ElStyle(
                      width: 10,
                      height: 10,
                      backgroundColor: c.style?.backgroundColor ?? context.elTheme.cardColor,
                      border: ElBorder.only(
                        borderTop: side == .down || side == .left
                            ? ElBorderSide(borderColor: context.elTheme.borderColor)
                            : ElBorderSide.none,
                        borderRight: side == .up || side == .left
                            ? ElBorderSide(borderColor: context.elTheme.borderColor)
                            : ElBorderSide.none,
                        borderBottom: side == .up || side == .right
                            ? ElBorderSide(borderColor: context.elTheme.borderColor)
                            : ElBorderSide.none,
                        borderLeft: side == .down || side == .right
                            ? ElBorderSide(borderColor: context.elTheme.borderColor)
                            : ElBorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: ElView(
        event: base.copyWith(
          onTap: (ElEventDetails e) => show(e, base.onTap),
          onLongPress: (ElEventDetails e) => show(e, base.onLongPress),
          onPointerEnter: (ElEventDetails e) {
            base.onPointerEnter?.call(e);
            if (e.defaultPrevented || c.disabled) return;
            timer.value?.cancel();
            timer.value = Timer(c.waitDuration, controller.open);
          },
          onPointerExit: (ElEventDetails e) {
            base.onPointerExit?.call(e);
            if (!e.defaultPrevented) closeLater();
          },
        ),
        child: c.child,
      ),
    );
  }
}
