import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../pages/components/catalog.dart';
import '../pages/components/index.dart';
import '../pages/custom_gestures.dart';
import '../pages/examples.dart';
import '../pages/home.dart';
import '../pages/settings.dart';
import '../pages/view.dart';
import '../pages/view/base.dart';

/// 统一声明导航标题、图标与页面工厂，两端据此生成菜单和路由。
final navigationPages = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(key: 'home', title: '首页', icon: ElIcon(Icons.home_outlined), data: (_) => HomePage()),
  ElMenuModel(
    key: 'components',
    title: '组件',
    icon: ElIcon(Icons.widgets_outlined),
    data: (_) => ComponentPage(),
    children: componentCatalog,
  ),
  ElMenuModel(
    key: 'examples',
    title: '示例',
    icon: ElIcon(Icons.grid_view_outlined),
    data: (_) => ExamplesPage(),
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
