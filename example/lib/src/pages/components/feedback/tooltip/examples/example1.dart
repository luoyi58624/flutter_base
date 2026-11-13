import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// placement 由主轴四边与起止对齐组合；首选侧放不下时翻到对侧，交叉轴越界时起止对调，箭头始终指向目标中心。
class Example1 extends StatelessWidget {
  /// 创建十二种方位示例。
  Example1({super.key});

  Widget _tip(ElPlacement placement) =>
      ElTooltip(placement: placement, content: '${placement.name} 方位的提示', child: ElButton(child: placement.name));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: 12,
      children: [
        for (final group in [
          [ElPlacement.topStart, ElPlacement.top, ElPlacement.topEnd],
          [ElPlacement.bottomStart, ElPlacement.bottom, ElPlacement.bottomEnd],
          [ElPlacement.leftStart, ElPlacement.left, ElPlacement.leftEnd],
          [ElPlacement.rightStart, ElPlacement.right, ElPlacement.rightEnd],
        ])
          Wrap(spacing: 12, runSpacing: 12, children: [for (final placement in group) _tip(placement)]),
      ],
    );
  }
}
