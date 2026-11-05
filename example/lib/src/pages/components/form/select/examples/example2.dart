import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 输入文字过滤候选，禁用条目和整组禁用分别生效。
class Example2 extends HookWidget {
  /// 创建过滤与禁用示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSelect<String>(
          value: 'beijing',
          enableFilter: true,
          hintText: '输入城市名',
          children: [
            ElSelectOption('北京', 'beijing'),
            ElSelectOption('上海', 'shanghai'),
            ElSelectOption('不可选择', 'disabled', disabled: true),
          ],
        ),
        ElSelect<String>(
          value: 'beijing',
          disabled: true,
          children: [ElLabelModel('北京', 'beijing'), ElLabelModel('上海', 'shanghai')],
        ),
      ],
    );
  }
}
