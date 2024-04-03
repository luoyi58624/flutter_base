import 'package:android_app/controllers/global.dart';
import 'package:android_app/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'pages/root/component/animation_widget_test.dart';
import 'pages/root/component/go_router.dart';
import 'pages/root/component/image_test.dart';
import 'pages/root/component/index.dart';
import 'pages/root/home/index.dart';
import 'pages/root/template/index.dart';
import 'pages/root/user/index.dart';
import 'pages/root/util/index.dart';

FlutterRouter initRouter() {
  return FlutterRouter(
    redirect: (context, state) => GlobalController.of.isLogin.value ? null : '/login',
    routes: [
      buildMaterialRootPage(rootRouterList),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    ],
  );
}

var rootRouterList = [
  RouterModel('首页', '/', const HomePage(), icon: Icons.home),
  RouterModel('组件', '/component', const ComponentPage(), icon: Icons.token_outlined, children: [
    RouterModel('图片组件测试', 'image', const ImageTestPage()),
    RouterModel('动画组件测试', 'animation', const AnimationWidgetTestPage()),
    RouterModel('GoRouter动态路由', 'go_router', const GoRouterTestPage()),
  ]),
  RouterModel('工具', '/util', const UtilPage(), icon: Icons.grid_view),
  RouterModel('模版', '/template', const TemplatePage(), icon: Icons.temple_hindu),
  RouterModel('我的', '/user', const UserPage(), icon: Icons.person_pin),
];
