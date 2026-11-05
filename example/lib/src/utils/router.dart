import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:go_router/go_router.dart';

import '../pages/components/catalog.dart';
import '../pages/example_page.dart';
import '../router/pages.dart';

/// 从现有菜单生成路由路径与页面。
abstract final class RouterUtil {
  /// 移动端详情与两端配置共用的根导航键。
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  /// 首页地址。
  static const home = '/home';

  /// 组件目录地址。
  static const component = '/components';

  /// 视图、手势和基础示例的共同地址。
  static const examples = '/examples';

  /// 设置页地址。
  static const setting = '/settings';

  /// 组件目录中的叶子，分组只承担展示。
  static final pages = [for (final menu in componentCatalog) ..._leaves(menu)];

  /// 现有示例菜单中的页面。
  static final examplePages = navigationPages[2].children;

  /// 侧栏使用完整路径，菜单内容沿用原来的定义。
  static final desktopMenus = navigationPages.toFullPath(parentPath: '');

  /// 桌面路由对应的全部叶子。
  static final desktopPages = [for (final menu in desktopMenus) ..._leaves(menu)];

  /// 按一级导航的统一声明构建页面，避免移动路由再次声明页面工厂。
  static Widget buildRootPage(BuildContext context, String path) =>
      buildPage(context, navigationPages.firstWhere((page) => '/${page.key}' == path));

  /// 由同一份页面声明读取导航标题，查询参数和锚点不影响匹配。
  static String titleOf(Uri location) {
    for (final page in desktopPages) {
      if (page.key == location.path) return page.title;
    }
    return 'El UI';
  }

  /// 将菜单叶子生成路由，分组只承担展示，不形成虚构地址。
  static List<GoRoute> pageToRoute(
    List<ElMenuModel<WidgetBuilder>> pages, {
    GlobalKey<NavigatorState>? parentNavigatorKey,
    Widget Function(BuildContext, GoRouterState, ElMenuModel<WidgetBuilder>)? builder,
    Page<dynamic> Function(BuildContext, GoRouterState, ElMenuModel<WidgetBuilder>)? pageBuilder,
  }) => [
    for (final menu in pages)
      for (final page in _leaves(menu))
        GoRoute(
          path: page.key,
          parentNavigatorKey: parentNavigatorKey,
          builder: builder == null ? null : (context, state) => builder(context, state, page),
          pageBuilder: pageBuilder == null ? null : (context, state) => pageBuilder(context, state, page),
        ),
  ];

  /// 将路由绑定到原有页面，未实现的条目沿用空页面。
  static Widget buildPage(BuildContext context, ElMenuModel<WidgetBuilder> page) {
    final key = page.key.split('/').last;
    Widget child = page.data?.call(context) ?? ExamplePage(title: page.title);
    // 这两个现有页面使用移动端专有实现，按路由安装完整预设。
    if (key == 'shadow-design' || key == 'settings') {
      child = ElComponentProvider(components: el.mobileComponents, child: child);
    }
    return KeyedSubtree(key: ValueKey('example-page-$key'), child: child);
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
