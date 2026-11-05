import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 范围模型使用 `List<DateTime>`；Material 替代通过官方范围对话框选择。
class Example2 extends HookWidget {
  /// 创建日期范围示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final range = useState<List<DateTime>>([]);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElCalendar<List<DateTime>>.range(modelValue: range, min: DateTime(2026, 1, 1), max: DateTime(2027, 12, 31)),
        Text('已选日期数：${range.value.length}'),
      ],
    );
  }
}
