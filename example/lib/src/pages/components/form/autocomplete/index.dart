import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Autocomplete 自动补全的交互文档。
class AutocompletePage extends StatelessWidget {
  /// 创建Autocomplete 自动补全文档页。
  AutocompletePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).autocomplete == null) return ExamplePage(title: 'Autocomplete 自动补全');
    return ComponentDocPage(
      title: 'Autocomplete 自动补全',
      description: '根据输入内容取得候选项，并将选中结果写入模型。',
      sections: [
        ComponentDocSection(
          title: '查询与选择',
          description: '使用本地异步数据源演示候选查询和选中通知。',
          example: Example1(),
          source: 'lib/src/pages/components/form/autocomplete/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '只读与禁用',
          description: '这两种状态不允许选择候选。',
          example: Example2(),
          source: 'lib/src/pages/components/form/autocomplete/examples/example2.dart',
        ),
      ],
    );
  }
}
