import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// size 和 color 可直接指定图标外观。
class Example1 extends HookWidget {
  /// 创建尺寸与颜色示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: .center,
      children: [
        for (final size in [20.0, 32.0, 48.0])
          ElIcon(Icons.favorite, size: size, color: Colors.red, semanticLabel: '喜欢'),
      ],
    );
  }
}
