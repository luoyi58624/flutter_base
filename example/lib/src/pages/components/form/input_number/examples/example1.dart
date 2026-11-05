import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 用可空数值模型绑定数字，并限制最小值和最大值。
class Example1 extends HookWidget {
  /// 创建步长与范围示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final value = useState<num?>(10);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElInputNumber(modelValue: value, min: 0, max: 20, step: 2, width: 220),
        Text('当前数字：${value.value ?? '空'}'),
      ],
    );
  }
}
