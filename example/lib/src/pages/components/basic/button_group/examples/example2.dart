import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照按钮组的语义配色和自定义背景色。
class Example2 extends StatelessWidget {
  /// 创建按钮组配色示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final type in [null, ...ElThemeType.types])
        ElButtonGroup(
          type: type,
          children: [
            ElButtonGroupItem(child: '上一页', onPressed: () {}),
            ElButtonGroupItem(child: '下一页', onPressed: () {}),
          ],
        ),
      ElButtonGroup(
        bgColor: Colors.teal,
        children: [
          ElButtonGroupItem(child: '上一页', onPressed: () {}),
          ElButtonGroupItem(child: '下一页', onPressed: () {}),
        ],
      ),
    ],
  );
}
