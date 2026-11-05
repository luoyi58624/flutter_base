import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Select 选择器的交互文档。
class SelectPage extends StatelessWidget {
  /// 创建Select 选择器文档页。
  SelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).select == null) return ExamplePage(title: 'Select 选择器');
    return ComponentDocPage(
      title: 'Select 选择器',
      description: '通过已定义的单值接口选择选项，支持过滤及禁用选项。',
      sections: [
        ComponentDocSection(
          title: '单值绑定',
          description: '显示文案与业务值分别声明，选择后同步外部模型。',
          example: Example1(),
          source: 'lib/src/pages/components/form/select/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '过滤与禁用',
          description: '输入文字过滤候选，禁用条目和整组禁用分别生效。',
          example: Example2(),
          source: 'lib/src/pages/components/form/select/examples/example2.dart',
        ),
      ],
    );
  }
}
