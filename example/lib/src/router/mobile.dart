import 'package:flutter_base/mobile.dart';
import 'package:go_router/go_router.dart';

import '../layout/mobile/index.dart';
import '../pages/components/index.dart' show desktopComponentGroup;
import '../utils/router.dart';

/// 移动路由为现有的四个底栏分别保留导航栈。
RoutingConfig get mobileRoute => RoutingConfig(
  routes: [
    GoRoute(path: '/', redirect: (context, state) => RouterUtil.home),
    StatefulShellRoute.indexedStack(
      pageBuilder: (context, state, shell) => NoTransitionPage(
        key: RouterUtil.layoutPageKey,
        child: MobileLayout(navigationShell: shell),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouterUtil.home,
              builder: (context, state) => RouterUtil.buildRootPage(context, RouterUtil.home),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouterUtil.component,
              builder: (context, state) => RouterUtil.buildRootPage(context, RouterUtil.component),
              routes: [
                for (final page in desktopComponentGroup.children)
                  GoRoute(path: page.key, redirect: (context, state) => RouterUtil.component),
                ...RouterUtil.pageToRoute(
                  RouterUtil.pages,
                  parentNavigatorKey: RouterUtil.rootNavigatorKey,
                  builder: (context, state, page) =>
                      ElComponentProvider(components: el.mobileComponents, child: RouterUtil.buildPage(context, page)),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouterUtil.examples,
              builder: (context, state) => RouterUtil.buildRootPage(context, RouterUtil.examples),
              routes: RouterUtil.exampleRoutes(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouterUtil.setting,
              builder: (context, state) => RouterUtil.buildRootPage(context, RouterUtil.setting),
            ),
          ],
        ),
      ],
    ),
  ],
);
