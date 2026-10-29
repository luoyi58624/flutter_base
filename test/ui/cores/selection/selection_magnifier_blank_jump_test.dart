// 移动端拖拽经过空白处时放大镜焦点跳到最上方的回归测试。
//
// 问题：长按选中下方段落后，手指向上移到段落间空白处，放大镜焦点（跟随
// _focus 端点）没有停留在原段落，而是被空白解析吸到了最上方段落，导致
// 放大镜内容跳到最上面。

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

RenderSelectionView _selectionRender(WidgetTester tester) {
  return tester.allRenderObjects.whereType<RenderSelectionView>().first;
}

void main() {
  group('移动端放大镜空白处跳跃', () {
    testWidgets('向上拖到段落间空白处，放大镜焦点不应跳到最上方段落', (tester) async {
      final controller = ElSelectionController();
      const topText = 'top paragraph text';
      const midText = 'middle paragraph text';
      const bottomText = 'bottom paragraph text';

      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElView(key: Key('top'), child: topText),
                SizedBox(height: 80),
                ElView(key: Key('mid'), child: midText),
                SizedBox(height: 80),
                ElView(key: Key('bottom'), child: bottomText),
              ],
            ),
          ),
        ),
      );

      // 在 bottom 段落中心长按选词。
      final pressPos = tester.getCenter(find.byKey(const Key('bottom')));
      final gesture = await tester.startGesture(pressPos, kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 450));

      expect(controller.text, isNotNull, reason: '前置：长按应选中词');
      final selectedWord = controller.text ?? '';
      expect(selectedWord, isNotEmpty);
      expect(bottomText.contains(selectedWord), isTrue, reason: '选中的词应来自 bottom 段落');

      final initialFocus = _selectionRender(tester).magnifierLineGeometryForDrag();
      expect(initialFocus, isNotNull);
      final initialLineTop = initialFocus!.line.lineTop;
      debugPrint('selectedWord=$selectedWord initialLineTop=$initialLineTop');

      // 向上移动到 top 和 mid 段落之间的空白处。
      final topRect = tester.getRect(find.byKey(const Key('top')));
      final midRect = tester.getRect(find.byKey(const Key('mid')));
      final blankY = topRect.bottom + 40;
      final blankX = pressPos.dx;
      debugPrint('topRect=$topRect midRect=$midRect blankY=$blankY');
      await gesture.moveTo(Offset(blankX, blankY));
      await tester.pump();

      final afterMoveFocus = _selectionRender(tester).magnifierLineGeometryForDrag();
      final afterMoveSelection = controller.text ?? '';
      debugPrint('afterMoveSelection=$afterMoveSelection afterMoveLineTop=${afterMoveFocus?.line.lineTop}');

      // 修复后：放大镜焦点应保持在原段落附近，不应跳到最上方段落。
      expect(afterMoveFocus, isNotNull);
      expect(
        (afterMoveFocus!.line.lineTop - initialLineTop).abs(),
        lessThanOrEqualTo(10.0),
        reason: '手指在 top/mid 之间空白处时，放大镜焦点不应跳到最上方段落',
      );

      await gesture.up();
      await tester.pump();
    });

    testWidgets('拖动 end handle 向上到段落间空白处，放大镜焦点不应跳到最上方段落', (tester) async {
      final controller = ElSelectionController();
      const topText = 'top paragraph text';
      const midText = 'middle paragraph text';
      const bottomText = 'bottom paragraph text';

      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElView(key: Key('top'), child: topText),
                SizedBox(height: 80),
                ElView(key: Key('mid'), child: midText),
                SizedBox(height: 80),
                ElView(key: Key('bottom'), child: bottomText),
              ],
            ),
          ),
        ),
      );

      // 在 bottom 段落中心长按选词后，直接开始拖动 end handle（不抬手，
      // 避免移动档选区在 tap up 时被清空）。
      final pressPos = tester.getCenter(find.byKey(const Key('bottom')));
      final gesture = await tester.startGesture(pressPos, kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 450));

      expect(controller.text, isNotNull, reason: '前置：长按应选中词');
      final selectedWord = controller.text ?? '';
      expect(selectedWord, isNotEmpty);

      final render = _selectionRender(tester);
      final initialFocus = render.magnifierLineGeometryForDrag();
      expect(initialFocus, isNotNull);
      final initialLineTop = initialFocus!.line.lineTop;
      debugPrint('handle selectedWord=$selectedWord initialLineTop=$initialLineTop');

      // 拖动 end handle 向上到 top/mid 之间的空白处。
      final topRect = tester.getRect(find.byKey(const Key('top')));
      final blankY = topRect.bottom + 40;
      final blankX = pressPos.dx;
      debugPrint('handle blankY=$blankY');

      render.beginHandleDrag(SelectionHandleSide.end, render.endpoints!.end.globalBottom + const Offset(0, 10));
      // 抬掉 body 手势的 pointer，避免它继续干扰 handle 拖动会话。
      await gesture.up();
      await tester.pump();
      render.updateHandleDrag(Offset(blankX, blankY));
      await tester.pump();

      final afterMoveFocus = render.magnifierLineGeometryForDrag();
      final afterMoveSelection = controller.text ?? '';
      debugPrint('handle afterMoveSelection=$afterMoveSelection afterMoveLineTop=${afterMoveFocus?.line.lineTop}');

      // 修复后：放大镜焦点应保持在原段落附近，不应跳到最上方段落。
      expect(afterMoveFocus, isNotNull);
      expect(
        (afterMoveFocus!.line.lineTop - initialLineTop).abs(),
        lessThanOrEqualTo(10.0),
        reason: '拖动 end handle 到 top/mid 之间空白处时，放大镜焦点不应跳到最上方段落',
      );

      render.endHandleDrag();
      await tester.pump();
    });
  });
}
