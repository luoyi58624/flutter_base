import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../log.dart';

/// 演示缩放与旋转的事件回调。
class ElScaleEventExample extends StatelessWidget {
  /// 创建缩放与旋转示例。
  // ignore: prefer_const_constructors_in_immutables
  ElScaleEventExample({super.key});

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
        onScaleStart: (event) => printEvent('onScaleStart', event.pointerCount),
        onScaleUpdate: (event) => printEvent('onScaleUpdate', event.scale),
        onScaleEnd: (_) => printEvent('onScaleEnd'),
        onScaleCancel: (event) => printEvent('onScaleCancel', event.cancelReason),
        onRotationUpdate: (event) => printEvent('onRotationUpdate', event.rotation),
      ),
      child: '双指缩放或旋转',
    );
  }
}
