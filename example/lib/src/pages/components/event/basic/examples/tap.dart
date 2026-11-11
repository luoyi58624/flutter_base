import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 观察单击、双击与三击的识别结果。
class ElTapEventExample extends HookWidget {
  /// 创建连击示例。
  // ignore: prefer_const_constructors_in_immutables
  ElTapEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = useState(0);
    final pulse = useState(0);
    final callback = useState('轻点一次或连续点击');

    void complete(int taps, String name) {
      count.value = taps;
      pulse.value++;
      callback.value = name;
    }

    final background = count.value == 3 ? colors.tertiaryContainer : colors.primaryContainer;
    final foreground = count.value == 3 ? colors.onTertiaryContainer : colors.onPrimaryContainer;
    final result = switch (count.value) {
      1 => '单击',
      2 => '双击',
      3 => '三击',
      _ => null,
    };
    return ElEventDemoSurface(
      footer: Text(callback.value),
      child: Center(
        child: ElView(
          key: ValueKey('event-basic-tap'),
          event: ElEvent(
            cursor: SystemMouseCursors.click,
            deferTap: true,
            onTap: (_) => complete(1, 'onTap'),
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
                  child: result == null
                      ? Icon(Icons.bolt, size: 48, color: foreground)
                      : Text(result, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: foreground)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
