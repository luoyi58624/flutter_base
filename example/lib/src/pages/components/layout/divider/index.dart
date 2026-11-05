import 'package:flutter/widgets.dart';

import '../../doc_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Divider 分割线的交互文档。
class DividerPage extends StatelessWidget {
  /// 创建Divider 分割线文档页。
  DividerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ComponentDocPage(
      title: 'Divider 分割线',
      description: '使用已有分割线基元组合内容与线段。',
      sections: [
        ComponentDocSection(
          title: '水平分割与文字',
          description: 'child 提供中间内容，thickness 和 color 控制线段。',
          example: Example1(),
          source: 'lib/src/pages/components/layout/divider/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '纵向分割',
          description: '纵向分割线由外层提供有界高度。',
          example: Example2(),
          source: 'lib/src/pages/components/layout/divider/examples/example2.dart',
        ),
      ],
    );
  }
}
