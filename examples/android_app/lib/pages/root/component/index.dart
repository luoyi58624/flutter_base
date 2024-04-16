import 'package:android_app/pages/root/component/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ComponentPage extends StatelessWidget {
  const ComponentPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<UrlNavModel> componentItems = [
      UrlNavModel('Image图片组件', '/component/image'),
      UrlNavModel('动画组件测试', '/component/animation'),
      UrlNavModel('GoRouter动态路由', '/component/go_router'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('组件列表'),
        actions: [
          Obx(
            () => Switch(
              value: FlutterController.of.config.useMaterial3,
              onChanged: (v) {
                FlutterController.of.config = FlutterController.of.config.copyWith(useMaterial3: v);
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
            // buildListSection(context, '自定义组件', componentItems),
            Obx(
              () => Container(
                width: 100,
                height: 100,
                color: FlutterController.of.getTheme(context).primary,
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          RouterUtil.push(context, const ThemePage());
        },
        child: const Icon(Icons.color_lens),
      ),
    );
  }
}
