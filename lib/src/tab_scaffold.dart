part of flutter_base;

enum TabType { material2, material3, cupertino }

class _TabController extends GetxController {
  _TabController({required this.tabType});

  static _TabController of = Get.find();

  final TabType tabType;

  /// 当前页面是否显示底部导航栏
  final _showTabbar = true.obs;

  bool get showTabbar => _showTabbar.value;

  set showTabbar(bool value) {
    if (_showTabbarTimer != null) _showTabbarTimer!.cancel();
    _showTabbar.value = value;
  }

  /// 路由过渡中tabbar的高度
  final tabbarAnimationHeight = 0.0.obs;

  static Timer? _showTabbarTimer;
}

/// 选项卡式导航栏脚手架
class FlutterTabScaffold extends StatefulWidget {
  const FlutterTabScaffold({
    super.key,
    required this.navigationShell,
    required this.pages,
    this.tabType = TabType.material2,
  });

  /// [GoRouter]有状态导航对象: [StatefulShellRoute.indexedStack]
  final StatefulNavigationShell navigationShell;

  /// 导航页面模型，渲染底部导航 tabbar
  final List<NavModel> pages;

  /// 底部导航类型，默认[TabType.material2]
  final TabType tabType;

  @override
  State<FlutterTabScaffold> createState() => _FlutterTabScaffoldState();
}

class _FlutterTabScaffoldState extends State<FlutterTabScaffold> {
  late _TabController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(_TabController(tabType: widget.tabType));
  }

  @override
  void dispose() {
    super.dispose();
    Get.delete<_TabController>();
  }

  @override
  Widget build(BuildContext context) {
    late Widget tabbarWidget;
    late double tabbarHeight;
    switch (widget.tabType) {
      case TabType.material2:
        tabbarWidget = buildMaterial2(context);
        tabbarHeight = 56;
        break;
      case TabType.material3:
        tabbarWidget = buildMaterial3(context);
        tabbarHeight = 80;
        break;
      case TabType.cupertino:
        tabbarWidget = buildCupertino(context);
        tabbarHeight = 50;
        break;
    }
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Obx(
        () => controller.showTabbar
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: tabbarHeight,
                child: Wrap(
                  children: [tabbarWidget],
                ),
              )
            : SizedBox(
                height: controller.tabbarAnimationHeight.value,
                child: Wrap(
                  children: [tabbarWidget],
                ),
              ),
      ),
    );
  }

  Widget buildMaterial2(BuildContext context) {
    return BottomNavigationBar(
      onTap: (int index) {
        widget.navigationShell.goBranch(index);
      },
      currentIndex: widget.navigationShell.currentIndex,
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
      items: widget.pages
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
        widget.navigationShell.goBranch(index);
      },
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
      currentIndex: widget.navigationShell.currentIndex,
      items: widget.pages
          .map((e) => BottomNavigationBarItem(
                icon: Icon(e.icon),
                label: e.title,
              ))
          .toList(),
    );
  }
}
