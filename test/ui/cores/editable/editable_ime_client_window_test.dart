import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter_base/src/flutter/views/editable/ime/editable_ime_client.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// IME client 窗口化通道的无渲染回归：大选区窗口钳制下的通道负载与越窗替换。
void main() {
  testWidgets('同修订与同锚点扩选时，窗口跟随活动端重建', (tester) async {
    final controller = EditableController(text: List.generate(120, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);

    controller.collapseTo(0);
    final revision = controller.docRevision;
    client.open(const TextInputConfiguration());
    final initial = tester.testTextInput.editingState!['text'] as String;
    expect(initial, 'line 0');

    controller.setSelection(TextSelection(baseOffset: 0, extentOffset: controller.document.length));
    expect(controller.docRevision, revision);
    expect(controller.selection.baseOffset, 0);
    client.syncFromController();

    final expanded = tester.testTextInput.editingState!['text'] as String;
    expect(expanded, isNot(initial));
    expect(expanded, endsWith('line 119'), reason: '大选区窗口必须围绕活动端，而不是复用锚点所在行');
  });

  testWidgets('同修订同窗口的选区与 composing 变化复用正文字符串，编辑后才重读', (tester) async {
    final text = 'a' * 12000;
    final controller = EditableController(text: text)..collapseTo(100);
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);

    client.open(const TextInputConfiguration());
    final seededText = client.currentTextEditingValue!.text;
    expect(client.debugWindowTextBuildCount, 1);
    expect(client.debugWindowTextReuseCount, 0);
    expect(client.debugCachedWindowTextCodeUnits, text.length);

    controller.collapseTo(101);
    client.syncFromController();
    expect(identical(client.currentTextEditingValue!.text, seededText), isTrue);
    expect(client.debugWindowTextBuildCount, 1);
    expect(client.debugWindowTextReuseCount, 1);

    controller.imeUpdateSelection(const TextSelection.collapsed(offset: 102), const TextRange(start: 100, end: 102));
    client.syncFromController();
    expect(identical(client.currentTextEditingValue!.text, seededText), isTrue);
    expect(client.debugWindowTextBuildCount, 1);
    expect(client.debugWindowTextReuseCount, 2);

    controller.replaceRange(0, 0, 'b');
    client.syncFromController();
    expect(client.currentTextEditingValue!.text, 'b$text');
    expect(client.debugWindowTextBuildCount, 2, reason: '正文修订变化必须丢弃旧窗口字符串');

    client.close();
    expect(client.currentTextEditingValue, isNull);
    expect(client.debugCachedWindowTextCodeUnits, 0, reason: '关闭连接不得长期钉住 autofill/窗口全文');
  });

  testWidgets('selection-only delta 复用已推窗口正文且不回读 piece tree', (tester) async {
    final text = 'a' * 12000;
    final controller = EditableController(text: text)..collapseTo(100);
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);

    client.open(const TextInputConfiguration(enableDeltaModel: true));
    final old = client.currentTextEditingValue!;
    final reuseBefore = client.debugWindowTextReuseCount;
    TextDocument.debugResetGetTextCounters();

    client.updateEditingValueWithDeltas([
      TextEditingDeltaNonTextUpdate(
        oldText: old.text,
        selection: const TextSelection.collapsed(offset: 101),
        composing: TextRange.empty,
      ),
    ]);

    expect(controller.selection, const TextSelection.collapsed(offset: 101));
    expect(controller.docRevision, 0);
    expect(TextDocument.debugGetTextCallCount, 0, reason: 'delta 校验与回推必须共享已缓存窗口正文');
    expect(client.debugWindowTextBuildCount, 1);
    expect(client.debugWindowTextReuseCount, greaterThan(reuseBefore));
  });

  testWidgets('同修订与同选区切换自动填充时，窗口在全文与有界模式间重建', (tester) async {
    final text = '${'a' * 12000}\n${'b' * 12000}';
    final selection = TextSelection.collapsed(offset: text.length ~/ 2);
    final controller = EditableController(text: text)..setSelection(selection);
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);

    client.open(const TextInputConfiguration());
    expect(tester.testTextInput.editingState!['text'], isNot(text), reason: '普通 IME 通道必须保持有界');

    client.updateConfiguration(
      TextInputConfiguration(
        autofillConfiguration: AutofillConfiguration(
          uniqueIdentifier: 'ime-window-cache-autofill',
          autofillHints: const <String>[],
          currentEditingValue: TextEditingValue(text: text, selection: selection),
        ),
      ),
    );
    expect(tester.testTextInput.editingState!['text'], text, reason: '自动填充连接必须拿到完整字段文本');

    client.updateConfiguration(const TextInputConfiguration());
    expect(tester.testTextInput.editingState!['text'], isNot(text), reason: '退出自动填充后必须恢复有界窗口');
  });

  testWidgets('同修订与同选区改变 composing 时，窗口覆盖新的组合区间', (tester) async {
    final text = List.generate(120, (i) => 'line $i').join('\n');
    final composing = TextRange(start: text.length - 8, end: text.length);
    final controller = EditableController(text: text);
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);

    controller.collapseTo(0);
    final revision = controller.docRevision;
    client.open(const TextInputConfiguration());
    expect(tester.testTextInput.editingState!['text'], 'line 0');

    controller.imeUpdateSelection(const TextSelection.collapsed(offset: 0), composing);
    expect(controller.docRevision, revision);
    client.syncFromController();

    final synced = tester.testTextInput.editingState!;
    expect(synced['text'], text);
    expect(synced['composingBase'], composing.start);
    expect(synced['composingExtent'], composing.end);
  });

  testWidgets('越窗大选区：通道只推钳制窗口，平台替换钳制选区 = 替换整个 doc 选区', (tester) async {
    final controller = EditableController(text: List.generate(120, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);

    controller.selectAll();
    client.open(const TextInputConfiguration());

    // 全选态推给平台的"全文"只是 caret 邻域窗口。
    final seeded = tester.testTextInput.editingState?['text'] as String?;
    expect(seeded, isNotNull);
    expect(seeded!.length, lessThan(controller.document.length ~/ 2), reason: '全选不得整篇物化过通道');

    // 平台把它眼中的（钳制）选区替换为 'x' —— 用户意图是替换整个选区。
    client.updateEditingValue(const TextEditingValue(text: 'x', selection: TextSelection.collapsed(offset: 1)));
    expect(controller.text, 'x');
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
  });

  // 全选后键入 [typed]，断言整个选区被替换为键入文本（而非被 diff 裁剪吃掉）。
  Future<void> expectSelectAllTypeReplaces(WidgetTester tester, String typed) async {
    final controller = EditableController(text: List.generate(120, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);

    controller.selectAll();
    client.open(const TextInputConfiguration());

    // 平台把它眼中的（钳制）全窗选区替换为键入文本。
    client.updateEditingValue(
      TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length),
      ),
    );
    expect(controller.text, typed, reason: "全选后键入 '$typed' 必须得到 '$typed'");
    expect(controller.selection, TextSelection.collapsed(offset: typed.length));
  }

  testWidgets('越窗大选区：键入文本与窗口文本同前缀（diff 裁剪陷阱）不得清空文档', (tester) async {
    // 窗口文本 'line 104…' 以 'l' 开头：最小 diff 会把 'l' 裁进公共前缀，
    // 其"保留"位置落在被整体删除的 doc 选区内。
    await expectSelectAllTypeReplaces(tester, 'l');
  });

  testWidgets('越窗大选区：键入文本与窗口文本同后缀（diff 裁剪陷阱）不得清空文档', (tester) async {
    // 窗口文本以 '…line 119' 结尾：'9' 被裁进公共后缀。
    await expectSelectAllTypeReplaces(tester, '9');
  });

  testWidgets('越窗大选区：键入多字符与窗口文本前后缀双重合不得丢字符', (tester) async {
    // 'line 9' 与窗口文本共享前缀 'line ' 与后缀 '9'，裁剪后 diff 只剩中间残片。
    await expectSelectAllTypeReplaces(tester, 'line 9');
  });

  testWidgets('越窗大选区：push 与 recv 之间本地选区漂移，扩回仍以推送时选区为锚', (tester) async {
    final controller = EditableController(text: List.generate(120, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);

    controller.selectAll();
    client.open(const TextInputConfiguration());

    // 协议竞态：平台基于全选窗口值的编辑仍在途，本地选区已折叠
    //（headless 下无视图桥接 syncFromController，恰好模拟"未及推送"）。
    controller.setSelection(const TextSelection.collapsed(offset: 0));
    client.updateEditingValue(const TextEditingValue(text: 'x', selection: TextSelection.collapsed(offset: 1)));
    expect(controller.text, 'x', reason: '扩回按平台实际看到的（推送时）全选兑现');
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
  });

  testWidgets('越窗大选区：与钳制推送等价的选区回声不得截断本地大选区', (tester) async {
    final controller = EditableController(text: List.generate(120, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);

    controller.selectAll();
    final fullSelection = controller.selection;
    client.open(const TextInputConfiguration());

    // 引擎带 affinity 微差回声钳制后的选区（text/端点均未变）。
    final seeded = tester.testTextInput.editingState!;
    client.updateEditingValue(
      TextEditingValue(
        text: seeded['text'] as String,
        selection: TextSelection(
          baseOffset: seeded['selectionBase'] as int,
          extentOffset: seeded['selectionExtent'] as int,
          affinity: TextAffinity.upstream,
        ),
      ),
    );
    expect(controller.selection, fullSelection, reason: '采纳窗内片段会把大选区截断');
  });
}
