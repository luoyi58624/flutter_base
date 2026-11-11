import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Alert 提示的交互文档。
class AlertPage extends StatelessWidget {
  /// 创建Alert 提示文档页。
  AlertPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).alert == null) return ExamplePage(title: 'Alert 提示');
    return DocsPage(
      title: 'Alert 提示',
      description: '通过布尔模型控制通知显示，关闭时先更新模型再通知调用方。',
      sections: [
        DocsSection(
          title: '语义状态',
          description: '对照四种提示状态和标题、正文组合。',
          source: 'lib/src/pages/components/feedback/alert/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '关闭与恢复',
          description: '显示状态由模型持有，关闭后可通过按钮恢复。',
          source: 'lib/src/pages/components/feedback/alert/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
