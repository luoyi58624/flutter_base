import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/disable.dart';
import 'examples/handoff.dart';
import 'examples/nested.dart';
import 'examples/transform.dart';

/// 展示多个事件共同参与的实际交互场景。
class ElEventAdvancedPage extends StatelessWidget {
  /// 创建事件高级示例页。
  // ignore: prefer_const_constructors_in_immutables
  ElEventAdvancedPage({super.key});

  @override
  Widget build(BuildContext context) => DocsPage(
    title: '高级示例',
    sections: [
      DocsSection(
        title: '嵌套拖拽',
        source: 'lib/src/pages/components/event/advanced/examples/nested.dart',
        child: ElNestedDragExample(),
      ),
      DocsSection(
        title: '多指接力',
        source: 'lib/src/pages/components/event/advanced/examples/handoff.dart',
        child: ElPointerHandoffExample(),
      ),
      DocsSection(
        title: '拖拽转缩放',
        source: 'lib/src/pages/components/event/advanced/examples/transform.dart',
        child: ElDragScaleExample(),
      ),
      DocsSection(
        title: '操作中禁用',
        source: 'lib/src/pages/components/event/advanced/examples/disable.dart',
        child: ElDisableDuringDragExample(),
      ),
    ],
  );
}
