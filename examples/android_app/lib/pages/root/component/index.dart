import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ComponentPage extends StatelessWidget {
  const ComponentPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<UrlNavModel> componentItems = [
      const UrlNavModel('Image图片组件', '/component/image'),
      const UrlNavModel('动画组件测试', '/component/animation'),
      const UrlNavModel('GoRouter动态路由', '/component/go_router'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('组件列表'),
        actions: [
          Obx(
            () => Switch(
              value: FlutterController.of.useMaterial3.value,
              onChanged: (v) {
                FlutterController.of.useMaterial3.value = v;
              },
            ),
          ),
        ],
      ),
      drawer: Drawer(
        shape: const BeveledRectangleBorder(borderRadius: BorderRadius.zero),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text(
                'luoyi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: const Text('https://www.luoyi.website'),
              currentAccountPicture: const CircleAvatar(
                backgroundImage: AssetImage('assets/images/avatars.jpg'),
              ),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/home_bg.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.grey.withOpacity(0.8), BlendMode.hardLight),
                ),
              ),
            ),
            Expanded(
              child: buildListViewDemo(),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildListSection(context, '自定义组件', componentItems),
          ],
        ),
      ),
    );
  }
}
