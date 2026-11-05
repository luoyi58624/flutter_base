import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 输入四位验证码，完成后显示回调收到的值。
class Example1 extends HookWidget {
  /// 创建输入与完成通知示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final code = useState('');
    final completed = useState('尚未完成');
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElInputOtp(modelValue: code, length: 4, onComplete: (value) => completed.value = value),
        Text('验证码：${code.value}'),
        Text('完成通知：${completed.value}'),
      ],
    );
  }
}
