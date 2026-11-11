import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 演示自由、水平与垂直拖拽的完整事件过程。
class ElDragEventExample extends HookWidget {
  /// 创建拖拽基础示例。
  // ignore: prefer_const_constructors_in_immutables
  ElDragEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final axis = useState<Axis?>(null);
    final position = useValueNotifier(Offset.zero);
    final lastOffset = useRef(Offset.zero);
    final currentEvent = useValueNotifier('—');
    final dragging = useValueNotifier(false);
    final colors = Theme.of(context).colorScheme;
    final prefix = switch (axis.value) {
      null => 'onDrag',
      .horizontal => 'onHorizontalDrag',
      .vertical => 'onVerticalDrag',
    };

    void reset() {
      position.value = Offset.zero;
      currentEvent.value = '—';
      dragging.value = false;
    }

    return Column(
      spacing: 12,
      crossAxisAlignment: .stretch,
      children: [
        Row(
          spacing: 8,
          children: [
            for (final option in <(Axis?, String, String)>[
              (null, '自由', 'free'),
              (.horizontal, '水平', 'horizontal'),
              (.vertical, '垂直', 'vertical'),
            ])
              Expanded(
                child: ElButton(
                  key: ValueKey('event-basic-drag-${option.$3}'),
                  type: axis.value == option.$1 ? .primary : null,
                  variant: axis.value == option.$1 ? .solid : .text,
                  onPressed: () {
                    axis.value = option.$1;
                    reset();
                  },
                  child: option.$2,
                ),
              ),
          ],
        ),
        ElEventDemoSurface(
          footer: ListenableBuilder(
            listenable: Listenable.merge([position, currentEvent]),
            builder: (context, child) => Row(
              spacing: 12,
              children: [
                Expanded(child: Text(currentEvent.value, maxLines: 1, overflow: .ellipsis)),
                Text('X ${position.value.dx.round()} · Y ${position.value.dy.round()}'),
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(80.0, constraints.maxWidth);
              final center = Offset((constraints.maxWidth - size) / 2, (constraints.maxHeight - size) / 2);
              Offset clampPosition(Offset value) =>
                  Offset(value.dx.clamp(-center.dx, center.dx), value.dy.clamp(-center.dy, center.dy));

              void move(ElEventDetails event) {
                // 丢弃越界余量，回拖立即跟手；松手时也补上最后一段位移。
                final delta = event.dragOffset - lastOffset.value;
                lastOffset.value = event.dragOffset;
                position.value = clampPosition(clampPosition(position.value) + delta);
              }

              void start(ElEventDetails event) {
                lastOffset.value = event.dragOffset;
                dragging.value = true;
                currentEvent.value = '${prefix}Start';
              }

              void update(ElEventDetails event) {
                move(event);
                currentEvent.value = '${prefix}Update';
              }

              void end(ElEventDetails event) {
                move(event);
                dragging.value = false;
                currentEvent.value = '${prefix}End';
              }

              void cancel(ElEventDetails event) {
                dragging.value = false;
                currentEvent.value = '${prefix}Cancel';
              }

              return Stack(
                key: ValueKey('event-basic-drag'),
                children: [
                  ValueListenableBuilder<Offset>(
                    valueListenable: position,
                    builder: (context, value, child) {
                      final current = clampPosition(value);
                      return Positioned(
                        left: center.dx + current.dx,
                        top: center.dy + current.dy,
                        width: size,
                        height: size,
                        child: child!,
                      );
                    },
                    child: ValueListenableBuilder<bool>(
                      valueListenable: dragging,
                      builder: (context, active, child) => ElView(
                        key: ValueKey('event-basic-drag-block'),
                        style: .new(
                          alignment: .center,
                          borderRadius: BorderRadius.circular(20),
                          backgroundColor: active ? colors.tertiary : colors.primary,
                        ),
                        event: ElEvent(
                          cursor: SystemMouseCursors.move,
                          dragStartDistance: 3,
                          onDragDown: (event) {
                            event.stopPropagation();
                            currentEvent.value = 'onDragDown';
                          },
                          onDragStart: axis.value == null ? start : null,
                          onDragUpdate: axis.value == null ? update : null,
                          onDragEnd: axis.value == null ? end : null,
                          onDragCancel: axis.value == null ? cancel : null,
                          onHorizontalDragStart: axis.value == .horizontal ? start : null,
                          onHorizontalDragUpdate: axis.value == .horizontal ? update : null,
                          onHorizontalDragEnd: axis.value == .horizontal ? end : null,
                          onHorizontalDragCancel: axis.value == .horizontal ? cancel : null,
                          onVerticalDragStart: axis.value == .vertical ? start : null,
                          onVerticalDragUpdate: axis.value == .vertical ? update : null,
                          onVerticalDragEnd: axis.value == .vertical ? end : null,
                          onVerticalDragCancel: axis.value == .vertical ? cancel : null,
                        ),
                        child: Icon(
                          switch (axis.value) {
                            null => Icons.open_with_rounded,
                            .horizontal => Icons.swap_horiz_rounded,
                            .vertical => Icons.swap_vert_rounded,
                          },
                          size: 32,
                          color: active ? colors.onTertiary : colors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: ElButton(
                      key: ValueKey('event-basic-drag-reset'),
                      semanticLabel: '重置拖拽',
                      variant: .text,
                      onPressed: reset,
                      child: Icons.restart_alt_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
