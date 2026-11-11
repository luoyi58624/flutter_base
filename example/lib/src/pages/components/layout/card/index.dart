import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Card 卡片的交互文档。
class CardPage extends StatelessWidget {
  /// 创建Card 卡片文档页。
  CardPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).card == null) return ExamplePage(title: 'Card 卡片');
    return DocsPage(
      title: 'Card 卡片',
      description: '现有卡片接口承载内容、点击动作与加载状态。',
      sections: [
        DocsSection(
          title: '内容与点击',
          description: '卡片内自由组合内容，通过 onTap 响应整卡点击。',
          source: 'lib/src/pages/components/layout/card/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '加载与样式',
          description: '加载时保留内容，style 在品牌默认样式之后合并。',
          source: 'lib/src/pages/components/layout/card/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
