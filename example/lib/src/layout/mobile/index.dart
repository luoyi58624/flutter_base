import 'package:example/src/layout/index.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 移动端壳：顶部标题栏 + 底部导航。
class MobileLayout extends StatefulWidget {
  const MobileLayout({super.key});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  @override
  Widget build(BuildContext context) {
    return ObsBuilder(
      builder: (context) {
        final tabs = AppLayout.tabbars;
        final index = GlobalState.boottomTabbarIndex.value;
        return Scaffold(
          appBar: AppBar(title: Text(tabs[index].$2)),
          // IndexedStack 保留各页状态，来回切 tab 不重建。
          body: IndexedStack(
            index: index,
            children: [for (final tab in tabs) Center(child: Text(tab.$2))],
          ),
          bottomNavigationBar: ElBottomTabbar(
            selectedIndex: index,
            onDestinationSelected: (i) =>
                GlobalState.boottomTabbarIndex.value = i,
            destinations: [
              for (final tab in tabs)
                NavigationDestination(icon: Icon(tab.$1), label: tab.$2),
            ],
          ),
        );
      },
    );
  }
}
