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
    final position = useState(Offset.zero);
    final origin = useRef(Offset.zero);
    final currentEvent = useState('—');
    final dragging = useState(false);
    final colors = Theme.of(context).colorScheme;
    return ElEventDemoSurface(
      height: 280,
      footer: Row(
        spacing: 12,
        children: [
          Expanded(child: Text(currentEvent.value, maxLines: 1, overflow: .ellipsis)),
          Text('X ${position.value.dx.round()} · Y ${position.value.dy.round()}'),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(80.0, constraints.maxWidth);
          final center = Offset((constraints.maxWidth - size) / 2, (constraints.maxHeight - size) / 2);
          Offset clampPosition(Offset value) =>
              Offset(value.dx.clamp(-center.dx, center.dx), value.dy.clamp(-center.dy, center.dy));
          final current = clampPosition(position.value);
          return Stack(
            key: ValueKey('event-drag-area'),
            children: [
              Positioned(
                left: center.dx + current.dx,
                top: center.dy + current.dy,
                width: size,
                height: size,
                child: ElView(
                  key: ValueKey('event-drag-block'),
                  style: .new(
                    alignment: .center,
                    borderRadius: BorderRadius.circular(20),
                    backgroundColor: dragging.value ? colors.tertiary : colors.primary,
                  ),
                  event: ElEvent(
                    cursor: SystemMouseCursors.move,
                    dragStartDistance: 3,
                    onDragDown: (event) {
                      event.stopPropagation();
                      currentEvent.value = 'onDragDown';
                    },
                    onDragStart: (_) {
                      origin.value = current;
                      dragging.value = true;
                      currentEvent.value = 'onDragStart';
                    },
                    onDragUpdate: (event) {
                      // 累计全局位移不受卡片自身移动影响，越界时只夹持显示位置。
                      position.value = clampPosition(origin.value + event.dragOffset);
                      currentEvent.value = 'onDragUpdate';
                    },
                    onDragEnd: (event) {
                      position.value = clampPosition(origin.value + event.dragOffset);
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
                    color: dragging.value ? colors.onTertiary : colors.onPrimary,
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
                    position.value = origin.value = Offset.zero;
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
