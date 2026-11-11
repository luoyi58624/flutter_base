import 'package:flutter/widgets.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/drag.dart';
import 'examples/keyboard.dart';
import 'examples/hover.dart';
import 'examples/mouse.dart';
import 'examples/pointer.dart';
import 'examples/press.dart';
import 'examples/rotation.dart';
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
    sections: [
      DocsSection(title: '原始指针', source: '$_examples/pointer.dart', child: ElPointerEventExample()),
      DocsSection(title: '按压', source: '$_examples/press.dart', child: ElPressEventExample()),
      DocsSection(title: '悬停', source: '$_examples/hover.dart', child: ElHoverEventExample()),
      DocsSection(title: '连击', source: '$_examples/tap.dart', child: ElTapEventExample()),
      DocsSection(title: '拖拽', source: '$_examples/drag.dart', child: ElDragEventExample()),
      DocsSection(title: '缩放', source: '$_examples/scale.dart', child: ElScaleEventExample()),
      DocsSection(title: '旋转', source: '$_examples/rotation.dart', child: ElRotationEventExample()),
      DocsSection(title: '鼠标按键', source: '$_examples/mouse.dart', child: ElMouseEventExample()),
      DocsSection(title: '滚轮与触控板', source: '$_examples/scroll.dart', child: ElScrollEventExample()),
      DocsSection(title: '键盘与焦点', source: '$_examples/keyboard.dart', child: ElKeyboardEventExample()),
    ],
  );
}
