import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 限制行数并省略长文本，或通过 TextSpan 组合不同样式。
class Example2 extends HookWidget {
  /// 创建长文本与混排示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        Text('这是一段较长的内容，用于展示可用宽度不足时的单行省略效果。', maxLines: 1, overflow: .ellipsis),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '普通文字 '),
              TextSpan(
                text: '强调内容',
                style: TextStyle(fontWeight: .bold, color: Colors.teal),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
