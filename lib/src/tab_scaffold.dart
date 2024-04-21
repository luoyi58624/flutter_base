part of flutter_base;

/// 选项卡式导航栏脚手架
class FlutterTabScaffold extends StatefulWidget {
  const FlutterTabScaffold({
    super.key,
    required this.navigationShell,
    required this.pages,
    this.bottomNavType = BottomNavType.material2,
    this.bottomNavHeight,
  });

  /// [GoRouter]有状态导航对象: [StatefulShellRoute.indexedStack]
  final StatefulNavigationShell navigationShell;

  /// 导航页面模型，渲染底部导航 tabbar
  final List<UrlNavModel> pages;

  /// 底部导航类型，默认[BottomNavType.material2]
  final BottomNavType bottomNavType;

  /// 底部导航栏高度
  final double? bottomNavHeight;

  @override
  State<FlutterTabScaffold> createState() => _FlutterTabScaffoldState();
}

class _FlutterTabScaffoldState extends State<FlutterTabScaffold> with FlutterThemeMixin {
  late TabScaffoldController controller;

  @override
  void initState() {
    controller = Get.put(TabScaffoldController._(
      pages: widget.pages,
      bottomNavType: widget.bottomNavType,
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
    switch (widget.bottomNavType) {
      case BottomNavType.material2:
        tabbarWidget = buildMaterial2(context);
        break;
      case BottomNavType.material3:
        tabbarWidget = buildMaterial3(context);
        break;
      case BottomNavType.cupertino:
        tabbarWidget = buildCupertino(context);
        break;
      case BottomNavType.custom:
        tabbarWidget = buildCustom(context);
        break;
    }
    return buildCustomScaffold(tabbarWidget);
  }

  Widget buildCustomScaffold(Widget tabbarWidget) {
    return Stack(
      children: [
        Obx(() {
          return Padding(
            // padding:
            //     controller._showBottomNav.value ? EdgeInsets.only(bottom: controller.bottomNavHeight) : EdgeInsets.zero,
            padding: EdgeInsets.only(bottom: controller._tabbarAnimationHeight.value),
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
            fontWeight: FlutterController.of.config.defaultFontWeight,
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
