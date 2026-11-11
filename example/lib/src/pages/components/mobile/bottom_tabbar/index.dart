import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/basic.dart';

/// 移动底部导航栏文档。
class BottomTabbarPage extends StatelessWidget {
  /// 创建底部导航栏文档。
  const BottomTabbarPage({super.key});

  @override
  Widget build(BuildContext context) => DocsPage(
    title: 'BottomTabbar 底部导航栏',
    description: '用于在移动端的一级页面之间切换。',
    sections: [
      DocsSection(
        title: '切换标签',
        description: '点击导航项，更新当前选中的标签。',
        source: 'lib/src/pages/components/mobile/bottom_tabbar/examples/basic.dart',
        child: BottomTabbarExample(),
      ),
    ],
  );
}
