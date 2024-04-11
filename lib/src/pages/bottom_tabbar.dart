part of flutter_base;

enum BottomTabbarType { material2, material3, cupertino }

class BottomTabbarController extends GetxController {
  static BottomTabbarController of = Get.find();
  final showBottomBar = true.obs;
}

/// 移动端底部导航栏组件
class BottomTabbarWidget extends StatefulWidget {
  const BottomTabbarWidget({
    super.key,
    required this.navigationShell,
    required this.pages,
    this.bottomTabbarType = BottomTabbarType.material2,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavModel> pages;
  final BottomTabbarType bottomTabbarType;

  @override
  State<BottomTabbarWidget> createState() => _BottomTabbarWidgetState();
}

class _BottomTabbarWidgetState extends State<BottomTabbarWidget> {
  final controller = Get.put(BottomTabbarController());

  @override
  void dispose() {
    super.dispose();
    Get.delete<BottomTabbarController>();
  }

  @override
  Widget build(BuildContext context) {
    late Widget tabbarWidget;
    late double tabbarHeight;
    switch (widget.bottomTabbarType) {
      case BottomTabbarType.material2:
        tabbarWidget = buildMaterial2(context);
        tabbarHeight = 56;
        break;
      case BottomTabbarType.material3:
        tabbarWidget = buildMaterial3(context);
        tabbarHeight = 80;
        break;
      case BottomTabbarType.cupertino:
        tabbarWidget = buildCupertino(context);
        tabbarHeight = 50;
        break;
    }
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Obx(() => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: controller.showBottomBar.value ? tabbarHeight : 0,
            child: Wrap(
              children: [tabbarWidget],
            ),
          )),
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
