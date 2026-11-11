import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../log.dart';

/// 演示点击、连击与长按的事件回调。
class ElTapEventExample extends StatelessWidget {
  /// 创建点击、连击与长按示例。
  // ignore: prefer_const_constructors_in_immutables
  ElTapEventExample({super.key});

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
        deferTap: true,
        onTapDown: (_) => printEvent('onTapDown'),
        onTapUp: (_) => printEvent('onTapUp'),
        onTap: (_) => printEvent('onTap'),
        onTapCancel: (event) => printEvent('onTapCancel', event.cancelReason),
        onDoubleTapDown: (_) => printEvent('onDoubleTapDown'),
        onDoubleTap: (_) => printEvent('onDoubleTap'),
        onTripleTapDown: (_) => printEvent('onTripleTapDown'),
        onTripleTap: (_) => printEvent('onTripleTap'),
        onLongPress: (_) => printEvent('onLongPress'),
      ),
      child: '点击、连击或长按',
    );
  }
}
