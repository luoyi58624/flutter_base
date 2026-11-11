import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 演示键盘与焦点的事件回调。
class ElKeyboardEventExample extends HookWidget {
  /// 创建键盘与焦点示例。
  // ignore: prefer_const_constructors_in_immutables
  ElKeyboardEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final currentEvent = useState('聚焦后按键');
    final colors = Theme.of(context).colorScheme;
    final focusNode = useFocusNode();
    return ElView(
      style: .new(
        backgroundColor: colors.primaryContainer,
        alignment: .center,
        padding: .all(12),
        height: 72,
        onFocus: .new(backgroundColor: colors.secondaryContainer),
      ),
      focusNode: focusNode,
      event: ElEvent(
        onFocus: (_) => currentEvent.value = 'onFocus',
        onBlur: (_) => currentEvent.value = 'onBlur',
        onKeyDown: (_) => currentEvent.value = 'onKeyDown',
        onKeyRepeat: (_) => currentEvent.value = 'onKeyRepeat',
        onKeyUp: (_) => currentEvent.value = 'onKeyUp',
      ),
      child: Text(
        currentEvent.value,
        textAlign: .center,
        style: TextStyle(color: colors.onPrimaryContainer),
      ),
    );
  }
}
