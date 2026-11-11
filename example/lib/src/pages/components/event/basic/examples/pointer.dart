import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../log.dart';

/// 演示指针与悬停的事件回调。
class ElPointerEventExample extends StatelessWidget {
  /// 创建指针与悬停示例。
  // ignore: prefer_const_constructors_in_immutables
  ElPointerEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      spacing: 8,
      crossAxisAlignment: .stretch,
      children: [
        ElView(
          style: .new(
            backgroundColor: colors.primaryContainer,
            color: colors.onPrimaryContainer,
            alignment: .center,
            padding: .all(12),
            height: 72,
          ),
          event: ElEvent(
            onPointerDown: (event) => printEvent('onPointerDown', event.localPosition),
            onPointerMove: (event) => printEvent('onPointerMove', event.localDelta),
            onPointerUp: (event) => printEvent('onPointerUp', event.localPosition),
            onPointerCancel: (event) => printEvent('onPointerCancel', event.cancelReason),
          ),
          child: '按下并移动',
        ),
        ElView(
          style: .new(
            backgroundColor: colors.tertiaryContainer,
            color: colors.onTertiaryContainer,
            alignment: .center,
            padding: .all(12),
            height: 72,
          ),
          event: ElEvent(
            onPointerEnter: (_) => printEvent('onPointerEnter'),
            onPointerHover: (event) => printEvent('onPointerHover', event.localPosition),
            onPointerExit: (_) => printEvent('onPointerExit'),
          ),
          child: '移入、悬停、移出',
        ),
      ],
    );
  }
}
