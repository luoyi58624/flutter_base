import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 取 [position] 对应桌面滚动条 thumb 的全局矩形；无条时返回 null。
///
/// 沿 thumb 的 Element 祖先找到所属 Scrollable，按 position 身份关联，嵌套多滚动视图时不会串条。
Rect? elThumbRect(WidgetTester tester, ScrollPosition position) {
  for (final axis in const ['vertical', 'horizontal']) {
    for (final element in find.byKey(ValueKey<String>('el-scrollbar-thumb-$axis')).evaluate()) {
      final thumbRender = element.renderObject;
      if (thumbRender is! RenderBox || !thumbRender.attached || !thumbRender.hasSize) continue;
      var owned = false;
      element.visitAncestorElements((ancestor) {
        if (ancestor is StatefulElement && ancestor.state is ScrollableState) {
          owned = identical((ancestor.state as ScrollableState).position, position);
          return false;
        }
        return true;
      });
      if (owned) return thumbRender.localToGlobal(Offset.zero) & thumbRender.size;
    }
  }
  return null;
}
