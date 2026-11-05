import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 用一个开关统一切换各种按钮的禁用状态。
class Example3 extends HookWidget {
  const Example3({super.key});

  @override
  Widget build(BuildContext context) {
    final disabled = useState(true);
    final types = [null, ...ElThemeType.types];
    final variants = <ElButtonVariant>[.solid, .outline, .text, .link];

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 8,
      children: [
        ElSwitch(semanticLabel: '禁用示例按钮', value: disabled.value, onChanged: (value) => disabled.value = value),
        for (final variant in variants)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in types)
                ElButton(type: type, variant: variant, disabled: disabled.value, onPressed: () {}, child: 'Hello'),
            ],
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in types)
              ElButton(
                type: type,
                disabled: disabled.value,
                semanticLabel: '亮度',
                style: ElStyle(borderRadius: .circular(999)),
                onPressed: () {},
                child: Icons.light_mode,
              ),
          ],
        ),
      ],
    );
  }
}
