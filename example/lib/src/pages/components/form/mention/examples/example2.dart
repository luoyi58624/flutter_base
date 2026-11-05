import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 沿用同一套候选接口，支持多个前缀和只读展示。
class Example2 extends HookWidget {
  /// 创建多个前缀与多行示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElMention<String>(
          prefix: ['@', '#'],
          textarea: true,
          minLine: 2,
          placeholder: '输入 @ 或 #',
          options: [
            ElMentionOption(value: 'flutter', label: 'Flutter'),
            ElMentionOption(value: 'dart', label: 'Dart'),
          ],
        ),
        ElMention<String>(
          value: '@flutter ',
          readOnly: true,
          options: [ElMentionOption(value: 'flutter', label: 'Flutter')],
        ),
      ],
    );
  }
}
