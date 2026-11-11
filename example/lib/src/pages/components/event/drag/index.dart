import 'package:flutter/widgets.dart';

import '../../doc_page.dart';
import 'examples/drag.dart';

/// 展示如何根据拖拽位移更新色块位置。
class ElEventDragPage extends StatelessWidget {
  /// 创建拖拽交互文档页。
  // ignore: prefer_const_constructors_in_immutables
  ElEventDragPage({super.key});

  @override
  Widget build(BuildContext context) => ComponentDocPage(
    title: '拖拽交互',
    description: '用 ElEvent 读取拖拽位移，再通过 Positioned 更新色块的位置。',
    sections: [
      ComponentDocSection(
        title: '移动色块',
        description: '按住深色色块在区域内拖动，中央会显示当前拖拽回调。松手后，色块留在当前位置。',
        example: ElEventDragExample(),
        source: 'lib/src/pages/components/event/drag/examples/drag.dart',
      ),
    ],
  );
}
