import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 比较密码输入、多行文本、只读和禁用状态。
class Example2 extends HookWidget {
  /// 创建密码、多行与状态示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElInput(value: '', showPassword: true, placeholder: '请输入密码'),
        ElInput(
          value: '',
          textarea: true,
          minLine: 2,
          maxLine: 4,
          maxLength: 120,
          showWordLimit: true,
          placeholder: '多行内容',
        ),
        ElInput(value: '只读内容', readOnly: true),
        ElInput(value: '禁用内容', disabled: true),
      ],
    );
  }
}
