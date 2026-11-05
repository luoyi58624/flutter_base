import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// toggle 构造使用布尔模型，不需要分组。
class Example2 extends HookWidget {
  /// 创建独立切换与禁用示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = useState(false);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: .center,
      children: [
        ElRadio.toggle(modelValue: selected),
        Text(selected.value ? '已开启' : '已关闭'),
        ElRadio.toggle(value: true, disabled: true),
      ],
    );
  }
}
