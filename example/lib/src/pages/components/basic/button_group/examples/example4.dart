import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 分别用 List 和 Set 保存多个选中项。
class Example4 extends HookWidget {
  /// 创建多选按钮组示例。
  Example4({super.key});

  @override
  Widget build(BuildContext context) {
    final list = useState<List<String>>(['加粗']);
    final set = useState<Set<String>>({'斜体'});
    final items = [
      for (final label in ['加粗', '斜体', '下划线']) ElButtonGroupItem(value: label, child: label),
    ];
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElButtonGroup<List<String>>.multi(modelValue: list, type: .primary, children: items),
        Text('List：${list.value.isEmpty ? '未选择' : list.value.join('、')}'),
        ElButtonGroup<Set<String>>.multi(modelValue: set, type: .success, children: items),
        Text('Set：${set.value.isEmpty ? '未选择' : set.value.join('、')}'),
      ],
    );
  }
}
