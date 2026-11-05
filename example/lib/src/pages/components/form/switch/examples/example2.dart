import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 禁用和加载期间不会重复切换。
class Example2 extends HookWidget {
  /// 创建禁用与加载示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        ElSwitch(value: false, disabled: true, semanticLabel: '关闭且禁用'),
        ElSwitch(value: true, disabled: true, semanticLabel: '开启且禁用'),
        ElSwitch(value: true, loading: true, semanticLabel: '正在保存'),
      ],
    );
  }
}
