import 'dart:ui' as ui;

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _navTitleKey = ValueKey<String>('file-read-nav-title');
const _toolbarTextKey = ValueKey<String>('file-read-toolbar-text');

Widget _fileReadPage({int rowCount = 32}) {
  return MaterialApp(
    home: ElSelectionView(
      child: Scaffold(
        appBar: AppBar(
          title: const ElView(key: _navTitleKey, child: 'FileRead'),
        ),
        body: ElView(
          style: const ElStyle(backgroundColor: Color(0xff282c34)),
          child: Column(
            children: [
              ElView(
                key: const ValueKey<String>('file-read-toolbar'),
                style: const ElStyle(
                  height: 52,
                  padding: .symmetric(horizontal: 16, vertical: 10),
                  backgroundColor: Color(0xff21252b),
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    ElView(child: '打开文件'),
                    Expanded(
                      child: ElView(key: _toolbarTextKey, child: 'render_view.dart 5663 行'),
                    ),
                    ElView(child: 'ElVirtual'),
                    ElView(child: 'SuperList'),
                  ],
                ),
              ),
              Expanded(child: _fileReadContent(rowCount: rowCount)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _fileReadContent({required int rowCount}) {
  return ElSelectionView(
    child: ElScrollView(
      axis: null,
      padding: .symmetric(vertical: 8),
      children: [ElListView.builder(itemCount: rowCount, itemBuilder: (_, index) => _fileReadLine(index))],
    ),
  );
}

Widget _fileReadLine(int index) {
  return ElView(
    style: const ElStyle(
      padding: .symmetric(horizontal: 16),
      fontFamily: 'Consolas',
      fontSize: 14,
      lineHeight: 1.5,
      softWrap: false,
    ),
    child: Row(
      spacing: 16,
      crossAxisAlignment: .start,
      children: [
        ElView(
          style: const ElStyle(width: 32, userSelect: .none),
          child: '${index + 1}',
        ),
        ElView(
          child: ElView(
            key: ValueKey<String>('file-read-line-text-$index'),
            child: <Object>[
              ElView(
                style: const ElStyle(color: Color(0xffc678dd)),
                child: 'final',
              ),
              ' line$index = readFileLine($index);',
            ],
          ),
        ),
      ],
    ),
  );
}

ElRenderView _renderForKey(WidgetTester tester, Key key) {
  return tester.renderObject<ElRenderView>(find.byKey(key));
}

SelectionParticipant _participantForRender(WidgetTester tester, ElRenderView render) {
  for (final participant in selectionParticipantsOf(tester.allRenderObjects)) {
    if (identical(participant.box, render)) return participant;
  }
  fail('未找到选区参与者: $render');
}

bool _isSelected(WidgetTester tester, Key key) {
  final render = _renderForKey(tester, key);
  final range = _participantForRender(tester, render).currentSelectionRange;
  return range != null && !range.isCollapsed ||
      selectionParticipantsOf([render]).any((participant) => participant.currentSelectionRange?.isCollapsed == false);
}

ui.Rect _selectionRect(ElRenderView render) {
  final rects =
      (render.selectionParticipant?.selectionPaintRectsForRange(
        ui.TextRange(start: 0, end: render.selectionTextLength),
      ) ??
      const <Rect>[]);
  expect(rects, isNotEmpty, reason: '文本行必须有可探测的选区带');
  return rects.firstWhere((rect) => rect.width > 8, orElse: () => rects.first);
}

ui.Rect _firstGlyphRect(ElRenderView render) {
  final boxes = render.textEngineForTest!.getBoxesForSelectionForTest(0, 1);
  expect(boxes, isNotEmpty, reason: '富文本首字符必须有 tight glyph box');
  // 首字符是 WidgetSpan 时，占位盒含完整行距；探针应读取子文本的真实字形。
  final placeholders = render.textEngineForTest!.painterForTest.inlinePlaceholderBoxes;
  if (placeholders != null && placeholders.isNotEmpty && boxes.first.toRect() == placeholders.first.toRect()) {
    final child = render.getChildrenAsList().first;
    if (child is ElRenderView && child.textEngineForTest != null) {
      return MatrixUtils.transformRect(child.getTransformTo(render), _firstGlyphRect(child));
    }
  }
  return boxes.first.toRect().shift(render.contentOrigin);
}

void main() {
  testWidgets(
    'FileRead 虚拟富文本行：行间 leading 和行界始终保持 text 光标',
    (tester) async {
      await tester.pumpWidget(_fileReadPage(rowCount: 12));
      await tester.pumpAndSettle();

      final renders = [
        for (var index = 0; index < 6; index++) _renderForKey(tester, ValueKey<String>('file-read-line-text-$index')),
      ];
      final points = <Offset>[];
      for (final render in renders) {
        final band = _selectionRect(render);
        final glyph = _firstGlyphRect(render);
        expect(glyph.top - band.top, greaterThan(1), reason: '判别前置：行顶必须存在 leading 空隙');
        expect(band.bottom - glyph.bottom, greaterThan(1), reason: '判别前置：行底必须存在 leading 空隙');
        points.add(render.localToGlobal(Offset(glyph.center.dx, (band.top + glyph.top) / 2)));
        points.add(render.localToGlobal(glyph.center));
        points.add(render.localToGlobal(Offset(glyph.center.dx, (glyph.bottom + band.bottom) / 2)));
      }

      for (var index = 0; index + 1 < renders.length; index++) {
        final upper = renders[index];
        final lower = renders[index + 1];
        final upperBand = _selectionRect(upper);
        final lowerBand = _selectionRect(lower);
        final upperBottom = upper.localToGlobal(Offset(0, upperBand.bottom)).dy;
        final lowerTop = lower.localToGlobal(Offset(0, lowerBand.top)).dy;
        final seamY = (upperBottom + lowerTop) / 2;
        final codeX = lower.localToGlobal(Offset(_firstGlyphRect(lower).center.dx, 0)).dx;
        points.add(Offset(codeX, seamY));
      }

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 1);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: points.first);
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.text,
      reason: '首行顶部 leading 内仍应是 text 光标',
    );
    for (final point in points.skip(1)) {
      await mouse.moveTo(point);
      await tester.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.text,
        reason: '虚拟富文本行的 leading 或相邻行界 $point 不得退回默认光标',
      );
    }
  });

  testWidgets(
    'FileRead 虚拟滚动：拖过正文行间空隙不得反向溢出到导航和工具栏',
    (tester) async {
      await tester.pumpWidget(_fileReadPage(rowCount: 64));
      await tester.pumpAndSettle();

      final anchor = _renderForKey(tester, const ValueKey<String>('file-read-line-text-2'));
      final anchorCenter = anchor.localToGlobal(anchor.size.center(Offset.zero));
      final first = _renderForKey(tester, const ValueKey<String>('file-read-line-text-0'));
      final firstBand = _selectionRect(first);
      final firstGlyph = _firstGlyphRect(first);
      expect(firstGlyph.top - firstBand.top, greaterThan(1), reason: '判别前置：首行字形上方必须有 leading 空隙');
      final gapPoint = first.localToGlobal(Offset(firstGlyph.center.dx, (firstBand.top + firstGlyph.top) / 2));

      final navRect = tester.getRect(find.byKey(_navTitleKey));
      final toolbarRect = tester.getRect(find.byKey(_toolbarTextKey));
      expect(gapPoint.dy, greaterThan(toolbarRect.bottom));
      expect(gapPoint.dy, greaterThan(navRect.bottom));

      final gesture = await tester.startGesture(anchorCenter, kind: PointerDeviceKind.mouse);
      await tester.pump();
      final middle = _renderForKey(tester, const ValueKey<String>('file-read-line-text-1'));
      await gesture.moveTo(middle.localToGlobal(middle.size.center(Offset.zero)));
      await tester.pump();
      await gesture.moveTo(gapPoint);
      await tester.pump();

      final navSelectedAtGap = _isSelected(tester, _navTitleKey);
      final toolbarSelectedAtGap = _isSelected(tester, _toolbarTextKey);
      final firstSelectedAtGap = _isSelected(tester, const ValueKey<String>('file-read-line-text-0'));
      final belowAnchorSelectedAtGap = _isSelected(tester, const ValueKey<String>('file-read-line-text-3'));
      await gesture.up();
      await tester.pump();

      expect(navSelectedAtGap, isFalse, reason: '鼠标仍在正文行间空隙时，导航标题不得被反向带入选区');
      expect(toolbarSelectedAtGap, isFalse, reason: '鼠标仍在正文行间空隙时，工具栏不得被反向带入选区');
      expect(belowAnchorSelectedAtGap, isFalse, reason: '锚点下方的正文行不得因空隙命中错误而反向溢出');
      expect(firstSelectedAtGap, isTrue, reason: '拖选停在首行顶部 leading 时，首行正文应正常进入选区');
    },
  );
}
