import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Tabs 标签页的交互文档。
class TabsPage extends StatelessWidget {
  /// 创建Tabs 标签页文档页。
  TabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).tabs == null) return ExamplePage(title: 'Tabs 标签页');
    return ComponentDocPage(
      title: 'Tabs 标签页',
      description: '使用已有页签模型与独立控制器组织标签和正文。',
      sections: [
        ComponentDocSection(
          title: '业务值与正文',
          description: '点击或滑动切换正文，禁用项不能被选中。',
          example: Example1(),
          source: 'lib/src/pages/components/layout/tabs/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '独立标签栏与视口',
          description: 'ElTabBar 与 ElTabView 共用现有 ElTabController，并由示例释放。',
          example: Example2(),
          source: 'lib/src/pages/components/layout/tabs/examples/example2.dart',
        ),
      ],
    );
  }
}
