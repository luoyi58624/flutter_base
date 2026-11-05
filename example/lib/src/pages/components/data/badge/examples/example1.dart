import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 徽标可附着在内容上，也可独立显示。
class Example1 extends HookWidget {
  /// 创建数字与圆点示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: .all(12),
      child: Wrap(
        spacing: 32,
        runSpacing: 24,
        crossAxisAlignment: .center,
        children: [
          ElBadge(value: 8, bgColor: Colors.red, child: Icon(Icons.mail_outline, size: 32)),
          ElBadge(value: 120, max: 99, bgColor: Colors.red, child: Icon(Icons.notifications_outlined, size: 32)),
          ElBadge(isDot: true, bgColor: Colors.red, child: Icon(Icons.chat_bubble_outline, size: 32)),
          ElBadge(value: '新', bgColor: Colors.teal),
        ],
      ),
    );
  }
}
