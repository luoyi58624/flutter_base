import 'package:flutter/material.dart';

/// 示例页面共用的标题栏与内容区域。
class ExamplePage extends StatelessWidget {
  /// 创建示例页，未提供内容时显示空白区域。
  const ExamplePage({super.key, required this.title, this.child});

  /// 导航栏标题。
  final String title;

  /// 页面正文。
  final Widget? child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: child,
  );
}
