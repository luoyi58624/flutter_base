import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter_base/src/flutter/views/editable/render/editable_render_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000));
// 默认 1.5 DIP 光标宽度，加上行尾 2 DIP 留白。
const _caretTrailingExtent = 3.5;

Widget _host(Widget child, {double width = 120, double height = 100, TextDirection textDirection = TextDirection.ltr}) {
  return MaterialApp(
    home: Directionality(
      textDirection: textDirection,
      child: Align(
        alignment: .topLeft,
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

RenderEditableLine _line(WidgetTester tester, [int index = 0]) =>
    tester.renderObject<RenderEditableLine>(find.byType(EditableLineView).at(index));

Rect _boxFor(TextPainter painter, int start, int end) {
  final boxes = painter.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end));
  expect(boxes, isNotEmpty);
  return boxes.map((box) => box.toRect()).reduce((left, right) => left.expandToInclude(right));
}

double _alignmentFraction(TextAlign align, TextDirection direction) => switch (align) {
  TextAlign.left => 0.0,
  TextAlign.right => 1.0,
  TextAlign.center => 0.5,
  TextAlign.start => direction == TextDirection.ltr ? 0.0 : 1.0,
  TextAlign.end => direction == TextDirection.ltr ? 1.0 : 0.0,
  TextAlign.justify => direction == TextDirection.ltr ? 0.0 : 1.0,
};

Future<void> _pumpFrames(WidgetTester tester, [int count = 3]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<bool> _pumpReveal(WidgetTester tester, Future<bool> future) async {
  bool? result;
  future.then((value) => result = value);
  for (var i = 0; i < 48 && result == null; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(result, isNotNull, reason: 'revealCaret 必须在有界帧内结清');
  return result!;
}

EditableRenderConfig _config({TextAlign textAlign = TextAlign.start, bool softWrap = false}) => EditableRenderConfig(
  textStyle: _style,
  textDirection: TextDirection.ltr,
  textAlign: textAlign,
  textScaler: TextScaler.noScaling,
  softWrap: softWrap,
  caretColor: const Color(0xff000000),
  caretWidth: 2,
  selectionColor: const Color(0x400000ff),
  composingUnderline: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('公开默认值与 render config equality/hash 包含 textAlign', () {
    expect(EditableView(style: EditableConfiguration()).style.textAlign, TextAlign.start);
    final left = _config(textAlign: TextAlign.left);
    final right = _config(textAlign: TextAlign.right);
    expect(left, isNot(right));
    expect(<EditableRenderConfig>{left, right}, hasLength(2));
    expect(left.hashCode, isNot(right.hashCode));
  });

  testWidgets('LTR/RTL 的 start/end/left/right/center 在 wrap/nowrap 使用真实行宽', (tester) async {
    const aligns = <TextAlign>[TextAlign.start, TextAlign.end, TextAlign.left, TextAlign.right, TextAlign.center];
    for (final softWrap in <bool>[true, false]) {
      for (final direction in TextDirection.values) {
        final text = direction == TextDirection.ltr ? 'ab' : 'אב';
        for (final align in aligns) {
          final controller = EditableController(text: text);
          await tester.pumpWidget(
            _host(
              EditableView(
                controller: controller,
                style: EditableConfiguration(
                  autofocus: true,
                  softWrap: softWrap,
                  textAlign: align,
                  textStyle: _style,
                  scrollbar: const ElNoScrollBar(),
                ),
              ),
              textDirection: direction,
            ),
          );
          await _pumpFrames(tester);

          final line = _line(tester);
          final painter = line.layoutedPainter!;
          final box = _boxFor(painter, 0, text.length);
          final expectedLeft = (painter.width - box.width) * _alignmentFraction(align, direction);
          expect(box.left, closeTo(expectedLeft, 0.01), reason: 'softWrap=$softWrap direction=$direction align=$align');
          expect(painter.textAlign, align);
          expect(painter.textDirection, direction);
          expect(line.paintStateForTest.carets, hasLength(1), reason: '对齐不得制造第二 caret');
          if (softWrap) {
            expect(painter.width, closeTo(line.size.width, 0.01));
          } else {
            expect(painter.width + _caretTrailingExtent, closeTo(line.size.width, 0.01));
          }

          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        }
      }
    }
  });

  testWidgets('nowrap 右对齐短文首帧即使用视口宽，空文不溢出且只有一个 caret', (tester) async {
    final short = EditableController(text: 'ab');
    final shortKey = GlobalKey<EditableViewTestState>();
    await tester.pumpWidget(
      _host(
        EditableView(
          key: shortKey,
          controller: short,
          style: EditableConfiguration(
            autofocus: true,
            softWrap: false,
            textAlign: .right,
            textStyle: _style,
            scrollbar: const ElNoScrollBar(),
          ),
        ),
      ),
    );

    final shortLine = _line(tester);
    final shortPainter = shortLine.layoutedPainter!;
    final shortBox = _boxFor(shortPainter, 0, 2);
    expect(shortPainter.width + _caretTrailingExtent, closeTo(120, 0.01));
    expect(shortBox.right, closeTo(shortPainter.width, 0.01));
    expect(shortKey.currentState!.rectAtOffset(2)!.right, lessThanOrEqualTo(120));
    expect(shortLine.paintStateForTest.carets, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    short.dispose();

    for (final align in <TextAlign>[TextAlign.left, TextAlign.center, TextAlign.right]) {
      final controller = EditableController();
      final key = GlobalKey<EditableViewTestState>();
      final horizontal = ScrollController();
      await tester.pumpWidget(
        _host(
          EditableView(
            key: key,
            controller: controller,
            horizontalScrollController: horizontal,
            style: EditableConfiguration(
              autofocus: true,
              softWrap: false,
              textAlign: align,
              textStyle: _style,
              scrollbar: const ElNoScrollBar(),
            ),
          ),
        ),
      );
      await _pumpFrames(tester);
      final line = _line(tester);
      final painter = line.layoutedPainter!;
      final expected = painter.width * _alignmentFraction(align, TextDirection.ltr);
      expect(key.currentState!.rectAtOffset(0)!.left, closeTo(expected, 0.01), reason: '$align');
      expect(line.paintStateForTest.carets, hasLength(1));
      expect(horizontal.position.maxScrollExtent, closeTo(0, 0.01));

      await tester.pumpWidget(const SizedBox());
      horizontal.dispose();
      controller.dispose();
    }
  });

  testWidgets('wrap 的末视觉行按 center/right 对齐且命中、选择与 caret 同轴', (tester) async {
    for (final align in <TextAlign>[TextAlign.center, TextAlign.right]) {
      final controller = EditableController(text: 'abcdefgh');
      final key = GlobalKey<EditableViewTestState>();
      await tester.pumpWidget(
        _host(
          EditableView(
            key: key,
            controller: controller,
            style: EditableConfiguration(
              autofocus: true,
              textAlign: align,
              textStyle: _style,
              scrollbar: const ElNoScrollBar(),
            ),
          ),
          width: 60,
        ),
      );
      await _pumpFrames(tester);

      final line = _line(tester);
      final painter = line.layoutedPainter!;
      final tail = _boxFor(painter, 6, 8);
      final expectedLeft = (painter.width - tail.width) * _alignmentFraction(align, TextDirection.ltr);
      expect(tail.left, closeTo(expectedLeft, 0.01));
      expect(tail.top, closeTo(10, 0.01));
      final caret = key.currentState!.rectAtOffset(6)!;
      expect(caret.left, closeTo(tail.left, 0.01));
      final global = line.localToGlobal(tail.center);
      expect(key.currentState!.positionAtGlobal(global).offset, inInclusiveRange(6, 8));
      expect(line.paintStateForTest.carets, hasLength(1));

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
  });

  testWidgets('外框热变宽只在安全帧尾发布 viewport，不在祖先 layout 中变异行节点', (tester) async {
    final controller = EditableController(text: 'ab');
    final key = GlobalKey<EditableViewTestState>();

    Widget editor(double width) => _host(
      EditableView(
        key: key,
        controller: controller,
        style: EditableConfiguration(
          softWrap: false,
          textAlign: .right,
          textStyle: _style,
          scrollbar: const ElNoScrollBar(),
        ),
      ),
      width: width,
    );

    await tester.pumpWidget(editor(120));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(_line(tester).layoutedPainter!.width + _caretTrailingExtent, closeTo(120, 0.01));

    await tester.pumpWidget(editor(180));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull, reason: 'layout 期间不得经 scope notifyListeners 反向标脏后代');
    expect(_line(tester).layoutedPainter!.width + _caretTrailingExtent, closeTo(180, 0.01));

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('nowrap 长文保留固有宽、横滚与 reveal，textAlign 不伪造额外宽度', (tester) async {
    final controller = EditableController(text: 'x' * 30)..collapseTo(30);
    final horizontal = ScrollController();
    final key = GlobalKey<EditableViewTestState>();
    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          horizontalScrollController: horizontal,
          style: EditableConfiguration(
            autofocus: true,
            softWrap: false,
            textAlign: .right,
            textStyle: _style,
            scrollbar: const ElNoScrollBar(),
          ),
        ),
        width: 80,
      ),
    );
    await _pumpFrames(tester, 5);

    final line = _line(tester);
    final painter = line.layoutedPainter!;
    final box = _boxFor(painter, 0, 30);
    expect(painter.maxIntrinsicWidth, closeTo(300, 0.01));
    expect(painter.width, closeTo(300, 0.01));
    expect(line.size.width, closeTo(300 + _caretTrailingExtent, 0.01));
    expect(box.left, closeTo(0, 0.01));
    expect(horizontal.position.maxScrollExtent, greaterThan(200));
    expect(await _pumpReveal(tester, key.currentState!.revealCaret()), isTrue);
    expect(horizontal.position.pixels, greaterThan(200));
    expect(line.paintStateForTest.carets, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    horizontal.dispose();
    controller.dispose();
  });

  testWidgets('selection/composing/pointer/reveal 全部复用 aligned painter 几何', (tester) async {
    final controller = EditableController(text: 'abcd')
      ..setSelection(const TextSelection(baseOffset: 1, extentOffset: 3));
    final horizontal = ScrollController();
    final key = GlobalKey<EditableViewTestState>();
    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          horizontalScrollController: horizontal,
          style: EditableConfiguration(
            autofocus: true,
            softWrap: false,
            textAlign: .center,
            textStyle: _style,
            scrollbar: const ElNoScrollBar(),
          ),
        ),
      ),
    );
    await _pumpFrames(tester);

    var line = _line(tester);
    var painter = line.layoutedPainter!;
    final selected = _boxFor(painter, 1, 3);
    expect(line.paintStateForTest.selections, hasLength(1));
    expect(key.currentState!.rectAtOffset(1)!.left, closeTo(selected.left, 0.01));
    expect(key.currentState!.positionAtGlobal(line.localToGlobal(selected.center)).offset, inInclusiveRange(1, 3));

    controller.imeReplace(
      0,
      4,
      'abcd',
      selection: const TextSelection.collapsed(offset: 2),
      composing: const TextRange(start: 1, end: 3),
    );
    await tester.pump();
    line = _line(tester);
    painter = line.layoutedPainter!;
    final composing = _boxFor(painter, 1, 3);
    expect(line.paintStateForTest.composingStart, 1);
    expect(line.paintStateForTest.composingEnd, 3);
    expect(composing, selected);
    expect(line.paintStateForTest.carets, hasLength(1), reason: 'composing 期间也只能有一个真实 caret');
    final caret = key.currentState!.rectAtOffset(2)!;
    expect(key.currentState!.positionAtGlobal(line.localToGlobal(caret.center)).offset, 2);
    expect(await _pumpReveal(tester, key.currentState!.revealCaret()), isTrue);
    expect(horizontal.position.pixels, closeTo(0, 0.01));

    controller.finishImeComposition(commit: true);
    await tester.pumpWidget(const SizedBox());
    horizontal.dispose();
    controller.dispose();
  });

  testWidgets('Tab+bidi 的 mounted/shared painter 对齐与几何完全一致', (tester) async {
    final controller = EditableController(text: 'a\tאב')..collapseTo(1);
    final scope = EditableRenderScope(
      controller: controller,
      config: _config(textAlign: TextAlign.right),
    )..pump(focused: true);

    await tester.pumpWidget(_host(SizedBox(width: 120, height: 20, child: EditableLineView(scope: scope, index: 0))));
    await tester.pump();

    final line = _line(tester);
    final mounted = line.layoutedPainter!;
    final mountedBoxes = mounted
        .getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 4))
        .map((box) => box.toRect())
        .toList();
    final mountedWidth = mounted.width;
    final mountedCaret = scope.caretRectInLine(0, const TextPosition(offset: 1));
    expect(mounted.textAlign, TextAlign.right);
    expect(mounted.width + _config().caretWidth + 2, closeTo(120, 0.01));
    expect(line.paintStateForTest.carets, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    final shared = scope.painterFor(0);
    final sharedBoxes = shared
        .getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 4))
        .map((box) => box.toRect())
        .toList();
    final sharedCaret = scope.caretRectInLine(0, const TextPosition(offset: 1));
    expect(shared.textAlign, TextAlign.right);
    expect(shared.width, closeTo(mountedWidth, 0.01));
    expect(sharedBoxes, orderedEquals(mountedBoxes));
    expect(sharedCaret, mountedCaret);

    scope.dispose();
    controller.dispose();
  });

  testWidgets('热切换 textAlign 重排同一行、更新 IME style 且不重连/不增 caret', (tester) async {
    final controller = EditableController(text: 'ab')..collapseTo(2);
    final focusNode = FocusNode();
    final key = GlobalKey<EditableViewTestState>();

    Widget editor(TextAlign align) => _host(
      EditableView(
        key: key,
        controller: controller,
        focusNode: focusNode,
        style: EditableConfiguration(
          autofocus: true,
          softWrap: false,
          textAlign: align,
          textStyle: _style,
          scrollbar: const ElNoScrollBar(),
        ),
      ),
    );

    await tester.pumpWidget(editor(TextAlign.left));
    await _pumpFrames(tester);
    final before = _boxFor(_line(tester).layoutedPainter!, 0, 2).left;
    final initialStyle = tester.testTextInput.log.lastWhere((call) => call.method == 'TextInput.setStyle');
    expect((initialStyle.arguments as Map<dynamic, dynamic>)['textAlignIndex'], TextAlign.left.index);

    tester.testTextInput.log.clear();
    RenderEditableLine.debugResetCounters();
    await tester.pumpWidget(editor(TextAlign.right));
    await _pumpFrames(tester);

    final line = _line(tester);
    final after = _boxFor(line.layoutedPainter!, 0, 2).left;
    expect(after, greaterThan(before));
    expect(RenderEditableLine.debugLayoutCount, greaterThanOrEqualTo(1));
    expect(line.paintStateForTest.carets, hasLength(1));
    final styles = tester.testTextInput.log.where((call) => call.method == 'TextInput.setStyle').toList();
    expect(styles, hasLength(1), reason: '配置热切只应推一次新 style');
    expect((styles.single.arguments as Map<dynamic, dynamic>)['textAlignIndex'], TextAlign.right.index);
    expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.setClient'), isEmpty);

    await tester.pumpWidget(const SizedBox());
    focusNode.dispose();
    controller.dispose();
  });

  testWidgets('Windows inset scrollbar 使用真实 305px viewport，并正确扣除非对称 padding', (tester) async {
    final text = <String>['ab', 'x' * 80, ...List<String>.generate(30, (index) => 'row $index')].join('\n');
    final controller = EditableController(text: text);
    final horizontal = ScrollController();
    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          horizontalScrollController: horizontal,
          style: EditableConfiguration(
            softWrap: false,
            textAlign: .right,
            textStyle: _style,
            contentPadding: const EdgeInsets.only(left: 10, right: 20),
            scrollbar: const ElWindowScrollBar(),
            cacheExtent: 0,
          ),
        ),
        width: 320,
        height: 180,
      ),
    );
    await _pumpFrames(tester, 8);

    expect(horizontal.position.viewportDimension, closeTo(305, 0.01));
    final painter = _line(tester).layoutedPainter!;
    expect(
      painter.width + _caretTrailingExtent,
      closeTo(305 - 30, 0.01),
      reason: '短行对齐宽度必须来自真实 viewport，且 padding 只能扣一次',
    );
    final box = _boxFor(painter, 0, 2);
    expect(box.right, closeTo(painter.width, 0.01));

    await tester.pumpWidget(const SizedBox());
    horizontal.dispose();
    controller.dispose();
  });
}
