import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'pages/root/component.dart';
import 'pages/root/home.dart';
import 'pages/root/util.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => FlutterTabScaffold(
        navigationShell: navigationShell,
        bottomNavType: BottomNavType.custom,
        pages: [
          UrlNavModel('首页', '/', icon: Icons.home),
          UrlNavModel('组件', '/component', icon: Icons.token_outlined),
          UrlNavModel('工具', '/util', icon: Icons.grid_view),
        ],
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
              routes: [
                GoRoute(
                  path: 'child',
                  pageBuilder: (context, state) => context.pageBuilder(state, const ChildPage()),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/component',
              builder: (context, state) => const ComponentPage(),
              routes: [
                GoRoute(
                  path: 'child',
                  pageBuilder: (context, state) {
                    logger.i(state.uri.queryParameters);
                    return context.pageBuilder(
                      state,
                      ComponentChildPage(title: state.uri.queryParameters['title']),
                      hideTabbar: true,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/util',
              builder: (context, state) => const UtilPage(),
              routes: [
                GoRoute(
                  path: 'child',
                  pageBuilder: (context, state) =>
                      context.pageBuilder(state, ChildPage(title: state.uri.queryParameters['title'])),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/root_child',
      pageBuilder: (context, state) => context.pageBuilder(
        state,
        const ChildPage(title: '根 - 子页面'),
      ),
    ),
    GoRoute(
      path: '/home_child',
      pageBuilder: (context, state) => context.pageBuilder(state, const HomeChildPage()),
    ),
  ],
);
