import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 开关状态与外部模型同步。
class Example1 extends HookWidget {
  /// 创建布尔值绑定示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final enabled = useState(false);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSwitch(modelValue: enabled, semanticLabel: '开启通知'),
        Text('通知：${enabled.value ? '已开启' : '已关闭'}'),
      ],
    );
  }
}
