part of flutter_base;

enum BottomTabbarType { material2, material3, cupertino }

/// 移动端底部导航栏组件
class BottomTabbarWidget extends StatelessWidget {
  const BottomTabbarWidget({
    super.key,
    required this.navigationShell,
    required this.pages,
    this.bottomTabbarType = BottomTabbarType.material2,
  });

  final StatefulNavigationShell navigationShell;
  final List<RouterModel> pages;
  final BottomTabbarType bottomTabbarType;

  /// 快速构建有状态嵌套导航
  ///
  /// 使用示例：
  /// ```dart
  /// final rootPage = BottomTabbarWidget.buildStatefulShellRoute();
  /// final router = FlutterRouter(
  ///   routes: [
  ///     rootPage,
  ///   ],
  /// );
  /// ```
  static RouteBase buildStatefulShellRoute(List<RouterModel> pages, [BottomTabbarType bottomTabbarType = BottomTabbarType.material2]) {
    List<StatefulShellBranch> branches = [];
    for (int i = 0; i < pages.length; i++) {
      branches.add(StatefulShellBranch(
        routes: [
          GoRoute(
            path: pages[i].path,
            builder: (context, state) => pages[i].page,
            routes: DartUtil.safeList(pages[i].children).isNotEmpty ? RouterUtil.routerModelToGoRouter(pages[i].children!) : [],
          ),
        ],
      ));
    }
    return StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => BottomTabbarWidget(
        navigationShell: navigationShell,
        pages: pages,
        bottomTabbarType: bottomTabbarType,
      ),
      branches: branches,
    );
  }

  @override
  Widget build(BuildContext context) {
    late Widget tabbarWidget;
    switch (bottomTabbarType) {
      case BottomTabbarType.material2:
        tabbarWidget = buildMaterial2(context);
        break;
      case BottomTabbarType.material3:
        tabbarWidget = buildMaterial3(context);
        break;
      case BottomTabbarType.cupertino:
        tabbarWidget = buildCupertino(context);
        break;
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: tabbarWidget,
    );
  }

  Widget buildMaterial2(BuildContext context) {
    return BottomNavigationBar(
      onTap: (int index) {
        navigationShell.goBranch(index);
      },
      currentIndex: navigationShell.currentIndex,
      unselectedFontSize: 12,
      selectedFontSize: 12,
      iconSize: 26,
      unselectedLabelStyle: TextStyle(
        fontWeight: FlutterAppData.of(context).config.defaultFontWeight,
      ),
      selectedItemColor: FlutterAppData.of(context).theme.primary,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
      type: BottomNavigationBarType.fixed,
      items: pages
          .map((e) => BottomNavigationBarItem(
                icon: Icon(e.icon),
                label: e.title,
              ))
          .toList(),
    );
  }

  Widget buildMaterial3(BuildContext context) {
    return NavigationBar(
      onDestinationSelected: (int index) {
        navigationShell.goBranch(index);
      },
      selectedIndex: navigationShell.currentIndex,
      destinations: pages
          .map((e) => NavigationDestination(
                icon: Icon(e.icon),
                label: e.title,
              ))
          .toList(),
    );
  }

  Widget buildCupertino(BuildContext context) {
    return CupertinoTabBar(
      onTap: (int index) {
        navigationShell.goBranch(index);
      },
      currentIndex: navigationShell.currentIndex,
      items: pages
          .map((e) => BottomNavigationBarItem(
                icon: Icon(e.icon),
                label: e.title,
              ))
          .toList(),
    );
  }
}
