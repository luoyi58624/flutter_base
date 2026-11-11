import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Progress 进度的交互文档。
class ProgressPage extends StatelessWidget {
  /// 创建Progress 进度文档页。
  ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).progress == null) return ExamplePage(title: 'Progress 进度');
    return DocsPage(
      title: 'Progress 进度',
      description: '条形与圆环共用完成量、总量和状态接口。',
      sections: [
        DocsSection(
          title: '条形进度与缓冲',
          description: '调整数值，对照缓冲与语义状态。',
          source: 'lib/src/pages/components/data/progress/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '圆环与自定义读数',
          description: '圆环和条形都可传入读数构建器；省略 value 为不确定进度。',
          source: 'lib/src/pages/components/data/progress/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
