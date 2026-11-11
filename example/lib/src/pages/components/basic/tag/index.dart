import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Tag 标签的交互文档。
class TagPage extends StatelessWidget {
  /// 创建Tag 标签文档页。
  TagPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).tag == null) return ExamplePage(title: 'Tag 标签');
    return ComponentDocPage(
      title: 'Tag 标签',
      description: '标签支持语义配色、浅底、实心、描边和独立切换。',
      sections: [
        ComponentDocSection(
          title: '配色与外观',
          description: '对照所有语义色和三种标签外观。',
          example: Example1(),
          source: 'lib/src/pages/components/basic/tag/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '切换与关闭',
          description: '选中值双向绑定，关闭回调由调用方决定是否移除标签。',
          example: Example2(),
          source: 'lib/src/pages/components/basic/tag/examples/example2.dart',
        ),
      ],
    );
  }
}
