import 'package:flutter/widgets.dart';

import '../../doc_page.dart';
import 'examples/propagation.dart';

/// 展示如何阻止内层点击向外传播。
class ElEventPropagationPage extends StatelessWidget {
  /// 创建事件冒泡文档页。
  // ignore: prefer_const_constructors_in_immutables
  ElEventPropagationPage({super.key});

  @override
  Widget build(BuildContext context) => ComponentDocPage(
    title: '阻止冒泡',
    description: '嵌套 ElView 的主键点击默认从内层向外层派发。内层可调用 event.stopPropagation()，截断当前点击的传播。',
    sections: [
      ComponentDocSection(
        title: '对照点击顺序',
        description: '点击上方内层可看到内层、外层的回调顺序。点击下方内层时，外层保持等待状态。',
        example: ElEventPropagationExample(),
        source: 'lib/src/pages/components/event/propagation/examples/propagation.dart',
      ),
    ],
  );
}
