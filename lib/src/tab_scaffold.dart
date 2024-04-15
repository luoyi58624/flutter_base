part of flutter_base;

/// 底部导航栏类型
enum BottomNavType { material2, material3, cupertino }

/// 选项卡式导航栏脚手架控制器
class TabScaffoldController extends GetxController {
  TabScaffoldController({required BottomNavType bottomNavType, double? bottomNavHeight}) {
    this.bottomNavType = bottomNavType.obs;
    _bottomNavHeight = bottomNavHeight;
  }

  /// 通过静态变量直接获取控制器实例
  static TabScaffoldController get of => Get.find();

  /// 应用的底部导航栏类型
  late Rx<BottomNavType> bottomNavType;
  double? _bottomNavHeight;

  /// 当前页面是否显示底部导航栏
  final _showTabbar = true.obs;

  /// 由于路由切换存在过渡动画，所以需要声明一个延迟定时器更新tabbar显示状态
  static Timer? _showTabbarTimer;

  /// 路由过渡中tabbar的高度
  final tabbarAnimationHeight = 0.0.obs;

  bool get showTabbar => _showTabbar.value;

  set showTabbar(bool value) {
    if (_showTabbarTimer != null) _showTabbarTimer!.cancel();
    _showTabbar.value = value;
  }

  /// 底部导航栏高度
  double get bottomNavHeight {
    if (_bottomNavHeight != null) return _bottomNavHeight!;
    switch (bottomNavType.value) {
      case BottomNavType.material2:
        return 56;
      case BottomNavType.material3:
        return 80;
      case BottomNavType.cupertino:
        return 50;
    }
  }
}

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
  final List<NavModel> pages;

  /// 底部导航类型，默认[BottomNavType.material2]
  final BottomNavType bottomNavType;

  /// 底部导航栏高度
  final double? bottomNavHeight;

  @override
  State<FlutterTabScaffold> createState() => _FlutterTabScaffoldState();
}

class _FlutterTabScaffoldState extends State<FlutterTabScaffold> {
  late TabScaffoldController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(TabScaffoldController(
      bottomNavType: widget.bottomNavType,
      bottomNavHeight: widget.bottomNavHeight,
    ));
  }

  @override
  void dispose() {
    super.dispose();
    Get.delete<TabScaffoldController>();
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
    }
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Obx(
        () => controller.showTabbar
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: controller.bottomNavHeight,
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
}
