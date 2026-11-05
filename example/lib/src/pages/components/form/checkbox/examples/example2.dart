import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 独立模型、半选外观和禁用状态分别展示。
class Example2 extends HookWidget {
  /// 创建半选与独立切换示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = useState(false);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: .center,
      children: [
        ElCheckbox.toggle(modelValue: selected),
        Text('当前值：${selected.value}'),
        ElCheckbox.toggle(indeterminate: true),
        ElCheckbox.toggle(value: true, disabled: true),
      ],
    );
  }
}
