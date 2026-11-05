import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 在各按钮的局部作用域内覆写主色。
class Example2 extends StatelessWidget {
  const Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.teal, Colors.red, Colors.green, Colors.yellow, Colors.orange, Colors.purple];
    final variants = <(ElButtonVariant, ElStyle?)>[
      (.solid, null),
      (.outline, null),
      (.outline, ElStyle(backgroundColor: Colors.transparent)),
      (.text, null),
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
              for (final color in colors)
                ElView(
                  style: ElStyle(vars: {ElTokens.$primary: color}),
                  child: ElButton(type: .primary, variant: variant, style: style, onPressed: () {}, child: 'Hello'),
                ),
            ],
          ),
      ],
    );
  }
}
