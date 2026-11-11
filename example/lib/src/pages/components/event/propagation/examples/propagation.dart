import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../log.dart';

/// 对照点击冒泡与内层停止传播的效果。
class ElEventPropagationExample extends StatelessWidget {
  /// 创建点击传播示例。
  // ignore: prefer_const_constructors_in_immutables
  ElEventPropagationExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      spacing: 12,
      crossAxisAlignment: .stretch,
      children: [
        for (final stop in [false, true])
          ElView(
            style: .new(backgroundColor: colors.secondaryContainer, padding: .all(12)),
            event: ElEvent(onTap: (_) => printEvent('外层收到点击')),
            child: Column(
              spacing: 8,
              crossAxisAlignment: .stretch,
              children: [
                Text(stop ? '外层 · 阻止冒泡' : '外层 · 默认冒泡', style: TextStyle(color: colors.onSecondaryContainer)),
                ElView(
                  style: .new(
                    backgroundColor: colors.primaryContainer,
                    color: colors.onPrimaryContainer,
                    alignment: .center,
                    height: 56,
                  ),
                  event: ElEvent(
                    onTap: (event) {
                      printEvent('内层收到点击');
                      if (stop) event.stopPropagation();
                    },
                  ),
                  child: stop ? '点击内层，截断传播' : '点击内层，继续冒泡',
                ),
              ],
            ),
          ),
      ],
    );
  }
}
