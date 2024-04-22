part of flutter_base;

/// App选项卡式底部导航栏脚手架，如果使用，将注入[TabScaffoldController]控制器，你可以通过控制器动态更新导航栏名字、图标、badge，
/// 同时，你可以在声明式路由设置[hideTab]属性，用于隐藏底部导航栏
///
/// ```dart
/// StatefulShellRoute.indexedStack(
///   builder: (c, s, navigationShell) => AppTabScaffold(
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
///             GoRoute(path: 'child', hideTab: true, pageBuilder: (c, s) => c.pageBuilder(s, const ChildPage())),
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
class AppTabScaffold extends StatefulWidget {
  const AppTabScaffold({
    super.key,
    required this.navigationShell,
    required this.pages,
    this.tabType = TabType.material2,
    this.bottomNavHeight,
  });

  /// [GoRouter]有状态导航对象: [StatefulShellRoute.indexedStack]
  final StatefulNavigationShell navigationShell;

  /// 导航页面模型，渲染底部导航 tabbar
  final List<UrlNavModel> pages;

  /// 底部导航类型，默认[BottomNavType.material2]
  final TabType tabType;

  /// 底部导航栏高度
  final double? bottomNavHeight;

  @override
  State<AppTabScaffold> createState() => _AppTabScaffoldState();
}

class _AppTabScaffoldState extends State<AppTabScaffold> with FlutterThemeMixin {
  late TabScaffoldController controller;

  @override
  void initState() {
    controller = Get.put(TabScaffoldController._(
      pages: widget.pages,
      tabType: widget.tabType,
      bottomNavHeight: widget.bottomNavHeight,
    ));
    _State.injectTabScaffoldController = true;
    super.initState();
  }

  @override
  void dispose() {
    Get.delete<TabScaffoldController>();
    _State.injectTabScaffoldController = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    late Widget tabbarWidget;
    switch (widget.tabType) {
      case TabType.material2:
        tabbarWidget = buildMaterial2(context);
        break;
      case TabType.material3:
        tabbarWidget = buildMaterial3(context);
        break;
      case TabType.cupertino:
        tabbarWidget = buildCupertino(context);
        break;
      case TabType.custom:
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
          i(_State.currentRoute);
          if (_State.currentRoute == null || _State.currentRoute!.bodyPaddingAnimation) {
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
