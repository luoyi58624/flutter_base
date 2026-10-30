import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';
// 选区覆盖文本背景（CSS highlight painting 对齐）—— 集成侧。
//
// 不变量：
// 1. 内容带 textBackgroundColor 时，即便 selectionTextColor == null 也走覆盖序
//    （内容 → 选区带 → 原色字形 overlay），overlay 计数必须增长。
// 2. 无背景且不换字色时维持旧快路径（选区带垫底），overlay 计数保持 0 ——
//    普通文章选中不付 overlay painter / Picture 成本。
//
// overlay 样式剥背景与选中字色一并验证。
import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElRenderView;

import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
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

List<ElRenderView> _textRenders(WidgetTester tester) {
  return tester.allRenderObjects
      .whereType<ElRenderView>()
      .where((r) => r.hasTextPayload && r.selectionTextLength > 0)
      .toSet()
      .toList();
}

int _overlayPaintCount(ElRenderView render) =>
    ((render.textEngineForTest?.debugSelectionUnclippedOverlayCount) ?? 0) +
    ((render.textEngineForTest?.debugSelectionClipRectOverlayCount) ?? 0);

void main() {
  group('选区覆盖文本背景（覆盖序 / 快路径分派）', () {
    testWidgets('rich inline 带 textBackgroundColor：selectionTextColor 为 null 也走覆盖序', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(
              child: [
                '前缀 ',
                TextSpan(
                  style: TextStyle(backgroundColor: Color(0xFFFEF08A)),
                  text: '荧光笔高亮',
                ),
                ' 后缀',
              ],
            ),
          ),
        ),
      );

      final render = _textRenders(tester).single;
      expect(_overlayPaintCount(render), 0, reason: '未选中时不画 overlay');

      controller.selectAll();
      await tester.pump();

      expect(render.currentSelectionRange, isNotNull);
      expect(_overlayPaintCount(render), greaterThan(0), reason: '内容带文本背景 → 选区带盖上内容后必须原色重绘字形（覆盖序）');
    });

    testWidgets('纯 String 带 textBackgroundColor：同样走覆盖序', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(
              style: ElStyle(textBackgroundColor: Color(0xFFFEF08A)),
              child: '整段荧光笔',
            ),
          ),
        ),
      );

      final render = _textRenders(tester).single;
      controller.selectAll();
      await tester.pump();

      expect(render.currentSelectionRange, const ui.TextRange(start: 0, end: 5));
      expect(_overlayPaintCount(render), greaterThan(0));
    });

    testWidgets('无文本背景且 selectionTextColor 为 null：维持垫底快路径，零 overlay', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            // 测试平台（android）默认半透明 bg，selectionTextColor 恒 null。
            child: const ElView(
              child: [
                '普通文本 ',
                TextSpan(
                  style: TextStyle(fontWeight: FontWeight.bold),
                  text: '加粗',
                ),
              ],
            ),
          ),
        ),
      );

      final render = _textRenders(tester).single;
      controller.selectAll();
      await tester.pump();

      expect(render.currentSelectionRange, isNotNull);
      expect(_overlayPaintCount(render), 0, reason: '无背景不换字色 → 旧快路径，不付 overlay 成本');
    });

    testWidgets('selectionTextColor 显式设置时 overlay 照常（既有 Windows 路径回归）', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(
              child: '不带背景的整段文本',
              style: ElStyle(
                onSelection: ElStyle(bgColor: Color(0xff0078d7), color: Color(0xffffffff)),
              ),
            ),
          ),
        ),
      );

      final render = _textRenders(tester).single;
      controller.selectAll();
      await tester.pump();

      expect(_overlayPaintCount(render), greaterThan(0));
    });
  });
}
