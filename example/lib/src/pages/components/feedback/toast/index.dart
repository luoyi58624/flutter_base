import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Toast 轻提示的交互文档。
class ToastPage extends StatelessWidget {
  /// 创建 Toast 轻提示文档页。
  ToastPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).toast == null) return ExamplePage(title: 'Toast 轻提示');
    return DocsPage(
      title: 'Toast 轻提示',
      description: '通过 el.toast.show 在根 Overlay 居中显示一条提示，同一时间只保留一条，不拦截点击。',
      sections: [
        DocsSection(
          title: '基础用法',
          description: 'show 显示文字提示，可附带图标并调整停留时长。',
          source: 'lib/src/pages/components/feedback/toast/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '常驻与替换',
          description: 'duration 为零时保留到 close；连续显示时新提示替换当前提示。',
          source: 'lib/src/pages/components/feedback/toast/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
