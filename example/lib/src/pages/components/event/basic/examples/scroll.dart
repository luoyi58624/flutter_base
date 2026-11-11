import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../log.dart';

/// 演示滚轮与触控板的事件回调。
class ElScrollEventExample extends StatelessWidget {
  /// 创建滚轮与触控板示例。
  // ignore: prefer_const_constructors_in_immutables
  ElScrollEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ElView(
      style: .new(
        backgroundColor: colors.primaryContainer,
        color: colors.onPrimaryContainer,
        alignment: .center,
        padding: .all(12),
        height: 72,
      ),
      event: ElEvent(
        onPointerSignal: (event) => printEvent('onPointerSignal', event.pointerEvent),
        onPointerPanZoomStart: (_) => printEvent('onPointerPanZoomStart'),
        onPointerPanZoomUpdate: (event) => printEvent('onPointerPanZoomUpdate', event.pointerEvent),
        onPointerPanZoomEnd: (_) => printEvent('onPointerPanZoomEnd'),
      ),
      child: '滚动或双指操作触控板',
    );
  }
}
