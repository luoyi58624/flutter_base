import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

class NestScrollPage extends StatelessWidget {
  const NestScrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('嵌套滚动示例')),
      body: ElScroll(
        children: [
          ...List.generate(500, (i) => ElView(child: 'Item - ${i + 1}')),
          ElView(
            style: .new(height: 300, backgroundColor: Colors.grey),
            child: ElScroll(children: [...List.generate(50, (i) => ElView(child: 'Item - ${i + 1}'))]),
          ),
          ...List.generate(500, (i) => ElView(child: 'Item - ${i + 1}')),
        ],
      ),
    );
  }
}
