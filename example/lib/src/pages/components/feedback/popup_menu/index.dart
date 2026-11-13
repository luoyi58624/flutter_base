import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';
import 'examples/example3.dart';
import 'examples/example4.dart';

/// PopupMenu 弹出菜单的交互文档。
class PopupMenuPage extends StatelessWidget {
  /// 创建 PopupMenu 弹出菜单文档页。
  PopupMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).popupMenu == null) return ExamplePage(title: 'PopupMenu 弹出菜单');
    return DocsPage(
      title: 'PopupMenu 弹出菜单',
      description: '包裹任意目标，点击、悬停或右键时在周围展开菜单；同一个组件覆盖下拉菜单、安卓溢出菜单与右键菜单，条目支持图标、勾选、快捷键、禁用和多级子菜单。',
      sections: [
        DocsSection(
          title: '下拉菜单',
          description: '选择条目后整条菜单先关闭再执行 onSelect；placement 决定展开方位，靠近边缘时自动翻转。桌面端打开后可用方向键切换、回车选择、Esc 关闭。',
          source: 'lib/src/pages/components/feedback/popup_menu/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '覆盖目标',
          description: 'cover 为真时菜单从目标所在位置展开并盖住目标，例如标题栏右上角的溢出菜单；下方放不下时改为向上展开。',
          source: 'lib/src/pages/components/feedback/popup_menu/examples/example2.dart',
          child: Example2(),
        ),
        DocsSection(
          title: '右键菜单',
          description: 'trigger 为 contextMenu 时在右键或长按的位置展开；再次右键会移动到新位置。',
          source: 'lib/src/pages/components/feedback/popup_menu/examples/example3.dart',
          child: Example3(),
        ),
        DocsSection(
          title: '多级菜单与悬停',
          description: '带 children 的条目悬停 150 毫秒展开子菜单，斜向移入子菜单途中不收起，桌面端按右键展开、左键收起；悬停触发的菜单按 hoverIntent 延迟打开且不抢焦点。',
          source: 'lib/src/pages/components/feedback/popup_menu/examples/example4.dart',
          child: Example4(),
        ),
      ],
    );
  }
}
