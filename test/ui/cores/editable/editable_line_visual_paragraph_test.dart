import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_base/src/flutter/views/editable/render/editable_line_layout.dart';

import 'package:flutter_base/src/flutter/views/editable/render/editable_render_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _baseStyle = TextStyle(fontFamily: 'Ahem', fontSize: 14, height: 1, color: Color(0xff202020));
const _firstFragmentColor = Color(0xffd32f2f);
const _secondFragmentColor = Color(0xff1565c0);

EditableRenderConfig _config({EditableComposer composer = EditableComposer.plain, int tabSize = 4}) =>
    EditableRenderConfig(
      textStyle: _baseStyle,
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
      softWrap: false,
      caretColor: const Color(0xff000000),
      caretWidth: 2,
      selectionColor: const Color(0x403390ff),
      composingUnderline: true,
      composer: composer,
      tabSize: tabSize,
    );

EditableLineVisualFragment _fragment(int start, int end, String text, {int level = 0, double tabPrefix = 0}) =>
    EditableLineVisualFragment(
      lineStart: start,
      lineEnd: end,
      text: text,
      resolvedLevel: level,
      logicalTabPrefix: tabPrefix,
    );

final class _VisualWindowScope extends EditableRenderScope {
  _VisualWindowScope({required super.controller, required super.config, required this._window});

  EditableLineLayoutWindow _window;
  int _windowRevision = 0;

  @override
  int get longLineWindowRevision => _windowRevision;

  @override
  bool usesWindowedLineLayout(int index) => true;

  @override
  EditableLineLayoutWindow longLineWindowFor(int index, Object identity) => _window;

  @override
  bool retainsLongLineWindow(Object identity) => true;

  @override
  EditableLineLayoutWindow reportLongLineWindow(
    Object identity,
    EditableLineLayoutWindow window, {
    required double paragraphWidth,
    TextPainter? paragraphPainter,
    required double insertTrailingExtent,
    required double overwriteTrailingExtent,
  }) => window;

  void replaceWindow(EditableLineLayoutWindow value) {
    _window = value;
    _windowRevision++;
    notifyListeners();
  }
}

final class _OffsetColorComposer implements EditableComposer, EditableWindowedComposer {
  final List<EditableLineContext> calls = <EditableLineContext>[];

  @override
  InlineSpan compose(EditableLineContext context) {
    calls.add(context);
    return TextSpan(
      text: context.text,
      style: context.baseStyle.copyWith(color: context.textStart >= 4 ? _firstFragmentColor : _secondFragmentColor),
    );
  }
}

Widget _host(Widget child, {double width = 320, double height = 80}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, height: height, child: child),
    ),
  ),
);

Future<RenderEditableLine> _mountLine(WidgetTester tester, _VisualWindowScope scope) async {
  await tester.pumpWidget(_host(EditableLineView(scope: scope, index: 0, identity: 'visual-line')));
  await tester.pump();
  return tester.renderObject<RenderEditableLine>(find.byType(EditableLineView));
}

TextPainter _oraclePainter(_VisualWindowScope scope, EditableLineLayoutWindow window) => TextPainter(
  text: scope.spanForVisualWindow(0, window),
  textDirection: window.textDirection,
  textAlign: scope.config.textAlign,
  textScaler: scope.config.textScaler,
)..layout();

List<TextSpan> _leafTextSpans(InlineSpan span) {
  final result = <TextSpan>[];
  void visit(InlineSpan current) {
    if (current is! TextSpan) return;
    if (current.text?.isNotEmpty ?? false) result.add(current);
    for (final child in current.children ?? const <InlineSpan>[]) {
      visit(child);
    }
  }

  visit(span);
  return result;
}

Rect _boxBounds(List<ui.TextBox> boxes) {
  assert(boxes.isNotEmpty);
  return boxes.skip(1).fold(boxes.first.toRect(), (bounds, box) => bounds.expandToInclude(box.toRect()));
}

