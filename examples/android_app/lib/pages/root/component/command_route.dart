import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

class CommandRoutePage extends StatelessWidget {
  const CommandRoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('命令式导航'),
      ),
      body: buildCenterColumn([
        ElevatedButton(
          onPressed: () {
            rootContext.push(const CommandChildPage());
          },
          child: const Text('子页面'),
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

class CommandChildPage extends StatelessWidget {
  const CommandChildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('命令式导航'),
      ),
      body: buildCenterColumn([
        ElevatedButton(
          onPressed: () {
            rootContext.push(const CommandChildPage());
          },
          child: const Text('下一个子页面'),
        ),
        ElevatedButton(
          onPressed: () {
            // rootContext.pushAndRemoveUntil(const CommandRoutePage(), RoutePath.root);
            // rootContext.popUntil(RoutePath.root);
            while (Navigator.of(rootContext).canPop()) {
              Navigator.of(context).pop();
            }
            // context.go(RoutePath.root);
          },
          child: const Text('返回首页'),
        ),
        ElevatedButton(
          onPressed: () {
            rootContext.pop();
          },
          child: const Text('返回'),
        ),
      ]),
    );
  }
}
