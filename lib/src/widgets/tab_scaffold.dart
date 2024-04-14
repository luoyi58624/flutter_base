part of flutter_base;

enum TabType { material2, material3, cupertino }

class _TabController extends GetxController {
  static _TabController of = Get.find();
  final showBottomBar = true.obs;

  /// 路由过渡中tabbar的高度
  final tabbarAnimationHeight = 0.0.obs;
}

/// 导航栏脚手架
class FlutterTabScaffold extends StatefulWidget {
  const FlutterTabScaffold({
    super.key,
    required this.navigationShell,
    required this.pages,
    this.bottomTabbarType = TabType.material2,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavModel> pages;
  final TabType bottomTabbarType;

  @override
  State<FlutterTabScaffold> createState() => _FlutterTabScaffoldState();
}

class _FlutterTabScaffoldState extends State<FlutterTabScaffold> {
  final controller = Get.put(_TabController());

  @override
  void dispose() {
    super.dispose();
    Get.delete<_TabController>();
  }

  @override
  Widget build(BuildContext context) {
    late Widget tabbarWidget;
    late double tabbarHeight;
    switch (widget.bottomTabbarType) {
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
            () => controller.showBottomBar.value
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
