import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ComponentPage extends StatelessWidget {
  const ComponentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('组件'),
      ),
      child:  SafeArea(
        child: Center(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  context.go('/component2');
                },
                child: const Text('Component2'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.go(Uri(path: '/component/child', queryParameters: {'title': '组件 - 子页面'}).toString());
                },
                child: const Text('子页面'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ComponentPage2 extends StatelessWidget {
  const ComponentPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('组件2'),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                context.go(Uri(path: '/component/child', queryParameters: {'title': '组件 - 子页面'}).toString());
              },
              child: const Text('子页面'),
            )
          ],
        ),
      ),
    );
  }
}
