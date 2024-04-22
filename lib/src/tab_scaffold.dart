part of flutter_base;

/// App选项卡式底部导航栏脚手架，它会自动注入[TabScaffoldController]控制器，你可以通过控制器动态更新导航栏名字、图标、badge，
/// 当注入[TabScaffoldController]控制器后，你可以在声明式路由设置[hideTabbar]属性，用于隐藏底部导航栏。
/// ```dart
/// StatefulShellRoute.indexedStack(
///   builder: (c, s, navigationShell) => TabScaffold(
///     navigationShell: navigationShell,
///     pages: [
///       UrlNavModel('One', '/', icon: Icons.home),
///       UrlNavModel('Two', '/two', icon: Icons.home),
///       UrlNavModel('Three', '/three', icon: Icons.home),
///     ],
///   ),
///   branches: [
///     StatefulShellBranch(
///       routes: [
///         GoRoute(
///           path: '/',
///           pageBuilder: (c, s) => c.pageBuilder(s, const OnePage()),
///           routes: [
///             // 通过context.go('/child')进入的页面将隐藏底部导航栏
///             GoRoute(path: 'child', hideTabbar: true, pageBuilder: (c, s) => c.pageBuilder(s, const ChildPage())),
///           ],
///         ),
///       ],
///     ),
///     StatefulShellBranch(
///       routes: [
///         GoRoute(path: '/two', pageBuilder: (c, s) => c.pageBuilder(s, const TwoPage())),
///       ],
///     ),
///     StatefulShellBranch(
///       routes: [
///         GoRoute(path: '/three', pageBuilder: (c, s) => c.pageBuilder(s, const ThreePage())),
///       ],
///     ),
///   ],
/// ),
/// ```
class TabScaffold extends StatefulWidget {
  const TabScaffold({
    super.key,
    required this.navigationShell,
    required this.pages,
    this.tabbarType = TabbarType.material2,
    this.bottomNavHeight,
  });

  /// [GoRouter]有状态导航对象: [StatefulShellRoute.indexedStack]
  final StatefulNavigationShell navigationShell;

  /// 导航页面模型，渲染底部导航 tabbar
  final List<UrlNavModel> pages;

  /// 底部导航类型，默认[BottomNavType.material2]
  final TabbarType tabbarType;

  /// 底部导航栏高度
  final double? bottomNavHeight;

  @override
  State<TabScaffold> createState() => _TabScaffoldState();
}

class _TabScaffoldState extends State<TabScaffold> with FlutterThemeMixin {
  late TabScaffoldController controller;

  @override
  void initState() {
    controller = Get.put(TabScaffoldController(
      pages: widget.pages,
      tabbarType: widget.tabbarType,
      bottomNavHeight: widget.bottomNavHeight,
    ));
    _RouteState.injectTabScaffoldController = true;
    super.initState();
  }

  @override
  void dispose() {
    Get.delete<TabScaffoldController>();
    _RouteState.injectTabScaffoldController = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    late Widget tabbarWidget;
    switch (widget.tabbarType) {
      case TabbarType.material2:
        tabbarWidget = buildMaterial2(context);
        break;
      case TabbarType.material3:
        tabbarWidget = buildMaterial3(context);
        break;
      case TabbarType.cupertino:
        tabbarWidget = buildCupertino(context);
        break;
      case TabbarType.custom:
        tabbarWidget = buildCustom(context);
        break;
    }
    return buildCustomScaffold(tabbarWidget);
  }

  Widget buildCustomScaffold(Widget tabbarWidget) {
    return Stack(
      children: [
        Obx(() {
          late EdgeInsets edgeInsets;
          i(_RouteState.currentRoute);
          if (_RouteState.currentRoute == null || _RouteState.currentRoute!.bodyPaddingAnimation) {
            edgeInsets = EdgeInsets.only(bottom: controller._tabbarAnimationHeight.value);
          } else {
            edgeInsets =
                controller._showBottomNav.value ? EdgeInsets.only(bottom: controller.bottomNavHeight) : EdgeInsets.zero;
          }
          return Padding(
            padding: edgeInsets,
            child: widget.navigationShell,
          );
        }),
        // widget.navigationShell,
        Obx(
          () => Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: controller._tabbarAnimationHeight.value,
            child: Wrap(
              children: [tabbarWidget],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMaterial2(BuildContext context) {
    return Obx(() => BottomNavigationBar(
          onTap: (int index) {
            widget.navigationShell.goBranch(index);
          },
          currentIndex: widget.navigationShell.currentIndex,
          unselectedFontSize: 12,
          selectedFontSize: 12,
          iconSize: 26,
          unselectedLabelStyle: TextStyle(
            fontWeight: AppController.of.config.defaultFontWeight,
          ),
          selectedItemColor: $primaryColor,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
          type: BottomNavigationBarType.fixed,
          items: controller.pages
              .map((e) => BottomNavigationBarItem(
                    icon: BadgeWidget(
                      bagde: controller.tabBadge.value[e.path],
                      child: Icon(e.icon),
                    ),
                    label: e.title,
                  ))
              .toList(),
        ));
  }

  Widget buildMaterial3(BuildContext context) {
    return NavigationBar(
      onDestinationSelected: (int index) {
        widget.navigationShell.goBranch(index);
      },
      height: controller.bottomNavHeight,
      selectedIndex: widget.navigationShell.currentIndex,
      destinations: widget.pages
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
        widget.navigationShell.goBranch(index);
      },
      height: controller.bottomNavHeight,
      currentIndex: widget.navigationShell.currentIndex,
      border: null,
      items: widget.pages
          .map((e) => BottomNavigationBarItem(
                icon: Icon(e.icon),
                label: e.title,
              ))
          .toList(),
    );
  }

  Widget buildCustom(BuildContext context) {
    return Container(
      height: controller.bottomNavHeight,
      color: Colors.grey.shade200,
      child: Row(
        children: widget.pages
            .mapIndexed(
              (i, e) => Expanded(
                child: GestureDetector(
                  onTap: () {
                    widget.navigationShell.goBranch(i);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(e.icon),
                      Text(e.title),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
