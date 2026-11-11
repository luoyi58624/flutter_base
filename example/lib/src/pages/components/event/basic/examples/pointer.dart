import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 演示指针与悬停的事件回调。
class ElPointerEventExample extends HookWidget {
  /// 创建指针与悬停示例。
  // ignore: prefer_const_constructors_in_immutables
  ElPointerEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final pointerEvent = useState('按下并移动');
    final hoverEvent = useState('移入、悬停、移出');
    final colors = Theme.of(context).colorScheme;
    return Column(
      spacing: 8,
      crossAxisAlignment: .stretch,
      children: [
        ElView(
          style: .new(backgroundColor: colors.primaryContainer, alignment: .center, padding: .all(12), height: 72),
          event: ElEvent(
            onPointerDown: (_) => pointerEvent.value = 'onPointerDown',
            onPointerMove: (_) => pointerEvent.value = 'onPointerMove',
            onPointerUp: (_) => pointerEvent.value = 'onPointerUp',
            onPointerCancel: (_) => pointerEvent.value = 'onPointerCancel',
          ),
          child: Text(
            pointerEvent.value,
            textAlign: .center,
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
        ),
        ElView(
          style: .new(backgroundColor: colors.tertiaryContainer, alignment: .center, padding: .all(12), height: 72),
          event: ElEvent(
            onPointerEnter: (_) => hoverEvent.value = 'onPointerEnter',
            onPointerHover: (_) => hoverEvent.value = 'onPointerHover',
            onPointerExit: (_) => hoverEvent.value = 'onPointerExit',
          ),
          child: Text(
            hoverEvent.value,
            textAlign: .center,
            style: TextStyle(color: colors.onTertiaryContainer),
          ),
        ),
      ],
    );
  }
}
