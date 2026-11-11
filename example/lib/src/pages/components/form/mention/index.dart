import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Mention 提及的交互文档。
class MentionPage extends StatelessWidget {
  /// 创建Mention 提及文档页。
  MentionPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).mention == null) return ExamplePage(title: 'Mention 提及');
    return ComponentDocPage(
      title: 'Mention 提及',
      description: '已有 Mention 接口通过前缀查询并插入候选内容。',
      sections: [
        ComponentDocSection(
          title: '用户提及',
          description: '输入 @ 后选择候选，观察文本模型与通知。',
          example: Example1(),
          source: 'lib/src/pages/components/form/mention/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '多个前缀与多行',
          description: '沿用同一套候选接口，支持多个前缀和只读展示。',
          example: Example2(),
          source: 'lib/src/pages/components/form/mention/examples/example2.dart',
        ),
      ],
    );
  }
}
