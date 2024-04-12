import 'package:android_app/controllers/global.dart';
import 'package:android_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'page_router.dart';

class TestRootPage extends StatelessWidget {
  const TestRootPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<UrlNavModel> items = [
      const UrlNavModel('Animation 动画测试', RoutePath.animationTest),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('测试页面'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                buildListSection(context, '动画组件测试', items),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Column(
              children: [
                CupertinoButton.filled(
                  onPressed: () {
                    GlobalController.of.isLogin.value = false;
                    context.go(RoutePath.login);
                  },
                  child: const Text('退出登录'),
                ),
                const SizedBox(height: 8),
                CupertinoButton.filled(
                  onPressed: () {
                    GlobalController.of.isLogin.value = false;
                  },
                  child: const Text('清除登录信息'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(CupertinoPageRoute(builder: (context) => const CustomPageRouterPage()));
                  },
                  child: const Text('自定义路由动画'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
