import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照三种已定义的外观，以及禁用的掩码输入。
class Example2 extends HookWidget {
  /// 创建外观与掩码示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        for (final type in ElInputOtpType.values) ElInputOtp(value: '12', length: 4, type: type),
        ElInputOtp(value: '1234', length: 4, mask: true, disabled: true),
      ],
    );
  }
}
