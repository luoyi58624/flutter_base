import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Segmented 分段选择的交互文档。
class SegmentedPage extends StatelessWidget {
  /// 创建Segmented 分段选择文档页。
  SegmentedPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).segmented == null) return ExamplePage(title: 'Segmented 分段选择');
    return ComponentDocPage(
      title: 'Segmented 分段选择',
      description: '使用现有单值模型，在一组互斥选项之间切换。',
      sections: [
        ComponentDocSection(
          title: '基础选择',
          description: '业务值与显示文案分开，通过模型观察选择变化。',
          example: Example1(),
          source: 'lib/src/pages/components/form/segmented/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '图标与禁用',
          description: '选项内容可使用图标，单项与整组均可禁用。',
          example: Example2(),
          source: 'lib/src/pages/components/form/segmented/examples/example2.dart',
        ),
      ],
    );
  }
}
