import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Checkbox 多选框的交互文档。
class CheckboxPage extends StatelessWidget {
  /// 创建Checkbox 多选框文档页。
  CheckboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).checkbox == null) return ExamplePage(title: 'Checkbox 多选框');
    return DocsPage(
      title: 'Checkbox 多选框',
      description: '多选组管理列表模型与数量限制，toggle 用于独立布尔值。',
      sections: [
        DocsSection(
          title: '多选与数量限制',
          description: '至少保留一项，最多选择两项。',
          source: 'lib/src/pages/components/form/checkbox/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '半选与独立切换',
          description: '独立模型、半选外观和禁用状态分别展示。',
          source: 'lib/src/pages/components/form/checkbox/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
