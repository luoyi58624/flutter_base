import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Message 消息的交互文档。
class MessagePage extends StatelessWidget {
  /// 创建 Message 消息文档页。
  MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).message == null) return ExamplePage(title: 'Message 消息');
    return DocsPage(
      title: 'Message 消息',
      description: '通过 el.message.show 在窗口顶部显示消息，多条消息同时存在、各自计时关闭；桌面纵向排列，移动端为顶部通栏并叠放。',
      sections: [
        DocsSection(
          title: '消息类型',
          description: 'type 决定颜色和图标。',
          source: 'lib/src/pages/components/feedback/message/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '时长与多条消息',
          description: 'duration 调整停留时长，为零时保留到用户关闭；连续显示时多条消息同时存在。',
          source: 'lib/src/pages/components/feedback/message/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
