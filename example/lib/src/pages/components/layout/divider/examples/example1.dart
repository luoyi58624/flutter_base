import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// child 提供中间内容，thickness 和 color 控制线段。
class Example1 extends HookWidget {
  /// 创建水平分割与文字示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        ElDivider(),
        ElDivider(child: '分组标题'),
        ElDivider(thickness: 2, color: Colors.teal, child: '自定义颜色'),
      ],
    );
  }
}
