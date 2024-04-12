import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

class AnimationTestPage extends StatelessWidget {
  const AnimationTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<UrlNavModel> items = [
      const UrlNavModel('Slider 滑块测试', '${RoutePath.animationTest}/slider'),
      const UrlNavModel('Darg 拖拽容器测试', '${RoutePath.animationTest}/drag'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('动画测试集合'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildListSection(context, '动画组件测试', items),
          ],
        ),
      ),
    );
  }
}
