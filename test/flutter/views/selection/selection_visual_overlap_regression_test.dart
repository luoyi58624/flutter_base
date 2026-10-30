import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('textAlign: center 选区无跨行垂直重叠', (tester) async {
    final controller = ElSelectionController();
    const key = Key('text');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 230,
              child: ElSelectionView(
                controller: controller,
                child: const ElView(
                  key: key,
                  style: ElStyle(padding: .all(1), textAlign: .center, fontSize: 16, lineHeight: 1.5),
                  child: 'This is a long text that will wrap into multiple lines to test selection overlap.',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.selectAll();
    await tester.pump();

    final render = tester.renderObject(find.byKey(key));
    final rects = (render as ElRenderView).selectionParticipant!.adjustedSelectionPaintRectsForRange(
      const TextRange(start: 0, end: 1000),
    );

    expect(rects.length, greaterThan(2), reason: '多行文本应该产生多个选区 rect');

    // 检查跨行重叠：不同行（top 差 > 2px）的 rect 不应有垂直重叠
    for (var i = 1; i < rects.length; i++) {
      final prev = rects[i - 1];
      final curr = rects[i];
      final topDiff = (curr.top - prev.top).abs();

      if (topDiff > 2.0) {
        // 不同行
        final overlap = prev.bottom - curr.top;
        expect(
          overlap,
          lessThanOrEqualTo(0.01),
          reason:
              'rect[$i] 与 rect[${i - 1}] 跨行垂直重叠 ${overlap}px\n'
              'rect[${i - 1}]: top=${prev.top}, bottom=${prev.bottom}\n'
              'rect[$i]: top=${curr.top}, bottom=${curr.bottom}',
        );
      }
    }
  });

  testWidgets('富文本 inline ElView 选区无视觉重叠（同行元素共享行盒）', (tester) async {
    final controller = ElSelectionController();
    const key = Key('rich');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: ElSelectionView(
                controller: controller,
                child: const ElView(
                  key: key,
                  style: ElStyle(padding: .all(14), color: Color(0xFF2563EB), fontSize: 17, lineHeight: 1.7),
                  child: [
                    '这段裸文本继承了父容器的 color 和 fontSize，',
                    ElView(
                      style: ElStyle(fontSize: 13, color: Color(0xFF059669)),
                      child: '这段嵌套 ElView 声明了不同 fontSize',
                    ),
                    '，回到父容器样式。',
                    ElView(
                      style: ElStyle(fontSize: 13, color: Color(0xFFDC2626)),
                      child: '又一段不同 fontSize 的嵌套',
                    ),
                    '，再回到父容器。',
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.selectAll();
    await tester.pump();

    final render = tester.renderObject(find.byKey(key));
    final rects = (render as ElRenderView).selectionParticipant!.adjustedSelectionPaintRectsForRange(
      const TextRange(start: 0, end: 1000),
    );

    expect(rects.length, greaterThan(4), reason: '富文本应该产生多个选区 rect');

    // 检查同行元素的行盒对齐：水平相接（leftDiff < 1px）且 top 接近（< 2px）的 rect 应该共享 bottom
    for (var i = 1; i < rects.length; i++) {
      final prev = rects[i - 1];
      final curr = rects[i];
      final leftDiff = (curr.left - prev.right).abs();
      final topDiff = (curr.top - prev.top).abs();

      if (leftDiff < 1.0 && topDiff < 2.0) {
        // 同行水平相接的元素
        final bottomDiff = (curr.bottom - prev.bottom).abs();
        expect(
          bottomDiff,
          lessThanOrEqualTo(1.0),
          reason:
              'rect[$i] 与 rect[${i - 1}] 同行水平相接但 bottom 不对齐（差 ${bottomDiff}px）\n'
              'rect[${i - 1}]: top=${prev.top}, bottom=${prev.bottom}, height=${prev.height}\n'
              'rect[$i]: top=${curr.top}, bottom=${curr.bottom}, height=${curr.height}\n'
              '同行 inline 元素应共享行盒，避免半透明选区重叠',
        );
      }
    }
  });
}