void _expectRectClose(Rect actual, Rect expected, {double tolerance = 0.01}) {
  expect(actual.left, closeTo(expected.left, tolerance));
  expect(actual.top, closeTo(expected.top, tolerance));
  expect(actual.right, closeTo(expected.right, tolerance));
  expect(actual.bottom, closeTo(expected.bottom, tolerance));
}

void _expectBoxesClose(List<ui.TextBox> actual, List<ui.TextBox> expected, {required double originX}) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < actual.length; index++) {
    final expectedRect = expected[index].toRect().shift(Offset(originX, 0));
    _expectRectClose(actual[index].toRect(), expectedRect);
    expect(actual[index].direction, expected[index].direction);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('visual window 以单一 synthetic Paragraph 排版，composer 保留原始 textStart 与视觉顺序', (tester) async {
    const text = 'abc__אב';
    final composer = _OffsetColorComposer();
    final window = EditableLineLayoutWindow.visual(
      lineLength: text.length,
      fragments: [_fragment(5, 7, 'אב', level: 1, tabPrefix: 70), _fragment(0, 3, 'abc')],
      originX: 11,
      estimatedTextWidth: 220,
      averageAdvance: 14,
    );
    final controller = EditableController(text: text);
    final scope = _VisualWindowScope(
      controller: controller,
      config: _config(composer: composer),
      window: window,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      controller.dispose();
    });

    final line = await _mountLine(tester, scope);
    final painter = line.windowPainter!;
    final calls = composer.calls.toList(growable: false);

    expect(line.layoutedPainter, isNull, reason: 'visual 长行只能暴露唯一的窗口 painter');
    expect(painter.textDirection, TextDirection.ltr, reason: 'synthetic Paragraph 必须固定 LTR 容器方向');
    expect(painter.text!.toPlainText(), window.paragraphText);
    expect(line.paragraphTextForTest, window.paragraphText);
    expect(line.windowTextLengthForTest, window.totalParagraphCodeUnits);
    expect(line.windowContentLengthForTest, window.totalContentCodeUnits);
    expect(calls.map((call) => call.text), ['אב', 'abc']);
    expect(calls.map((call) => call.textStart), [5, 0]);
    expect(calls.every((call) => !call.isCompleteLine && call.lineLength == text.length), isTrue);

    final leaves = _leafTextSpans(painter.text!);
    expect(leaves.singleWhere((span) => span.text == 'אב').style!.color, _firstFragmentColor);
    expect(leaves.singleWhere((span) => span.text == 'abc').style!.color, _secondFragmentColor);

    final oracle = _oraclePainter(scope, window);
    addTearDown(oracle.dispose);
    expect(painter.width, closeTo(oracle.width, 0.01));
    expect(painter.height, closeTo(oracle.height, 0.01));
    final firstBoxes = painter.getBoxesForSelection(
      TextSelection(
        baseOffset: window.fragmentContentRanges.first.start,
        extentOffset: window.fragmentContentRanges.first.end,
      ),
    );
    final secondBoxes = painter.getBoxesForSelection(
      TextSelection(
        baseOffset: window.fragmentContentRanges.last.start,
        extentOffset: window.fragmentContentRanges.last.end,
      ),
    );
    expect(firstBoxes, isNotEmpty);
    expect(secondBoxes, isNotEmpty);
    expect(_boxBounds(firstBoxes).left, lessThan(_boxBounds(secondBoxes).left));
    expect(firstBoxes.every((box) => box.direction == TextDirection.rtl), isTrue);

    final contentRanges = window.fragmentContentRanges;
    for (var paragraphOffset = 0; paragraphOffset <= window.totalParagraphCodeUnits; paragraphOffset++) {
      if (contentRanges.any((range) => paragraphOffset >= range.start && paragraphOffset <= range.end)) continue;
      final x = painter.getOffsetForCaret(TextPosition(offset: paragraphOffset), Rect.zero).dx + window.originX;
      final hit = line.positionForOffset(Offset(x, painter.preferredLineHeight / 2));
      expect(hit.offset, inInclusiveRange(0, window.lineLength), reason: '控制符 offset=$paragraphOffset 不得泄漏为模型 offset');
      expect(window.containsOffset(hit.offset), isTrue);
    }
  });

  testWidgets('caret、窗外 overwrite、跨片段 selection 与 composing 都使用纯正文映射', (tester) async {
    const text = 'abc__אב';
    final window = EditableLineLayoutWindow.visual(
      lineLength: text.length,
      fragments: [_fragment(5, 7, 'אב', level: 1), _fragment(0, 3, 'abc')],
      originX: 9,
      estimatedTextWidth: 180,
      averageAdvance: 14,
    );
    final controller = EditableController(text: text);
    final scope = _VisualWindowScope(controller: controller, config: _config(), window: window)..pump(focused: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      controller.dispose();
    });

    final line = await _mountLine(tester, scope);
    final oracle = _oraclePainter(scope, window);
    addTearDown(oracle.dispose);

    for (final position in const [TextPosition(offset: 1), TextPosition(offset: 6)]) {
      final expected = scope
          .caretRectForPainter(oracle, window.toParagraphPosition(position), overwriteEnd: -1, availableWidth: null)
          .shift(Offset(window.originX, 0));
      _expectRectClose(line.caretRectFor(position), expected);
    }

    const caret = TextPosition(offset: 1);
    final mappedOverwriteEnd = window.toParagraphPosition(const TextPosition(offset: 2)).offset;
    final expectedBlock = scope
        .caretRectForPainter(
          oracle,
          window.toParagraphPosition(caret),
          overwriteEnd: mappedOverwriteEnd,
          availableWidth: null,
        )
        .shift(Offset(window.originX, 0));
    _expectRectClose(line.caretRectFor(caret, overwriteEnd: 2), expectedBlock);

    final outsideOverwrite = line.caretRectFor(caret, overwriteEnd: 4);
    final expectedThin = scope
        .caretRectForPainter(oracle, window.toParagraphPosition(caret), overwriteEnd: -1, availableWidth: null)
        .shift(Offset(window.originX, 0));
    _expectRectClose(outsideOverwrite, expectedThin);
    expect(outsideOverwrite.width, 2, reason: '窗外下一字素不得被钳到任一可见 fragment 形成假 block caret');

    final ranges = window.paragraphRanges(1, 6);
    final expectedBoxes = <ui.TextBox>[
      for (final range in ranges)
        ...oracle.getBoxesForSelection(
          TextSelection(baseOffset: range.start, extentOffset: range.end),
          boxHeightStyle: ui.BoxHeightStyle.max,
        ),
    ];
    final actualBoxes = line.selectionBoxesForLineRange(1, 6);
    _expectBoxesClose(actualBoxes, expectedBoxes, originX: window.originX);
    expect(line.selectionBoxesForLineRange(3, 5), isEmpty, reason: '隐藏 gap 与 synthetic controls 都不可绘制');

    controller.imeUpdateSelection(
      const TextSelection(baseOffset: 1, extentOffset: 6),
      const TextRange(start: 1, end: 6),
    );
    RenderEditableLine.debugResetCounters();
    scope.pumpFromController();
    await tester.pump();
    expect(line.paintStateForTest.selectionStart, 1);
    expect(line.paintStateForTest.selectionEnd, 6);
    expect(line.paintStateForTest.composingStart, 1);
    expect(line.paintStateForTest.composingEnd, 6);
    expect(RenderEditableLine.debugSelectionPaintCount, 1, reason: '多个正文片段统一填充一次，几何范围仍保留隐藏 gap');
  });

  testWidgets('宿主注入代理对中间 selection/composing 时 visual paint 向外归一且不崩溃', (tester) async {
    const text = 'a😀b';
    final window = EditableLineLayoutWindow.visual(
      lineLength: text.length,
      fragments: [_fragment(0, text.length, text)],
      estimatedTextWidth: 80,
      averageAdvance: 14,
    );
    final controller = EditableController(text: text)
      ..setSelection(const TextSelection(baseOffset: 2, extentOffset: 3));
    final scope = _VisualWindowScope(controller: controller, config: _config(), window: window)..pump(focused: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      controller.dispose();
    });

    final line = await _mountLine(tester, scope);
    expect(tester.takeException(), isNull);
    expect(line.selectionBoxesForLineRange(2, 3), isNotEmpty);
    expect(
      line.selectionBoxesForLineRange(2, 3),
      hasLength(line.selectionBoxesForLineRange(1, 3).length),
      reason: 'start 落在 emoji 代理对中间时必须向前覆盖完整 scalar',
    );

    controller.imeUpdateSelection(
      const TextSelection(baseOffset: 2, extentOffset: 3),
      const TextRange(start: 2, end: 3),
    );
    scope.pumpFromController();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL visual 行末 overwrite fallback 与真实 caret 右边界贴合', (tester) async {
    const text = 'אב';
    final window = EditableLineLayoutWindow.visual(
      lineLength: text.length,
      fragments: [_fragment(0, text.length, text, level: 1)],
      estimatedTextWidth: 40,
      averageAdvance: 14,
    );
    final controller = EditableController(text: text);
    final scope = _VisualWindowScope(controller: controller, config: _config(), window: window);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      controller.dispose();
    });

    final line = await _mountLine(tester, scope);
    final lastGlyphBlock = line.caretRectFor(const TextPosition(offset: 1), overwriteEnd: 2);
    expect(lastGlyphBlock.width, greaterThan(2), reason: 'fragment 最后一个字素的半开终点允许落在 fragment.end');
    final thin = line.caretRectFor(const TextPosition(offset: 2));
    final block = line.caretRectFor(const TextPosition(offset: 2), overwriteEnd: 2);
    expect(block.width, greaterThan(thin.width));
    expect(block.right, closeTo(thin.right, 0.01), reason: 'RTL 空白块应以 caret boundary 为右边界，不能多留 caretWidth 缝隙');
  });

  testWidgets('每个 visual fragment 独立继承逻辑 tab prefix', (tester) async {
    const text = '\tA__\tB';
    final window = EditableLineLayoutWindow.visual(
      lineLength: text.length,
      fragments: [_fragment(4, 6, '\tB', tabPrefix: 37), _fragment(0, 2, '\tA', tabPrefix: 0)],
      estimatedTextWidth: 220,
      averageAdvance: 14,
    );
    final controller = EditableController(text: text);
    final scope = _VisualWindowScope(controller: controller, config: _config(tabSize: 4), window: window);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      controller.dispose();
    });

    final line = await _mountLine(tester, scope);
    final painter = line.windowPainter!;
    final widths = <double>[];
    for (var index = 0; index < window.visualFragments.length; index++) {
      final fragment = window.visualFragments[index];
      final content = window.fragmentContentRanges[index];
      final actualBoxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: content.start, extentOffset: content.end),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      final expectedPainter = TextPainter(
        text: scope.spanForText(
          0,
          fragment.text,
          tabInitialAdvance: fragment.logicalTabPrefix,
          completeLine: false,
          textStart: fragment.lineStart,
          lineLength: window.lineLength,
          textDirection: fragment.isRtl ? TextDirection.rtl : TextDirection.ltr,
        ),
        textDirection: fragment.isRtl ? TextDirection.rtl : TextDirection.ltr,
        textScaler: scope.config.textScaler,
      )..layout();
      addTearDown(expectedPainter.dispose);
      final expectedBoxes = expectedPainter.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: fragment.text.length),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      final actualWidth = _boxBounds(actualBoxes).width;
      final expectedWidth = _boxBounds(expectedBoxes).width;
      expect(actualWidth, closeTo(expectedWidth, 0.01), reason: 'fragment $index 必须使用自己的逻辑 tab prefix');
      widths.add(actualWidth);
    }
    expect((widths.first - widths.last).abs(), greaterThan(0.1), reason: '不同逻辑前缀应落到不同 tab stop');
  });

  testWidgets('窗口等价缓存包含 fragment 原始映射与 tab prefix', (tester) async {
    const text = 'aaaaaaaaaa';
    EditableLineLayoutWindow makeWindow({
      int secondStart = 4,
      double secondTabPrefix = 12,
      bool zeroWidthGap = false,
      int generation = 0,
      int metricRevision = 0,
    }) => EditableLineLayoutWindow.visual(
      lineLength: text.length,
      fragments: [
        _fragment(0, 2, 'aa'),
        _fragment(secondStart, secondStart + 2, 'aa', tabPrefix: secondTabPrefix),
      ],
      estimatedTextWidth: 160,
      averageAdvance: 14,
      visualGeneration: generation,
      visualMetricRevision: metricRevision,
      zeroWidthLogicalRanges: zeroWidthGap ? <TextRange>[TextRange(start: 2, end: secondStart)] : const <TextRange>[],
    );

    final controller = EditableController(text: text);
    final scope = _VisualWindowScope(controller: controller, config: _config(), window: makeWindow());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      controller.dispose();
    });

    await _mountLine(tester, scope);
    RenderEditableLine.debugResetCounters();
    scope.replaceWindow(makeWindow());
    await tester.pump();
    expect(RenderEditableLine.debugLayoutCount, 0, reason: '完全等价的新实例不得重排');

    RenderEditableLine.debugResetCounters();
    scope.replaceWindow(makeWindow(secondStart: 6));
    await tester.pump();
    expect(RenderEditableLine.debugLayoutCount, 1, reason: 'paragraphText 相同但原文映射变化必须重排');

    RenderEditableLine.debugResetCounters();
    scope.replaceWindow(makeWindow(secondStart: 6, secondTabPrefix: 29));
    await tester.pump();
    expect(RenderEditableLine.debugLayoutCount, 1, reason: 'paragraphText 相同但 tab prefix 变化必须重排');

    RenderEditableLine.debugResetCounters();
    scope.replaceWindow(makeWindow(secondStart: 6, secondTabPrefix: 29, zeroWidthGap: true));
    await tester.pump();
    expect(RenderEditableLine.debugLayoutCount, 1, reason: '零宽格式区间元数据变化必须重排');

    RenderEditableLine.debugResetCounters();
    scope.replaceWindow(makeWindow(secondStart: 6, secondTabPrefix: 29, zeroWidthGap: true, generation: 2));
    await tester.pump();
    expect(RenderEditableLine.debugLayoutCount, 1, reason: 'pipeline generation 变化必须拒绝旧 Paragraph 缓存');

    RenderEditableLine.debugResetCounters();
    scope.replaceWindow(
      makeWindow(secondStart: 6, secondTabPrefix: 29, zeroWidthGap: true, generation: 2, metricRevision: 1),
    );
    await tester.pump();
    expect(RenderEditableLine.debugLayoutCount, 1, reason: 'tile 宽度代际变化即使总 extent 抵消也必须完成一次确认布局');
  });

  testWidgets('visual synthetic Paragraph 连同控制符严格不超过 64KiB', (tester) async {
    final content = 'x' * (64 * 1024 - 6);
    final window = EditableLineLayoutWindow.visual(
      lineLength: content.length,
      fragments: [_fragment(0, content.length, content)],
      estimatedTextWidth: content.length * 14,
      averageAdvance: 14,
    );
    final controller = EditableController(text: content);
    final scope = _VisualWindowScope(controller: controller, config: _config(), window: window);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      controller.dispose();
    });

    RenderEditableLine.debugResetCounters();
    final line = await _mountLine(tester, scope);
    expect(window.totalParagraphCodeUnits, 64 * 1024);
    expect(line.windowTextLengthForTest, 64 * 1024);
    expect(line.windowContentLengthForTest, 64 * 1024 - 6);
    expect(line.windowPainter!.text!.toPlainText().length, 64 * 1024);
    expect(RenderEditableLine.debugMaxParagraphCodeUnits, lessThanOrEqualTo(64 * 1024));
    expect(line.windowPainter!.width, lessThanOrEqualTo(math.max(window.estimatedTextWidth, 1)));
  });
}
