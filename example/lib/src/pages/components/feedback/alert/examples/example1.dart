import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照四种提示状态和标题、正文组合。
class Example1 extends HookWidget {
  /// 创建语义状态示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        for (final type in [ElThemeType.info, ElThemeType.success, ElThemeType.warning, ElThemeType.error])
          ElAlert(type: type, title: '状态提示', description: '这是一条提示内容。'),
      ],
    );
  }
}
