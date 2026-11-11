import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/drag.dart';
import 'examples/keyboard.dart';
import 'examples/mouse.dart';
import 'examples/pointer.dart';
import 'examples/scale.dart';
import 'examples/scroll.dart';
import 'examples/tap.dart';

/// 展示 ElEvent 各类事件的基础用法。
class ElEventBasicPage extends StatelessWidget {
  /// 创建事件基础用法文档页。
  // ignore: prefer_const_constructors_in_immutables
  ElEventBasicPage({super.key});

  static final _examples = 'lib/src/pages/components/event/basic/examples';

  @override
  Widget build(BuildContext context) => DocsPage(
    title: '基础使用',
    description: '在 ElView 的 event 参数中绑定 ElEvent，操作色块后，中间会显示最近触发的回调名称。',
    sections: [
      DocsSection(
        title: '指针与悬停',
        description: '在第一个色块按下、移动或松开指针。将鼠标移入、移出第二个色块可观察悬停回调。',
        source: '$_examples/pointer.dart',
        child: ElPointerEventExample(),
      ),
      DocsSection(
        title: '点击、连击与长按',
        description: '在第一个色块轻点或连击，按下后移出再松开可观察点击取消。启用 deferTap 后，单击会等连击窗口结束。按住第二个色块约半秒可触发长按。',
        source: '$_examples/tap.dart',
        child: ElTapEventExample(),
      ),
      DocsSection(
        title: '鼠标按钮',
        description: '使用鼠标右键、中键（按下滚轮）或前进、后退侧键点击色块。侧键需要鼠标和平台提供对应输入。',
        source: '$_examples/mouse.dart',
        child: ElMouseEventExample(),
      ),
      DocsSection(
        title: '自由与轴向拖拽',
        description: '在第一个色块任意方向拖动，在第二个色块尝试横向或纵向起拖。两个色块各自绑定一组拖拽回调。',
        source: '$_examples/drag.dart',
        child: ElDragEventExample(),
      ),
      DocsSection(
        title: '缩放与旋转',
        description: '在色块上用双指捏合、张开或旋转，观察缩放与旋转回调。',
        source: '$_examples/scale.dart',
        child: ElScaleEventExample(),
      ),
      DocsSection(
        title: '滚轮与触控板',
        description: '在色块上滚动鼠标滚轮，或用触控板双指平移、捏合。不同平台可能将触控板滚动报告为指针信号。',
        source: '$_examples/scroll.dart',
        child: ElScrollEventExample(),
      ),
      DocsSection(
        title: '键盘与焦点',
        description: '点击色块或按 Tab 聚焦，再按下、长按或松开键盘按键。按 Tab 移走焦点可观察失焦。',
        source: '$_examples/keyboard.dart',
        child: ElKeyboardEventExample(),
      ),
    ],
  );
}
