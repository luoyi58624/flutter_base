import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 限制可选日期区间，选择后显示日期。
class Example1 extends HookWidget {
  /// 创建单日选择示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final value = useState<DateTime?>(DateTime(2026, 11, 5));
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElCalendar<DateTime?>(modelValue: value, min: DateTime(2026, 1, 1), max: DateTime(2027, 12, 31)),
        Text('当前日期：${value.value?.toIso8601String().split('T').first ?? '未选择'}'),
      ],
    );
  }
}
