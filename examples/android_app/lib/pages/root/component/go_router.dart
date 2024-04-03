import 'package:android_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class GoRouterTestPage extends StatelessWidget {
  const GoRouterTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GoRouter动态路由'),
      ),
      body: buildCenterColumn([
        ElevatedButton(
          onPressed: () {
            var newList = List.from(rootRouterList).toList().cast<RouterModel>();
            logger.i(newList[1].children![2].title);
            newList[1].children![2].children!.add(
                  RouterModel('动态路由页面', 'dynamic', const _DynamicPage()),
                );
            router.routes = [buildMaterialRootPage(newList)];
          },
          child: const Text('创建动态路由'),
        ),
        ElevatedButton(
          onPressed: () {
            context.go('/component/go_router/dynamic');
          },
          child: const Text('跳转动态路由'),
        ),
        ElevatedButton(
          onPressed: () {
            context.go('/');
          },
          child: const Text('跳转首页'),
        ),
        ElevatedButton(
          onPressed: () {
            context.go('/util');
          },
          child: const Text('跳转工具页面'),
        ),
        ElevatedButton(
          onPressed: () {
            context.pop();
          },
          child: const Text('返回'),
        ),
      ]),
    );
  }
}

class _DynamicPage extends StatelessWidget {
  const _DynamicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('动态路由页面'),
      ),
      body: Container(),
    );
  }
}
