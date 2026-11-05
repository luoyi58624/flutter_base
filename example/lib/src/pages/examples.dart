import 'package:flutter/material.dart';

import 'example_page.dart';

/// 现有示例一级页，两端使用同一个页面声明。
class ExamplesPage extends StatelessWidget {
  /// 创建示例一级页。
  const ExamplesPage({super.key});

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '示例',
    child: Center(child: Text('示例')),
  );
}
