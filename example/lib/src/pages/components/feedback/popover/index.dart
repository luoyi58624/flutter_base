import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';
import 'examples/example3.dart';

/// Popover 弹出框的交互文档。
class PopoverPage extends StatelessWidget {
  /// 创建 Popover 弹出框文档页。
  PopoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).popover == null) return ExamplePage(title: 'Popover 弹出框');
    return DocsPage(
      title: 'Popover 弹出框',
      description: '包裹任意目标，在周围弹出可包含交互内容的卡片；支持点击、悬停、焦点与右键触发，滚动和窗口变化时实时跟随目标重新选择方位。',
      sections: [
        DocsSection(
          title: '触发方式',
          description: 'trigger 可组合 click、hover、focus 与 contextMenu；悬停延迟由 hoverIntent 控制，斜向移入卡片途中不会关闭。',
          source: 'lib/src/pages/components/feedback/popover/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '交互内容与控制器',
          description: '卡片里可以放按钮、输入框等交互组件；ElPopupController 在内容中主动关闭，onOpenChanged 回调开闭状态。',
          source: 'lib/src/pages/components/feedback/popover/examples/example2.dart',
          child: Example2(),
        ),
        DocsSection(
          title: '滚动与边界',
          description: '打开后滚动列表，卡片在同一帧跟随目标；首选侧放不下时翻到另一侧，目标滚出列表可见区域后暂时隐藏，滚回后恢复。',
          source: 'lib/src/pages/components/feedback/popover/examples/example3.dart',
          child: Example3(),
        ),
      ],
    );
  }
}
