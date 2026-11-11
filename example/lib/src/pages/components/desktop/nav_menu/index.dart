import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/basic.dart';

/// 桌面导航菜单文档。
class NavMenuPage extends StatelessWidget {
  /// 创建导航菜单文档。
  const NavMenuPage({super.key});

  @override
  Widget build(BuildContext context) => DocsPage(
    title: 'NavMenu 导航菜单',
    description: '用于桌面侧栏，支持分组、子菜单和选中值绑定。',
    sections: [
      DocsSection(
        title: '分组导航',
        description: '分组标题组织菜单项，点击叶子项切换选中状态。',
        source: 'lib/src/pages/components/desktop/nav_menu/examples/basic.dart',
        child: NavMenuExample(),
      ),
    ],
  );
}
