import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 设置标签上限并折叠较多条目，开关控制禁用。
class Example2 extends HookWidget {
  /// 创建折叠与数量限制示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final tags = useState<List<String>>(['开发', '设计', '测试']);
    final disabled = useState(false);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSwitch(modelValue: disabled, semanticLabel: '禁用标签输入'),
        ElInputTag(
          modelValue: tags,
          max: 4,
          collapseTags: true,
          maxCollapseTags: 1,
          disabled: disabled.value,
          style: ElStyle(width: '100%'),
        ),
        Text('标签数量：${tags.value.length} / 4'),
      ],
    );
  }
}
