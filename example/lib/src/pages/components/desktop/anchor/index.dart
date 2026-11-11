import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/basic.dart';

/// 桌面锚点文档。
class AnchorPage extends StatelessWidget {
  /// 创建锚点文档。
  const AnchorPage({super.key});

  @override
  Widget build(BuildContext context) => DocsPage(
    title: 'Anchor 锚点',
    description: '用于页内目录，点击可定位小节，滚动正文时同步高亮。',
    sections: [
      DocsSection(
        title: '双向绑定',
        description: '目录和正文通过同一个模型同步当前小节。',
        source: 'lib/src/pages/components/desktop/anchor/examples/basic.dart',
        child: AnchorExample(),
      ),
    ],
  );
}
