import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 比较整组禁用和单项禁用，保留已有选择。
class Example6 extends HookWidget {
  /// 创建禁用按钮组示例。
  Example6({super.key});

  @override
  Widget build(BuildContext context) {
    final disabled = useState(true);
    final selected = useState<String?>('编辑');
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSwitch(modelValue: disabled, semanticLabel: '禁用整组'),
        ElButtonGroup<String?>.single(
          modelValue: selected,
          disabled: disabled.value,
          type: .primary,
          children: [
            ElButtonGroupItem(value: '查看', child: '查看'),
            ElButtonGroupItem(value: '编辑', child: '编辑'),
            ElButtonGroupItem(value: '删除', child: '删除', disabled: true),
          ],
        ),
        Text('当前操作：${selected.value ?? '未选择'}'),
      ],
    );
  }
}
