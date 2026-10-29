import 'package:flutter_base/src/ui/cores/selection/docs/selection_view.dart';
import 'package:flutter_base/src/ui/cores/scroll/scroll_view.dart';
import 'package:flutter_base/src/ui/cores/selection/common/selection_core.dart';

import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElRenderView;
import 'package:flutter_base/src/ui/cores/view/view.dart';
import 'package:flutter_base/src/ui/cores/view/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: .ltr,
      child: Align(alignment: .topLeft, child: child),
    ),
  );
}

RenderSelectionView _selectionRender(WidgetTester tester) {
  return tester.allRenderObjects.whereType<RenderSelectionView>().first;
}

int _selectedTextParticipantCount(WidgetTester tester) {
  return tester.allRenderObjects.whereType<ElRenderView>().where((render) => render.hasTextPayload).where((render) {
    final range = render.currentSelectionRange;
    return range != null && !range.isCollapsed;
  }).length;
}

void main() {
  group('plainText 正确性', () {
    testWidgets('文本内容变化后 selectionTextLength 反映新值', (tester) async {
      const hostKey = ValueKey('selection-text-replacement');
      Widget build(String text) => _app(
        ElSelectionView(
          child: ElView(key: hostKey, child: text),
        ),
      );

      await tester.pumpWidget(build('short'));
      final render = tester.allRenderObjects
          .whereType<ElRenderView>()
          .where((item) => item.hasTextPayload)
          .toSet()
          .single;
      expect(render.selectionTextLength, 'short'.length);

      await tester.pumpWidget(build('a much longer replacement text content'));

      expect(
        render.selectionTextLength,
        'a much longer replacement text content'.length,
        reason: '文本 payload 更新后长度必须立即反映新内容',
      );
    });
  });

  group('participant geometry cache', () {
    testWidgets('handle 稳态拖动保持固定端与有效选区', (tester) async {
      final controller = ElSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const Column(
              crossAxisAlignment: .start,
              children: [
                ElView(child: 'first line of text content'),
                ElView(child: 'second line of text content'),
                ElView(child: 'third line of text content'),
              ],
            ),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      final endEndpoint = render.endpoints!.end;
      render.beginHandleDrag(SelectionHandleSide.end, endEndpoint.globalPosition);
      render.updateHandleDrag(endEndpoint.globalPosition);
      await tester.pump();

      final fixedStart = render.endpoints!.start.globalPosition;
      for (var move = 1; move <= 15; move++) {
        render.updateHandleDrag(endEndpoint.globalPosition - Offset(move * 0.5, 0));
      }
      await tester.pump();

      expect(render.endpoints!.start.globalPosition, fixedStart, reason: '拖动末端不能改变固定起点');
      expect(controller.hasSelection, isTrue);

      render.endHandleDrag();
      await tester.pump();
    });

    testWidgets('viewport 滚动后端点使用新几何', (tester) async {
      final controller = ElSelectionController();
      final scrollController = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 400,
            height: 200,
            child: ElSelectionView(
              controller: controller,
              child: ElScrollView(
                controller: scrollController,
                children: const [
                  ElView(child: 'row 0 selectable text content'),
                  ElView(child: 'row 1 selectable text content'),
                  ElView(child: 'row 2 selectable text content'),
                  ElView(child: 'row 3 selectable text content'),
                  ElView(child: 'row 4 selectable text content'),
                  ElView(child: 'row 5 selectable text content'),
                  ElView(child: 'row 6 selectable text content'),
                  ElView(child: 'row 7 selectable text content'),
                  ElView(child: 'row 8 selectable text content'),
                  ElView(child: 'row 9 selectable text content'),
                ],
              ),
            ),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      final endEndpoint = render.endpoints!.end;
      render.beginHandleDrag(SelectionHandleSide.end, endEndpoint.globalPosition);
      render.updateHandleDrag(endEndpoint.globalPosition);
      await tester.pump();
      final startBefore = render.endpoints!.start.globalPosition;

      scrollController.jumpTo(50);
      await tester.pump();
      render.updateHandleDrag(endEndpoint.globalPosition + const Offset(0, 5));
      await tester.pump();
      render.endHandleDrag();
      await tester.pump();

      expect(
        render.endpoints!.start.globalPosition.dy,
        closeTo(startBefore.dy - 50, 1),
        reason: '滚动失效后端点必须跟随内容上移，不能复用旧几何',
      );
    });

    testWidgets('拖选中滚动持续扩展到新进入视口的文字', (tester) async {
      const tickCount = 8;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 400,
            height: 240,
            child: ElSelectionView(
              child: ElScrollView(
                controller: controller,
                children: [
                  for (var row = 0; row < 40; row++)
                    ElView(
                      key: ValueKey('scroll-contract-row-$row'),
                      style: const ElStyle(height: 24, fontSize: 14),
                      child: '第 $row 行：选区滚动几何缓存正确性文本',
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      final firstRect = tester.getRect(find.byKey(const ValueKey('scroll-contract-row-0')));
      final gesture = await tester.createGesture(kind: .mouse);
      addTearDown(gesture.removePointer);
      await gesture.down(firstRect.topLeft + const Offset(6, 12));
      await gesture.moveTo(const Offset(220, 150));
      await tester.pump();

      final selectedBefore = _selectedTextParticipantCount(tester);
      expect(selectedBefore, greaterThan(0), reason: '测试前提：拖选必须已建立');
      for (var tick = 0; tick < tickCount; tick++) {
        controller.jumpTo(controller.offset + 12);
        await tester.pump();
      }
      expect(_selectedTextParticipantCount(tester), greaterThan(selectedBefore), reason: '滚动同步必须让拖选焦点跟随指针下的新内容');

      await gesture.up();
      await tester.pump();
    });

    testWidgets('连续文本拖选建立选区且不误触自动滚动', semanticsEnabled: false, (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 800,
            height: 600,
            child: ElSelectionView(
              child: ElScrollView(
                controller: controller,
                children: const [
                  ElView(
                    key: ValueKey('continuous-text-contract'),
                    style: ElStyle(fontSize: 14, lineHeight: 1.5),
                    child:
                        '连续大文本拖选需要沿折行稳定解析端点，并且在指针远离视口边缘时保持滚动位置。'
                        '本段重复用于形成足够多的折行。连续大文本拖选需要沿折行稳定解析端点，并且在指针远离视口边缘时保持滚动位置。'
                        '本段重复用于形成足够多的折行。连续大文本拖选需要沿折行稳定解析端点，并且在指针远离视口边缘时保持滚动位置。'
                        '本段重复用于形成足够多的折行。',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final textRect = tester.getRect(find.byKey(const ValueKey('continuous-text-contract')));
      final gesture = await tester.createGesture(kind: .mouse);
      addTearDown(gesture.removePointer);
      await gesture.down(textRect.topLeft + const Offset(30, 12));
      await gesture.moveTo(textRect.topLeft + const Offset(600, 90));
      await tester.pump();

      final textRender = tester.renderObject<ElRenderView>(find.byKey(const ValueKey('continuous-text-contract')));
      expect(textRender.currentSelectionRange, isNotNull);
      expect(textRender.currentSelectionRange!.isCollapsed, isFalse);
      expect(controller.offset, 0, reason: '指针远离边缘时连续文本拖选不应启动自动滚动');

      await gesture.up();
      await tester.pump();
    });
  });
}
