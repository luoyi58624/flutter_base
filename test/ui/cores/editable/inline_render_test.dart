import 'dart:ui' as ui;
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _scene(
  ElEditableController controller, {
  double width = 200,
  TextDirection direction = .ltr,
  bool wrap = true,
  ElScrollController? scroll,
  Color color = const Color(0xff000000),
}) => Directionality(
  textDirection: direction,
  child: Align(
    alignment: .topLeft,
    child: ElView(
      style: ElStyle(width: width, height: 100, fontSize: 16, lineHeight: 1.5, color: color),
      child: ElEditableView(
        controller: controller,
        scrollController: scroll,
        style: ElEditableStyle(
          softWrap: wrap,
          retainSelectionOnBlur: true,
          selectionTextColor: Color(0xffffffff),
          selectionColor: Color(0xff2255aa),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('外层全选只复制原始 token，不重复复制组件内部文字', (tester) async {
    final selection = ElSelectionController();
    final controller = ElEditableController(
      text: '前[x]后',
      inlineContent: {'[x]': (_) => ElView(style: ElStyle(width: 48, height: 20, fontSize: 10), child: '内部标签')},
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElSelectionView(controller: selection, child: _scene(controller)),
      ),
    );
    await tester.pumpAndSettle();
    selection.selectAll();
    await tester.pumpAndSettle();
    expect(selection.text, '前[x]后');
    await tester.pumpWidget(ElView());
    controller.dispose();
    selection.dispose();
  });

  testWidgets('文本变更后立即查询几何时使用新占位符数量', (tester) async {
    final controller = ElEditableController(
      text: 'a',
      inlineContent: {'[x]': (_) => ElView(style: ElStyle(width: 22, height: 22))},
    );
    await tester.pumpWidget(_scene(controller));
    await tester.pumpAndSettle();
    for (final text in ['[x]', 'a', '[x][x]', '']) {
      controller.text = text;
      expect(controller.rectAtOffset(controller.length), isNotNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(ElView());
    controller.dispose();
  });

  testWidgets('实测自动宽度参与光标命中、换行和固定行高', (tester) async {
    final controller = ElEditableController(
      text: 'a[wide]b[small]c',
      inlineContent: {
        '[wide]': (_) => ElView(
          key: ValueKey('wide'),
          style: ElStyle(width: 52, height: 80, bgColor: Color(0xffaa0000)),
        ),
        '[small]': (_) => ElView(key: ValueKey('small'), style: ElStyle(width: 10, height: 12)),
      },
    );
    await tester.pumpWidget(RepaintBoundary(key: ValueKey('selected-preview'), child: _scene(controller, width: 90)));
    await tester.pumpAndSettle();
    final line = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView).first);
    final painter = line.layoutedPainter!;
    expect(tester.getSize(find.byKey(ValueKey('wide'))), Size(52, 24));
    expect(tester.getSize(find.byKey(ValueKey('small'))), Size(10, 12));
    expect(line.size.height % 24, closeTo(0, 0.001));
    final boxes = painter.getBoxesForSelection(TextSelection(baseOffset: 1, extentOffset: 7));
    expect(boxes.single.right - boxes.single.left, closeTo(52, .001));
    expect(painter.getPositionForOffset(boxes.single.toRect().centerLeft + Offset(1, 0)).offset, 1);
    expect(painter.getPositionForOffset(boxes.single.toRect().centerRight - Offset(1, 0)).offset, 7);
    controller.selectAll();
    await tester.pumpAndSettle();
    expect(controller.selectedText, 'a[wide]b[small]c');
    final center = tester.getCenter(find.byKey(ValueKey('wide')));
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(ValueKey('selected-preview')));
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final offset = (center.dy.floor() * image.width + center.dx.floor()) * 4;
      expect(
        [bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2)],
        [170, 0, 0],
        reason: '选中文字颜色不得覆盖图片自身的颜色',
      );
      image.dispose();
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(ElView());
    controller.dispose();
  });

  testWidgets('图片异步改变宽度后修正占位，不重新构建兄弟组件', (tester) async {
    final width = ValueNotifier<double>(20);
    var builds = 0;
    final controller = ElEditableController(
      text: '[x][y]',
      inlineContent: {
        '[x]': (_) => ValueListenableBuilder(
          valueListenable: width,
          builder: (_, value, _) => ElView(style: ElStyle(width: value, height: 16)),
        ),
        '[y]': (_) {
          builds++;
          return ElView(style: ElStyle(width: 30, height: 16));
        },
      },
    );
    await tester.pumpWidget(_scene(controller));
    await tester.pumpAndSettle();
    final line = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView).first);
    width.value = 60;
    await tester.pumpAndSettle();
    expect(
      line.layoutedPainter!.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: 3)).single.toRect().width,
      60,
    );
    expect(builds, 1);
    controller.collapseTo(0);
    controller.insertText('a');
    await tester.pumpAndSettle();
    expect(builds, 1);
    await tester.pumpWidget(ElView());
    controller.dispose();
    width.dispose();
  });

  testWidgets('RTL 混排返回原文位置，活动输入法组合显示文字', (tester) async {
    final controller = ElEditableController(
      text: 'אב[x]גד',
      inlineContent: {'[x]': (_) => ElView(key: ValueKey('image'), style: ElStyle(width: 25, height: 20))},
    );
    await tester.pumpWidget(_scene(controller, direction: .rtl));
    await tester.pumpAndSettle();
    final line = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView).first);
    expect(
      line.layoutedPainter!.getBoxesForSelection(TextSelection(baseOffset: 2, extentOffset: 5)).single.toRect().width,
      25,
    );
    controller.testModel.imeUpdateSelection(TextSelection.collapsed(offset: 3), TextRange(start: 2, end: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('image')), findsNothing);
    controller.finishImeComposition();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('image')), findsOneWidget);
    await tester.pumpWidget(ElView());
    controller.dispose();
  });

  testWidgets('一条长换行文本只挂载可见表情，移动光标不重建', (tester) async {
    var builds = 0;
    final scroll = ElScrollController();
    final controller = ElEditableController(
      text: '[x] ' * 3000,
      inlineContent: {
        '[x]': (_) {
          builds++;
          return ElView(key: UniqueKey(), style: ElStyle(width: 20, height: 20));
        },
      },
    );
    await tester.pumpWidget(_scene(controller, scroll: scroll));
    await tester.pumpAndSettle();
    expect(builds, lessThan(150));
    final initialBuilds = builds;
    controller.collapseTo(4);
    await tester.pumpAndSettle();
    expect(builds, initialBuilds);
    final layouts = RenderEditableLine.debugLayoutCount;
    await tester.pumpWidget(_scene(controller, scroll: scroll, color: Color(0xffaa0000)));
    await tester.pumpAndSettle();
    expect(RenderEditableLine.debugLayoutCount, layouts);
    expect(builds, initialBuilds);
    scroll.jumpTo(4000);
    await tester.pumpAndSettle();
    final widgets = find.byType(InlineContentWidget);
    expect(widgets.evaluate().length, inInclusiveRange(1, 150));
    expect(builds - initialBuilds, lessThan(150));
    final visible = widgets.evaluate().map((e) => tester.getRect(find.byElementPredicate((x) => identical(x, e))));
    expect(visible.any((r) => r.overlaps(Rect.fromLTWH(0, 0, 200, 100))), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(ElView());
    controller.dispose();
    scroll.dispose();
  });

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('超长不换行 $direction 保留有界 Paragraph 和完整表情', (tester) async {
      final controller = ElEditableController(
        text: (direction == .rtl ? 'אב[12]גד ' : 'ab[12]cd ') * 9000,
        inlineContent: {'[12]': (_) => ElView(key: ValueKey('long-image'), style: ElStyle(width: 25, height: 20))},
      );
      await tester.pumpWidget(_scene(controller, direction: direction, wrap: false));
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: 30)));
        await tester.pump(Duration(milliseconds: 20));
      }
      final line = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView).first);
      expect(line.windowedForTest, isTrue);
      expect(line.windowPlaceholderForTest, isFalse);
      expect(line.windowTextLengthForTest, lessThanOrEqualTo(65536));
      expect(find.byKey(ValueKey('long-image')), findsAtLeastNWidgets(1));
      expect(find.byKey(ValueKey('long-image')).evaluate().length, lessThan(60));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(ElView());
      controller.dispose();
    });
  }
}
