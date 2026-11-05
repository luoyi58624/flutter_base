import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// required: false 时可再次点击选中项取消选择。
class Example1 extends HookWidget {
  /// 创建单选分组示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final value = useState<String?>('上海');
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElRadioGroup<String>(
          modelValue: value,
          required: false,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final item in ['北京', '上海', '深圳']) ElRadio<String>(value: item, label: item),
            ],
          ),
        ),
        Text('当前选择：${value.value ?? '未选择'}'),
      ],
    );
  }
}
