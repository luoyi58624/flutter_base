import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('首页'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  context.push('/root_child');
                },
                child: const Text('根 - 子页面'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.push('/home_child');
                },
                child: const Text('根 - 首页 - 子页面'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.go('/child');
                },
                child: const Text('子页面'),
              ),
              ElevatedButton(
                onPressed: () async {
                  RouterUtil.push(context, ChildPage());
                },
                child: const Text('命令式 - 子页面'),
              ),
              ElevatedButton(
                onPressed: () {
                  ToastUtil.showToast('hello');
                },
                child: const Text('toast'),
              ),
              ElevatedButton(
                onPressed: () async {
                  LoadingUtil.show('加载中');
                  await 2.delay();
                  LoadingUtil.close();
                },
                child: const Text('loading'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeChildPage extends StatelessWidget {
  const HomeChildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('首页 - 子页面'),
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
              CupertinoButton.filled(
                onPressed: () {
                  context.go('/util');
                },
                child: const Text('工具页面'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
