import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 单独观察双击与三击的按下和完成阶段。
class ElTapEventExample extends HookWidget {
  /// 创建连击示例。
  // ignore: prefer_const_constructors_in_immutables
  ElTapEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = useState(0);
    final pulse = useState(0);
    final callback = useState('连续点击两次或三次');

    void complete(int taps, String name) {
      count.value = taps;
      pulse.value++;
      callback.value = name;
    }

    final background = count.value == 3 ? colors.tertiaryContainer : colors.primaryContainer;
    final foreground = count.value == 3 ? colors.onTertiaryContainer : colors.onPrimaryContainer;
    return ElEventDemoSurface(
      footer: Text(callback.value),
      child: Center(
        child: ElView(
          key: ValueKey('event-basic-tap'),
          event: ElEvent(
            cursor: SystemMouseCursors.click,
            deferTap: true,
            onDoubleTapDown: (_) => callback.value = 'onDoubleTapDown',
            onDoubleTap: (_) => complete(2, 'onDoubleTap'),
            onTripleTapDown: (_) => callback.value = 'onTripleTapDown',
            onTripleTap: (_) => complete(3, 'onTripleTap'),
          ),
          child: SizedBox(
            width: 144,
            height: 120,
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(pulse.value),
                tween: Tween(begin: count.value == 0 ? 1 : .78, end: 1),
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 112,
                  height: 112,
                  alignment: .center,
                  decoration: BoxDecoration(color: background, shape: .circle),
                  child: count.value == 0
                      ? Icon(Icons.bolt, size: 48, color: foreground)
                      : Text(
                          '${count.value} 连击',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: foreground),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
