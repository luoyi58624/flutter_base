import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

/// 精确复现 _textAlignDemo 的选区重叠问题
void main() {
  testWidgets('_textAlignDemo exact reproduction - TextAlign.center', (tester) async {
    const sample = '每一次对齐都是内容层级的宣言。start 靠开始边、center 居中、end 靠结束边、justify 两端顶到边。';
    final controller = ElSelectionController();

    // 完全相同的样式配置
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 250,
              child: ElSelectionView(
                controller: controller,
                child: ElView(
                  style: const ElStyle(
                    width: '100%',
                    minHeight: 68,
                    bgColor: Color(0xFFF8FAFC), // kSlate50
                    border: .all(color: Color(0xFFE2E8F0)), // kSlate200
                    borderRadius: BorderRadius.all(Radius.elliptical(6, 6)),
                    padding: .symmetric(horizontal: 10, vertical: 8),
                    fontSize: 12,
                    lineHeight: 1.55,
                    textAlign: TextAlign.center,
                  ),
                  child: sample,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 全选文本
    controller.selectAll();
    await tester.pump();

    // 获取选区 rects
    const key = Key('text');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 250,
              child: ElSelectionView(
                controller: controller,
                child: const ElView(
                  key: key,
                  style: ElStyle(
                    width: '100%',
                    minHeight: 68,
                    bgColor: Color(0xFFF8FAFC), // kSlate50
                    border: .all(color: Color(0xFFE2E8F0)), // kSlate200
                    borderRadius: BorderRadius.all(Radius.elliptical(6, 6)),
                    padding: .symmetric(horizontal: 10, vertical: 8),
                    fontSize: 12,
                    lineHeight: 1.55,
                    textAlign: TextAlign.center,
                  ),
                  child: sample,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.selectAll();
    await tester.pump();

    final render = tester.renderObject(find.byKey(key));
    final rects = (render as ElRenderView).selectionParticipant!.adjustedSelectionPaintRectsForRange(
      const ui.TextRange(start: 0, end: 1000),
    );

    debugPrint('\n=== _textAlignDemo exact repro (TextAlign.center) ===');
    debugPrint('Total rects: ${rects.length}');

    // 检查每个 rect 与前一个的关系
    for (int i = 0; i < rects.length; i++) {
      final r = rects[i];
      debugPrint(
        'rect[$i]: left=${r.left.toStringAsFixed(2)}, top=${r.top.toStringAsFixed(2)}, '
        'right=${r.right.toStringAsFixed(2)}, bottom=${r.bottom.toStringAsFixed(2)}, '
        'width=${r.width.toStringAsFixed(2)}, height=${r.height.toStringAsFixed(2)}',
      );

      if (i > 0) {
        final prev = rects[i - 1];
        final verticalGap = r.top - prev.bottom;
        final horizontalGap = r.left - prev.right;

        // 检查垂直重叠（跨行的情况）
        if (r.top < prev.bottom - 0.01) {
          final overlap = prev.bottom - r.top;
          // 同行水平相接
          if ((r.top - prev.top).abs() < 2.0 && horizontalGap.abs() < 1.0) {
            debugPrint('  → 与 rect[${i - 1}] 同行水平相接（top 差 ${(r.top - prev.top).toStringAsFixed(2)}px）');
          } else {
            debugPrint(
              '  ⚠️  与 rect[${i - 1}] 重叠 ${overlap.toStringAsFixed(2)}px (verticalGap=${verticalGap.toStringAsFixed(2)})',
            );
            debugPrint('      prev: top=${prev.top.toStringAsFixed(2)}, bottom=${prev.bottom.toStringAsFixed(2)}');
            debugPrint('      curr: top=${r.top.toStringAsFixed(2)}, bottom=${r.bottom.toStringAsFixed(2)}');
          }
        } else if (verticalGap < 0.5) {
          debugPrint('  ✓ 与 rect[${i - 1}] 首尾相接（verticalGap=${verticalGap.toStringAsFixed(2)}px）');
        } else {
          debugPrint('  ✓ 与 rect[${i - 1}] 间隔 ${verticalGap.toStringAsFixed(2)}px');
        }
      }
    }

    // 断言：任意两个 rect 不得有正面积交集（半透明选区叠加变深的充要条件），
    // 不只查相邻对——一行拆多个 box 时，行缝重叠发生在非相邻 rect 之间。
    expectNoAreaOverlap(rects);
  });

  // 测试所有 4 种 textAlign
  for (final (name, align) in [
    ('start', TextAlign.start),
    ('center', TextAlign.center),
    ('end', TextAlign.end),
    ('justify', TextAlign.justify),
  ]) {
    testWidgets('_textAlignDemo $name - no cross-line overlaps', (tester) async {
      const sample = '每一次对齐都是内容层级的宣言。start 靠开始边、center 居中、end 靠结束边、justify 两端顶到边。';
      final controller = ElSelectionController();
      final key = Key(name);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                child: ElSelectionView(
                  controller: controller,
                  child: ElView(
                    key: key,
                    style: ElStyle(
                      width: '100%',
                      minHeight: 68,
                      bgColor: const Color(0xFFF8FAFC),
                      border: const .all(color: Color(0xFFE2E8F0)),
                      borderRadius: const BorderRadius.all(Radius.elliptical(6, 6)),
                      padding: const .symmetric(horizontal: 10, vertical: 8),
                      fontSize: 12,
                      lineHeight: 1.55,
                      textAlign: align,
                    ),
                    child: sample,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.selectAll();
      await tester.pump();

      final render = tester.renderObject(find.byKey(key));
      final rects = (render as ElRenderView).selectionParticipant!.adjustedSelectionPaintRectsForRange(
        const ui.TextRange(start: 0, end: 1000),
      );

      expectNoAreaOverlap(rects, label: name);
    });
  }
}

/// 任意两 rect 的交集宽高均不得同时超过容差（否则半透明选区叠加出深色带）。
void expectNoAreaOverlap(List<Rect> rects, {String? label}) {
  for (int i = 0; i < rects.length; i++) {
    for (int j = i + 1; j < rects.length; j++) {
      final overlap = rects[i].intersect(rects[j]);
      final hasArea = overlap.width > 0.01 && overlap.height > 0.01;
      expect(
        hasArea,
        isFalse,
        reason:
            '${label == null ? '' : '$label: '}rect[$i]=${rects[i]} 与 rect[$j]=${rects[j]} '
            '交集 ${overlap.width.toStringAsFixed(2)}x${overlap.height.toStringAsFixed(2)}',
      );
    }
  }
}
