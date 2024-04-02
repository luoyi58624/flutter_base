import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            router.push(const ChildPage(title: '子页面'));
          },
          child: const Text('hello'),
        ),
      ),
    );
  }
}
