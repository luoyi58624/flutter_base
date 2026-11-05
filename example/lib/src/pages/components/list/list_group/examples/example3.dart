import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 多选使用列表模型，leading 控制选择标记的位置。
class Example3 extends HookWidget {
  /// 创建多选分组示例。
  Example3({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = useState<List<String>>(['邮件']);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElListGroup<List<String>>.multi(
          modelValue: selected,
          leading: false,
          children: [
            for (final item in ['邮件', '短信', '推送']) ElListTile<String>(value: item, title: item),
          ],
        ),
        Text('已选通知：${selected.value.join('、')}'),
      ],
    );
  }
}
