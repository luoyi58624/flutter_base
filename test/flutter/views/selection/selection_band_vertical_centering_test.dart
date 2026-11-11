import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart' show selectionParticipantOf;
import 'package:flutter_base/src/flutter/views/view/text/text_engine.dart' show TextEngine;
import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';

import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElRenderView;
import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 选区带在字形上下的留白必须对称（CSS half-leading 语义）。
///
/// CSS 的 line-height 多余空间按**半行距**均分到字形上下；Flutter TextStyle
/// height 的默认 leading 分布是 proportional（按字体 ascent:descent ≈ 3:1
/// 分配），字形在行盒里偏下，铺满行盒的选区带看起来整体偏上——中英文皆然。
/// 选区带对齐整行盒是正确的（对齐浏览器），要修的是字形在行盒内的落位：
/// initial 级 `leadingDistribution: even`。
///
/// 度量方式：
/// - 选区带 = `selectionPaintRectsForTest`（行带归拢后，即真实绘制的矩形）
/// - 字形墨迹带 = baseline ± 无行高倍数时的自然 ascent/descent
///   （FlutterTest 测试字体：ascent 0.75em / descent 0.25em）
void main() {
  Widget app(Widget child) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }

  ElRenderView textRender(WidgetTester tester, Key key) {
    final host = tester.renderObject<ElRenderView>(find.byKey(key));
    expect((host.content is TextEngine), isTrue);
    return host;
  }

  /// 无行高倍数时的自然 ascent/descent（字形墨迹相对 baseline 的范围）。
  ({double ascent, double descent}) naturalMetrics(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final line = painter.computeLineMetrics().single;
    final result = (ascent: line.ascent, descent: line.descent);
    painter.dispose();
    return result;
  }

  /// 单行全选：返回 (选区带, 字形上方留白, 字形下方留白)。
  /// rich inline 同行多 run 会产出多个矩形（不跨行），取并集作为整行选区带。
  ({Rect band, double gapAbove, double gapBelow}) measure(WidgetTester tester, Key key, String text, double fontSize) {
    final render = textRender(tester, key);
    final rects =
        (selectionParticipantOf(render)?.selectionPaintRectsForRange(
          ui.TextRange(start: 0, end: (selectionParticipantOf(render)?.selectionTextLength ?? 0)),
        ) ??
        const <Rect>[]);
    expect(rects, isNotEmpty);
    final band = rects.reduce((a, b) => a.expandToInclude(b));
    final baseline = render.computeDistanceToActualBaseline(TextBaseline.alphabetic)!;
    final natural = naturalMetrics(text, fontSize);
    final glyphTop = baseline - natural.ascent;
    final glyphBottom = baseline + natural.descent;
    return (band: band, gapAbove: glyphTop - band.top, gapBelow: band.bottom - glyphBottom);
  }

  group('选区带与字形垂直居中（CSS half-leading）', () {
    testWidgets('默认样式英文：上下留白对称且带高铺满行盒', (tester) async {
      const key = Key('en');
      await tester.pumpWidget(
        app(
          const ElSelectionView(
            child: ElView(key: key, style: ElStyle(fontSize: 16, lineHeight: 1.5), child: 'alpha'),
          ),
        ),
      );

      // fontSize 16 / lineHeight 1.5 → 行盒 24。
      final m = measure(tester, key, 'alpha', 16);
      expect(m.band.height, moreOrLessEquals(24, epsilon: 1.5), reason: '选区带必须铺满整行盒（floor/ceil 容差）');
      expect(
        (m.gapAbove - m.gapBelow).abs(),
        lessThanOrEqualTo(1.5),
        reason:
            '多余行高应均分到字形上下（half-leading）；'
            '实际 above=${m.gapAbove.toStringAsFixed(2)} below=${m.gapBelow.toStringAsFixed(2)}',
      );
    });

    testWidgets('默认样式中文：上下留白对称', (tester) async {
      const key = Key('zh');
      await tester.pumpWidget(
        app(
          const ElSelectionView(
            child: ElView(key: key, child: '中文选区'),
          ),
        ),
      );

      final m = measure(tester, key, '中文选区', 16);
      expect(
        (m.gapAbove - m.gapBelow).abs(),
        lessThanOrEqualTo(1.5),
        reason: '实际 above=${m.gapAbove.toStringAsFixed(2)} below=${m.gapBelow.toStringAsFixed(2)}',
      );
    });

    testWidgets('更大行距 lineHeight 2.0：不对称随行距放大的回归锚', (tester) async {
      const key = Key('lh2');
      await tester.pumpWidget(
        app(
          const ElSelectionView(
            child: ElView(key: key, style: ElStyle(fontSize: 20, lineHeight: 2.0), child: 'tall'),
          ),
        ),
      );

      // fontSize 20 / lineHeight 2.0 → 行盒 40，多余 20。
      final m = measure(tester, key, 'tall', 20);
      expect(m.band.height, moreOrLessEquals(40, epsilon: 1.5));
      expect(
        (m.gapAbove - m.gapBelow).abs(),
        lessThanOrEqualTo(1.5),
        reason: '实际 above=${m.gapAbove.toStringAsFixed(2)} below=${m.gapBelow.toStringAsFixed(2)}',
      );
    });

    testWidgets('rich inline 路径（嵌套 inline ElView）：上下留白对称', (tester) async {
      const key = Key('rich');
      await tester.pumpWidget(
        app(
          const ElSelectionView(
            child: ElView(
              key: key,
              style: ElStyle(fontSize: 16, lineHeight: 1.5),
              child: [
                'pre ',
                ElView(
                  style: ElStyle(fontWeight: .w700),
                  child: 'bold',
                ),
                ' post',
              ],
            ),
          ),
        ),
      );

      final m = measure(tester, key, 'pre bold post', 16);
      expect(m.band.height, moreOrLessEquals(24, epsilon: 1.5));
      expect(
        (m.gapAbove - m.gapBelow).abs(),
        lessThanOrEqualTo(1.5),
        reason: '实际 above=${m.gapAbove.toStringAsFixed(2)} below=${m.gapBelow.toStringAsFixed(2)}',
      );
    });

    testWidgets('显式 leadingDistribution.proportional 覆盖仍被尊重', (tester) async {
      const key = Key('prop');
      await tester.pumpWidget(
        app(
          const ElSelectionView(
            child: ElView(
              key: key,
              style: ElStyle(
                fontSize: 16,
                lineHeight: 2.0,
                textOptions: ElTextOptions(leadingDistribution: .proportional),
              ),
              child: 'opt-out',
            ),
          ),
        ),
      );

      // FlutterTest 字体 ascent:descent = 3:1，proportional 下多余 16px 按
      // 12:4 分配 → 字形上方留白明显大于下方。
      final m = measure(tester, key, 'opt-out', 16);
      expect(
        m.gapAbove - m.gapBelow,
        greaterThan(4),
        reason:
            '显式 proportional 必须保留 Flutter 原生分布；'
            '实际 above=${m.gapAbove.toStringAsFixed(2)} below=${m.gapBelow.toStringAsFixed(2)}',
      );
    });
  });
}
