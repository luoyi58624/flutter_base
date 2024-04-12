import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

class CustomPageRouterPage extends StatefulWidget {
  const CustomPageRouterPage({super.key});

  @override
  State<CustomPageRouterPage> createState() => _CustomPageRouterPageState();
}

class _CustomPageRouterPageState extends State<CustomPageRouterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义路由动画'),
      ),
      body: Center(
        child: Column(
          children: [
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
                RouterUtil.push(context, const _ChildPage(), rootNavigator: true);
              },
              child: const Text('子页面'),
            ),
            ElevatedButton(
              onPressed: () {
                RouterUtil.pop(context);
              },
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildPage extends StatefulWidget {
  const _ChildPage({super.key});

  @override
  State<_ChildPage> createState() => _ChildPageState();
}

class _ChildPageState extends State<_ChildPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('子页面'),
      ),
      body: Container(),
    );
  }
}
