import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../pages/components/index.dart';
import '../pages/examples/index.dart';
import '../pages/home/index.dart';
import '../pages/settings/index.dart';

/// 统一声明导航标题、图标与页面工厂，两端据此生成菜单和路由。
final navigationPages = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(key: 'home', title: '首页', icon: ElIcon(Icons.home_outlined), data: (_) => HomePage()),
  ElMenuModel(
    key: 'components',
    title: '组件',
    icon: ElIcon(Icons.widgets_outlined),
    data: (_) => ComponentPage(),
    children: componentCatalogFor(mobile: false),
  ),
  ElMenuModel(key: 'examples', title: '示例', icon: ElIcon(Icons.grid_view_outlined), data: (_) => ExamplesPage()),
  ElMenuModel(key: 'settings', title: '设置', icon: ElIcon(Icons.settings_outlined), data: (_) => SettingPage()),
];
