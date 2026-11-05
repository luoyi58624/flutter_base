import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 调整数值，对照缓冲与语义状态。
class Example1 extends HookWidget {
  /// 创建条形进度与缓冲示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final value = useState(35.0);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElProgress(value: value.value, buffer: 80),
        ElSlider<double>(modelValue: value),
        ElProgress(value: 100, status: .success),
        ElProgress(value: 60, status: .error),
      ],
    );
  }
}
