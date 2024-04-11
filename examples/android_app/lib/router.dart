import 'package:android_app/controllers/global.dart';
import 'package:android_app/global.dart';
import 'package:android_app/pages/login.dart';
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
import 'pages/root/user/index.dart';
import 'pages/root/util/index.dart';

GoRouter initRouter() {
  return GoRouter(
    initialLocation: '/component',
    navigatorKey: RouterUtil.rootNavigatorKey,
    redirect: (context, state) => GlobalController.of.isLogin.value ? null : '/login',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => BottomTabbarWidget(
          navigationShell: navigationShell,
          pages: const [
            NavModel('组件', icon: Icons.token_outlined),
            NavModel('工具', icon: Icons.grid_view),
            NavModel('模版', icon: Icons.temple_hindu),
            NavModel('聊天', icon: Icons.chat_bubble),
            NavModel('我的', icon: Icons.person_pin),
          ],
          bottomTabbarType: BottomTabbarType.material2,
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/component', builder: (context, state) => const ComponentPage(), routes: [
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
          StatefulShellBranch(routes: [GoRoute(path: '/util', builder: (context, state) => const UtilPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/template', builder: (context, state) => const TemplatePage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatListPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) =>
                      RouterUtil.pageBuilder(context, state, ChatPage(id: state.pathParameters['id']!)),
                  routes: [
                    GoRoute(path: 'info', builder: (context, state) => const ChatInfoPage()),
                  ],
                ),
              ],
            )
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/user', builder: (context, state) => const UserPage())]),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/root_child', builder: (context, state) => const ChildPage(title: '根页面child')),
    ],
  );
}
