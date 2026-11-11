import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Segmented 分段选择的交互文档。
class SegmentedPage extends StatelessWidget {
  /// 创建Segmented 分段选择文档页。
  SegmentedPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).segmented == null) return ExamplePage(title: 'Segmented 分段选择');
    return DocsPage(
      title: 'Segmented 分段选择',
      description: '使用现有单值模型，在一组互斥选项之间切换。',
      sections: [
        DocsSection(
          title: '基础选择',
          description: '业务值与显示文案分开，通过模型观察选择变化。',
          source: 'lib/src/pages/components/form/segmented/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '图标与禁用',
          description: '选项内容可使用图标，单项与整组均可禁用。',
          source: 'lib/src/pages/components/form/segmented/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
