import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 演示点击、连击与长按的事件回调。
class ElTapEventExample extends HookWidget {
  /// 创建点击、连击与长按示例。
  // ignore: prefer_const_constructors_in_immutables
  ElTapEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final tapEvent = useState('点击或连击');
    final longPressEvent = useState('按住色块');
    final colors = Theme.of(context).colorScheme;
    return Column(
      spacing: 8,
      crossAxisAlignment: .stretch,
      children: [
        ElView(
          key: ValueKey('event-basic-tap'),
          style: .new(backgroundColor: colors.primaryContainer, alignment: .center, padding: .all(12), height: 72),
          event: ElEvent(
            deferTap: true,
            onTapDown: (_) => tapEvent.value = 'onTapDown',
            onTapUp: (_) => tapEvent.value = 'onTapUp',
            onTap: (_) => tapEvent.value = 'onTap',
            onTapCancel: (_) => tapEvent.value = 'onTapCancel',
            onDoubleTapDown: (_) => tapEvent.value = 'onDoubleTapDown',
            onDoubleTap: (_) => tapEvent.value = 'onDoubleTap',
            onTripleTapDown: (_) => tapEvent.value = 'onTripleTapDown',
            onTripleTap: (_) => tapEvent.value = 'onTripleTap',
          ),
          child: Text(
            tapEvent.value,
            textAlign: .center,
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
        ),
        ElView(
          key: ValueKey('event-basic-long-press'),
          style: .new(backgroundColor: colors.tertiaryContainer, alignment: .center, padding: .all(12), height: 72),
          event: ElEvent(onLongPress: (_) => longPressEvent.value = 'onLongPress'),
          child: Text(
            longPressEvent.value,
            textAlign: .center,
            style: TextStyle(color: colors.onTertiaryContainer),
          ),
        ),
      ],
    );
  }
}
