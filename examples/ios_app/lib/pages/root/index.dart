import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class RootPage extends StatelessWidget {
  const RootPage({super.key, required this.navigationShell, required this.pages});

  final StatefulNavigationShell navigationShell;
  final List<RouterModel> pages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CupertinoTabBar(
        onTap: (int index) {
          navigationShell.goBranch(index);
        },
        currentIndex: navigationShell.currentIndex,
        items: pages
            .map((e) => BottomNavigationBarItem(
          icon: Icon(e.icon),
          label: e.title,
        ))
            .toList(),
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   onTap: (int index) {
      //     navigationShell.goBranch(index);
      //   },
      //   currentIndex: navigationShell.currentIndex,
      //   unselectedFontSize: 12,
      //   selectedFontSize: 12,
      //   iconSize: 26,
      //   type: BottomNavigationBarType.fixed,
      //   items: pages
      //       .map((e) => BottomNavigationBarItem(
      //             icon: Icon(e.icon),
      //             label: e.title,
      //           ))
      //       .toList(),
      // ),
    );
  }
}
