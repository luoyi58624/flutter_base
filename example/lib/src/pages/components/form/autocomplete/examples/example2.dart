import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 这两种状态不允许选择候选。
class Example2 extends HookWidget {
  /// 创建只读与禁用示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElAutocomplete<String>(value: '只读内容', readOnly: true, fetchSuggestions: (_) => []),
        ElAutocomplete<String>(value: '禁用内容', disabled: true, fetchSuggestions: (_) => []),
      ],
    );
  }
}
