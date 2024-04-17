import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

class RootGoRoutePage extends StatelessWidget {
  const RootGoRoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('根GoRoute页面'),
      ),
      body: buildCenterColumn([
        ElevatedButton(
          onPressed: () {
            context.pop();
          },
          child: const Text('返回'),
        ),
        ElevatedButton(
          onPressed: () {
            context.go(RoutePath.root);
          },
          child: const Text('首页'),
        ),
        ElevatedButton(
          onPressed: () {
            context.go('${RoutePath.root}/image');
          },
          child: const Text('首页 - 图片测试'),
        ),
        ElevatedButton(
          onPressed: () {
            context.go(RoutePath.util);
          },
          child: const Text('工具'),
        ),
      ]),
    );
  }
}
