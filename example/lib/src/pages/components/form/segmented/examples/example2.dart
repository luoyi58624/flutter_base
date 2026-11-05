import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 选项内容可使用图标，单项与整组均可禁用。
class Example2 extends HookWidget {
  /// 创建图标与禁用示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSegmented<int>(
          value: 0,
          options: [
            ElSegmentedOption(value: 0, label: Icon(Icons.grid_view)),
            ElSegmentedOption(value: 1, label: Icon(Icons.list)),
            ElSegmentedOption(value: 2, label: Icon(Icons.lock), disabled: true),
          ],
        ),
        ElSegmented<String>(
          value: '周',
          disabled: true,
          options: [
            ElSegmentedOption(value: '日'),
            ElSegmentedOption(value: '周'),
          ],
        ),
      ],
    );
  }
}
