import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 演示自由与轴向拖拽的事件回调。
class ElDragEventExample extends HookWidget {
  /// 创建自由与轴向拖拽示例。
  // ignore: prefer_const_constructors_in_immutables
  ElDragEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final dragEvent = useState('自由拖拽');
    final axisEvent = useState('横向或纵向拖拽');
    final colors = Theme.of(context).colorScheme;
    return Column(
      spacing: 8,
      crossAxisAlignment: .stretch,
      children: [
        ElView(
          style: .new(backgroundColor: colors.primaryContainer, alignment: .center, padding: .all(12), height: 72),
          event: ElEvent(
            dragStartDistance: 3,
            onDragDown: (event) {
              event.stopPropagation();
              dragEvent.value = 'onDragDown';
            },
            onDragStart: (_) => dragEvent.value = 'onDragStart',
            onDragUpdate: (_) => dragEvent.value = 'onDragUpdate',
            onDragEnd: (_) => dragEvent.value = 'onDragEnd',
            onDragCancel: (_) => dragEvent.value = 'onDragCancel',
          ),
          child: Text(
            dragEvent.value,
            textAlign: .center,
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
        ),
        ElView(
          style: .new(backgroundColor: colors.tertiaryContainer, alignment: .center, padding: .all(12), height: 72),
          event: ElEvent(
            dragStartDistance: 3,
            onDragDown: (event) {
              event.stopPropagation();
              axisEvent.value = 'onDragDown';
            },
            onHorizontalDragStart: (_) => axisEvent.value = 'onHorizontalDragStart',
            onHorizontalDragUpdate: (_) => axisEvent.value = 'onHorizontalDragUpdate',
            onHorizontalDragEnd: (_) => axisEvent.value = 'onHorizontalDragEnd',
            onHorizontalDragCancel: (_) => axisEvent.value = 'onHorizontalDragCancel',
            onVerticalDragStart: (_) => axisEvent.value = 'onVerticalDragStart',
            onVerticalDragUpdate: (_) => axisEvent.value = 'onVerticalDragUpdate',
            onVerticalDragEnd: (_) => axisEvent.value = 'onVerticalDragEnd',
            onVerticalDragCancel: (_) => axisEvent.value = 'onVerticalDragCancel',
          ),
          child: Text(
            axisEvent.value,
            textAlign: .center,
            style: TextStyle(color: colors.onTertiaryContainer),
          ),
        ),
      ],
    );
  }
}
