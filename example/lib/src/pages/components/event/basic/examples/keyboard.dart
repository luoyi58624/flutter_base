import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 聚焦后用键帽显示真实按键与按下状态。
class ElKeyboardEventExample extends HookWidget {
  /// 创建键盘示例。
  // ignore: prefer_const_constructors_in_immutables
  ElKeyboardEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final focus = useFocusNode();
    final focused = useState(false);
    final pressed = useState(false);
    final keyLabel = useState('');
    final callback = useState('点击或按 Tab 聚焦');

    void showKey(ElEventDetails event, String name, {required bool down}) {
      final label = event.logicalKey?.keyLabel;
      keyLabel.value = label == null || label.trim().isEmpty ? '空格' : label;
      pressed.value = down;
      callback.value = name;
    }

    return ElEventDemoSurface(
      footer: Text(callback.value),
      child: Center(
        child: ElView(
          key: ValueKey('event-basic-keyboard'),
          focusNode: focus,
          event: ElEvent(
            cursor: SystemMouseCursors.click,
            onFocus: (_) {
              focused.value = true;
              callback.value = 'onFocus';
            },
            onBlur: (_) {
              focused.value = false;
              pressed.value = false;
              callback.value = 'onBlur';
            },
            onKeyDown: (event) => showKey(event, 'onKeyDown', down: true),
            onKeyRepeat: (event) => showKey(event, 'onKeyRepeat', down: true),
            onKeyUp: (event) => showKey(event, 'onKeyUp', down: false),
          ),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 120),
            width: 152,
            height: 100,
            alignment: .center,
            padding: .all(12),
            decoration: BoxDecoration(
              color: pressed.value ? colors.primaryContainer : colors.surface,
              border: Border.all(color: focused.value ? colors.primary : colors.outlineVariant, width: 2),
              borderRadius: .circular(16),
            ),
            child: keyLabel.value.isEmpty
                ? Icon(Icons.keyboard_outlined, size: 48, color: colors.primary)
                : FittedBox(
                    fit: .scaleDown,
                    child: Text(keyLabel.value, style: Theme.of(context).textTheme.headlineMedium),
                  ),
          ),
        ),
      ),
    );
  }
}
