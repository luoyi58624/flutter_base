import 'package:android_app/controllers/global.dart';
import 'package:android_app/global.dart';
import 'package:android_app/pages/root/component/theme.dart';
import 'package:android_app/pages/root/test/animation/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ComponentPage extends StatefulWidget {
  const ComponentPage({super.key});

  @override
  State<ComponentPage> createState() => _ComponentPageState();
}

class _ComponentPageState extends State<ComponentPage> {
  int count = 0;

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
            buildListSection(context, '自定义组件', componentItems),
            Row(
              children: [
                const Text('开启慢动画:'),
                Obx(
                  () => Switch(
                    onChanged: (v) {
                      if (v) {
                        FlutterController.of.timeDilation.value = 3.0;
                      } else {
                        FlutterController.of.timeDilation.value = 1.0;
                      }
                    },
                    value: FlutterController.of.timeDilation.value > 1.0 ? true : false,
                  ),
                ),
              ],
            ),
            Obx(
              () => Container(
                width: 100,
                height: 100,
                color: FlutterController.of.getTheme(context).primary,
              ),
            ),
            Obx(() {
              return ElevatedButton(
                onPressed: () {
                  GlobalController.of.count.value = 1;
                },
                child: Text('修改getx：${GlobalController.of.count.value}'),
              );
            }),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  count++;
                });
              },
              child: Text('count: $count'),
            ),
            ElevatedButton(
              onPressed: () {
                context.push(const AnimationTestPage());
              },
              child: const Text('go 动画测试'),
            ),
            ElevatedButton(
              onPressed: () {
                context.go('/root_child');
              },
              child: const Text('go root_go_route'),
            ),
            ElevatedButton(
              onPressed: () {
                context.go('/chat/2/info');
              },
              child: const Text('go /chat/2/info'),
            ),
            ElevatedButton(
              onPressed: () {
                context.go('/chat/2/info/user');
              },
              child: const Text('go /chat/2/info/user'),
            ),
            ElevatedButton(
              onPressed: () {
                context.pushPath('/chat/2/info');
              },
              child: const Text('push /chat/2/info'),
            ),
            ElevatedButton(
              onPressed: () {
                context.pushPath('/root_child');
              },
              child: const Text('push root_go_route'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('${RoutePath.root}/theme');
        },
        child: const Icon(Icons.color_lens),
      ),
    );
  }
}
