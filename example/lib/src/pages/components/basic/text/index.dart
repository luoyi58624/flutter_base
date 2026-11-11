import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Text 文本的交互文档。
class TextPage extends StatelessWidget {
  /// 创建Text 文本文档页。
  TextPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DocsPage(
      title: 'Text 文本',
      description: '沿用 Flutter Text 与 RichText，不增加新的文本组件接口。',
      sections: [
        DocsSection(
          title: '文字排版',
          description: '使用 Flutter TextStyle 设置字号、字重和颜色。',
          source: 'lib/src/pages/components/basic/text/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '长文本与混排',
          description: '限制行数并省略长文本，或通过 TextSpan 组合不同样式。',
          source: 'lib/src/pages/components/basic/text/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
