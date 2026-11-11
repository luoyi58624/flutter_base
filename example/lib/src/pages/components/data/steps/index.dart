import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Steps 步骤条的交互文档。
class StepsPage extends StatelessWidget {
  /// 创建Steps 步骤条文档页。
  StepsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).steps == null) return ExamplePage(title: 'Steps 步骤条');
    return DocsPage(
      title: 'Steps 步骤条',
      description: '已有步骤接口用索引控制当前步骤，并支持错误与禁用状态。',
      sections: [
        DocsSection(
          title: '交互式步骤',
          description: '点击步骤标题切换，外部模型显示当前索引。',
          source: 'lib/src/pages/components/data/steps/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '错误与独立步骤',
          description: '错误状态作用于当前步骤，独立 ElStep 可展示一条说明。',
          source: 'lib/src/pages/components/data/steps/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
