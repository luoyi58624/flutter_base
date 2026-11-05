import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 错误状态作用于当前步骤，独立 ElStep 可展示一条说明。
class Example2 extends HookWidget {
  /// 创建错误与独立步骤示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSteps(
          value: 1,
          status: .error,
          children: [
            ElStep(title: '一', description: '准备'),
            ElStep(title: '二', description: '发生错误'),
            ElStep(title: '三', disabled: true),
          ],
        ),
        ElStep(title: '独立步骤', description: '现有单项接口', icon: Icons.info_outline),
      ],
    );
  }
}
