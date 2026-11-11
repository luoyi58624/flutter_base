import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/drag.dart';

/// 展示如何根据拖拽位移更新色块位置。
class ElEventDragPage extends StatelessWidget {
  /// 创建拖拽交互文档页。
  // ignore: prefer_const_constructors_in_immutables
  ElEventDragPage({super.key});

  @override
  Widget build(BuildContext context) => DocsPage(
    title: '拖拽交互',
    sections: [
      DocsSection(
        title: '移动色块',
        source: 'lib/src/pages/components/event/drag/examples/drag.dart',
        child: ElEventDragExample(),
      ),
    ],
  );
}
