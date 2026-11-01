import 'package:example/src/layout/desktop/index.dart';
import 'package:example/src/layout/mobile/index.dart';
import 'package:example/src/pages/components/catalog.dart';
import 'package:example/src/pages/custom_gestures.dart';
import 'package:example/src/pages/view.dart';
import 'package:example/src/pages/view/base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'mobile/pages/1.dart';
import 'mobile/pages/4.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({super.key});

  /// 顶层同时对应移动 tab 与桌面菜单，组件目录直接复用共用分组。
  static final menus = <ElMenuModel<WidgetBuilder>>[
    ElMenuModel(key: 'home', title: '首页', icon: ElIcon(Icons.home_outlined), data: (_) => HomePage()),
    ElMenuModel(key: 'components', title: '组件', icon: ElIcon(Icons.widgets_outlined), children: componentCatalog),
    ElMenuModel(
      key: 'examples',
      title: '示例',
      icon: ElIcon(Icons.grid_view_outlined),
      children: [
        ElMenuModel(key: 'view', title: '视图', icon: ElIcon(Icons.web_outlined), data: (_) => ElViewPage()),
        ElMenuModel(
          key: 'gestures',
          title: '手势',
          icon: ElIcon(Icons.touch_app_outlined),
          data: (_) => CustomGesturesPage(),
        ),
        ElMenuModel(key: 'base', title: '基础', icon: ElIcon(Icons.layers_outlined), data: (_) => ViewBasePage()),
      ],
    ),
    ElMenuModel(key: 'settings', title: '设置', icon: ElIcon(Icons.settings_outlined), data: (_) => SettingPage()),
  ];

  /// 真实页面由菜单树收集，分组标题和可折叠父项不占页面。
  static final pages = [for (final menu in menus) ..._leaves(menu)];

  /// 叶子归属由菜单树推导，新增目录项无需维护第二份映射。
  static final menuTabs = {
    for (final (index, menu) in menus.indexed) ...{menu.key: index, for (final page in _leaves(menu)) page.key: index},
  };

  /// 外部切换 tab 时选择该菜单的首个真实叶子。
  static String tabKeyOf(int index) => _leaves(menus[index]).first.key;

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

Iterable<ElMenuModel<WidgetBuilder>> _leaves(ElMenuModel<WidgetBuilder> menu) sync* {
  if (menu.children.isEmpty) {
    if (!menu.group) yield menu;
  } else {
    for (final child in menu.children) {
      yield* _leaves(child);
    }
  }
}
