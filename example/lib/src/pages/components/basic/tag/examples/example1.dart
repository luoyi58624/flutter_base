import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照所有语义色和三种标签外观。
class Example1 extends HookWidget {
  /// 创建配色与外观示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 10,
      children: [
        for (final effect in ElTagEffect.values)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in ElThemeType.types)
                ElTag(type: type, effect: effect, round: effect == .dark, child: '标签'),
            ],
          ),
      ],
    );
  }
}
