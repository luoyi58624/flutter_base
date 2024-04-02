part of flutter_base;

class MaterialRootPage extends StatefulWidget {
  const MaterialRootPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

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
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.ac_unit),
            label: '二级页面',
          ),
        ],
      ),
    );
  }
}
