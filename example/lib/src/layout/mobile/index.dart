import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:go_router/go_router.dart';

import '../../router/pages.dart';
import '../../state/index.dart';

/// 移动端布局，底栏选中项与分支导航栈由路由持有。
class MobileLayout extends StatelessWidget {
  /// 创建移动导航壳。
  const MobileLayout({super.key, required this.navigationShell});

  /// 当前导航分支。
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => ObsBuilder(
    builder: (context) => ElComponentProvider(
      components: el.mobileComponents,
      style: GlobalState.appearanceStyle,
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: ElBottomTabbar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(index),
          destinations: [for (final tab in navigationPages) NavigationDestination(icon: tab.icon!, label: tab.title)],
        ),
      ),
    ),
  );
}
