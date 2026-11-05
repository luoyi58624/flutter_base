import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 点击步骤标题切换，外部模型显示当前索引。
class Example1 extends HookWidget {
  /// 创建交互式步骤示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final current = useState(0);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSteps(
          modelValue: current,
          interactive: true,
          vertical: true,
          children: [
            ElStep(title: '填写信息', description: '填写必要资料'),
            ElStep(title: '确认信息', description: '核对输入内容'),
            ElStep(title: '完成', description: '操作成功'),
          ],
        ),
        Text('当前索引：${current.value}'),
      ],
    );
  }
}
