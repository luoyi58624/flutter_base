import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Tooltip 文字提示的交互文档。
class TooltipPage extends StatelessWidget {
  /// 创建 Tooltip 文字提示文档页。
  TooltipPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).tooltip == null) return ExamplePage(title: 'Tooltip 文字提示');
    return DocsPage(
      title: 'Tooltip 文字提示',
      description: '包裹目标并在周围显示简短说明：桌面端悬停 waitDuration 后显示，移动端点击或长按显示并在 showDuration 后自动关闭；放不下时自动翻转并钳进视口。',
      sections: [
        DocsSection(
          title: '十二种方位',
          description: 'placement 由主轴四边与起止对齐组合；首选侧放不下时翻到对侧，交叉轴越界时起止对调，箭头始终指向目标中心。',
          source: 'lib/src/pages/components/feedback/tooltip/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '内容与行为',
          description: 'content 可以是任意 Widget；waitDuration 控制悬停延迟，arrow 控制箭头，disabled 停用提示。',
          source: 'lib/src/pages/components/feedback/tooltip/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
