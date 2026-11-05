import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 范围模型为 `List<double>`，禁用后保留原值。
class Example2 extends HookWidget {
  /// 创建范围与禁用示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final range = useState<List<double>>([20, 70]);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSlider<List<double>>.range(modelValue: range, step: 5),
        Text('范围：${range.value.first.round()} ～ ${range.value.last.round()}'),
        ElSlider<double>(value: 60, disabled: true),
      ],
    );
  }
}
