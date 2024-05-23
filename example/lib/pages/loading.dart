import 'package:flutter/material.dart';
import 'package:example/global.dart';

class LoadingPage extends HookWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Loading测试'),
        ),
        body: ColumnWidget(children: [
          ElevatedButton(
            onPressed: () async {
              LoadingUtil.show('加载中');
              await 3.delay();
              LoadingUtil.close();
            },
            child: const Text('显示loading'),
          ),
          ElevatedButton(
            onPressed: () async {
              LoadingUtil.show('加载中');
              await 0.5.delay();
              LoadingUtil.show('哈喽哈喽');
              await 1.delay();
              LoadingUtil.show('你好呀');
              await 1.delay();
              LoadingUtil.close();
            },
            child: const Text('显示多个loading'),
          ),
          ElevatedButton(
            onPressed: () async {
              LoadingUtil.show('加载中', delayClose: 1000);
              LoadingUtil.close();
            },
            child: const Text('延迟关闭loading'),
          ),
        ]));
  }
}
