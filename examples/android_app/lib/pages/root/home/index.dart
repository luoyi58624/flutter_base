import 'package:android_app/controllers/global.dart';
import 'package:android_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          // Obx(
          //   () => IconButton(
          //     onPressed: () {},
          //     icon: Icon(GlobalController.of.useMaterial3.value ? Icons.material2 : Icons.material2),
          //   ),
          // ),
          Obx(
            () => Switch(
              value: GlobalController.of.useMaterial3.value,
              onChanged: (v) {
                GlobalController.of.useMaterial3.value = v;
              },
            ),
          ),
        ],
      ),
      body: buildCenterColumn([
        ElevatedButton(
          onPressed: () {
            RouterUtil.push(context,const ChildPage(title: '子页面'));
          },
          child: const Text('hello'),
        ),
        ElevatedButton(
          onPressed: () {
            context.push('/root_child');
          },
          child: const Text('根子页面'),
        ),
      ]),
    );
  }
}
