import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('首页'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 76),
            sliver: SliverList.list(
              children: [
                ElevatedButton(
                  onPressed: () {
                    context.pushUrl('/root_child');
                  },
                  child: const Text('根 - 子页面'),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.pushUrl('/home_child');
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
                    context.push(const HomeChildPage());
                  },
                  child: const Text('命令式 - 子页面'),
                ),
                ...List.generate(50, (index) => const Text('xxx')),
              ],
            ),
          ),
        ],
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
        previousPageTitle: '首页',
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
