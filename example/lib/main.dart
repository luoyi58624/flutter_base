import 'package:flutter/material.dart';

import 'animations_page.dart';

void main() {
  runApp(ElAnimationExampleApp());
}

/// 展示 Flutter Base 开关动画的独立示例应用。
class ElAnimationExampleApp extends StatelessWidget {
  /// 创建动画示例应用。
  const ElAnimationExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Base · 开关动画',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xff6658df),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Color(0xfff5f6fa),
        useMaterial3: true,
      ),
      home: ElAnimationExamplesPage(),
    );
  }
}
