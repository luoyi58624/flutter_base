import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 演示滚轮与触控板的事件回调。
class ElScrollEventExample extends HookWidget {
  /// 创建滚轮与触控板示例。
  // ignore: prefer_const_constructors_in_immutables
  ElScrollEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final currentEvent = useState('滚动或双指操作触控板');
    final colors = Theme.of(context).colorScheme;
    return ElView(
      style: .new(backgroundColor: colors.primaryContainer, alignment: .center, padding: .all(12), height: 72),
      event: ElEvent(
        onPointerSignal: (_) => currentEvent.value = 'onPointerSignal',
        onPointerPanZoomStart: (_) => currentEvent.value = 'onPointerPanZoomStart',
        onPointerPanZoomUpdate: (_) => currentEvent.value = 'onPointerPanZoomUpdate',
        onPointerPanZoomEnd: (_) => currentEvent.value = 'onPointerPanZoomEnd',
      ),
      child: Text(
        currentEvent.value,
        textAlign: .center,
        style: TextStyle(color: colors.onPrimaryContainer),
      ),
    );
  }
}
