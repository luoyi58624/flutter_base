// 移动端文本选中向上拖拽经过空白区域的回归测试。
//
// 修复前：长按选中下方段落后，手指向上移过两段之间的空白处时，空白解析按
// 「块轴 floor」语义归到上方段落，导致 focus 被吸到上方段落末尾，从而
// 把上方整段文本拉入选区。
//
// 修复后：手指在段落间空白处时，选区不应跨过空白扩展到上方段落，保持
// 原有选区；只有手指真正进入上方段落内部时才允许扩展。

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

void main() {
  group('移动端向上拖拽经过空白处', () {
    testWidgets('长按下方段落后向上移入空白，不应把上方段落内容拉入选区', (tester) async {
      final controller = ElSelectionController();
      const topText = 'top paragraph text';
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
                SizedBox(height: 80), // 足够明显的两段空白
                ElView(key: Key('bottom'), child: bottomText),
              ],
            ),
          ),
        ),
      );

      final bottomCenter = tester.getCenter(find.byKey(const Key('bottom')));
      final gesture = await tester.startGesture(bottomCenter, kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);

      // 触发长按选词。
      await tester.pump(const Duration(milliseconds: 450));
      expect(controller.text, isNotNull, reason: '前置：长按应选中下方段落中的词');
      final selectedWord = controller.text ?? '';
      expect(selectedWord, isNotEmpty);
      expect(bottomText.contains(selectedWord), isTrue, reason: '选中的词应来自下方段落');

      // 向上移动到两段之间的空白处（不在任何文本几何内）。
      final topRect = tester.getRect(find.byKey(const Key('top')));
      final blankY = topRect.bottom + 40; // 空白中间
      await gesture.moveTo(Offset(bottomCenter.dx, blankY));
      await tester.pump();

      final selectedAfterMove = controller.text ?? '';

      // 修复后：手指在空白处时，选区不应扩展到上方段落。
      expect(selectedAfterMove.contains('text'), isFalse, reason: '向上拖拽经过空白处不应把上方段落内容选入');
      // 选区应保持在长按初始选中的词不变。
      expect(selectedAfterMove, selectedWord, reason: '手指在空白处时选区应保持不变');

      await gesture.up();
      await tester.pump();
    });

    testWidgets('当上方段落为单个不可分割词时，空白处也不应整选上方段落', (tester) async {
      final controller = ElSelectionController();
      const topText = 'topp entireblock';
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
                ElView(key: Key('bottom'), child: bottomText),
              ],
            ),
          ),
        ),
      );

      final bottomCenter = tester.getCenter(find.byKey(const Key('bottom')));
      final gesture = await tester.startGesture(bottomCenter, kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);

      await tester.pump(const Duration(milliseconds: 450));
      expect(controller.text, isNotNull);

      final topRect = tester.getRect(find.byKey(const Key('top')));
      final blankY = topRect.bottom + 40;
      await gesture.moveTo(Offset(bottomCenter.dx, blankY));
      await tester.pump();

      final selectedAfterMove = controller.text ?? '';

      // 修复后：即使上方段落为单长词，手指在空白处时也不应整选上方段落。
      expect(selectedAfterMove.contains('entireblock'), isFalse, reason: '上方段落为单长词时，空白处拖拽也不应整选上方段落');

      await gesture.up();
      await tester.pump();
    });

    testWidgets('继续向上移入上方段落内部，选区才正常扩展到上方段落', (tester) async {
      final controller = ElSelectionController();
      const topText = 'top paragraph text';
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
                ElView(key: Key('bottom'), child: bottomText),
              ],
            ),
          ),
        ),
      );

      final bottomCenter = tester.getCenter(find.byKey(const Key('bottom')));
      final gesture = await tester.startGesture(bottomCenter, kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);

      await tester.pump(const Duration(milliseconds: 450));
      expect(controller.text, isNotNull);

      // 向上移入上方段落内部（而不是空白处）。
      final topRect = tester.getRect(find.byKey(const Key('top')));
      await gesture.moveTo(Offset(bottomCenter.dx, topRect.center.dy));
      await tester.pump();

      final selectedAfterMove = controller.text ?? '';

      // 手指确实进入上方段落内部时，选区正常扩展到上方段落。
      expect(selectedAfterMove.contains('paragraph text'), isTrue, reason: '手指确实进入上方段落时，应允许选入上方段落');

      await gesture.up();
      await tester.pump();
    });
  });
}
