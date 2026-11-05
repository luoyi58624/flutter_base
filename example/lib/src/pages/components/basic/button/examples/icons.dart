import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 展示前置图标、方形图标按钮和圆形图标按钮。
class ButtonIconsExample extends StatelessWidget {
  const ButtonIconsExample({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: .center,
    children: [
      ElButton(type: .primary, icon: Icons.add, onPressed: () {}, child: '新建'),
      ElButton(variant: .outline, semanticLabel: '搜索', onPressed: () {}, child: Icons.search),
      ElButton(
        type: .primary,
        semanticLabel: '收藏',
        style: ElStyle(borderRadius: .circular(999)),
        onPressed: () {},
        child: Icons.favorite_border,
      ),
    ],
  );
}
