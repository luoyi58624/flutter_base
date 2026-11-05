import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../pages/components/catalog.dart';
import '../pages/custom_gestures.dart';
import '../pages/view.dart';
import '../pages/view/base.dart';
import 'mobile/pages/1.dart';
import 'mobile/pages/4.dart';

/// 两端布局共用的示例菜单。
abstract final class AppLayout {
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
}
