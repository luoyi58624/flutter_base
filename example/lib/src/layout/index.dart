import 'package:example/src/layout/desktop/index.dart';
import 'package:example/src/layout/mobile/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({super.key});

  static const tabbars = [
    (Icons.home, '首页', 'home'),
    (Icons.widgets, '组件', 'components'),
    (Icons.grid_view, '示例', 'examples'),
    (Icons.settings, '设置', 'settings'),
  ];

  /// 菜单 key 到一级 tab 索引的映射，子项归到其所属分组。
  static const menuTabs = {
    'home': 0,
    'components': 1,
    'component-overview': 1,
    'examples': 2,
    'view': 2,
    'gestures': 2,
    'base': 2,
    'settings': 3,
  };

  /// 一级 tab 索引对应的菜单 key。
  static String tabKeyOf(int index) => tabbars[index].$3;

  @override
  Widget build(BuildContext context) {
    return ElView(
      child: Builder(
        builder: (context) {
          return ElView.of(context).sm ? const MobileLayout() : const DesktopLayout();
        },
      ),
    );
  }
}
