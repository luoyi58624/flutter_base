import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 输入 @ 后选择候选，观察文本模型与通知。
class Example1 extends HookWidget {
  /// 创建用户提及示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final value = useState('');
    final selected = useState('尚未选择');
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElMention<String>(
          modelValue: value,
          placeholder: '输入 @ 选择用户',
          options: [
            ElMentionOption(value: 'alice', label: 'Alice'),
            ElMentionOption(value: 'bob', label: 'Bob'),
            ElMentionOption(value: 'locked', label: '不可选择', disabled: true),
          ],
          onSelected: (item, prefix) => selected.value = '$prefix${item.value}',
        ),
        Text('当前输入：${value.value}'),
        Text('选中候选：${selected.value}'),
      ],
    );
  }
}
