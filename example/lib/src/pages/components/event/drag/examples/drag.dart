import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 使用自由拖拽在区域内移动一个色块。
class ElEventDragExample extends HookWidget {
  /// 创建可拖动色块示例。
  // ignore: prefer_const_constructors_in_immutables
  ElEventDragExample({super.key});

  @override
  Widget build(BuildContext context) {
    final position = useState(Offset(16, 16));
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 184,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(72.0, constraints.maxWidth);
          final maxX = constraints.maxWidth - width;
          final maxY = constraints.maxHeight - 48;

          Offset clampPosition(Offset point) => Offset(point.dx.clamp(0.0, maxX), point.dy.clamp(0.0, maxY));

          final current = clampPosition(position.value);
          return Stack(
            key: ValueKey('event-drag-area'),
            children: [
              Positioned.fill(child: ColoredBox(color: colors.secondaryContainer)),
              Positioned(
                left: current.dx,
                top: current.dy,
                width: width,
                height: 48,
                child: ElView(
                  key: ValueKey('event-drag-block'),
                  style: .new(alignment: .center, backgroundColor: colors.primary, color: colors.onPrimary),
                  event: ElEvent(
                    cursor: SystemMouseCursors.move,
                    // 让色块在外层滚动开始前先识别拖拽。
                    dragStartDistance: 3,
                    // 按下时截断向外层 ElView 的拖拽传播。
                    onDragDown: (event) => event.stopPropagation(),
                    // 使用全局位移，避免色块移动后局部坐标系跟着变化。
                    onDragUpdate: (event) =>
                        position.value = clampPosition(clampPosition(position.value) + event.delta),
                  ),
                  child: '拖动我',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
