import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'animation_widget_test.dart';
import 'image_test.dart';

class ComponentPage extends StatelessWidget {
  const ComponentPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<UrlNavModel> customComponentItems = [
      const UrlNavModel('Image图片组件', '/component/image'),
      const UrlNavModel('动画组件测试', '/component/animation'),
      const UrlNavModel('GoRouter动态路由', '/component/go_router'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('组件列表'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildListSection(context, '自定义组件', customComponentItems),
          ],
        ),
      ),
    );
  }
}
