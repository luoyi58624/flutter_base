import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Collapse 折叠面板的交互文档。
class CollapsePage extends StatelessWidget {
  /// 创建Collapse 折叠面板文档页。
  CollapsePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).collapse == null) return ExamplePage(title: 'Collapse 折叠面板');
    return ComponentDocPage(
      title: 'Collapse 折叠面板',
      description: '单项和多项构造使用同一套条目接口。',
      sections: [
        ComponentDocSection(
          title: '单项展开',
          description: '可空模型表示全部收起，选择另一项会收起前一项。',
          example: Example1(),
          source: 'lib/src/pages/components/layout/collapse/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '多项与独立条目',
          description: '多选列表控制展开项，独立 ElCollapseItem 也可单独使用。',
          example: Example2(),
          source: 'lib/src/pages/components/layout/collapse/examples/example2.dart',
        ),
      ],
    );
  }
}
