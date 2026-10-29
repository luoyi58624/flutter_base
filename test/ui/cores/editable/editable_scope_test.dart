import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter_base/src/ui/cores/editable/render/editable_render_scope.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试字体：fontSize 10 + height 1.0 → 行高 10、字宽 10。
const _style = TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000));

EditableRenderScope _makeScope(EditableController controller, {double width = 100}) {
  final scope = EditableRenderScope(
    controller: controller,
    config: const EditableRenderConfig(
      textStyle: _style,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      softWrap: true,
      caretColor: Color(0xff000000),
      caretWidth: 2.0,
      selectionColor: Color(0x400000ff),
      composingUnderline: true,
    ),
  );
  scope.reportLayoutWidth(width);
  return scope;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('paintStateOf', () {
    test('跨行选区：首行截断 + 中间行全选 + 换行延伸标记', () {
      final controller = EditableController(text: 'aa\nbb\ncc');
      controller.setSelection(const TextSelection(baseOffset: 1, extentOffset: 7));
      final scope = _makeScope(controller)..pump(focused: true);

      final line0 = scope.paintStateOf(0);
      expect(line0.selectionStart, 1);
      expect(line0.selectionEnd, 2);
      expect(line0.selectsNewline, isTrue);

      final line1 = scope.paintStateOf(1);
      expect(line1.selectionStart, 0);
      expect(line1.selectionEnd, 2);
      expect(line1.selectsNewline, isTrue);

      final line2 = scope.paintStateOf(2);
      expect(line2.selectionStart, 0);
      expect(line2.selectionEnd, 1);
      expect(line2.selectsNewline, isFalse);
      scope.dispose();
    });

    test('caret 行归属：行尾 offset 属本行、下一行行首属下一行', () {
      final controller = EditableController(text: 'ab\ncd');
      final scope = _makeScope(controller)..pump(focused: true);

      controller.collapseTo(2); // 'ab' 行尾
      expect(scope.paintStateOf(0).caretOffset, 2);
      expect(scope.paintStateOf(1).caretOffset, -1);

      controller.collapseTo(3); // 'cd' 行首
      expect(scope.paintStateOf(0).caretOffset, -1);
      expect(scope.paintStateOf(1).caretOffset, 0);
      scope.dispose();
    });

    test('聚焦的正向、反向与跨行选区都在 active 端绘制 caret', () {
      final forwardController = EditableController(text: 'abcdef')
        ..setSelection(const TextSelection(baseOffset: 1, extentOffset: 4));
      final forwardScope = _makeScope(forwardController)..pump(focused: true);
      expect(forwardScope.paintStateOf(0).carets, const [EditableLineCaretPaint(offset: 4, upstream: false)]);

      final reverseController = EditableController(text: 'abcdef')
        ..setSelection(const TextSelection(baseOffset: 4, extentOffset: 1));
      final reverseScope = _makeScope(reverseController)..pump(focused: true);
      expect(reverseScope.paintStateOf(0).carets, const [EditableLineCaretPaint(offset: 1, upstream: false)]);

      final crossLineController = EditableController(text: 'abc\ndef')
        ..setSelection(const TextSelection(baseOffset: 1, extentOffset: 5));
      final crossLineScope = _makeScope(crossLineController)..pump(focused: true);
      expect(crossLineScope.paintStateOf(0).carets, isEmpty);
      expect(crossLineScope.paintStateOf(1).carets, const [EditableLineCaretPaint(offset: 1, upstream: false)]);

      forwardScope.dispose();
      reverseScope.dispose();
      crossLineScope.dispose();
      forwardController.dispose();
      reverseController.dispose();
      crossLineController.dispose();
    });

    test('未聚焦不出 caret；聚焦后可见相位出 caret', () {
      final controller = EditableController(text: 'ab');
      final scope = _makeScope(controller);
      controller.collapseTo(1);
      expect(scope.paintStateOf(0).hasCaret, isFalse);

      scope.pump(focused: true);
      expect(scope.paintStateOf(0).caretOffset, 1);
      expect(scope.paintStateOf(0).caretVisible, isTrue);

      scope.dispose();
    });

    test('composing 局部映射', () {
      final controller = EditableController(text: 'aa\nbbbb');
      controller.imeReplace(
        5,
        5,
        'ni',
        selection: const TextSelection.collapsed(offset: 7),
        composing: const TextRange(start: 5, end: 7),
      );
      final scope = _makeScope(controller);
      final line1 = scope.paintStateOf(1);
      expect(line1.composingStart, 2);
      expect(line1.composingEnd, 4);
      expect(scope.paintStateOf(0).hasComposing, isFalse);
      scope.dispose();
    });
  });

  group('布局查询（wrap 100px = 每视觉行 10 字符）', () {
    test('visualLineEdge：wrap 行的视觉行首尾', () {
      final controller = EditableController(text: 'a' * 20);
      final scope = _makeScope(controller);

      final end0 = scope.visualLineEdge(const TextPosition(offset: 3), end: true);
      expect(end0.offset, 10);
      expect(end0.affinity, TextAffinity.upstream);

      final start1 = scope.visualLineEdge(const TextPosition(offset: 15), end: false);
      expect(start1.offset, 10);

      final end1 = scope.visualLineEdge(const TextPosition(offset: 15), end: true);
      expect(end1.offset, 20);
      scope.dispose();
    });

    test('moveVertical：逻辑行内跨视觉行', () {
      final controller = EditableController(text: 'a' * 20);
      final scope = _makeScope(controller);

      final down = scope.moveVertical(const TextPosition(offset: 3), down: true, xGoal: 12);
      expect(down!.offset, 11);

      final up = scope.moveVertical(const TextPosition(offset: 15), down: false, xGoal: 52);
      expect(up!.offset, 5);
      scope.dispose();
    });

    test('moveVertical：跨逻辑行 + 文档边界返回 null', () {
      final controller = EditableController(text: 'aaa\nbb');
      final scope = _makeScope(controller);

      final down = scope.moveVertical(const TextPosition(offset: 1), down: true, xGoal: 12);
      expect(down!.offset, 5); // 'bb' 第 1 列

      final clampedDown = scope.moveVertical(const TextPosition(offset: 1), down: true, xGoal: 55);
      expect(clampedDown!.offset, 6); // xGoal 超行宽钳到行尾

      expect(scope.moveVertical(const TextPosition(offset: 1), down: false, xGoal: 0), isNull);
      expect(scope.moveVertical(const TextPosition(offset: 5), down: true, xGoal: 0), isNull);
      scope.dispose();
    });

    test('pageMove：按页高步进视觉行', () {
      final controller = EditableController(text: List.generate(6, (i) => 'xxxxx').join('\n'));
      final scope = _makeScope(controller);

      final target = scope.pageMove(const TextPosition(offset: 0), down: true, xGoal: 0, pageExtent: 25);
      expect(controller.document.lineIndexOf(target.offset), 3);

      // 到底钳制不越界。
      final bottom = scope.pageMove(const TextPosition(offset: 0), down: true, xGoal: 0, pageExtent: 1000);
      expect(controller.document.lineIndexOf(bottom.offset), 5);
      scope.dispose();
    });

    test('wordBoundary / docPositionInLine / caretRectInLine', () {
      final controller = EditableController(text: 'foo bar\nzzz');
      final scope = _makeScope(controller);

      final word = scope.wordBoundary(const TextPosition(offset: 5));
      expect(word.start, 4);
      expect(word.end, 7);

      final hit = scope.docPositionInLine(1, const Offset(12, 5));
      expect(hit.offset, 9); // 'zzz' 行首 8 + 1

      final rect = scope.caretRectInLine(0, const TextPosition(offset: 4));
      expect(rect.left, 40);
      expect(rect.top, 0);
      expect(rect.height, 10);
      scope.dispose();
    });

    test('wrap caret 亲和：同 offset 折行点上下两个几何', () {
      final controller = EditableController(text: 'a' * 20);
      final scope = _makeScope(controller);

      final downstream = scope.caretRectInLine(0, const TextPosition(offset: 10));
      expect(downstream.top, 10);
      expect(downstream.left, 0);

      final upstream = scope.caretRectInLine(0, const TextPosition(offset: 10, affinity: TextAffinity.upstream));
      expect(upstream.top, 0);
      expect(upstream.left, 100);
      scope.dispose();
    });
  });
}
