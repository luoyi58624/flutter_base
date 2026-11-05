import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 可空模型表示全部收起，选择另一项会收起前一项。
class Example1 extends HookWidget {
  /// 创建单项展开示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = useState<String?>('一');
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElCollapse<String?>.single(
          modelValue: selected,
          children: [
            for (final item in ['一', '二']) ElCollapseItem(value: item, title: '面板$item', child: '这里是面板$item的内容'),
          ],
        ),
        Text('当前展开：${selected.value ?? '无'}'),
      ],
    );
  }
}
