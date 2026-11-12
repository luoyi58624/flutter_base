// 移动端拖拽跟随点稳定性回归测试。
//
// 问题：在可滚动容器中，长按选词后手指向下拖拽到 viewport 底部触发自动滚动，
// 再把手指移回 viewport 中间（非边缘）时，选区本应随手指位置同步收缩到当前
// 词，但当前实现会保留一个从原 anchor 到当前 focus 的超大跨度选区，导致
// 放大镜焦点 / 复制内容异常偏移。本测试复现这一现象。

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

/// 在当前位置驻留 [frames] 帧。
Future<void> _pumpFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('移动端拖拽跟随点稳定性', () {
    testWidgets('非滚动场景：长按后拖到内容区域外再回到原位，选区保持不变', (tester) async {
      final controller = ElSelectionController();
      const textKey = ValueKey<String>('mobile-drag-follow-text');
      const text = 'alpha beta gamma delta';

      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(key: textKey, child: text),
          ),
        ),
      );

      final participant = tester.allRenderObjects
          .whereType<ElRenderView>()
          .where((r) => (r.content is TextEngine))
          .first;
      Offset caretQueryPos(int offset) {
        final line = selectionParticipantOf(participant)!.selectionLineGeometryAt(offset)!;
        final caret = selectionParticipantOf(participant)!.selectionCaretGeometryAt(offset)!;
        return participant.localToGlobal(Offset(caret.position.dx + 1, line.lineTop + line.lineHeight / 2));
      }

      // 长按 'beta' 内部选词（触摸 400ms）。
      final pressPos = caretQueryPos(7);
      final gesture = await tester.startGesture(pressPos, kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 450));

      expect(controller.text, isNotNull, reason: '前置：长按应选中词');
      final selectedWord = controller.text ?? '';
      expect(selectedWord, isNotEmpty);

      // 记录初始放大镜焦点 caretX。
      final initialFocus = _selectionRender(tester).magnifierLineGeometryForDrag();
      expect(initialFocus, isNotNull);
      final initialCaretX = initialFocus!.caretX;

      // 向下移动到文本内容区域下方（下方无内容，不触发滚动）。
      final textRect = tester.getRect(find.byKey(textKey));
      final belowContentY = textRect.bottom + 80;
      await gesture.moveTo(Offset(pressPos.dx, belowContentY));
      await tester.pump();

      final afterMoveSelection = controller.text ?? '';
      expect(afterMoveSelection.length, greaterThan(selectedWord.length), reason: '向下拖到内容外应扩展选区');

      // 回到原位。
      await gesture.moveTo(pressPos);
      await tester.pump();

      final afterReturnSelection = controller.text ?? '';
      final afterReturnFocus = _selectionRender(tester).magnifierLineGeometryForDrag();

      // 非滚动场景下，选区和放大镜焦点应精确回到初始状态。
      expect(afterReturnSelection, selectedWord, reason: '回到原位后选区应保持不变');
      expect(
        (afterReturnFocus?.caretX ?? initialCaretX) - initialCaretX,
        lessThan(1.0),
        reason: '回到原位后放大镜焦点 caretX 应保持不变',
      );

      await gesture.up();
      await tester.pump();
    });

    testWidgets('可滚动容器：自动滚动后手指回到视口中间，选区不应异常扩大', (tester) async {
      final controller = ElSelectionController();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      final rows = List<Widget>.generate(30, (index) {
        return SizedBox(
          height: 36,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElView(child: 'row $index word text', key: ValueKey('row-$index')),
          ),
        );
      });

      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 240,
            height: 240,
            child: ElSelectionView(
              controller: controller,
              child: ElScrollView(controller: scroll, physics: ClampingScrollPhysics(), children: rows),
            ),
          ),
        ),
      );

      // 从第 3 行开始（全局坐标固定，便于后续回到原位）。
      final start = tester.getCenter(find.byKey(const ValueKey('row-3')));
      final gesture = await tester.startGesture(start, kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 450));

      expect(controller.text, isNotNull, reason: '前置：长按应选中词');
      final selectedWord = controller.text ?? '';
      expect(selectedWord, isNotEmpty);

      // 向下移动到 viewport 底部边缘内侧，触发 auto-scroll。
      await gesture.moveTo(Offset(start.dx, 230));
      await tester.pump();
      // 滚动几帧，让内容发生位移。
      await _pumpFrames(tester, 20);
      final scrollOffsetAfter = scroll.offset;
      expect(scrollOffsetAfter, greaterThan(0), reason: '应触发自动滚动');

      final afterScrollSelection = controller.text ?? '';
      expect(afterScrollSelection.length, greaterThan(selectedWord.length), reason: '滚动过程中选区应扩展');

      // 把手指移回 viewport 中间（非边缘，停止自动滚动）。
      await gesture.moveTo(Offset(start.dx, 120));
      await tester.pump();
      // 给 ticker 一帧时间真正停下来。
      await tester.pump(const Duration(milliseconds: 16));

      final afterReturnSelection = controller.text ?? '';
      final afterReturnFocus = _selectionRender(tester).magnifierLineGeometryForDrag();

      // 复现：当前实现会保留从原 anchor 到当前 focus 的超大跨度选区，
      // 导致放大镜焦点 / 复制内容异常偏移。修复后应改为验证选区只包含
      // 手指当前位置附近的内容。
      expect(afterReturnSelection.split('\n').length, greaterThan(3), reason: '复现：自动滚动后手指回到视口中间，选区仍跨越大量行');
      debugPrint(
        'afterReturnSelection lines=${afterReturnSelection.split('\n').length} caretX=${afterReturnFocus?.caretX}',
      );

      await gesture.up();
      await tester.pump();
    });
  });
}
