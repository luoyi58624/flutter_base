import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 内容可为图标或原始 Widget，semanticLabel 提供辅助名称。
class Example2 extends HookWidget {
  /// 创建自定义内容示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        ElAvatar(semanticLabel: '用户头像', child: Icons.person),
        ElAvatar(
          shape: .square,
          size: 56,
          semanticLabel: '宠物头像',
          child: Icon(Icons.pets, color: Colors.teal),
        ),
      ],
    );
  }
}
