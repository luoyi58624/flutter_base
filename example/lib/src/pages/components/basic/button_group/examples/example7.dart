import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 以图标呈现对齐方式，并为每个条目提供辅助名称。
class Example7 extends HookWidget {
  /// 创建图标按钮组示例。
  Example7({super.key});

  @override
  Widget build(BuildContext context) {
    final alignment = useState(TextAlign.left);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElButtonGroup<TextAlign>.single(
          modelValue: alignment,
          mandatory: true,
          semanticLabel: '文字对齐方式',
          children: [
            ElButtonGroupItem(value: TextAlign.left, child: Icons.format_align_left, semanticLabel: '左对齐'),
            ElButtonGroupItem(value: TextAlign.center, child: Icons.format_align_center, semanticLabel: '居中对齐'),
            ElButtonGroupItem(value: TextAlign.right, child: Icons.format_align_right, semanticLabel: '右对齐'),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: Text('点击图标，调整这段文字的对齐方式。', textAlign: alignment.value),
        ),
      ],
    );
  }
}
