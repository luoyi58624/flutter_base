import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../log.dart';

/// 演示鼠标按钮的事件回调。
class ElMouseEventExample extends StatelessWidget {
  /// 创建鼠标按钮示例。
  // ignore: prefer_const_constructors_in_immutables
  ElMouseEventExample({super.key});

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
        onSecondaryTapDown: (_) => printEvent('onSecondaryTapDown'),
        onSecondaryTapUp: (_) => printEvent('onSecondaryTapUp'),
        onSecondaryTap: (_) => printEvent('onSecondaryTap'),
        onTertiaryTapDown: (_) => printEvent('onTertiaryTapDown'),
        onTertiaryTapUp: (_) => printEvent('onTertiaryTapUp'),
        onTertiaryTap: (_) => printEvent('onTertiaryTap'),
        onForwardTapDown: (_) => printEvent('onForwardTapDown'),
        onForwardTapUp: (_) => printEvent('onForwardTapUp'),
        onForwardTap: (_) => printEvent('onForwardTap'),
        onBackTapDown: (_) => printEvent('onBackTapDown'),
        onBackTapUp: (_) => printEvent('onBackTapUp'),
        onBackTap: (_) => printEvent('onBackTap'),
      ),
      child: '右键、中键、前进或后退',
    );
  }
}
