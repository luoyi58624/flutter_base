import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Card 卡片的交互文档。
class CardPage extends StatelessWidget {
  /// 创建Card 卡片文档页。
  CardPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).card == null) return ExamplePage(title: 'Card 卡片');
    return ComponentDocPage(
      title: 'Card 卡片',
      description: '现有卡片接口承载内容、点击动作与加载状态。',
      sections: [
        ComponentDocSection(
          title: '内容与点击',
          description: '卡片内自由组合内容，通过 onTap 响应整卡点击。',
          example: Example1(),
          source: 'lib/src/pages/components/layout/card/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '加载与样式',
          description: '加载时保留内容，style 在品牌默认样式之后合并。',
          example: Example2(),
          source: 'lib/src/pages/components/layout/card/examples/example2.dart',
        ),
      ],
    );
  }
}
