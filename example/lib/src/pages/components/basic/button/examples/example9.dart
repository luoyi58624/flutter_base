import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 让不同外观的切换按钮共用同一个布尔值。
class Example9 extends HookWidget {
  const Example9({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = useState(false);
    final label = selected.value.toString();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElButton.toggle(modelValue: selected, child: label),
        ElButton.toggle(modelValue: selected, type: .primary, child: label),
        ElView(
          style: ElStyle(vars: {ElTokens.$primary: Colors.teal}),
          child: ElButton.toggle(modelValue: selected, type: .primary, child: label),
        ),
        ElButton.toggle(modelValue: selected, variant: .outline, child: label),
        ElButton.toggle(
          modelValue: selected,
          variant: .outline,
          style: ElStyle(backgroundColor: Colors.transparent),
          child: label,
        ),
        ElButton.toggle(modelValue: selected, variant: .text, child: label),
      ],
    );
  }
}
