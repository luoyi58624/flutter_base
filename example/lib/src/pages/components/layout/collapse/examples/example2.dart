import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 多选列表控制展开项，独立 ElCollapseItem 也可单独使用。
class Example2 extends HookWidget {
  /// 创建多项与独立条目示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final expanded = useState<List<int>>([1]);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElCollapse<List<int>>.multi(
          modelValue: expanded,
          children: [
            ElCollapseItem(value: 1, title: '第一个面板', child: '面板内容'),
            ElCollapseItem(value: 2, title: '第二个面板', child: '其他内容'),
            ElCollapseItem(value: 3, title: '禁用面板', disabled: true, child: '不可展开'),
          ],
        ),
        Text('展开项：${expanded.value}'),
        ElCollapseItem(value: '独立', title: '独立条目', child: '不绑定分组模型'),
      ],
    );
  }
}
