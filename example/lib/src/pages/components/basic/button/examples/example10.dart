import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对比样式扩展提供的按压缩放和淡化反馈。
class Example10 extends HookWidget {
  /// 创建按压反馈示例。
  const Example10({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElView(style: .new().withTapScale(0.9), child: 'Scale Button'),
        ElButtonView(style: .new().withTapFade(), child: 'Scale Button'),
      ],
    );
  }
}
