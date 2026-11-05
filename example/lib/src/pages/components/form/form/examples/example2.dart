import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// ElFormItem 也可单独组合标签、内容和外部错误。
class Example2 extends HookWidget {
  /// 创建帮助信息与显式错误示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return ElForm(
      value: <String, dynamic>{'email': ''},
      labelPosition: .top,
      child: ElFormItem(
        prop: 'email',
        label: '电子邮箱',
        error: '这里演示来自外部的错误提示',
        child: ElInput(placeholder: 'name@example.com'),
      ),
    );
  }
}
