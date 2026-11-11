import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 演示鼠标按钮的事件回调。
class ElMouseEventExample extends HookWidget {
  /// 创建鼠标按钮示例。
  // ignore: prefer_const_constructors_in_immutables
  ElMouseEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final currentEvent = useState('右键、中键、前进或后退');
    final colors = Theme.of(context).colorScheme;
    return ElView(
      style: .new(backgroundColor: colors.primaryContainer, alignment: .center, padding: .all(12), height: 72),
      event: ElEvent(
        onSecondaryTapDown: (_) => currentEvent.value = 'onSecondaryTapDown',
        onSecondaryTapUp: (_) => currentEvent.value = 'onSecondaryTapUp',
        onSecondaryTap: (_) => currentEvent.value = 'onSecondaryTap',
        onTertiaryTapDown: (_) => currentEvent.value = 'onTertiaryTapDown',
        onTertiaryTapUp: (_) => currentEvent.value = 'onTertiaryTapUp',
        onTertiaryTap: (_) => currentEvent.value = 'onTertiaryTap',
        onForwardTapDown: (_) => currentEvent.value = 'onForwardTapDown',
        onForwardTapUp: (_) => currentEvent.value = 'onForwardTapUp',
        onForwardTap: (_) => currentEvent.value = 'onForwardTap',
        onBackTapDown: (_) => currentEvent.value = 'onBackTapDown',
        onBackTapUp: (_) => currentEvent.value = 'onBackTapUp',
        onBackTap: (_) => currentEvent.value = 'onBackTap',
      ),
      child: Text(
        currentEvent.value,
        textAlign: .center,
        style: TextStyle(color: colors.onPrimaryContainer),
      ),
    );
  }
}
