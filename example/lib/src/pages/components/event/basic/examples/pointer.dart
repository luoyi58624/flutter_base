import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 用圆点标记按下、移动和抬起时的指针位置。
class ElPointerEventExample extends HookWidget {
  /// 创建原始指针示例。
  // ignore: prefer_const_constructors_in_immutables
  ElPointerEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final position = useState<Offset?>(null);
    final active = useState(false);
    final callback = useState('等待指针');

    void track(ElEventDetails event, String name, {required bool pressed}) {
      position.value = event.localPosition;
      active.value = pressed;
      callback.value = name;
    }

    final point = position.value;
    return ElEventDemoSurface(
      footer: Text(point == null ? callback.value : '${callback.value} · ${point.dx.round()}, ${point.dy.round()}'),
      child: ElView(
        key: ValueKey('event-basic-pointer'),
        event: ElEvent(
          behavior: .opaque,
          // 先于外层滚动识别拖拽，舞台仍只展示原始指针事件。
          dragStartDistance: 3,
          onDragStart: (event) => event.stopPropagation(),
          onPointerDown: (event) => track(event, 'onPointerDown', pressed: true),
          onPointerMove: (event) => track(event, 'onPointerMove', pressed: true),
          onPointerUp: (event) => track(event, 'onPointerUp', pressed: false),
          onPointerCancel: (event) => track(event, 'onPointerCancel', pressed: false),
        ),
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: .expand,
              children: [
                if (point == null)
                  Center(
                    child: Column(
                      mainAxisSize: .min,
                      spacing: 8,
                      children: [
                        Icon(Icons.my_location, size: 48, color: colors.primary),
                        Text('按下并移动', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  )
                else
                  Positioned(
                    left: (point.dx.clamp(12.0, constraints.maxWidth - 12) - 12).toDouble(),
                    top: (point.dy.clamp(12.0, constraints.maxHeight - 12) - 12).toDouble(),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 120),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: .circle,
                        color: active.value ? colors.primary : colors.surface,
                        border: Border.all(color: colors.primary, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
