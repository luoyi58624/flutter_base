import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 至少保留一项，最多选择两项。
class Example1 extends HookWidget {
  /// 创建多选与数量限制示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = useState<List<String>>(['阅读']);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElCheckboxGroup<String>(
          modelValue: selected,
          min: 1,
          max: 2,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final item in ['阅读', '音乐', '旅行']) ElCheckbox(value: item, label: item),
            ],
          ),
        ),
        Text('当前选择：${selected.value.join('、')}'),
      ],
    );
  }
}
