import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';
import 'dart:ui' as ui;


import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElRenderView;
import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// TextLocalePage 同构布局：多语种独立 ElView 竖排、无 spacing、lineHeight 1.25。
///
/// 示例页 `examples/ui_example/.../text_locale` 全选时，相邻语言行选区带
/// 出现齿状垂直重叠。既有 adjacent-block 回归用 fontSize 20/24 + lineHeight 1.5，
/// 盖不住本页口径。
///
/// 断言走绘制实际使用的 [ElRenderView.adjustedSelectionPaintRectsForTest]
///（节点 clamp + root 邻接对齐）。
void main() {
  Widget app(Widget child) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }

  /// 与 TextLocalePage._languageLines 同构（含 RTL 阿语行）。
  const languageLines = <(String text, TextDirection? direction)>[
    ('The quick brown fox jumps over the lazy dog.', null),
    ('敏捷的棕色狐狸跳过懒狗。', null),
    ('敏捷的棕色狐狸跳過懶狗。', null),
    ('素早い茶色の狐が怠け者の犬を飛び越える。', null),
    ('빠른 갈색 여우가 게으른 개를 뛰어넘는다.', null),
    ('Le vif renard brun saute par-dessus le chien paresseux.', null),
    ('Der schnelle braune Fuchs springt über den faulen Hund.', null),
    ('El rápido zorro marrón salta sobre el perro perezoso.', null),
    ('A rápida raposa marrom salta sobre o cão preguiçoso.', null),
    ('Быстрая коричневая лиса перепрыгивает через ленивую собаку.', null),
    ('الثعلب البني السريع يقفز فوق الكلب الكسول.', TextDirection.rtl),
    ('तेज़ भूरी लोमड़ी सुस्त कुत्ते के ऊपर कूदती है।', null),
  ];

  List<(Key key, ElRenderView render, List<Rect> paintRects)> collectLineRenders(WidgetTester tester) {
    final out = <(Key, ElRenderView, List<Rect>)>[];
    for (var i = 0; i < languageLines.length; i++) {
      final key = ValueKey<String>('locale-line-$i');
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(render.hasTextPayload, isTrue);
      final rects =
          (render.selectionParticipant?.adjustedSelectionPaintRectsForRange(
            ui.TextRange(start: 0, end: render.selectionTextLength),
          ) ??
          const <Rect>[]);
      expect(rects, isNotEmpty, reason: 'line#$i 全选后应有绘制用选区 rect');
      out.add((key, render, rects));
    }
    return out;
  }

  void expectNoCrossLinePaintOverlap(List<(Key key, ElRenderView render, List<Rect> paintRects)> lines) {
    for (var i = 0; i < lines.length - 1; i++) {
      final (_, upper, upperRects) = lines[i];
      final (_, lower, lowerRects) = lines[i + 1];
      final toUpper = lower.getTransformTo(upper);
      for (final upperRect in upperRects) {
        for (final lowerRect in lowerRects) {
          final lowerInUpper = MatrixUtils.transformRect(toUpper, lowerRect);
          final overlap = upperRect.intersect(lowerInUpper);
          expect(
            overlap.width <= 0 || overlap.height <= 0,
            isTrue,
            reason:
                'TextLocalePage 同构：相邻语言行 #$i / #${i + 1} 绘制选区重叠 '
                'upper=$upperRect lowerInUpper=$lowerInUpper '
                'overlapH=${overlap.height.toStringAsFixed(3)} '
                '（半透明/系统选区会形成齿状深色带）',
          );
        }
      }
    }
  }

  void expectPaintRectsInsideNode(List<(Key key, ElRenderView render, List<Rect> paintRects)> lines) {
    for (final (key, render, rects) in lines) {
      final size = render.size;
      for (final rect in rects) {
        expect(rect.top, greaterThanOrEqualTo(-0.01), reason: '$key 选区 top 越出节点');
        expect(
          rect.bottom,
          lessThanOrEqualTo(size.height + 0.01),
          reason:
              '$key 选区 bottom=${rect.bottom.toStringAsFixed(3)} '
              '越出节点高 ${size.height.toStringAsFixed(3)}（会叠到下行）',
        );
        expect(rect.left, greaterThanOrEqualTo(-0.01), reason: '$key 选区 left 越出节点');
        expect(
          rect.right,
          lessThanOrEqualTo(size.width + 0.01),
          reason:
              '$key 选区 right=${rect.right.toStringAsFixed(3)} '
              '越出节点宽 ${size.width.toStringAsFixed(3)}',
        );
      }
    }
  }

  testWidgets('TextLocalePage 同构：多语种紧挨竖排全选，绘制选区不跨行重叠', (tester) async {
    final controller = ElSelectionController();
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 420,
          child: ElSelectionView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < languageLines.length; i++)
                  ElView(
                    key: ValueKey<String>('locale-line-$i'),
                    locale: null,
                    style: ElStyle(
                      color: const Color(0xff111827),
                      lineHeight: 1.25,
                      direction: languageLines[i].$2,
                    ),
                    child: languageLines[i].$1,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    controller.selectAll();
    await tester.pump();

    final lines = collectLineRenders(tester);
    expectPaintRectsInsideNode(lines);
    expectNoCrossLinePaintOverlap(lines);
  });

  testWidgets('TextLocalePage 同构：卡片内 title/desc + 多语种（含 locale）全选不跨行重叠', (tester) async {
    final controller = ElSelectionController();
    // 卡片内容高于默认 600 高视口；与示例页一样可滚，避免 Column overflow。
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(
        SizedBox(
          width: 420,
          child: ElSelectionView(
            controller: controller,
            child: ElView(
              style: const ElStyle(
                padding: .all(12),
                borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
                backgroundColor: Colors.white,
                border: .all(borderColor: Color(0xffe2e8f0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  const ElView(
                    key: Key('locale-title'),
                    child: '默认 locale: null',
                    style: ElStyle(color: Color(0xff0f172a), fontWeight: .w700, lineHeight: 1.25),
                  ),
                  const ElView(
                    key: Key('locale-desc'),
                    child: '不从 Localizations 读取 locale，交给平台或 Web fallback 自己选择字体。',
                    style: ElStyle(color: Color(0xff64748b), lineHeight: 1.3),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < languageLines.length; i++)
                        ElView(
                          key: ValueKey<String>('locale-line-$i'),
                          locale: const Locale('zh', 'CN'),
                          style: ElStyle(
                            color: const Color(0xff111827),
                            lineHeight: 1.25,
                            direction: languageLines[i].$2,
                          ),
                          child: languageLines[i].$1,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    controller.selectAll();
    await tester.pump();

    final lines = collectLineRenders(tester);
    expectPaintRectsInsideNode(lines);
    expectNoCrossLinePaintOverlap(lines);
  });
}
