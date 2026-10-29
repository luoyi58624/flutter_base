import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 12, height: 1, color: Color(0xff000000));

Widget _host(Widget child) {
  return MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: SizedBox(width: 320, height: 180, child: child),
    ),
  );
}

Future<void> _shortcut(
  WidgetTester tester, {
  required LogicalKeyboardKey modifier,
  required LogicalKeyboardKey key,
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(modifier);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

Future<void> _selectionOnlyComposing(
  WidgetTester tester,
  EditableController controller, {
  required int start,
  required int end,
}) async {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: controller.text,
      selection: TextSelection.collapsed(offset: end),
      composing: TextRange(start: start, end: end),
    ),
  );
  await tester.pump();
  expect(controller.hasActiveImeComposition, isTrue);
}

Map<dynamic, dynamic> _lastPlatformEditingState(WidgetTester tester) =>
    tester.testTextInput.log.lastWhere((call) => call.method == 'TextInput.setEditingState').arguments
        as Map<dynamic, dynamic>;

void _expectPlatformComposingCleared(WidgetTester tester) {
  final state = _lastPlatformEditingState(tester);
  expect(state['composingBase'], -1);
  expect(state['composingExtent'], -1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final configuration in <({String name, TargetPlatform platform, LogicalKeyboardKey modifier})>[
    (name: 'Windows Ctrl', platform: TargetPlatform.windows, modifier: LogicalKeyboardKey.controlLeft),
    (name: 'macOS Command', platform: TargetPlatform.macOS, modifier: LogicalKeyboardKey.metaLeft),
  ]) {
    testWidgets('${configuration.name} undo/redo 先结清 selection-only composing', (tester) async {
      debugDefaultTargetPlatformOverride = configuration.platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final controller = EditableController(text: 'a')..collapseTo(1);
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      controller.insertText('b');

      await tester.pumpWidget(
        _host(
          EditableView(
            controller: controller,
            focusNode: focusNode,
            style: EditableConfiguration(textStyle: _style),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue);

      await _selectionOnlyComposing(tester, controller, start: 0, end: 1);
      tester.testTextInput.log.clear();
      await _shortcut(tester, modifier: configuration.modifier, key: LogicalKeyboardKey.keyZ);

      expect(controller.text, 'a');
      expect(controller.composing, TextRange.empty);
      expect(controller.hasActiveImeComposition, isFalse);
      expect(controller.undoDepth, 0);
      expect(controller.redoDepth, 1);
      _expectPlatformComposingCleared(tester);

      await _selectionOnlyComposing(tester, controller, start: 0, end: 1);
      tester.testTextInput.log.clear();
      await _shortcut(tester, modifier: configuration.modifier, key: LogicalKeyboardKey.keyZ, shift: true);

      expect(controller.text, 'ab');
      expect(controller.composing, TextRange.empty);
      expect(controller.hasActiveImeComposition, isFalse);
      expect(controller.undoDepth, 1);
      expect(controller.redoDepth, 0);
      _expectPlatformComposingCleared(tester);

      controller.text = 'base';
      await tester.pump();
      await _selectionOnlyComposing(tester, controller, start: 0, end: 1);
      tester.testTextInput.log.clear();
      await _shortcut(tester, modifier: configuration.modifier, key: LogicalKeyboardKey.keyZ);

      expect(controller.text, 'base');
      expect(controller.composing, TextRange.empty);
      expect(controller.hasActiveImeComposition, isFalse);
      expect(controller.undoDepth, 0);
      expect(controller.redoDepth, 0);
      _expectPlatformComposingCleared(tester);

      await _selectionOnlyComposing(tester, controller, start: 0, end: 1);
      tester.testTextInput.log.clear();
      await _shortcut(tester, modifier: configuration.modifier, key: LogicalKeyboardKey.keyZ, shift: true);

      expect(controller.text, 'base');
      expect(controller.composing, TextRange.empty);
      expect(controller.hasActiveImeComposition, isFalse);
      expect(controller.undoDepth, 0);
      expect(controller.redoDepth, 0);
      _expectPlatformComposingCleared(tester);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('编辑态 Space/Enter 截断祖先，热切只读后释放焦点并放行文本键', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final controller = EditableController();
    final editorFocus = FocusNode();
    final nextFocus = FocusNode();
    final ancestorEvents = <KeyEvent>[];
    addTearDown(controller.dispose);
    addTearDown(editorFocus.dispose);
    addTearDown(nextFocus.dispose);

    Widget editor({required bool readOnly}) => _host(
      Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (_reservedTextKeys.contains(event.logicalKey)) ancestorEvents.add(event);
          return KeyEventResult.handled;
        },
        child: Column(
          children: [
            SizedBox(
              width: 260,
              height: 100,
              child: EditableView(
                controller: controller,
                focusNode: editorFocus,
                style: EditableConfiguration(readOnly: readOnly, textStyle: _style),
              ),
            ),
            Focus(focusNode: nextFocus, child: const SizedBox(width: 20, height: 20)),
          ],
        ),
      ),
    );

    await tester.pumpWidget(editor(readOnly: false));
    editorFocus.requestFocus();
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);

    for (final key in _reservedKeyCases) {
      expect(editorFocus.onKeyEvent!(editorFocus, key.down), KeyEventResult.skipRemainingHandlers);
      expect(editorFocus.onKeyEvent!(editorFocus, key.repeat), KeyEventResult.skipRemainingHandlers);
      expect(editorFocus.onKeyEvent!(editorFocus, key.up), KeyEventResult.skipRemainingHandlers);
      _dispatchKeyPhases(key);
      await tester.pump();
    }
    expect(ancestorEvents, isEmpty);
    expect(controller.text, isEmpty, reason: '物理键不得绕开 TextInput 直接双写正文');

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: ' ', selection: TextSelection.collapsed(offset: 1)),
    );
    await tester.pump();
    expect(controller.text, ' ', reason: 'Space 的平台 TextInput 通道仍可提交');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
    expect(controller.text, ' ', reason: 'multiline newline action 只通知，不得在平台文本更新之外二次写入');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: ' \n', selection: TextSelection.collapsed(offset: 2)),
    );
    await tester.pump();
    expect(controller.text, ' \n', reason: 'Enter 的换行正文由平台 TextInput 更新提交');

    await tester.pumpWidget(editor(readOnly: true));
    await tester.pump();
    expect(editorFocus.hasFocus, isFalse);
    ancestorEvents.clear();
    for (final key in _reservedKeyCases) {
      expect(editorFocus.onKeyEvent!(editorFocus, key.down), KeyEventResult.ignored);
      expect(editorFocus.onKeyEvent!(editorFocus, key.repeat), KeyEventResult.ignored);
      expect(editorFocus.onKeyEvent!(editorFocus, key.up), KeyEventResult.ignored);
    }
    expect(ancestorEvents, isEmpty, reason: '直接调用只验证编辑器边界返回值，不经过 FocusManager 冒泡');
    expect(controller.text, ' \n');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('code profile 的 Enter 在 IME composing 中留给平台，不插入第二个换行', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final controller = EditableController(text: 'x')..collapseTo(1);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'xy',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
    );
    await tester.pump();
    expect(controller.hasActiveImeComposition, isTrue);
    final beforeRevision = controller.docRevision;
    final beforeUndoDepth = controller.undoDepth;

    final result = focusNode.onKeyEvent!(
      focusNode,
      KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        character: '\n',
        timeStamp: Duration.zero,
      ),
    );
    expect(result, KeyEventResult.skipRemainingHandlers);
    expect(controller.text, 'xy');
    expect(controller.composing, const TextRange(start: 1, end: 2));
    expect(controller.docRevision, beforeRevision);
    expect(controller.undoDepth, beforeUndoDepth);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'xy', selection: TextSelection.collapsed(offset: 2)),
    );
    await tester.pump();
    expect(controller.text, 'xy');
    expect(controller.composing, TextRange.empty);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS 行边界删除与字符交换经内建命令端到端执行', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final controller = EditableController(text: 'ab')..collapseTo(1);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    Widget editor({bool readOnly = false, bool obscureText = false}) => _host(
      EditableView(
        controller: controller,
        focusNode: focusNode,
        style: EditableConfiguration(readOnly: readOnly, obscureText: obscureText, textStyle: _style),
      ),
    );

    await tester.pumpWidget(editor());
    focusNode.requestFocus();
    await tester.pump();

    await _shortcut(tester, modifier: LogicalKeyboardKey.controlLeft, key: LogicalKeyboardKey.keyT);
    expect(controller.text, 'ba');
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
    expect(controller.lastChangeSet?.source, EditableEditSource.keyboard);

    controller
      ..text = 'left middle right\nsecond'
      ..collapseTo(11);
    await tester.pump();
    await _shortcut(tester, modifier: LogicalKeyboardKey.metaLeft, key: LogicalKeyboardKey.backspace);
    expect(controller.text, ' right\nsecond');
    expect(controller.selection, const TextSelection.collapsed(offset: 0));

    controller
      ..text = 'left middle right\nsecond'
      ..collapseTo(5);
    await tester.pump();
    await _shortcut(tester, modifier: LogicalKeyboardKey.metaLeft, key: LogicalKeyboardKey.delete);
    expect(controller.text, 'left \nsecond');
    expect(controller.selection, const TextSelection.collapsed(offset: 5));

    controller
      ..text = 'ab\ncd'
      ..collapseTo(4);
    await tester.pumpWidget(editor(obscureText: true));
    await tester.pump();
    await _shortcut(tester, modifier: LogicalKeyboardKey.metaLeft, key: LogicalKeyboardKey.backspace);
    expect(controller.text, 'd', reason: '密码态 Command+Backspace 必须退化为文档边界，不泄露行结构');

    controller
      ..text = 'ab'
      ..collapseTo(1);
    await tester.pumpWidget(editor(readOnly: true));
    await tester.pump();
    await _shortcut(tester, modifier: LogicalKeyboardKey.controlLeft, key: LogicalKeyboardKey.keyT);
    await _shortcut(tester, modifier: LogicalKeyboardKey.metaLeft, key: LogicalKeyboardKey.backspace);
    await _shortcut(tester, modifier: LogicalKeyboardKey.metaLeft, key: LogicalKeyboardKey.delete);
    expect(controller.text, 'ab');
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
    expect(controller.undoDepth, 0);

    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}

