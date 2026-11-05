import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照横向通栏、份额分配与有界高度下的纵向布局。
class Example8 extends StatelessWidget {
  /// 创建按钮组布局示例。
  Example8({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    mainAxisSize: .min,
    spacing: 12,
    children: [
      ElButtonGroup.single(
        value: 0,
        block: true,
        children: [
          ElButtonGroupItem(child: '左'),
          ElButtonGroupItem(child: '中'),
          ElButtonGroupItem(child: '右'),
        ],
      ),
      ElButtonGroup.single(
        value: 1,
        block: true,
        type: .primary,
        children: [
          ElButtonGroupItem(child: '返回'),
          ElButtonGroupItem(child: '确认', flex: 2),
        ],
      ),
      Align(
        alignment: .centerLeft,
        child: SizedBox(
          height: 156,
          child: ElButtonGroup.single(
            value: 0,
            axis: .vertical,
            block: true,
            children: [
              ElButtonGroupItem(child: '顶部'),
              ElButtonGroupItem(child: '中部'),
              ElButtonGroupItem(child: '底部'),
            ],
          ),
        ),
      ),
    ],
  );
}
