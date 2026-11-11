import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 通过官方 Painter 的命中区域取得滑块矩形，按控制器关联所属滚动位置。
Rect? elThumbRect(WidgetTester tester, ScrollPosition position) {
  for (final element in find.byType(CustomPaint).evaluate()) {
    final paint = element.widget as CustomPaint;
    final painter = paint.foregroundPainter;
    if (painter is! ScrollbarPainter) continue;
    var owned = false;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is RawScrollbar) {
        final controller = widget.controller ?? PrimaryScrollController.maybeOf(ancestor);
        owned = controller?.positions.any((candidate) => identical(candidate, position)) ?? false;
        return false;
      }
      return true;
    });
    final render = element.renderObject;
    if (!owned || render is! RenderBox || !render.hasSize) continue;
    final vertical = position.axis == Axis.vertical;
    final cross = (vertical ? render.size.width : render.size.height) - painter.crossAxisMargin - painter.thickness / 2;
    double? first;
    double? last;
    final extent = vertical ? render.size.height : render.size.width;
    // 直接查询官方命中区域，避免在测试里复制滑块长度和反向轴算法。
    for (var main = 0.5; main < extent; main += 1) {
      final point = vertical ? Offset(cross, main) : Offset(main, cross);
      if (!painter.hitTestOnlyThumbInteractive(point, PointerDeviceKind.mouse)) continue;
      first ??= main - 0.5;
      last = main + 0.5;
    }
    if (first == null || last == null) continue;
    final local = vertical
        ? Rect.fromLTWH(cross - painter.thickness / 2, first, painter.thickness, last - first)
        : Rect.fromLTWH(first, cross - painter.thickness / 2, last - first, painter.thickness);
    return local.shift(render.localToGlobal(Offset.zero));
  }
  return null;
}
