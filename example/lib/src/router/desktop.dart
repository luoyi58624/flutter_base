import 'package:go_router/go_router.dart';

import '../layout/desktop/index.dart';
import '../utils/router.dart';

/// 桌面路由把现有页面放入共同侧栏布局。
RoutingConfig get desktopRoute => RoutingConfig(
  routes: [
    GoRoute(path: '/', redirect: (context, state) => RouterUtil.home),
    ShellRoute(
      // 由本次配置创建导航键，避免旧壳退出时与再次进入的新壳共享 key。
      pageBuilder: (context, state, child) => NoTransitionPage(
        key: RouterUtil.layoutPageKey,
        child: DesktopLayout(
          title: RouterUtil.titleOf(state.uri),
          showThemeToggle: state.uri.path == RouterUtil.home,
          child: child,
        ),
      ),
      routes: [
        GoRoute(
          path: RouterUtil.component,
          redirect: (context, state) => '${RouterUtil.component}/${RouterUtil.pages.first.key}',
        ),
        ...RouterUtil.pageToRoute(
          RouterUtil.desktopPages,
          pageBuilder: (context, state, page) =>
              NoTransitionPage(key: state.pageKey, child: RouterUtil.buildPage(context, page)),
          routes: (page) => page.key == RouterUtil.examples ? RouterUtil.exampleRoutes() : [],
        ),
      ],
    ),
  ],
);
