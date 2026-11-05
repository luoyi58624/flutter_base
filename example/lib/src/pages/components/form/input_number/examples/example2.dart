import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照小数精度、右侧按钮、无按钮和禁用状态。
class Example2 extends HookWidget {
  /// 创建精度与控制按钮示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElInputNumber(value: 1.5, step: .25, precision: 2, width: 220, controlsPosition: .right),
        ElInputNumber(value: 5, controls: false, width: 220),
        ElInputNumber(value: 5, disabled: true, width: 220),
      ],
    );
  }
}
