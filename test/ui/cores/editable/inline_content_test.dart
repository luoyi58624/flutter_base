import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart'
    show EditableControllerTestAccess, InlineContent, InlineContentMatcher;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _image(BuildContext context) => ElView(style: ElStyle(width: 22, height: 22));

void main() {
  test('最长匹配、重叠消歧和未知 token 都保留确定的原文区间', () {
    final content = InlineContent({'[1]': _image, '[12]': _image, 'ab': _image, 'abc': _image, 'bc': _image});
    final matches = content.matcher.matches('前[12][99]abc[1]').toList();
    expect(matches.map((m) => m.token), ['[12]', 'abc', '[1]']);
    final controller = ElEditableController(text: 'abc', inlineContent: content.builders);
    addTearDown(controller.dispose);
    expect(content.containing(controller, 2)!.token, 'abc');
  });

  test('原文选区不能停在对象内部，局部替换与撤销按完整对象处理', () {
    final controller = ElEditableController(text: '前[12]后', inlineContent: {'[12]': _image});
    addTearDown(controller.dispose);
    controller.collapseTo(3);
    expect(controller.selection.extentOffset, 5);
    controller.collapseTo(4);
    expect(controller.selection.extentOffset, 1);
    controller.setSelection(TextSelection(baseOffset: 4, extentOffset: 2));
    expect(controller.selection, TextSelection(baseOffset: 5, extentOffset: 1));
    expect(controller.selectedText, '[12]');
    controller.replaceRange(3, 4, 'x');
    expect(controller.text, '前x后');
    expect(controller.selection.extentOffset, 2);
    expect(controller.undoEdit(), isTrue);
    expect(controller.text, '前[12]后');
    expect(controller.redoEdit(), isTrue);
    expect(controller.text, '前x后');
  });

  test('共享视口复用原始表，更新构建器不重新编译 token', () {
    final controller = ElEditableController(text: '[1]', inlineContent: {'[1]': _image});
    final view = ElEditableController.view(controller);
    addTearDown(view.dispose);
    addTearDown(controller.dispose);
    controller.collapseTo(1);
    final compiled = InlineContentMatcher.debugCompileCount;
    expect(view.inlineContent, same(controller.inlineContent));
    controller.inlineContent = {'[1]': (_) => ElView()};
    expect(InlineContentMatcher.debugCompileCount, compiled);
    view.insertText('[1]');
    expect(controller.text, '[1][1]');
    expect(() => controller.inlineContent['[2]'] = _image, throwsUnsupportedError);
  });

  test('活动组合保持原始文字和内部选区，结束后恢复对象边界', () {
    final controller = ElEditableController(inlineContent: {'[12]': _image});
    addTearDown(controller.dispose);
    controller.testModel.imeReplace(
      0,
      0,
      '[12]',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 4),
    );
    expect(controller.selection.extentOffset, 2);
    expect(controller.composing, TextRange(start: 0, end: 4));
    controller.finishImeComposition();
    expect(controller.composing, TextRange.empty);
    expect(controller.selection.extentOffset, 4);
    controller.undoEdit();
    expect(controller.text, '');
  });

  test('分隔符 token 的端点查询只读取有界文字，不物化超长行', () {
    final text = '${'a' * 100000}[12]${'b' * 100000}';
    final controller = ElEditableController(text: text, inlineContent: {'[12]': _image});
    addTearDown(controller.dispose);
    final before = InlineContentMatcher.debugScannedCodeUnits;
    controller.collapseTo(100002);
    expect(controller.selection.extentOffset, 100004);
    expect(InlineContentMatcher.debugScannedCodeUnits - before, lessThanOrEqualTo(12));
  });

  test('平台单字符删除也扩展整张表情，撤销恢复编码', () {
    final controller = ElEditableController(text: '前[12]后', inlineContent: {'[12]': _image});
    addTearDown(controller.dispose);
    controller.testModel.imeReplace(
      4,
      5,
      '',
      selection: TextSelection.collapsed(offset: 4),
      composing: TextRange.empty,
    );
    expect(controller.text, '前后');
    expect(controller.selection.extentOffset, 1);
    controller.undoEdit();
    expect(controller.text, '前[12]后');
  });
}
