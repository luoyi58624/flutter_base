import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 显示多根手指接续驱动同一次拖拽时的位置和触点数量。
class ElPointerHandoffExample extends HookWidget {
  /// 创建多指接力示例。
  // ignore: prefer_const_constructors_in_immutables
  ElPointerHandoffExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final position = useState(Offset(20, 80));
    final pointers = useState(0);
    final phase = useState('就绪');

    return ElEventDemoSurface(
      footer: Row(
        children: [
          Expanded(child: Text(phase.value, key: ValueKey('advanced-handoff-phase'))),
          Text('触点 ${pointers.value}', key: ValueKey('advanced-handoff-count')),
          IconButton(
            key: ValueKey('advanced-handoff-reset'),
            tooltip: '重置',
            onPressed: () {
              position.value = Offset(20, 80);
              phase.value = '就绪';
            },
            icon: Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          Offset clamp(Offset value) => Offset(
            value.dx.clamp(0.0, math.max(0.0, constraints.maxWidth - 80)),
            value.dy.clamp(0.0, constraints.maxHeight - 80),
          );
          final current = clamp(position.value);
          return ElView(
            key: ValueKey('advanced-handoff-area'),
            event: ElEvent(
              cursor: SystemMouseCursors.move,
              dragStartDistance: 3,
              onPointerDown: (event) => pointers.value = event.pointerCount,
              onPointerUp: (event) => pointers.value = event.pointerCount,
              onPointerCancel: (event) => pointers.value = event.pointerCount,
              onDragStart: (event) {
                phase.value = '拖动中';
                pointers.value = event.pointerCount;
                event.stopPropagation();
              },
              onDragUpdate: (event) {
                position.value = clamp(clamp(position.value) + event.delta);
                pointers.value = event.pointerCount;
              },
              onDragEnd: (event) {
                pointers.value = event.pointerCount;
                phase.value = '已松手';
              },
              onDragCancel: (event) {
                pointers.value = event.pointerCount;
                phase.value = '已取消';
              },
            ),
            child: Stack(
              children: [
                Positioned(
                  left: current.dx,
                  top: current.dy,
                  width: 80,
                  height: 80,
                  child: DecoratedBox(
                    key: ValueKey('advanced-handoff-card'),
                    decoration: BoxDecoration(color: colors.primary, borderRadius: .circular(18)),
                    child: Icon(Icons.touch_app_rounded, size: 36, color: colors.onPrimary),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
