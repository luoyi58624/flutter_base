import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Input 输入框的交互文档。
class InputPage extends StatelessWidget {
  /// 创建Input 输入框文档页。
  InputPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).input == null) return ExamplePage(title: 'Input 输入框');
    return DocsPage(
      title: 'Input 输入框',
      description: '演示现有输入接口的值绑定、清空、密码、多行和禁用状态。',
      sections: [
        DocsSection(
          title: '值绑定与清空',
          description: '输入内容同步到外部模型，clearable 显示清空入口。',
          source: 'lib/src/pages/components/form/input/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '密码、多行与状态',
          description: '比较密码输入、多行文本、只读和禁用状态。',
          source: 'lib/src/pages/components/form/input/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
