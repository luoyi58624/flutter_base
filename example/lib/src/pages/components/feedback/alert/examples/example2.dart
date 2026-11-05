import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 显示状态由模型持有，关闭后可通过按钮恢复。
class Example2 extends HookWidget {
  /// 创建关闭与恢复示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final visible = useState(true);
    final closed = useState(0);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElAlert(
          modelValue: visible,
          title: '可关闭提示',
          description: '点击关闭会同步外部模型。',
          closable: true,
          onClose: () => closed.value++,
        ),
        ElButton(onPressed: () => visible.value = true, child: '恢复提示'),
        Text('已关闭 ${closed.value} 次'),
      ],
    );
  }
}
