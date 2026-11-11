import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

class ElScrollPage extends StatelessWidget {
  const ElScrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ElScroll 测试')),
      body: ElScroll.sliver(
        slivers: [
          ElSliverRefresh(
            onRefresh: () async {
              // await 200.ms.delay();
            },
          ),
          ElSliverList(
            stretch: true,
            children: [...List.generate(100, (index) => ElView(child: 'Item - ${index + 1}'))],
          ),
        ],
      ),
    );
  }
}
