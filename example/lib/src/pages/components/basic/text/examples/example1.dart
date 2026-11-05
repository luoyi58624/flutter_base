import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 使用 Flutter TextStyle 设置字号、字重和颜色。
class Example1 extends HookWidget {
  /// 创建文字排版示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 8,
      children: [
        Text('标题文字', style: Theme.of(context).textTheme.titleLarge),
        Text('正文内容，跟随应用主题。'),
        Text('次要说明', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
