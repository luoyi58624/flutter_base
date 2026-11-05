import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 将相关操作排列在同一个按钮组中，并反馈最后一次操作。
class Example1 extends HookWidget {
  /// 创建普通按钮组示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final action = useState('尚未操作');
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElButtonGroup(
          children: [
            for (final label in ['上一页', '下一页']) ElButtonGroupItem(child: label, onPressed: () => action.value = label),
          ],
        ),
        Text('最近操作：${action.value}'),
      ],
    );
  }
}
