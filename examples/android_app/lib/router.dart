import 'package:android_app/controllers/global.dart';
import 'package:android_app/global.dart';
import 'package:android_app/pages/login.dart';
import 'package:android_app/pages/root/component/root_go_route.dart';
import 'package:android_app/pages/root/component/theme.dart';
import 'package:android_app/pages/root/test/animation/darg.dart';
import 'package:android_app/pages/root/test/animation/index.dart';
import 'package:android_app/pages/root/test/animation/slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'pages/common/chat/index.dart';
import 'pages/common/chat/info.dart';
import 'pages/root/chat/index.dart';
import 'pages/root/component/animation_widget_test.dart';
import 'pages/root/component/command_route.dart';
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
    redirect: (c, s) => GlobalController.of.isLogin.value ? null : RoutePath.login,
    routes: [
      GoRoute(path: '/', redirect: (c, s) => RoutePath.root),
      GoRoute(path: '/command_route_child', pageBuilder: (c, s) => c.pageBuilder(s, CommandChildPage())),
      StatefulShellRoute.indexedStack(
        builder: (c, s, navigationShell) => TabScaffold(
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
            GoRoute(path: RoutePath.root, pageBuilder: (c, s) => c.pageBuilder(s, const ComponentPage()), routes: [
              GoRoute(
                path: 'theme',
                hideTabbar: true,
                pageBuilder: (c, s) => c.pageBuilder(s, const ThemePage()),
              ),
              GoRoute(
                path: 'image',
                hideTabbar: true,
                pageBuilder: (c, s) => c.pageBuilder(s, const ImageTestPage()),
              ),
              GoRoute(
                path: 'animation',
                pageBuilder: (c, s) => c.pageBuilder(s, const AnimationWidgetTestPage()),
              ),
              GoRoute(
                path: 'go_router',
                pageBuilder: (c, s) => c.pageBuilder(s, const GoRouterTestPage()),
              ),
            ]),
          ]),
          StatefulShellBranch(
            routes: [
              GoRoute(path: RoutePath.util, pageBuilder: (c, s) => c.pageBuilder(s, const UtilPage())),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePath.template, pageBuilder: (c, s) => c.pageBuilder(s, const TemplatePage()))
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePath.chat,
              pageBuilder: (c, s) => c.pageBuilder(s, const ChatRootPage()),
              routes: [
                GoRoute(
                  path: ':id',
                  hideTabbar: true,
                  bodyPaddingAnimation: false,
                  pageBuilder: (c, s) => c.pageBuilder(s, ChatPage(id: s.pathParameters['id']!)),
                  routes: [
                    GoRoute(
                        path: 'info',
                        pageBuilder: (c, s) => c.pageBuilder(s, ChatInfoPage(id: s.pathParameters['id']!)),
                        routes: [
                          GoRoute(
                            path: 'user',
                            pageBuilder: (c, s) => c.pageBuilder(s, const ChatUserInfoPage()),
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
              pageBuilder: (c, s) => c.pageBuilder(s, const TestRootPage()),
              routes: [
                GoRoute(
                  path: 'animation',
                  pageBuilder: (c, s) => c.pageBuilder(s, const AnimationTestPage()),
                  routes: [
                    GoRoute(
                      path: 'slider',
                      pageBuilder: (c, s) => c.pageBuilder(s, const SliderAnimationTestPage()),
                    ),
                    GoRoute(
                      path: 'drag',
                      pageBuilder: (c, s) => c.pageBuilder(s, const DragAnimationTestPage()),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(path: RoutePath.login, builder: (c, s) => const LoginPage()),
      GoRoute(path: '/root_child', builder: (c, s) => const RootGoRoutePage()),
    ],
  );
}
