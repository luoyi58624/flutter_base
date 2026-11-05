import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照语义颜色与按钮变体。
class ButtonAppearanceExample extends StatelessWidget {
  const ButtonAppearanceExample({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    mainAxisSize: .min,
    spacing: 12,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElButton(onPressed: () {}, child: '默认'),
          ElButton(type: .primary, onPressed: () {}, child: '主要'),
          ElButton(type: .success, onPressed: () {}, child: '成功'),
          ElButton(type: .info, onPressed: () {}, child: '信息'),
          ElButton(type: .warning, onPressed: () {}, child: '警告'),
          ElButton(type: .error, onPressed: () {}, child: '危险'),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: .center,
        children: [
          ElButton(type: .primary, variant: .solid, onPressed: () {}, child: '实心'),
          ElButton(type: .primary, variant: .outline, onPressed: () {}, child: '描边'),
          ElButton(type: .primary, variant: .text, onPressed: () {}, child: '文字'),
          ElButton(type: .primary, variant: .link, onPressed: () {}, child: '链接'),
        ],
      ),
    ],
  );
}
