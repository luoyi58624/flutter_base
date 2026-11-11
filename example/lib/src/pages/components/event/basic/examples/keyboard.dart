import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../log.dart';

/// 演示键盘与焦点的事件回调。
class ElKeyboardEventExample extends HookWidget {
  /// 创建键盘与焦点示例。
  // ignore: prefer_const_constructors_in_immutables
  ElKeyboardEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final focusNode = useFocusNode();
    return ElView(
      style: .new(
        backgroundColor: colors.primaryContainer,
        color: colors.onPrimaryContainer,
        alignment: .center,
        padding: .all(12),
        height: 72,
        onFocus: .new(backgroundColor: colors.primary, color: colors.onPrimary),
      ),
      focusNode: focusNode,
      event: ElEvent(
        onFocus: (event) => printEvent('onFocus', event.focusReason),
        onBlur: (event) => printEvent('onBlur', event.focusReason),
        onKeyDown: (event) => printEvent('onKeyDown', event.logicalKey?.keyLabel),
        onKeyRepeat: (event) => printEvent('onKeyRepeat', event.logicalKey?.keyLabel),
        onKeyUp: (event) => printEvent('onKeyUp', event.logicalKey?.keyLabel),
      ),
      child: '聚焦后按键',
    );
  }
}
