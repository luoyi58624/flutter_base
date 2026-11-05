import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 为单选和多选设置必选，保留最后一个选中项。
class Example5 extends HookWidget {
  /// 创建必选按钮组示例。
  Example5({super.key});

  @override
  Widget build(BuildContext context) {
    final period = useState<String?>('周');
    final filters = useState<List<String>>(['已读']);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElButtonGroup<String?>.single(
          modelValue: period,
          mandatory: true,
          type: .primary,
          children: [
            for (final label in ['日', '周', '月']) ElButtonGroupItem(value: label, child: label),
          ],
        ),
        Text('统计周期：${period.value}'),
        ElButtonGroup<List<String>>.multi(
          modelValue: filters,
          mandatory: true,
          type: .primary,
          children: [
            for (final label in ['已读', '收藏', '置顶']) ElButtonGroupItem(value: label, child: label),
          ],
        ),
        Text('筛选条件：${filters.value.join('、')}'),
      ],
    );
  }
}
