import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 使用可空单值模型切换视图，再次点击选中项可以清空。
class Example3 extends HookWidget {
  /// 创建单选按钮组示例。
  Example3({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = useState<String?>('网格');
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElButtonGroup<String?>.single(
          modelValue: layout,
          type: .primary,
          children: [
            for (final label in ['网格', '列表', '详情']) ElButtonGroupItem(value: label, child: label),
          ],
        ),
        Text('当前视图：${layout.value ?? '未选择'}'),
      ],
    );
  }
}
