import 'package:flutter_base/src/ui/cores/scroll/common/viewport/scroll_viewport.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 取某个滚动视口对应的 widget 层滚动条 thumb 矩形(**视口本地坐标**,与
/// 旧 render 集成条 debugThumbRect 同口径,便于 `render.localToGlobal` 续用)。
///
/// 沿 thumb 的 Render parent 链找到真实滚动视口，按 position 身份关联，
/// 嵌套多滚动视图场景不会串条。无条(内容未溢出/轴不滚动)返回 null。
Rect? elThumbRect(WidgetTester tester, ScrollViewport render) {
  final position = render.position;
  for (final axis in const ['vertical', 'horizontal']) {
    for (final element in find.byKey(ValueKey<String>('el-scrollbar-thumb-$axis')).evaluate()) {
      final thumbRender = element.renderObject;
      if (thumbRender is! RenderBox || !thumbRender.attached || !thumbRender.hasSize) continue;
      RenderObject? ancestor = thumbRender.parent;
      while (ancestor != null && ancestor is! ScrollViewport) {
        ancestor = ancestor.parent;
      }
      if (ancestor is! ScrollViewport || !identical(ancestor.position, position)) continue;
      return render.globalToLocal(thumbRender.localToGlobal(Offset.zero)) & thumbRender.size;
    }
  }
  return null;
}
