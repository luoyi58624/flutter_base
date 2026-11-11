import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 在独立按钮上演示按下、松手、点击取消和长按。
class ElPressEventExample extends HookWidget {
  /// 创建按压示例。
  // ignore: prefer_const_constructors_in_immutables
  ElPressEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pressed = useState(false);
    final feedback = useState(('按下或长按', '等待按压'));

    void update(String label, String name, {bool held = false}) {
      pressed.value = held;
      feedback.value = (label, name);
    }

    return ElEventDemoSurface(
      footer: Text(feedback.value.$2),
      child: Center(
        child: ElView(
          key: ValueKey('event-basic-press'),
          event: ElEvent(
            cursor: SystemMouseCursors.click,
            onTapDown: (_) => update('按下', 'onTapDown', held: true),
            onTapUp: (_) => update('松手', 'onTapUp'),
            onTap: (_) => update('已点击', 'onTap'),
            onTapCancel: (event) {
              // 长按已生效时，点击取消只负责释放按压外观。
              if (event.cancelReason == .selfGestureAccepted && feedback.value.$2 == 'onLongPress') {
                pressed.value = false;
                return;
              }
              update('已取消', 'onTapCancel');
            },
            onLongPress: (_) => update('已长按', 'onLongPress'),
          ),
          child: AnimatedScale(
            scale: pressed.value ? .92 : 1,
            duration: Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 120),
              width: 152,
              height: 112,
              decoration: BoxDecoration(
                color: pressed.value ? colors.primary : colors.primaryContainer,
                borderRadius: .circular(24),
              ),
              child: Column(
                mainAxisAlignment: .center,
                spacing: 8,
                children: [
                  Icon(Icons.touch_app, size: 48, color: pressed.value ? colors.onPrimary : colors.onPrimaryContainer),
                  Text(
                    feedback.value.$1,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: pressed.value ? colors.onPrimary : colors.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
