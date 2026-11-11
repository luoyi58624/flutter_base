import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 使用滚轮移动滑块，用触控板平移与缩放滑块。
class ElScrollEventExample extends HookWidget {
  /// 创建滚轮与触控板示例。
  // ignore: prefer_const_constructors_in_immutables
  ElScrollEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final offset = useState(Offset.zero);
    final scale = useState(1.0);
    final startScale = useRef(1.0);
    final callback = useState('滚动鼠标或双指操作触控板');

    return ElEventDemoSurface(
      footer: Text(callback.value),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxX = (constraints.maxWidth / 2 - 60).clamp(0.0, 120.0);
          final maxY = (constraints.maxHeight / 2 - 56).clamp(0.0, 64.0);

          Offset move(Offset delta) {
            final next = offset.value + delta;
            return Offset(next.dx.clamp(-maxX, maxX), next.dy.clamp(-maxY, maxY));
          }

          return ElView(
            key: ValueKey('event-basic-scroll'),
            event: ElEvent(
              onPointerSignal: (event) {
                final pointer = event.pointerEvent;
                if (pointer is! PointerScrollEvent) return;
                final next = move(pointer.scrollDelta * .35);
                if (next != offset.value) event.preventDefault();
                offset.value = next;
                callback.value = 'onPointerSignal';
              },
              onPointerPanZoomStart: (_) {
                startScale.value = scale.value;
                callback.value = 'onPointerPanZoomStart';
              },
              onPointerPanZoomUpdate: (event) {
                offset.value = move(event.localDelta);
                scale.value = (startScale.value * event.scale).clamp(.6, 1.6);
                callback.value = 'onPointerPanZoomUpdate';
              },
              onPointerPanZoomEnd: (_) => callback.value = 'onPointerPanZoomEnd',
            ),
            child: SizedBox.expand(
              child: Stack(
                alignment: .center,
                children: [
                  Container(width: 2, height: maxY * 2 + 68, color: colors.outlineVariant),
                  Transform.translate(
                    offset: offset.value,
                    child: Transform.scale(
                      scale: scale.value,
                      child: Container(
                        width: 68,
                        height: 68,
                        alignment: .center,
                        decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: .circular(18)),
                        child: Icon(Icons.swap_vert, size: 40, color: colors.onPrimaryContainer),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
