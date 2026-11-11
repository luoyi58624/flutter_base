import 'package:flutter/widgets.dart';

import '../../doc_page.dart';
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
  Widget build(BuildContext context) => ComponentDocPage(
    title: '基础使用',
    description: '在 ElView 的 event 参数中绑定 ElEvent，操作色块后可在调试控制台查看对应的回调和数据。',
    sections: [
      ComponentDocSection(
        title: '指针与悬停',
        description: '按下并移动可查看原始指针坐标与位移。用鼠标移入、移动或移出色块可触发悬停事件。',
        example: ElPointerEventExample(),
        source: '$_examples/pointer.dart',
      ),
      ComponentDocSection(
        title: '点击、连击与长按',
        description: '轻点、连续点两次或三次，或按住约半秒。按住后移出色块再松开可观察点击取消。启用 deferTap 后，单击会等连击窗口结束。',
        example: ElTapEventExample(),
        source: '$_examples/tap.dart',
      ),
      ComponentDocSection(
        title: '鼠标按钮',
        description: '使用鼠标右键、中键（按下滚轮）或前进、后退侧键点击色块。侧键需要鼠标和平台提供对应输入。',
        example: ElMouseEventExample(),
        source: '$_examples/mouse.dart',
      ),
      ComponentDocSection(
        title: '自由与轴向拖拽',
        description: '在第一个色块任意方向拖动，在第二个色块尝试横向或纵向起拖。两个色块各自绑定一组拖拽回调。',
        example: ElDragEventExample(),
        source: '$_examples/drag.dart',
      ),
      ComponentDocSection(
        title: '缩放与旋转',
        description: '在色块上用双指捏合、张开或旋转。控制台会打印缩放比例和以弧度为单位的旋转角度。',
        example: ElScaleEventExample(),
        source: '$_examples/scale.dart',
      ),
      ComponentDocSection(
        title: '滚轮与触控板',
        description: '在色块上滚动鼠标滚轮，或用触控板双指平移、捏合。不同平台可能将触控板滚动报告为指针信号。',
        example: ElScrollEventExample(),
        source: '$_examples/scroll.dart',
      ),
      ComponentDocSection(
        title: '键盘与焦点',
        description: '点击色块或按 Tab 聚焦，再按下、长按或松开键盘按键。按 Tab 移走焦点可观察失焦。',
        example: ElKeyboardEventExample(),
        source: '$_examples/keyboard.dart',
      ),
    ],
  );
}
