import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../log.dart';

/// 演示自由与轴向拖拽的事件回调。
class ElDragEventExample extends StatelessWidget {
  /// 创建自由与轴向拖拽示例。
  // ignore: prefer_const_constructors_in_immutables
  ElDragEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      spacing: 8,
      crossAxisAlignment: .stretch,
      children: [
        ElView(
          style: .new(
            backgroundColor: colors.primaryContainer,
            color: colors.onPrimaryContainer,
            alignment: .center,
            padding: .all(12),
            height: 72,
          ),
          event: ElEvent(
            dragStartDistance: 3,
            onDragDown: (event) {
              event.stopPropagation();
              printEvent('onDragDown', event.localPosition);
            },
            onDragStart: (_) => printEvent('onDragStart'),
            onDragUpdate: (event) => printEvent('onDragUpdate', event.localDelta),
            onDragEnd: (event) => printEvent('onDragEnd', event.velocity),
            onDragCancel: (event) => printEvent('onDragCancel', event.cancelReason),
          ),
          child: '自由拖拽',
        ),
        ElView(
          style: .new(
            backgroundColor: colors.tertiaryContainer,
            color: colors.onTertiaryContainer,
            alignment: .center,
            padding: .all(12),
            height: 72,
          ),
          event: ElEvent(
            dragStartDistance: 3,
            onDragDown: (event) => event.stopPropagation(),
            onHorizontalDragStart: (_) => printEvent('onHorizontalDragStart'),
            onHorizontalDragUpdate: (event) => printEvent('onHorizontalDragUpdate', event.localDelta.dx),
            onHorizontalDragEnd: (event) => printEvent('onHorizontalDragEnd', event.primaryVelocity),
            onHorizontalDragCancel: (event) => printEvent('onHorizontalDragCancel', event.cancelReason),
            onVerticalDragStart: (_) => printEvent('onVerticalDragStart'),
            onVerticalDragUpdate: (event) => printEvent('onVerticalDragUpdate', event.localDelta.dy),
            onVerticalDragEnd: (event) => printEvent('onVerticalDragEnd', event.primaryVelocity),
            onVerticalDragCancel: (event) => printEvent('onVerticalDragCancel', event.cancelReason),
          ),
          child: '横向或纵向拖拽',
        ),
      ],
    );
  }
}
