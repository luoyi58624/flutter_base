import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';
import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElRenderView;

import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 半透明选区矩形重叠回归：相邻行选区带的垂直交叠在半透明背景下形成深色重叠带。
///
/// 用户反馈（Android + 半透明选区）：换行处出现明显深色横条，Windows 不透明
/// 蓝底白字掩盖了此问题，但设置半透明后同样重现。
///
/// **根因**：`adjustedSelectionPaintRectsForRange` 未做相邻行 bottom/top 对齐，
/// FlutterTest 字体的行盒 baseline 落在半像素（fontSize 16 / lineHeight 1.5
/// → 行盒 24，ascent 12 / descent 4，baseline = 16.0，顶 top=4.0 / 底 bottom=20.0，
/// 下一行 top=24.0）时，Flutter TextPainter 返回的选区 rects 可能在行缝处产生
/// 0.5~1px 的垂直重叠或间隙（浮点舍入 + painter 实现细节）——不透明色下肉眼
/// 不可见，半透明色叠加后形成明显双倍 alpha 的深色带。
///
/// **修复**：相邻行选区矩形在垂直方向上首尾相接、不重叠不留缝（下行 top 对齐
/// 上行 bottom）。
void main() {
  Widget app(Widget child) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }

  ElRenderView textRender(WidgetTester tester, Finder finder) {
    final host = tester.renderObject<ElRenderView>(finder);
    expect(host.hasTextPayload, isTrue);
    return host;
  }

  testWidgets('半透明选区：同一段多行相邻行选区矩形垂直方向首尾相接不重叠', (tester) async {
    final controller = ElSelectionController();
    const key = Key('multi');
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 140, // 强制 3+ 行
          child: ElSelectionView(
            controller: controller,
            child: const ElView(
              key: key,
              style: ElStyle(fontSize: 16, lineHeight: 1.5),
              child: 'This is a very long text that will definitely wrap across multiple lines.',
            ),
          ),
        ),
      ),
    );

    controller.selectAll();
    await tester.pump();

    final render = textRender(tester, find.byKey(key));
    final rects =
        (render.selectionParticipant?.adjustedSelectionPaintRectsForRange(
          ui.TextRange(start: 0, end: render.selectionTextLength),
        ) ??
        const <Rect>[]);

    expect(rects.length, greaterThanOrEqualTo(3), reason: '140px 宽度下长文本必须至少 3 行');

    for (var i = 0; i < rects.length - 1; i++) {
      final current = rects[i];
      final next = rects[i + 1];
      // 相邻行：下行 top 必须 ≥ 上行 bottom（首尾相接或留缝，禁止重叠）。
      expect(
        next.top,
        greaterThanOrEqualTo(current.bottom - 0.01), // 0.01 容差兜底浮点误差
        reason:
            '相邻行 #$i bottom=${current.bottom.toStringAsFixed(2)} / '
            '#${i + 1} top=${next.top.toStringAsFixed(2)} 发生重叠，'
            '半透明选区会在此处形成深色重叠带',
      );
    }
  });

  testWidgets('半透明选区：相邻 ElView 块之间选区矩形不重叠（已有回归）', (tester) async {
    final controller = ElSelectionController();
    const firstKey = Key('first');
    const secondKey = Key('second');
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 260,
          child: ElSelectionView(
            controller: controller,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElView(key: firstKey, style: ElStyle(fontSize: 20), child: 'First block'),
                ElView(key: secondKey, style: ElStyle(fontSize: 20), child: 'Second block'),
              ],
            ),
          ),
        ),
      ),
    );

    controller.selectAll();
    await tester.pump();

    final first = textRender(tester, find.byKey(firstKey));
    final second = textRender(tester, find.byKey(secondKey));
    final firstRects =
        (first.selectionParticipant?.adjustedSelectionPaintRectsForRange(
          ui.TextRange(start: 0, end: first.selectionTextLength),
        ) ??
        const <Rect>[]);
    final secondRects =
        (second.selectionParticipant?.adjustedSelectionPaintRectsForRange(
          ui.TextRange(start: 0, end: second.selectionTextLength),
        ) ??
        const <Rect>[]);

    final transform = second.getTransformTo(first);
    for (final firstRect in firstRects) {
      for (final secondRect in secondRects) {
        final secondInFirst = MatrixUtils.transformRect(transform, secondRect);
        final overlap = firstRect.intersect(secondInFirst);
        expect(overlap.width <= 0 || overlap.height <= 0, isTrue, reason: '不同 ElView 块的选区矩形不得重叠（半透明色会叠加成深色带）');
      }
    }
  });

  testWidgets('半透明选区：rich inline 嵌套 ElView 的多行选区矩形不重叠', (tester) async {
    final controller = ElSelectionController();
    const key = Key('rich');
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 140, // 强制多行
          child: ElSelectionView(
            controller: controller,
            child: const ElView(
              key: key,
              style: ElStyle(fontSize: 16, lineHeight: 1.5),
              child: [
                'Start text ',
                ElView(
                  style: ElStyle(fontWeight: .w700),
                  child: 'bold inline',
                ),
                ' more text that wraps to next line.',
              ],
            ),
          ),
        ),
      ),
    );

    controller.selectAll();
    await tester.pump();

    final render = textRender(tester, find.byKey(key));
    final rects =
        (render.selectionParticipant?.adjustedSelectionPaintRectsForRange(
          ui.TextRange(start: 0, end: render.selectionTextLength),
        ) ??
        const <Rect>[]);

    expect(rects.length, greaterThanOrEqualTo(2), reason: 'rich inline 长文本应至少 2 行');

    for (var i = 0; i < rects.length - 1; i++) {
      final current = rects[i];
      final next = rects[i + 1];
      // 跳过同一行内水平相接的 rect（top 相同，left 紧接 right）
      final sameLine = (current.top - next.top).abs() < 0.5 && (next.left - current.right).abs() < 0.5;
      if (sameLine) continue;
      // 跨行或垂直堆叠的 rect：下行 top 必须 ≥ 上行 bottom
      expect(
        next.top,
        greaterThanOrEqualTo(current.bottom - 0.01),
        reason:
            'rich inline 相邻 rect #$i/#${i + 1} 重叠：'
            'current=$current next=$next',
      );
    }
  });
}
