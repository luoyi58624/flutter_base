import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 可选择头像占位并调整正文行数。
class Example2 extends HookWidget {
  /// 创建头像与行数示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 20,
      children: [ElSkeleton(avatar: true, rows: 2), ElSkeleton(rows: 5)],
    );
  }
}
