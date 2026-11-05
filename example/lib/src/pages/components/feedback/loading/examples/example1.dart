import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// size 指定指示图形的逻辑边长。
class Example1 extends HookWidget {
  /// 创建不同尺寸示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: .center,
      children: [
        for (final size in [16.0, 24.0, 36.0]) ElLoadingIndicator(size: size),
      ],
    );
  }
}
