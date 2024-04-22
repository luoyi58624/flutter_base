import 'package:flutter/cupertino.dart';
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
      child: SafeArea(
        child: Center(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  context.go(Uri(path: '/component/child', queryParameters: {'title': '组件 - 子页面'}).toString());
                },
                child: const Text('子页面-声明式'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.push(const ComponentChildPage());
                },
                child: const Text('子页面-命令式'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ComponentChildPage extends StatelessWidget {
  const ComponentChildPage({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title ?? '子页面'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            children: [
              CupertinoButton.filled(
                onPressed: () {
                  context.pop();
                },
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
