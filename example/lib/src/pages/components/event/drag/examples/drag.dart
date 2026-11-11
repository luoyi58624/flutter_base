import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 在区域边界内拖动卡片，并显示累计位移。
class ElEventDragExample extends HookWidget {
  /// 创建可拖动卡片示例。
  // ignore: prefer_const_constructors_in_immutables
  ElEventDragExample({super.key});

  @override
  Widget build(BuildContext context) {
    final position = useValueNotifier(Offset.zero);
    final lastOffset = useRef(Offset.zero);
    final currentEvent = useValueNotifier('—');
    final dragging = useValueNotifier(false);
    final colors = Theme.of(context).colorScheme;
    return ElEventDemoSurface(
      height: 280,
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

          return Stack(
            key: ValueKey('event-drag-area'),
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
                    key: ValueKey('event-drag-block'),
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
                      onDragStart: (event) {
                        lastOffset.value = event.dragOffset;
                        dragging.value = true;
                        currentEvent.value = 'onDragStart';
                      },
                      onDragUpdate: (event) {
                        move(event);
                        currentEvent.value = 'onDragUpdate';
                      },
                      onDragEnd: (event) {
                        move(event);
                        dragging.value = false;
                        currentEvent.value = 'onDragEnd';
                      },
                      onDragCancel: (_) {
                        dragging.value = false;
                        currentEvent.value = 'onDragCancel';
                      },
                    ),
                    child: Icon(
                      Icons.open_with_rounded,
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
                  key: ValueKey('event-drag-reset'),
                  semanticLabel: '重置拖拽',
                  variant: .text,
                  onPressed: () {
                    position.value = Offset.zero;
                    currentEvent.value = '—';
                    dragging.value = false;
                  },
                  child: Icons.restart_alt_rounded,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
