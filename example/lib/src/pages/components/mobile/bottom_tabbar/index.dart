import 'package:flutter/widgets.dart';

import '../../doc_page.dart';
import 'examples/basic.dart';

/// 移动底部导航栏文档。
class BottomTabbarPage extends StatelessWidget {
  /// 创建底部导航栏文档。
  const BottomTabbarPage({super.key});

  @override
  Widget build(BuildContext context) => ComponentDocPage(
    title: 'BottomTabbar 底部导航栏',
    description: '用于在移动端的一级页面之间切换。',
    sections: [
      ComponentDocSection(
        title: '切换标签',
        description: '点击导航项，更新当前选中的标签。',
        example: BottomTabbarExample(),
        source: 'lib/src/pages/components/mobile/bottom_tabbar/examples/basic.dart',
      ),
    ],
  );
}
