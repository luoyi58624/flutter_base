import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 使用鼠标右键、中键、前进键与后退键操作同一按钮。
class ElMouseEventExample extends HookWidget {
  /// 创建鼠标按键示例。
  // ignore: prefer_const_constructors_in_immutables
  ElMouseEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final feedback = useState(('鼠标按键', '右键 · 中键 · 前进 · 后退', Icons.mouse_outlined));
    final pressed = useState(false);

    void update(String label, String event, IconData icon, {bool held = false}) {
      feedback.value = (label, event, icon);
      pressed.value = held;
    }

    return ElEventDemoSurface(
      footer: Text(feedback.value.$2),
      child: Center(
        child: ElView(
          key: ValueKey('event-basic-mouse'),
          event: ElEvent(
            cursor: SystemMouseCursors.click,
            onSecondaryTapDown: (_) => update('右键', 'onSecondaryTapDown', Icons.mouse, held: true),
            onSecondaryTapUp: (_) => update('右键', 'onSecondaryTapUp', Icons.mouse),
            onSecondaryTap: (_) => update('右键', 'onSecondaryTap', Icons.mouse),
            onTertiaryTapDown: (_) => update('中键', 'onTertiaryTapDown', Icons.unfold_more, held: true),
            onTertiaryTapUp: (_) => update('中键', 'onTertiaryTapUp', Icons.unfold_more),
            onTertiaryTap: (_) => update('中键', 'onTertiaryTap', Icons.unfold_more),
            onForwardTapDown: (_) => update('前进键', 'onForwardTapDown', Icons.arrow_forward, held: true),
            onForwardTapUp: (_) => update('前进键', 'onForwardTapUp', Icons.arrow_forward),
            onForwardTap: (_) => update('前进键', 'onForwardTap', Icons.arrow_forward),
            onBackTapDown: (_) => update('后退键', 'onBackTapDown', Icons.arrow_back, held: true),
            onBackTapUp: (_) => update('后退键', 'onBackTapUp', Icons.arrow_back),
            onBackTap: (_) => update('后退键', 'onBackTap', Icons.arrow_back),
          ),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 120),
            width: 144,
            height: 112,
            decoration: BoxDecoration(
              color: pressed.value ? colors.primary : colors.secondaryContainer,
              borderRadius: .circular(20),
            ),
            child: Column(
              mainAxisAlignment: .center,
              spacing: 8,
              children: [
                Icon(
                  feedback.value.$3,
                  size: 48,
                  color: pressed.value ? colors.onPrimary : colors.onSecondaryContainer,
                ),
                Text(
                  feedback.value.$1,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: pressed.value ? colors.onPrimary : colors.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
