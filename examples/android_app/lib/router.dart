import 'package:android_app/controllers/global.dart';
import 'package:android_app/global.dart';
import 'package:android_app/pages/login.dart';
import 'package:android_app/pages/root/test/animation/darg.dart';
import 'package:android_app/pages/root/test/animation/index.dart';
import 'package:android_app/pages/root/test/animation/slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'pages/common/chat/index.dart';
import 'pages/common/chat/info.dart';
import 'pages/root/chat/index.dart';
import 'pages/root/component/animation_widget_test.dart';
import 'pages/root/component/go_router.dart';
import 'pages/root/component/image_test.dart';
import 'pages/root/component/index.dart';
import 'pages/root/template/index.dart';
import 'pages/root/test/index.dart';
import 'pages/root/util/index.dart';

/// 常用的路由地址
class RoutePath {
  RoutePath._();

  static const root = '/component';
  static const login = '/login';
  static const util = '/util';
  static const template = '/template';
  static const chat = '/chat';
  static const test = '/test';
  static const animationTest = '$test/animation';
}

GoRouter initRouter() {
  return GoRouter(
    initialLocation: RoutePath.root,
    navigatorKey: RouterUtil.rootNavigatorKey,
    redirect: (context, state) => GlobalController.of.isLogin.value ? null : RoutePath.login,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => RoutePath.root),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => FlutterTabScaffold(
          navigationShell: navigationShell,
          pages: [
            UrlNavModel('组件', RoutePath.root, icon: Icons.token_outlined),
            UrlNavModel('工具', RoutePath.util, icon: Icons.grid_view),
            UrlNavModel('模版', RoutePath.template, icon: Icons.temple_hindu),
            UrlNavModel('聊天', RoutePath.chat, icon: Icons.chat_bubble),
            UrlNavModel('我的', RoutePath.test, icon: Icons.person_pin),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePath.root, builder: (context, state) => const ComponentPage(), routes: [
              GoRoute(
                path: 'theme',
                pageBuilder: (context, state) => RouterUtil.pageBuilder(context, state, const ImageTestPage()),
              ),
              GoRoute(
                path: 'image',
                pageBuilder: (context, state) => RouterUtil.pageBuilder(context, state, const ImageTestPage()),
              ),
              GoRoute(
                path: 'animation',
                pageBuilder: (context, state) =>
                    RouterUtil.pageBuilder(context, state, const AnimationWidgetTestPage()),
              ),
              GoRoute(
                path: 'go_router',
                pageBuilder: (context, state) => RouterUtil.pageBuilder(context, state, const GoRouterTestPage()),
              ),
            ]),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePath.util, builder: (context, state) => const UtilPage())]),
          StatefulShellBranch(
              routes: [GoRoute(path: RoutePath.template, builder: (context, state) => const TemplatePage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePath.chat,
              builder: (context, state) => const ChatRootPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) => RouterUtil.pageBuilder(
                      context, state, ChatPage(id: state.pathParameters['id']!),
                      rootNavigator: true),
                  routes: [
                    GoRoute(
                        path: 'info',
                        pageBuilder: (context, state) =>
                            RouterUtil.pageBuilder(context, state, ChatInfoPage(id: state.pathParameters['id']!)),
                        routes: [
                          GoRoute(
                            path: 'user',
                            pageBuilder: (context, state) =>
                                RouterUtil.pageBuilder(context, state, const ChatUserInfoPage(), rootNavigator: true),
                          )
                        ]),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePath.test,
              builder: (context, state) => const TestRootPage(),
              routes: [
                GoRoute(
                  path: 'animation',
                  pageBuilder: (context, state) => RouterUtil.pageBuilder(context, state, const AnimationTestPage()),
                  routes: [
                    GoRoute(
                      path: 'slider',
                      pageBuilder: (context, state) =>
                          RouterUtil.pageBuilder(context, state, const SliderAnimationTestPage()),
                    ),
                    GoRoute(
                      path: 'drag',
                      pageBuilder: (context, state) =>
                          RouterUtil.pageBuilder(context, state, const DragAnimationTestPage()),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(path: RoutePath.login, builder: (context, state) => const LoginPage()),
      GoRoute(path: '/root_child', builder: (context, state) => const ChildPage(title: '根页面child')),
    ],
  );
}
