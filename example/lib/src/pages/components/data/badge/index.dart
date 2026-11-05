import 'package:flutter/widgets.dart';

import '../../doc_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Badge 徽标的交互文档。
class BadgePage extends StatelessWidget {
  /// 创建Badge 徽标文档页。
  BadgePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ComponentDocPage(
      title: 'Badge 徽标',
      description: '复用公共 ElBadge，展示数字、文字、圆点与条件显示。',
      sections: [
        ComponentDocSection(
          title: '数字与圆点',
          description: '徽标可附着在内容上，也可独立显示。',
          example: Example1(),
          source: 'lib/src/pages/components/data/badge/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '条件显示',
          description: 'hidden 保留宿主内容，showZero 控制零值徽标。',
          example: Example2(),
          source: 'lib/src/pages/components/data/badge/examples/example2.dart',
        ),
      ],
    );
  }
}
