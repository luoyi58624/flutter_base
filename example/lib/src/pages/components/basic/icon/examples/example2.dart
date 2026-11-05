import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 父级样式统一设置图标通道，局部图标可单独覆写。
class Example2 extends HookWidget {
  /// 创建样式继承示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ElStyle(iconSize: 30, iconColor: Colors.teal),
      child: Wrap(
        spacing: 16,
        children: [
          ElIcon(Icons.home),
          ElIcon(Icons.settings),
          ElIcon(Icons.star, color: Colors.orange),
        ],
      ),
    );
  }
}
