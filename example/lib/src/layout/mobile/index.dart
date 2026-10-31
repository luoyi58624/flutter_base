import 'package:example/src/layout/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 移动端壳：顶部标题栏 + 底部导航。
class MobileLayout extends StatefulWidget {
  const MobileLayout({super.key});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = AppLayout.tabbars;
    return Scaffold(
      appBar: AppBar(title: Text(tabs[_index].$2)),
      // IndexedStack 保留各页状态，来回切 tab 不重建。
      body: IndexedStack(
        index: _index,
        children: [for (final tab in tabs) Center(child: Text(tab.$2))],
      ),
      bottomNavigationBar: ElBottomTabbar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.$1), label: tab.$2),
        ],
      ),
    );
  }
}
