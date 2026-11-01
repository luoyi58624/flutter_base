import 'package:example/src/layout/index.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import 'pages/2.dart';

/// 移动端壳：顶部标题栏 + 底部导航。
class MobileLayout extends StatefulWidget {
  const MobileLayout({super.key});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  @override
  Widget build(BuildContext context) {
    return ElMobileTheme(
      child: ObsBuilder(
        builder: (context) {
          final tabs = AppLayout.tabbars;
          final index = GlobalState.boottomTabbarIndex.value;
          return Scaffold(
            appBar: AppBar(title: Text(tabs[index].$2)),
            // IndexedStack 保留各页状态，来回切 tab 不重建。
            body: IndexedStack(
              index: index,
              children: [
                Center(child: Text(tabs[0].$2)),
                ElComponentCatalogPage(),
                Center(child: Text(tabs[2].$2)),
                Center(child: Text(tabs[3].$2)),
              ],
            ),
            bottomNavigationBar: ElBottomTabbar(
              selectedIndex: index,
              onDestinationSelected: (i) => GlobalState.boottomTabbarIndex.value = i,
              destinations: [for (final tab in tabs) NavigationDestination(icon: Icon(tab.$1), label: tab.$2)],
            ),
          );
        },
      ),
    );
  }
}
