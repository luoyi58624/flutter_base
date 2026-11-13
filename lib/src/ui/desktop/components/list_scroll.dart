import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart';

import '../../../flutter/views/scroll/scroll.dart' show ElScrollView;
import '../../../flutter/views/scroll/sliver/list/index.dart' show ElSliverList;

/// 弹层候选列表的滚动区：按内容收缩，并在视口内部提供 list 语义。
///
/// listItem 语义要求直接父节点是 list，而 Scrollable 自身会插入滚动语义节点，
/// 所以 list 角色必须落在 Sliver 层，不能包在滚动容器外面。
Widget buildListScroll({required ScrollController controller, required List<Widget> children}) => ElScrollView.sliver(
  controller: controller,
  shrinkWrap: true,
  slivers: [
    SliverSemantics(
      role: SemanticsRole.list,
      explicitChildNodes: true,
      sliver: ElSliverList(stretch: true, children: children),
    ),
  ],
);
