import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 点击或滑动切换正文，禁用项不能被选中。
class Example1 extends HookWidget {
  /// 创建业务值与正文示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = useState('推荐');
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElTabs<String>(
          modelValue: selected,
          panes: [
            ElTabPane(
              value: '推荐',
              label: '推荐',
              child: Center(child: Text('推荐内容')),
            ),
            ElTabPane(
              value: '关注',
              label: '关注',
              child: Center(child: Text('关注内容')),
            ),
            ElTabPane(
              value: '禁用',
              label: '禁用',
              disabled: true,
              child: Center(child: Text('不可选择')),
            ),
          ],
        ),
        Text('当前页：${selected.value}'),
      ],
    );
  }
}
