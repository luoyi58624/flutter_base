import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// LoadingIndicator 加载指示的交互文档。
class LoadingPage extends StatelessWidget {
  /// 创建LoadingIndicator 加载指示文档页。
  LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).loadingIndicator == null) return ExamplePage(title: 'LoadingIndicator 加载指示');
    return ComponentDocPage(
      title: 'LoadingIndicator 加载指示',
      description: '现有加载接口支持尺寸、说明内容和辅助名称。',
      sections: [
        ComponentDocSection(
          title: '不同尺寸',
          description: 'size 指定指示图形的逻辑边长。',
          example: Example1(),
          source: 'lib/src/pages/components/feedback/loading/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '可见说明',
          description: 'child 可提供文字或自定义 Widget。',
          example: Example2(),
          source: 'lib/src/pages/components/feedback/loading/examples/example2.dart',
        ),
      ],
    );
  }
}
