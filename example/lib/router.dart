import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:go_router/go_router.dart';

import 'src/layout/desktop/index.dart';
import 'src/layout/index.dart';
import 'src/layout/mobile/index.dart';
import 'src/layout/mobile/pages/1.dart';
import 'src/layout/mobile/pages/2.dart';
import 'src/layout/mobile/pages/4.dart';
import 'src/pages/components/catalog.dart';

/// 随可用宽度切换的路由配置。
final routingConfig = _RoutingConfigNotifier();

/// 示例应用共用的声明式路由入口。
final router = GoRouter.routingConfig(
  navigatorKey: _rootKey,
  routingConfig: routingConfig,
  initialLocation: RouterUtil.home,
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: Text('页面未找到')),
    body: Center(
      child: TextButton(onPressed: () => context.go(RouterUtil.home), child: Text('返回首页')),
    ),
  ),
);

class _RoutingConfigNotifier extends ChangeNotifier implements ValueListenable<RoutingConfig> {
  bool _isMobile = true;
  late RoutingConfig _config = mobileRoute;

  @override
  RoutingConfig get value => _config;

  /// 当前是否使用移动端导航结构。
  bool get isMobile => _isMobile;

  set isMobile(bool value) {
    if (_isMobile == value) return;
    _isMobile = value;
    _config = value ? mobileRoute : desktopRoute;
    notifyListeners();
  }
}

final _rootKey = GlobalKey<NavigatorState>();
final _desktopKey = GlobalKey<NavigatorState>();

/// 桌面路由把现有页面放入共同侧栏布局。
RoutingConfig get desktopRoute => RoutingConfig(
  routes: [
    GoRoute(path: '/', redirect: (context, state) => RouterUtil.home),
    ShellRoute(
      navigatorKey: _desktopKey,
      pageBuilder: (context, state, child) => NoTransitionPage(child: DesktopLayout(child: child)),
      routes: [
        GoRoute(
          path: RouterUtil.component,
          redirect: (context, state) => '${RouterUtil.component}/${RouterUtil.pages.first.key}',
        ),
        GoRoute(
          path: RouterUtil.examples,
          redirect: (context, state) => '${RouterUtil.examples}/${RouterUtil.examplePages.first.key}',
        ),
        for (final page in RouterUtil.desktopPages)
          GoRoute(
            path: page.key,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: RouterUtil.buildPage(context, page)),
          ),
      ],
    ),
  ],
);

/// 移动路由为现有的四个底栏分别保留导航栈。
RoutingConfig get mobileRoute => RoutingConfig(
  routes: [
    GoRoute(path: '/', redirect: (context, state) => RouterUtil.home),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MobileLayout(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: RouterUtil.home, builder: (context, state) => HomePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouterUtil.component,
              builder: (context, state) => ComponentPage(),
              routes: [
                for (final page in RouterUtil.pages)
                  GoRoute(
                    path: page.key,
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => ElComponentProvider(
                      components: el.mobileComponents,
                      child: RouterUtil.buildPage(context, page),
                    ),
                  ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouterUtil.examples,
              builder: (context, state) => Center(child: Text('示例')),
              routes: [
                for (final page in RouterUtil.examplePages)
                  GoRoute(
                    path: page.key,
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => ElComponentProvider(
                      components: el.mobileComponents,
                      child: RouterUtil.buildPage(context, page),
                    ),
                  ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: RouterUtil.setting, builder: (context, state) => SettingPage())],
        ),
      ],
    ),
  ],
);

/// 从现有菜单生成路由路径与页面。
abstract final class RouterUtil {
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
  static final examplePages = AppLayout.menus[2].children;

  /// 侧栏使用完整路径，菜单内容沿用原来的定义。
  static final desktopMenus = AppLayout.menus.toFullPath(parentPath: '');

  /// 桌面路由对应的全部叶子。
  static final desktopPages = [for (final menu in desktopMenus) ..._leaves(menu)];

  /// 将路由绑定到原有页面，未实现的条目沿用空页面。
  static Widget buildPage(BuildContext context, ElMenuModel<WidgetBuilder> page) {
    final key = page.key.split('/').last;
    Widget child = page.data?.call(context) ?? Scaffold(appBar: AppBar(title: Text(page.title)));
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
