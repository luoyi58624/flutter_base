import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 输入内容同步到外部模型，clearable 显示清空入口。
class Example1 extends HookWidget {
  /// 创建值绑定与清空示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final value = useState('Hello');
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElInput(modelValue: value, clearable: true, placeholder: '请输入内容', semanticLabel: '示例输入'),
        Text('当前值：${value.value}'),
      ],
    );
  }
}
