import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 使用本地异步数据源演示候选查询和选中通知。
class Example1 extends HookWidget {
  /// 创建查询与选择示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final value = useState('');
    final selected = useState('尚未选择');
    final options = ['Apple', 'Apricot', 'Banana', 'Blueberry'];
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElAutocomplete<String>(
          modelValue: value,
          placeholder: '输入 A 或 B',
          debounce: Duration(milliseconds: 150),
          fetchSuggestions: (query) async => [
            for (final item in options)
              if (item.toLowerCase().contains(query.toLowerCase())) ElLabelModel(item, item),
          ],
          onSelected: (item) => selected.value = item.label!,
        ),
        Text('当前输入：${value.value}'),
        Text('选中候选：${selected.value}'),
      ],
    );
  }
}
