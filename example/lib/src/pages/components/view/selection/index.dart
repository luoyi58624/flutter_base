import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/basic.dart';

/// 展示 ElSelectionView 的文档选区用法。
class ElSelectionPage extends StatelessWidget {
  /// 创建文本选择文档页。
  // ignore: prefer_const_constructors_in_immutables
  ElSelectionPage({super.key});

  @override
  Widget build(BuildContext context) => DocsPage(
    title: 'Selection 文本选择',
    description: '用 ElSelectionView 包裹一组文本，让选区跨越不同段落。',
    sections: [
      DocsSection(
        title: '跨段落选择',
        description: '用鼠标拖选或双击正文。在触屏上长按开始选择，再拖动选区手柄。下方会同步显示选中的文字。',
        source: 'lib/src/pages/components/view/selection/examples/basic.dart',
        child: ElSelectionExample(),
      ),
    ],
  );
}
