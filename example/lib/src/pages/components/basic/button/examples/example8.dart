import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照通栏按钮的填充、描边和圆角。
class Example8 extends StatelessWidget {
  const Example8({super.key});

  @override
  Widget build(BuildContext context) {
    final block = ElStyle(width: '100%');
    final roundedBlock = ElStyle(width: '100%', borderRadius: .circular(999));

    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 8,
      children: [
        ElButton(variant: .outline, style: block, child: 'Hello'),
        ElButton(type: .primary, variant: .outline, style: roundedBlock, child: 'Hello'),
        ElButton(type: .primary, style: block, child: 'Hello'),
        ElButton(type: .primary, style: roundedBlock, child: 'Hello'),
      ],
    );
  }
}
