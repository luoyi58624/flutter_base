import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';
import 'examples/example3.dart';

/// ListTileGroup 列表组的交互文档。
class ListGroupPage extends StatelessWidget {
  /// 创建ListTileGroup 列表组文档页。
  ListGroupPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).listTileGroup == null) return ExamplePage(title: 'ListTileGroup 列表组');
    return ComponentDocPage(
      title: 'ListTileGroup 列表组',
      description: '用既有普通、单选和多选构造组合列表行。',
      sections: [
        ComponentDocSection(
          title: '普通分组',
          description: '普通分组只组织内容，不管理选中值。',
          example: Example1(),
          source: 'lib/src/pages/components/list/list_group/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '单选分组',
          description: '条目 value 对应完整单值模型。',
          example: Example2(),
          source: 'lib/src/pages/components/list/list_group/examples/example2.dart',
        ),
        ComponentDocSection(
          title: '多选分组',
          description: '多选使用列表模型，leading 控制选择标记的位置。',
          example: Example3(),
          source: 'lib/src/pages/components/list/list_group/examples/example3.dart',
        ),
      ],
    );
  }
}
