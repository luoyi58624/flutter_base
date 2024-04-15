part of flutter_base;

/// 底部导航栏类型
enum BottomNavType {
  material2,
  material3,
  cupertino,
  custom,
}

/// 选项卡式导航栏脚手架控制器
class TabScaffoldController extends GetxController {
  TabScaffoldController({required BottomNavType bottomNavType, double? bottomNavHeight}) {
    this.bottomNavType = bottomNavType.obs;
    _bottomNavHeight = bottomNavHeight;
    tabbarAnimationHeight = _getBottomNavHeight().obs;
  }

  /// 通过静态变量直接获取控制器实例
  static TabScaffoldController get of => Get.find();

  /// 应用的底部导航栏类型
  late Rx<BottomNavType> bottomNavType;
  double? _bottomNavHeight;

  /// 路由过渡中tabbar的高度
  late Rx<double> tabbarAnimationHeight;

  /// 当前是否显示底部导航栏，此变量的作用仅限于解决[CupertinoNavigationBar]、[Hero]动画异常bug，
  /// 通过监听路由的[didPush]、[didPop]生命周期函数，预先设置页面底部[Padding]，这样可以解决[Hero]动画异常bug，
  /// 因为页面过渡期间，底部导航栏的高度是不断变化的，导致整个页面高度也发生变化，从而影响到[Hero]动画的执行。
  final _showBottomNav = true.obs;

  /// 底部导航栏高度
  double get bottomNavHeight => _getBottomNavHeight();

  double _getBottomNavHeight() {
    if (_bottomNavHeight != null) return _bottomNavHeight!;
    switch (bottomNavType.value) {
      case BottomNavType.material2:
        return 56;
      case BottomNavType.material3:
        return 80;
      case BottomNavType.cupertino:
        return 50;
      case BottomNavType.custom:
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
      case BottomNavType.custom:
        tabbarWidget = buildCustom(context);
        break;
    }
    return buildCustomScaffold(tabbarWidget);
  }

  Widget buildCustomScaffold(Widget tabbarWidget) {
    return Stack(
      children: [
        Obx(() => Padding(
              padding: controller._showBottomNav.value
                  ? EdgeInsets.zero
                  : EdgeInsets.only(bottom: controller.bottomNavHeight),
              child: widget.navigationShell,
            )),
        Obx(
          () => Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: controller.tabbarAnimationHeight.value,
            child: Wrap(
              children: [tabbarWidget],
            ),
          ),
        ),
      ],
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
