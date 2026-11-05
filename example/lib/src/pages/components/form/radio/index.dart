import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Radio 单选框的交互文档。
class RadioPage extends StatelessWidget {
  /// 创建Radio 单选框文档页。
  RadioPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).radio == null) return ExamplePage(title: 'Radio 单选框');
    return ComponentDocPage(
      title: 'Radio 单选框',
      description: '组负责单值模型和选择规则，子项可自由布局。',
      sections: [
        ComponentDocSection(
          title: '单选分组',
          description: 'required: false 时可再次点击选中项取消选择。',
          example: Example1(),
          source: 'lib/src/pages/components/form/radio/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '独立切换与禁用',
          description: 'toggle 构造使用布尔模型，不需要分组。',
          example: Example2(),
          source: 'lib/src/pages/components/form/radio/examples/example2.dart',
        ),
      ],
    );
  }
}
