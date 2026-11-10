import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

class NestScrollPage extends StatelessWidget {
  const NestScrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('嵌套滚动示例')),
      body: ElScroll(
        slivers: [
          ElSliverList(children: [...List.generate(50, (i) => ElView(child: 'Item - ${i + 1}'))]),
          SliverToBoxAdapter(
            child: ElView(
              style: .new(
                height: 300,
                backgroundColor: Colors.grey
              ),
              child: ElScroll(
                slivers: [
                  ElSliverList(children: [...List.generate(50, (i) => ElView(child: 'Item - ${i + 1}'))]),
                ],
              ),
            ),
          ),
          ElSliverList(children: [...List.generate(50, (i) => ElView(child: 'Item - ${i + 1}'))]),
        ],
      ),
    );
  }
}
