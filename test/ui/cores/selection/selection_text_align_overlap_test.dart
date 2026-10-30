import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';
import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElRenderView;

import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 回归：textAlign 对齐变体 + 富文本继承时的半透明选区跨行重叠（用户截图反馈）。
///
/// 根因：行缝裁剪逻辑要求 sameHorizontalBand（left/right 几乎相等），只适用
/// 全选整行。部分选中（首尾行宽度不同）或 textAlign 导致每行 left 不同时判定
/// 失效，半透明选区叠加形成深色横带。
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

  testWidgets('textAlign: center 多行选中不重叠（截图场景1）', (tester) async {
    final controller = ElSelectionController();
    const key = Key('center');
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 250,
          child: ElSelectionView(
            controller: controller,
            child: const ElView(
              key: key,
              style: ElStyle(
                padding: .all(10),
                fontSize: 12,
                lineHeight: 1.55,
                textAlign: TextAlign.center, // center 对齐，每行 left 不同
              ),
              child: '每一次对齐都是内容层级的宣言。start 靠开始边、center 居中、end 靠结束边、justify 两端顶到边。',
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

    expect(rects.length, greaterThanOrEqualTo(3), reason: '250px 宽度下长文本必须至少 3 行');
    _expectNoAreaOverlap(rects, label: 'textAlign: center');
  });

  testWidgets('富文本继承多行选中不重叠（截图场景2）', (tester) async {
    final controller = ElSelectionController();
    const key = Key('rich');
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 420,
          child: ElSelectionView(
            controller: controller,
            child: const ElView(
              key: key,
              style: ElStyle(
                padding: .all(14),
                color: Color(0xFF2563EB), // blue600
                fontSize: 17,
                lineHeight: 1.7,
              ),
              child: [
                '这段裸文本继承了父容器的 color 和 fontSize，',
                ElView(
                  style: ElStyle(
                    color: Color(0xFF64748B), // slate500
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  child: '这一小段则显式覆写为 slate500 / 13 / italic',
                ),
                '，覆写只作用于该子节点及其后代；后面这段又回到父级默认。',
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

    expect(rects.length, greaterThanOrEqualTo(3), reason: '420px 宽度下长富文本必须至少 3 行');
    _expectNoAreaOverlap(rects, label: '富文本继承');
  });

  testWidgets('textAlign: justify 多行选中不重叠', (tester) async {
    final controller = ElSelectionController();
    const key = Key('justify');
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 250,
          child: ElSelectionView(
            controller: controller,
            child: const ElView(
              key: key,
              style: ElStyle(padding: .all(10), fontSize: 12, lineHeight: 1.55, textAlign: TextAlign.justify),
              child: '每一次对齐都是内容层级的宣言。start 靠开始边、center 居中、end 靠结束边、justify 两端顶到边。',
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

    expect(rects.length, greaterThanOrEqualTo(3));
    _expectNoAreaOverlap(rects, label: 'textAlign: justify');
  });
}

/// 任意两 rect 的交集面积必须为零（±0.01 容差）——半透明选区叠加变深的充要条件。
/// 只查相邻对不够：一行拆多个 box 时行缝重叠发生在非相邻 rect 之间。
void _expectNoAreaOverlap(List<ui.Rect> rects, {required String label}) {
  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      final overlap = rects[i].intersect(rects[j]);
      final hasArea = overlap.width > 0.01 && overlap.height > 0.01;
      expect(
        hasArea,
        isFalse,
        reason:
            '$label: rect[$i]=${rects[i]} 与 rect[$j]=${rects[j]} '
            '交集 ${overlap.width.toStringAsFixed(2)}x${overlap.height.toStringAsFixed(2)}',
      );
    }
  }
}
