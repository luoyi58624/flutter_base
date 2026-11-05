import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 按 size 和 shape 展示文字头像。
class Example1 extends HookWidget {
  /// 创建尺寸与形状示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: .center,
      children: [
        ElAvatar(size: 32, alt: '小头像', child: 'A'),
        ElAvatar(size: 48, alt: '中头像', child: 'B'),
        ElAvatar(size: 64, shape: .square, alt: '方形头像', child: 'C'),
      ],
    );
  }
}
