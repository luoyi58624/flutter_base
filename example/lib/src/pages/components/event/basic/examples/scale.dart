import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 演示缩放与旋转的事件回调。
class ElScaleEventExample extends HookWidget {
  /// 创建缩放与旋转示例。
  // ignore: prefer_const_constructors_in_immutables
  ElScaleEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final currentEvent = useState('双指缩放或旋转');
    final colors = Theme.of(context).colorScheme;
    return ElView(
      style: .new(backgroundColor: colors.primaryContainer, alignment: .center, padding: .all(12), height: 72),
      event: ElEvent(
        onScaleStart: (_) => currentEvent.value = 'onScaleStart',
        onScaleUpdate: (_) => currentEvent.value = 'onScaleUpdate',
        onScaleEnd: (_) => currentEvent.value = 'onScaleEnd',
        onScaleCancel: (_) => currentEvent.value = 'onScaleCancel',
        onRotationUpdate: (_) => currentEvent.value = 'onRotationUpdate',
      ),
      child: Text(
        currentEvent.value,
        textAlign: .center,
        style: TextStyle(color: colors.onPrimaryContainer),
      ),
    );
  }
}
