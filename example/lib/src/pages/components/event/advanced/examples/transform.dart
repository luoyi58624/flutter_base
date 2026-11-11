import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 演示同一图形从单指拖动连续切换为双指缩放。
class ElDragScaleExample extends HookWidget {
  /// 创建拖拽转缩放示例。
  // ignore: prefer_const_constructors_in_immutables
  ElDragScaleExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final position = useState(Offset.zero);
    final scale = useState(1.0);
    final scaleBase = useRef(1.0);
    final phase = useState('就绪');
    final pointers = useState(0);

    return ElEventDemoSurface(
      footer: Row(
        children: [
          Expanded(child: Text(phase.value, key: ValueKey('advanced-transform-phase'))),
          Text('${scale.value.toStringAsFixed(2)}×', key: ValueKey('advanced-transform-scale')),
          SizedBox(width: 12),
          Text('触点 ${pointers.value}', key: ValueKey('advanced-transform-count')),
          IconButton(
            key: ValueKey('advanced-transform-reset'),
            tooltip: '重置',
            onPressed: () {
              position.value = Offset.zero;
              scale.value = scaleBase.value = 1;
              phase.value = '就绪';
            },
            icon: Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxScale = math.max(1.0, math.min(2.0, (constraints.maxWidth - 24) / 100));
          Offset clamp(Offset value) {
            final x = math.max(0.0, (constraints.maxWidth - 100 * scale.value) / 2);
            final y = math.max(0.0, (constraints.maxHeight - 100 * scale.value) / 2);
            return Offset(value.dx.clamp(-x, x), value.dy.clamp(-y, y));
          }

          return ElView(
            key: ValueKey('advanced-transform-area'),
            style: .new(alignment: .center),
            event: ElEvent(
              cursor: SystemMouseCursors.move,
              dragStartDistance: 3,
              onPointerDown: (event) => pointers.value = event.pointerCount,
              onPointerUp: (event) => pointers.value = event.pointerCount,
              onPointerCancel: (event) => pointers.value = event.pointerCount,
              onDragStart: (event) {
                phase.value = '拖动中';
                event.stopPropagation();
              },
              onDragUpdate: (event) => position.value = clamp(clamp(position.value) + event.delta),
              onDragEnd: (_) => phase.value = '已松手',
              onDragCancel: (_) => phase.value = '拖动取消',
              onScaleStart: (event) {
                scaleBase.value = scale.value;
                phase.value = '缩放中';
                event.stopPropagation();
              },
              onScaleUpdate: (event) {
                scale.value = (scaleBase.value * event.scale).clamp(0.5, maxScale);
                position.value = clamp(position.value + event.delta);
              },
              onScaleEnd: (_) => phase.value = '已松手',
              onScaleCancel: (_) => phase.value = '缩放取消',
            ),
            child: Transform.translate(
              offset: clamp(position.value),
              child: Transform.scale(
                scale: scale.value,
                child: Container(
                  key: ValueKey('advanced-transform-card'),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(color: colors.primary, borderRadius: .circular(22)),
                  child: Icon(Icons.open_in_full_rounded, color: colors.onPrimary, size: 38),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
