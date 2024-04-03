part of flutter_base;

/// 快速构建[MaterialRootPage]根页面。
///
/// 使用示例：
/// ```dart
/// final rootPage = buildMaterialRootPage();
/// final router = FlutterRouter(
///   routes: [
///     rootPage,
///   ],
/// );
/// ```
RouteBase buildMaterialRootPage(List<RouterModel> pages) {
  List<StatefulShellBranch> branches = [];
  for (int i = 0; i < pages.length; i++) {
    branches.add(StatefulShellBranch(
      routes: [
        GoRoute(
          path: pages[i].path,
          builder: (context, state) => pages[i].page,
          routes: DartUtil.safeList(pages[i].children).isNotEmpty
              ? FlutterRouter.buildChildrenRoute(pages[i].children!)
              : [],
        ),
      ],
    ));
  }
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => MaterialRootPage(navigationShell: navigationShell, pages: pages),
    branches: branches,
  );
}

class MaterialRootPage extends StatefulWidget {
  const MaterialRootPage({super.key, required this.navigationShell, required this.pages});

  final StatefulNavigationShell navigationShell;
  final List<RouterModel> pages;

  @override
  State<MaterialRootPage> createState() => _MaterialRootPageState();
}

class _MaterialRootPageState extends State<MaterialRootPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        onTap: (int index) {
          widget.navigationShell.goBranch(index);
        },
        currentIndex: widget.navigationShell.currentIndex,
        unselectedFontSize: 12,
        selectedFontSize: 12,
        iconSize: 26,
        unselectedLabelStyle: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
        selectedItemColor: appTheme.primaryColor,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        type: BottomNavigationBarType.fixed,
        items: widget.pages
            .map((e) => BottomNavigationBarItem(
                  icon: Icon(e.icon),
                  label: e.title,
                ))
            .toList(),
      ),
    );
  }
}
