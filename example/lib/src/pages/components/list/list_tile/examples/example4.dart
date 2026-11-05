import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';

/// 统一切换普通行、开关行和菜单行的禁用状态。
class Example4 extends HookWidget {
  /// 创建禁用状态示例。
  Example4({super.key});

  @override
  Widget build(BuildContext context) {
    final disabled = useState(true);
    final count = useState(0);
    final enabled = useState(false);
    final density = useState('standard');

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: .center,
          children: [
            ElSwitch(modelValue: disabled, semanticLabel: '禁用列表示例'),
            Text('禁用全部列表行'),
          ],
        ),
        ElListGroup(
          children: [
            ElListTile(title: '禁用点击', disabled: disabled.value, onTap: () => count.value++),
            ElListTile<bool>.switcher(title: '禁用开关', disabled: disabled.value, modelValue: enabled),
            ElListTile<String>.popup(
              title: '禁用菜单',
              disabled: disabled.value,
              modelValue: density,
              options: [ElLabelModel('标准', 'standard'), ElLabelModel('紧凑', 'compact')],
            ),
          ],
        ),
        Text('已点击 ${count.value} 次'),
        Text(enabled.value ? '开关已开启' : '开关已关闭'),
      ],
    );
  }
}
