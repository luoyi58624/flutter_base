import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 用样式声明按钮的高度、圆角和通栏宽度。
class ButtonSizingExample extends StatelessWidget {
  const ButtonSizingExample({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    mainAxisSize: .min,
    spacing: 12,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: .center,
        children: [
          ElButton(
            variant: .outline,
            style: ElStyle(height: 32, fontSize: 13, padding: .symmetric(horizontal: 12)),
            onPressed: () {},
            child: '小按钮',
          ),
          ElButton(onPressed: () {}, child: '默认按钮'),
          ElButton(
            type: .primary,
            style: ElStyle(height: 56, fontSize: 17, padding: .symmetric(horizontal: 24), borderRadius: .circular(999)),
            onPressed: () {},
            child: '大按钮',
          ),
        ],
      ),
      ElButton(
        type: .primary,
        style: ElStyle(width: '100%'),
        onPressed: () {},
        child: '通栏按钮',
      ),
    ],
  );
}
