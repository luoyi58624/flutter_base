import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// placement 选择从哪条边缘滑入，默认右侧。
class Example1 extends StatelessWidget {
  /// 创建停靠方向示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (placement, label) in [
          (ElPopupPlacement.left, '左侧'),
          (ElPopupPlacement.right, '右侧'),
          (ElPopupPlacement.top, '顶部'),
          (ElPopupPlacement.bottom, '底部'),
        ])
          ElButton(
            onPressed: () => el.drawer.show(
              context,
              placement: placement,
              title: '$label抽屉',
              child: ElView(child: '从$label边缘滑入，点击遮罩、按 Esc 或关闭按钮收起。'),
            ),
            child: label,
          ),
      ],
    );
  }
}
