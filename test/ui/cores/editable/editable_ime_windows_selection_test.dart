import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_base/src/ui/cores/editable/editable_controller.dart';
import 'package:flutter_base/src/ui/cores/editable/ime/editable_ime_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Windows 同批开始组合与后续文本替换使用归一化后的范围', (tester) async {
    final controller = EditableController(text: 'before')..setSelection(TextSelection(baseOffset: 6, extentOffset: 0));
    final client = EditableImeClient(controller: controller);
    addTearDown(controller.dispose);
    addTearDown(client.close);
    client.open(TextInputConfiguration(enableDeltaModel: true));
    final revision = controller.docRevision;
    client.updateEditingValueWithDeltas([
      TextEditingDeltaNonTextUpdate(
        oldText: 'before',
        selection: controller.selection,
        composing: TextRange.collapsed(0),
      ),
      TextEditingDeltaInsertion(
        oldText: 'before',
        textInserted: 'a',
        insertionOffset: 0,
        selection: TextSelection.collapsed(offset: -1),
        composing: TextRange(start: 0, end: 1),
      ),
      TextEditingDeltaReplacement(
        oldText: 'a',
        replacementText: 'av',
        replacedRange: TextRange(start: 0, end: 1),
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    ]);
    expect(controller.text, 'av');
    expect(controller.docRevision, revision + 1);
    expect(controller.composing, TextRange(start: 0, end: 2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows 非组合显式插入仍严格保留 delta 原始范围', (tester) async {
    final controller = EditableController(text: 'old')..setSelection(TextSelection(baseOffset: 0, extentOffset: 3));
    final client = EditableImeClient(controller: controller);
    addTearDown(controller.dispose);
    addTearDown(client.close);
    client.open(TextInputConfiguration(enableDeltaModel: true));
    client.updateEditingValueWithDeltas([
      TextEditingDeltaInsertion(
        oldText: 'old',
        textInserted: 'a',
        insertionOffset: 0,
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange.empty,
      ),
    ]);
    expect(controller.text, 'aold');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  for (final scenario in [
    (name: '全选', text: '尺寸尝试多次受到', selection: TextSelection(baseOffset: 0, extentOffset: 8)),
    (name: '反向局部选择', text: '头部旧文本尾部', selection: TextSelection(baseOffset: 5, extentOffset: 2)),
    (name: '跨 IME 窗口反向全选', text: 'x' * 100000, selection: TextSelection(baseOffset: 100000, extentOffset: 0)),
    (name: '非零窗口起点全选', text: 'x' * 100000, selection: TextSelection(baseOffset: 0, extentOffset: 100000)),
  ]) {
    testWidgets('Windows ${scenario.name} 首个拼音立即替换原选区且整次组合一步撤销', (tester) async {
      final controller = EditableController(text: scenario.text)..setSelection(scenario.selection);
      final client = EditableImeClient(controller: controller);
      addTearDown(controller.dispose);
      addTearDown(client.close);
      client.open(TextInputConfiguration(enableDeltaModel: true));
      final state = tester.testTextInput.editingState!;
      final remoteText = state['text'] as String;
      final remoteSelection = TextSelection(
        baseOffset: state['selectionBase'] as int,
        extentOffset: state['selectionExtent'] as int,
      );
      final start = remoteSelection.start;
      tester.testTextInput.log.clear();

      client.updateEditingValueWithDeltas([
        TextEditingDeltaNonTextUpdate(
          oldText: remoteText,
          selection: remoteSelection,
          composing: TextRange.collapsed(start),
        ),
      ]);
      expect(controller.selection, scenario.selection);
      // Windows 引擎先删除 selection，但首笔 delta 仍使用删除前的 collapsed composing_range。
      client.updateEditingValueWithDeltas([
        TextEditingDeltaInsertion(
          oldText: remoteText,
          textInserted: 'a',
          insertionOffset: start,
          selection: TextSelection.collapsed(offset: start + 1),
          composing: TextRange(start: start, end: start + 1),
        ),
      ]);
      final prefix = scenario.text.substring(0, scenario.selection.start);
      final suffix = scenario.text.substring(scenario.selection.end);
      expect(controller.text, '${prefix}a$suffix', reason: '不能等第二个字母的 oldText 失步再被动修正');
      final first = controller.text;
      final caret = prefix.length;
      client.updateEditingValueWithDeltas([
        TextEditingDeltaReplacement(
          oldText: first,
          replacementText: 'av',
          replacedRange: TextRange(start: caret, end: caret + 1),
          selection: TextSelection.collapsed(offset: caret + 2),
          composing: TextRange(start: caret, end: caret + 2),
        ),
      ]);
      expect(controller.text, '${prefix}av$suffix');
      client.updateEditingValueWithDeltas([
        TextEditingDeltaReplacement(
          oldText: controller.text,
          replacementText: '啊',
          replacedRange: TextRange(start: caret, end: caret + 2),
          selection: TextSelection.collapsed(offset: caret + 1),
          composing: TextRange.empty,
        ),
      ]);
      expect(controller.text, '$prefix啊$suffix');
      expect(
        tester.testTextInput.log.where((call) => call.method == 'TextInput.setEditingState'),
        isEmpty,
        reason: '识别平台真实替换意图即可，不应回推编辑状态打断输入法',
      );
      expect(controller.undoEdit(), isTrue);
      expect(controller.text, scenario.text);
      expect(controller.selection, scenario.selection);
      expect(controller.canUndo, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
