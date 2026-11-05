import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../navbar_menu.dart';

/// 桌面页面共用的导航头，左侧标识和导航标题只作展示。
class DesktopNavbar extends StatelessWidget implements PreferredSizeWidget {
  /// 创建桌面导航头，标题取自当前路由的页面声明。
  const DesktopNavbar({
    super.key,
    required this.title,
    this.leading,
    this.showThemeToggle = false,
    this.actions = const [],
  });

  /// 当前导航页面的标题。
  final String title;

  /// 独立推入的页面可提供返回入口，公共壳中省略。
  final Widget? leading;

  /// 当前页面为首页时显示主题切换。
  final bool showThemeToggle;

  /// 当前页面专用的导航操作。
  final List<Widget> actions;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    key: ValueKey('desktop-navbar'),
    automaticallyImplyLeading: false,
    leading: leading,
    centerTitle: false,
    elevation: 1,
    scrolledUnderElevation: 4,
    titleSpacing: 24,
    title: Row(
      spacing: 10,
      children: [
        ElIcon(Icons.layers_outlined, color: Theme.of(context).colorScheme.primary, size: 24, semanticLabel: 'El UI'),
        Expanded(child: Text(title, maxLines: 1, overflow: .ellipsis)),
      ],
    ),
    actionsPadding: .only(right: 8),
    actions: [...actions, if (showThemeToggle) NavbarMenu()],
  );
}
