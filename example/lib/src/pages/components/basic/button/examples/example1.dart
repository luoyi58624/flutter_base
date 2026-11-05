import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 以相同的主题色顺序对照五种按钮外观。
class Example1 extends StatelessWidget {
  const Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final types = [null, ...ElThemeType.types];
    final variants = <(ElButtonVariant, ElStyle?)>[
      (.solid, null),
      (.outline, null),
      (.outline, ElStyle(backgroundColor: Colors.transparent)),
      (.text, null),
      (.text, ElStyle(backgroundColor: context.elTheme.fill)),
    ];

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 8,
      children: [
        for (final (variant, style) in variants)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in types)
                ElButton(type: type, variant: variant, style: style, onPressed: () {}, child: 'Hello'),
            ],
          ),
      ],
    );
  }
}
