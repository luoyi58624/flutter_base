import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 纵向分割线由外层提供有界高度。
class Example2 extends HookWidget {
  /// 创建纵向分割示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(mainAxisSize: .min, children: [Text('左侧'), ElDivider(vertical: true), Text('右侧')]),
    );
  }
}
