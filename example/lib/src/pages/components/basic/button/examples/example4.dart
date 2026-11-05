import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照可用与禁用的链接按钮。
class Example4 extends StatelessWidget {
  const Example4({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    mainAxisSize: .min,
    spacing: 8,
    children: [
      for (final disabled in [false, true])
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final type in [null, ...ElThemeType.types])
              ElButton(variant: .link, type: type, disabled: disabled, onPressed: () {}, child: 'Hello'),
          ],
        ),
    ],
  );
}
