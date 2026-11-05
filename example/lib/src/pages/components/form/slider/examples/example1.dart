import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 使用 double 模型，步长限制可选刻度。
class Example1 extends HookWidget {
  /// 创建单值与步长示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final value = useState(40.0);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSlider<double>(modelValue: value, step: 10, label: '音量', marks: true),
        Text('当前值：${value.value.round()}'),
      ],
    );
  }
}
