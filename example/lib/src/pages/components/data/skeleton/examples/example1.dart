import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 开关控制 loading，标题和正文行使用现有骨架实现。
class Example1 extends HookWidget {
  /// 创建加载与正文示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final loading = useState(true);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSwitch(modelValue: loading, semanticLabel: '显示骨架'),
        ElSkeleton(loading: loading.value, rows: 3, child: Text('加载完成后的实际内容。')),
      ],
    );
  }
}