final _reservedTextKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
};

final _reservedKeyCases =
    <
      ({
        LogicalKeyboardKey logical,
        PhysicalKeyboardKey physical,
        KeyDownEvent down,
        KeyRepeatEvent repeat,
        KeyUpEvent up,
      })
    >[
      _keyCase(LogicalKeyboardKey.space, PhysicalKeyboardKey.space, ' '),
      _keyCase(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter, '\n'),
      _keyCase(LogicalKeyboardKey.numpadEnter, PhysicalKeyboardKey.numpadEnter, '\n'),
    ];

void _dispatchKeyPhases(
  ({LogicalKeyboardKey logical, PhysicalKeyboardKey physical, KeyDownEvent down, KeyRepeatEvent repeat, KeyUpEvent up})
  key,
) {
  HardwareKeyboard.instance
    ..handleKeyEvent(key.down)
    ..handleKeyEvent(key.repeat)
    ..handleKeyEvent(key.up);
}

({LogicalKeyboardKey logical, PhysicalKeyboardKey physical, KeyDownEvent down, KeyRepeatEvent repeat, KeyUpEvent up})
_keyCase(LogicalKeyboardKey logical, PhysicalKeyboardKey physical, String character) => (
  logical: logical,
  physical: physical,
  down: KeyDownEvent(physicalKey: physical, logicalKey: logical, character: character, timeStamp: Duration.zero),
  repeat: KeyRepeatEvent(physicalKey: physical, logicalKey: logical, character: character, timeStamp: Duration.zero),
  up: KeyUpEvent(physicalKey: physical, logicalKey: logical, timeStamp: Duration.zero),
);
