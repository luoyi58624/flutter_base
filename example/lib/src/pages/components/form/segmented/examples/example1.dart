import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 业务值与显示文案分开，通过模型观察选择变化。
class Example1 extends HookWidget {
  /// 创建基础选择示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final period = useState('周');
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSegmented<String>(
          modelValue: period,
          options: [
            for (final item in ['日', '周', '月']) ElSegmentedOption(value: item, label: item),
          ],
        ),
        Text('当前周期：${period.value}'),
      ],
    );
  }
}
