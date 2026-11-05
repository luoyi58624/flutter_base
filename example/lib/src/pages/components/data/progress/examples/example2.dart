import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 圆环和条形都可传入读数构建器；省略 value 为不确定进度。
class Example2 extends HookWidget {
  /// 创建圆环与自定义读数示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 16,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            ElProgress.circle(value: 65),
            ElProgress.circle(value: 100, status: .success),
          ],
        ),
        ElProgress(
          value: 4,
          max: 10,
          textBuilder: (context, value) => Text('已完成 ${value.value?.round()} / ${value.max.round()}'),
        ),
        ElProgress(showText: false),
      ],
    );
  }
}
