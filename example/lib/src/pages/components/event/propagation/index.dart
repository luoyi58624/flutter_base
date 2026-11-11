import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/propagation.dart';

/// 展示如何阻止内层点击向外传播。
class ElEventPropagationPage extends StatelessWidget {
  /// 创建事件冒泡文档页。
  // ignore: prefer_const_constructors_in_immutables
  ElEventPropagationPage({super.key});

  @override
  Widget build(BuildContext context) => DocsPage(
    title: '阻止冒泡',
    sections: [
      DocsSection(
        title: '点击冒泡',
        source: 'lib/src/pages/components/event/propagation/examples/propagation.dart',
        child: ElEventPropagationExample(),
      ),
    ],
  );
}
