import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:flutter_base/desktop.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return WidgetsApp(
    color: Color(0xffffffff),
    // 标准 Tab 行为由应用环境提供，品牌安装器只安装主题与组件。
    builder: (context, _) => FocusScope(
      autofocus: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ElComponentProvider(
          components: el.desktopComponents,
          child: ElView(style: const ElStyle(width: 600), child: child),
        ),
      ),
    ),
  );
}

/// 格子 = 宽高相等的那批 ElView
List<ElView> _cells(WidgetTester tester) => tester
    .widgetList<ElView>(find.byType(ElView))
    .where((v) => v.style?.width != null && v.style?.width == v.style?.height)
    .toList();

ElEditableView _editable(WidgetTester tester) => tester.widget<ElEditableView>(find.byType(ElEditableView));

ElEditableController _controller(WidgetTester tester) => _editable(tester).controller!;

/// 当前分格不暴露逐格语义，活动格以真实外观和控制器选区共同验证。
bool _isActiveCell(WidgetTester tester, ElView cell) =>
    cell.style?.border?.borderTop.borderColor == tester.element(find.byWidget(cell)).elTheme.primary;

EditableViewTestState _editableState(WidgetTester tester) =>
    findEditableViewState(tester.element(find.byType(ElEditableView)));

const _borderColor = Color(0xffdcdfe6);

Future<void> _type(WidgetTester tester, String text) async {
  _editable(tester).focusNode!.requestFocus();
  await tester.pump();
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump(const Duration(milliseconds: 40));
}

Future<void> _unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

Future<void> _clickCell(WidgetTester tester, int index) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byWidget(_cells(tester)[index])),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> _dragCell(WidgetTester tester, int from, int to) async {
  final cells = _cells(tester);
  final fromPosition = tester.getCenter(find.byWidget(cells[from]));
  final toPosition = tester.getCenter(find.byWidget(cells[to]));
  final gesture = await tester.startGesture(fromPosition, kind: PointerDeviceKind.mouse);
  await tester.pump();
  await gesture.moveTo(toPosition);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

List<int> _graphemeOffsets(String text) {
  final offsets = <int>[0];
  var offset = 0;
  for (final grapheme in text.characters) {
    offset += grapheme.length;
    offsets.add(offset);
  }
  return offsets;
}

int _activeClientId(WidgetTester tester) {
  final call = tester.testTextInput.log.lastWhere((entry) => entry.method == 'TextInput.setClient');
  return (call.arguments as List<dynamic>).first as int;
}

Future<void> _sendTaggedAutofill(WidgetTester tester, String id, TextEditingValue value) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(
      MethodCall('TextInputClient.updateEditingStateWithTag', [
        _activeClientId(tester),
        {id: value.toJSON()},
      ]),
    ),
    (_) {},
  );
  await tester.pump();
}

List<SemanticsNode> _semanticsNodes(WidgetTester tester) {
  final nodes = <SemanticsNode>[];

  void collect(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      collect(child);
      return true;
    });
  }

  // 测试绑定的语义树仍挂在 pipelineOwner，Flutter 暂无非弃用等价入口。
  // ignore: deprecated_member_use
  collect(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return nodes;
}

List<SemanticsNode> _textFieldNodes(WidgetTester tester) =>
    _semanticsNodes(tester).where((node) => node.getSemanticsData().flagsCollection.isTextField).toList();

List<String> _exposedSemanticText(WidgetTester tester) => [
  for (final node in _semanticsNodes(tester))
    ...[
      node.getSemanticsData().label,
      node.getSemanticsData().value,
      node.getSemanticsData().hint,
    ].where((text) => text.isNotEmpty),
];

void main() {
  group('ElInputOtp 值通道', () {
    testWidgets('默认 6 格空白', (tester) async {
      await tester.pumpWidget(_host(ElInputOtp(value: '')));
      await tester.pumpAndSettle();

      expect(_cells(tester), hasLength(6));
      expect(_cells(tester).every((c) => c.child == null), isTrue);
    });

    testWidgets('运行时只挂普通 input preset 的唯一 ElEditableView，不依赖 Flutter 输入或外部 drop region', (tester) async {
      await tester.pumpWidget(_host(ElInputOtp(value: '', keyboardType: TextInputType.emailAddress)));
      await tester.pump();

      expect(find.byType(ElEditableView), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(_controller(tester).singleLine, isTrue);
      expect(_controller(tester).maxLength, isNull, reason: '格子上限由 editable 字素事务拦截器负责');
      expect(_editable(tester).style.inputConfiguration?.inputType, TextInputType.emailAddress);

      expect(_editable(tester).style.inputConfiguration?.autofillConfiguration.autofillHints, const [
        AutofillHints.oneTimeCode,
      ]);
    });

    testWidgets('非掩码 OTP 的空 caret Ctrl+C/X 不复制整串也不清空值', (tester) async {
      final clipboardWrites = <MethodCall>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboardWrites.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(_host(ElInputOtp(value: '1234')));
      _editable(tester).focusNode!.requestFocus();
      _controller(tester).collapseTo(2);
      await tester.pump();

      for (final key in [LogicalKeyboardKey.keyC, LogicalKeyboardKey.keyX]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
      }

      expect(clipboardWrites, isEmpty);
      expect(_controller(tester).text, '1234');
      expect(_controller(tester).undoDepth, 0);
      await _unmount(tester);
    });

    testWidgets('autofocus 由 ElEditableView 建立真实焦点与 IME', (tester) async {
      await tester.pumpWidget(_host(ElInputOtp(value: '', autofocus: true)));
      await tester.pump();

      expect(_editable(tester).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.setClientArgs, isNotNull);
      expect((tester.testTextInput.setClientArgs!['autofill'] as Map<dynamic, dynamic>)['hints'], [
        AutofillHints.oneTimeCode,
      ]);
      await _unmount(tester);
    });

    testWidgets('value 受控：逐格画出字符', (tester) async {
      await tester.pumpWidget(_host(ElInputOtp(value: '123')));
      await tester.pumpAndSettle();

      final cells = _cells(tester);
      expect(cells[0].child, '1');
      expect(cells[2].child, '3');
      expect(cells[3].child, isNull, reason: '未输入的位应留空');
    });

    testWidgets('输入写回 modelValue，填满触发 onComplete', (tester) async {
      final obs = Obs<String>('');
      addTearDown(obs.dispose);
      String? completed;
      await tester.pumpWidget(_host(ElInputOtp(length: 4, modelValue: obs, onComplete: (v) => completed = v)));
      await tester.pumpAndSettle();

      await _type(tester, '12');
      expect(obs.value, '12');
      expect(completed, isNull, reason: '没填满不该回调');

      await _type(tester, '1234');
      expect(obs.value, '1234');
      expect(completed, '1234');
      await _unmount(tester);
    });

    testWidgets('AutofillGroup tagged 回填未聚焦 OTP，字素上限、双向值与 onComplete 只结算一次', (tester) async {
      final triggerController = ElEditableController(text: 'user', singleLine: true);
      final triggerFocus = FocusNode(debugLabel: 'otp-autofill-trigger');
      final value = Obs<String>('');
      final changes = <String>[];
      final completed = <String>[];
      addTearDown(triggerController.dispose);
      addTearDown(triggerFocus.dispose);
      addTearDown(value.dispose);

      await tester.pumpWidget(
        _host(
          AutofillGroup(
            child: Column(
              children: [
                ElView(
                  style: const ElStyle(width: 180, height: 40),
                  child: ElEditableView(
                    controller: triggerController,
                    focusNode: triggerFocus,
                    style: ElEditableStyle(
                      softWrap: false,
                      inputConfiguration: TextInputConfiguration(
                        autofillConfiguration: AutofillConfiguration(
                          uniqueIdentifier: 'decoy',
                          autofillHints: const [AutofillHints.username],
                          currentEditingValue: TextEditingValue.empty,
                        ),
                      ),
                    ),
                  ),
                ),
                ElInputOtp(length: 4, modelValue: value, onChanged: changes.add, onComplete: completed.add),
              ],
            ),
          ),
        ),
      );
      triggerFocus.requestFocus();
      await tester.pump();
      final fields = (tester.testTextInput.setClientArgs!['fields'] as List<dynamic>).cast<Map<dynamic, dynamic>>();
      final otp = fields.singleWhere(
        (field) => ((field['autofill'] as Map<dynamic, dynamic>)['hints'] as List<dynamic>).contains(
          AutofillHints.oneTimeCode,
        ),
      );
      final otpId = (otp['autofill'] as Map<dynamic, dynamic>)['uniqueIdentifier'] as String;

      await _sendTaggedAutofill(
        tester,
        otpId,
        const TextEditingValue(text: '12345', selection: TextSelection.collapsed(offset: 5)),
      );
      await tester.pump();

      expect(value.value, '1234');
      expect(changes, ['1234']);
      expect(completed, ['1234']);
      expect(triggerFocus.hasFocus, isTrue);
      final otpEditable = tester.widget<ElEditableView>(
        find.byWidgetPredicate(
          (widget) =>
              widget is ElEditableView &&
              widget.style.inputConfiguration?.autofillConfiguration.autofillHints.contains(
                    AutofillHints.oneTimeCode,
                  ) ==
                  true,
        ),
      );
      expect(otpEditable.controller!.text, '1234');
      expect(_cells(tester).take(4).map((cell) => cell.child).join(), '1234');
      await _unmount(tester);
    });

    testWidgets('prop 从祖先 ElForm 取值并写回', (tester) async {
      final model = Obs<Map<String, dynamic>>({'code': '99'});
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _host(
          ElForm(
            modelValue: model,
            child: ElFormItem(
              prop: 'code',
              label: '验证码',
              child: ElInputOtp(value: '', length: 4),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_cells(tester)[0].child, '9', reason: '首帧就该是表单值');

      await _type(tester, '8888');
      expect(model.value['code'], '8888');
      await _unmount(tester);
    });

    testWidgets('外部改值最小回灌并映射、钳制选区', (tester) async {
      final obs = Obs<String>('123');
      addTearDown(obs.dispose);
      final changes = <String>[];
      await tester.pumpWidget(_host(ElInputOtp(modelValue: obs, onChanged: changes.add)));
      await tester.pumpAndSettle();

      _controller(tester).setSelection(const TextSelection(baseOffset: 1, extentOffset: 2));
      obs.value = '9123';
      changes.clear();
      await tester.pumpAndSettle();
      expect(_controller(tester).text, '9123');
      expect(_controller(tester).selection, const TextSelection(baseOffset: 2, extentOffset: 3));
      expect(_cells(tester)[0].child, '9');
      expect(changes, isEmpty, reason: '外部回灌不得从 controller 再循环写回');

      obs.value = '9';
      await tester.pumpAndSettle();
      expect(_controller(tester).selection, const TextSelection.collapsed(offset: 1));
    });

    testWidgets('length 增大复用 controller、拦截器、焦点、viewState 与 IME client', (tester) async {
      const family = '👨‍👩‍👧‍👦';
      final obs = Obs<String>('A');
      addTearDown(obs.dispose);
      var length = 2;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElInputOtp(length: length, modelValue: obs);
            },
          ),
        ),
      );
      await tester.pump();
      _editable(tester).focusNode!.requestFocus();
      await tester.pump();
      final controller = _controller(tester);
      final formatter = controller.inputFormatters.single;
      final focusNode = _editable(tester).focusNode;
      final viewState = _editableState(tester);
      final clientId = _activeClientId(tester);
      final setClientCount = tester.testTextInput.log.where((entry) => entry.method == 'TextInput.setClient').length;
      controller.insertText('😀');
      await tester.pump();
      expect(controller.text, 'A😀');
      expect(controller.undoDepth, 1);

      update(() => length = 4);
      await tester.pumpAndSettle();
      expect(find.byType(ElEditableView), findsOneWidget);
      expect(identical(_controller(tester), controller), isTrue);
      expect(identical(_controller(tester).inputFormatters.single, formatter), isTrue);
      expect(identical(_editable(tester).focusNode, focusNode), isTrue);
      expect(identical(_editableState(tester), viewState), isTrue);
      expect(_activeClientId(tester), clientId);
      expect(
        tester.testTextInput.log.where((entry) => entry.method == 'TextInput.setClient'),
        hasLength(setClientCount),
      );
      expect(controller.text, 'A😀');
      expect(controller.undoDepth, 1, reason: '增大格数不得清掉旧 undo lineage');

      controller.collapseTo(controller.text.length);
      controller.insertText(
        '$family'
        'e\u0301',
      );
      await tester.pump();
      expect(
        obs.value,
        'A😀$family'
        'e\u0301',
      );
      expect(_cells(tester).map((cell) => cell.child), ['A', '😀', family, 'e\u0301']);
      expect(controller.undoDepth, 2, reason: '长度配置变更应断开前后 typing 合并段');
      expect(controller.undoEdit(), isTrue);
      expect(controller.text, 'A😀');
      expect(controller.undoEdit(), isTrue);
      expect(controller.text, 'A');

      await _unmount(tester);
    });

    testWidgets('length 缩短是一笔字素后缀删除，undo 精确恢复正文与反向选区', (tester) async {
      const family = '👨‍👩‍👧‍👦';
      const full = 'A😀e\u0301${family}Z';
      const limited = 'A😀e\u0301';
      final obs = Obs<String>(full);
      final changes = <String>[];
      addTearDown(obs.dispose);
      var length = 5;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElInputOtp(length: length, modelValue: obs, onChanged: changes.add);
            },
          ),
        ),
      );
      await tester.pump();
      final controller = _controller(tester);
      final viewState = _editableState(tester);
      controller.setSelection(const TextSelection(baseOffset: full.length, extentOffset: 1, isDirectional: true));
      final selectionsBefore = controller.selections;

      update(() => length = 3);
      await tester.pumpAndSettle();
      expect(identical(_controller(tester), controller), isTrue);
      expect(identical(_editableState(tester), viewState), isTrue);
      expect(controller.text, limited);
      expect(obs.value, limited);
      expect(changes, [limited], reason: '配置收敛只允许一次模型回写');
      expect(controller.undoDepth, 1);
      expect(
        controller.selections.primary,
        const EditableSelection(anchor: limited.length, active: 1, isDirectional: true),
      );
      expect(controller.selections.secondary, isEmpty);

      expect(controller.undoEdit(), isTrue);
      expect(controller.text, full, reason: 'undo 恢复后不得被仍为 3 的上限监听器立刻二次截断');
      expect(controller.selections, selectionsBefore);

      expect(controller.redoDepth, 1);

      expect(controller.redoEdit(), isTrue);
      expect(controller.text, limited);
      expect(
        controller.selections.primary,
        const EditableSelection(anchor: limited.length, active: 1, isDirectional: true),
      );
      expect(controller.selections.secondary, isEmpty);

      expect(controller.undoEdit(), isTrue);
      controller.collapseTo(0);

      controller.insertText('Q');
      await tester.pump();
      expect(controller.text, 'QA😀');
      expect(controller.redoDepth, 0, reason: 'undo 后普通新编辑必须清正文 redo 分支');

      await _unmount(tester);
    });

    testWidgets('组合期缩短延迟到平台提交后收敛，模型只见终态且 IME 历史与长度删除分两笔', (tester) async {
      const composingText = '😀e\u0301Z';
      const limited = '😀e\u0301';
      final obs = Obs<String>('');
      final changes = <String>[];
      addTearDown(obs.dispose);
      var length = 4;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElInputOtp(
                length: length,
                modelValue: obs,
                keyboardType: TextInputType.text,
                onChanged: changes.add,
              );
            },
          ),
        ),
      );
      _editable(tester).focusNode!.requestFocus();
      await tester.pump();
      final controller = _controller(tester);
      final viewState = _editableState(tester);
      final clientId = _activeClientId(tester);
      final setClientCount = tester.testTextInput.log.where((entry) => entry.method == 'TextInput.setClient').length;

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: composingText,
          selection: TextSelection.collapsed(offset: composingText.length),
          composing: TextRange(start: 0, end: composingText.length),
        ),
      );
      await tester.pump();
      expect(controller.text, composingText);
      expect(controller.hasActiveImeComposition, isTrue);
      expect(controller.undoDepth, 0, reason: '候选中间态不能提前进入历史');
      expect(obs.value, isEmpty);
      expect(changes, isEmpty);

      update(() => length = 2);
      await tester.pumpAndSettle();
      expect(identical(_controller(tester), controller), isTrue);
      expect(identical(_editableState(tester), viewState), isTrue);
      expect(_activeClientId(tester), clientId);
      expect(
        tester.testTextInput.log.where((entry) => entry.method == 'TextInput.setClient'),
        hasLength(setClientCount),
      );
      expect(controller.text, composingText, reason: '活动候选必须继续使用进入组合时的上限，配置缩短不能截断候选');
      expect(controller.hasActiveImeComposition, isTrue);
      expect(obs.value, isEmpty);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: composingText,
          selection: TextSelection.collapsed(offset: composingText.length),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.hasActiveImeComposition, isFalse);
      expect(controller.text, limited);
      expect(obs.value, limited);
      expect(changes, [limited], reason: '候选正文与配置删除之间不得泄漏未截断模型值');
      expect(controller.undoDepth, 2, reason: '先提交 IME 会话，再以独立一笔删除超出的字素后缀');
      expect(tester.testTextInput.editingState?['text'], limited, reason: '收敛后的权威正文必须回推同一平台 client');

      expect(controller.undoEdit(), isTrue);
      expect(controller.text, composingText);
      expect(controller.undoEdit(), isTrue);
      expect(controller.text, isEmpty);
      await _unmount(tester);
    });

    testWidgets('组合期缩短在平台取消后只删除原值后缀，保留旧正文', (tester) async {
      final obs = Obs<String>('ABCD');
      final changes = <String>[];
      addTearDown(obs.dispose);
      var length = 4;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElInputOtp(
                length: length,
                modelValue: obs,
                keyboardType: TextInputType.text,
                onChanged: changes.add,
              );
            },
          ),
        ),
      );
      _editable(tester).focusNode!.requestFocus();
      await tester.pump();
      final controller = _controller(tester);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ABxy',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 2, end: 4),
        ),
      );
      await tester.pump();
      update(() => length = 2);
      await tester.pump();
      expect(controller.text, 'ABxy');
      expect(obs.value, 'ABCD');

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(text: 'ABCD', selection: TextSelection.collapsed(offset: 4)),
      );
      await tester.pumpAndSettle();
      expect(controller.text, 'AB');
      expect(obs.value, 'AB');
      expect(changes, ['AB']);
      expect(controller.undoDepth, 1, reason: '取消的候选不留历史，只保留长度配置触发的后缀删除');

      expect(controller.undoEdit(), isTrue);
      expect(controller.text, 'ABCD');

      await _unmount(tester);
    });
  });

  group('ElInputOtp 形态', () {
    testWidgets('length 决定格数', (tester) async {
      await tester.pumpWidget(_host(ElInputOtp(value: '', length: 4)));
      await tester.pumpAndSettle();
      expect(_cells(tester), hasLength(4));
    });

    testWidgets('超长输入被截断到 length', (tester) async {
      final obs = Obs<String>('');
      addTearDown(obs.dispose);
      await tester.pumpWidget(_host(ElInputOtp(length: 4, modelValue: obs)));
      await tester.pumpAndSettle();

      await _type(tester, '1234567');
      expect(obs.value, '1234', reason: '不该超过 length');
      await _unmount(tester);
    });

    testWidgets('emoji 与组合音标各占一格且截断不劈字素', (tester) async {
      final obs = Obs<String>('😀e\u0301');
      addTearDown(obs.dispose);
      await tester.pumpWidget(_host(ElInputOtp(length: 2, modelValue: obs, keyboardType: TextInputType.text)));
      await tester.pumpAndSettle();

      expect(_cells(tester)[0].child, '😀');
      expect(_cells(tester)[1].child, 'e\u0301');

      await _type(tester, '😀e\u0301x');
      expect(obs.value, '😀e\u0301');
      expect(_controller(tester).text, '😀e\u0301');
      await _unmount(tester);
    });

    testWidgets('字素光标映射到下一格而不是 UTF-16 下标', (tester) async {
      await tester.pumpWidget(_host(ElInputOtp(value: '😀a', length: 3, keyboardType: TextInputType.text)));
      await tester.pumpAndSettle();
      _editable(tester).focusNode!.requestFocus();
      _controller(tester).collapseTo('😀'.length);
      await tester.pump();

      final cells = _cells(tester);
      expect(_isActiveCell(tester, cells[1]), isTrue);
      expect(_isActiveCell(tester, cells[2]), isFalse);
      await _unmount(tester);
    });

    testWidgets('真实点击每个视觉格都命中对应 Unicode 字素边界并保持唯一真实焦点', (tester) async {
      const text = 'A😀e\u0301👨‍👩‍👧‍👦';
      final offsets = _graphemeOffsets(text);
      await tester.pumpWidget(_host(ElInputOtp(value: text, length: 4, keyboardType: TextInputType.text)));
      await tester.pump();

      for (var index = 0; index < 4; index++) {
        await _clickCell(tester, index);
        expect(_editable(tester).focusNode!.hasFocus, isTrue);
        expect(_controller(tester).selection, TextSelection.collapsed(offset: offsets[index]));
        expect(
          [for (final cell in _cells(tester)) _isActiveCell(tester, cell)],
          [for (var i = 0; i < 4; i++) i == index],
          reason: '第 $index 格的视觉 active 必须与真实 editable caret 使用同一字素坐标',
        );
      }
      expect(find.byType(ElEditableView), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('真实反向拖选与键盘移动都以视觉格中心映射字素 offset', (tester) async {
      const text = 'A😀e\u0301👨‍👩‍👧‍👦';
      final offsets = _graphemeOffsets(text);
      await tester.pumpWidget(_host(ElInputOtp(value: text, length: 4, keyboardType: TextInputType.text)));
      await tester.pump();

      await _dragCell(tester, 3, 1);
      expect(
        _controller(tester).selection,
        TextSelection(baseOffset: offsets[3], extentOffset: offsets[1]),
        reason: '拖动活动端不能再按透明真实字形宽度落到错误 code unit',
      );
      expect(_isActiveCell(tester, _cells(tester)[1]), isTrue);

      await _clickCell(tester, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_controller(tester).selection, TextSelection.collapsed(offset: offsets[2]));
      expect(_isActiveCell(tester, _cells(tester)[2]), isTrue);
      await _unmount(tester);
    });

    testWidgets('整串粘贴按 length 截断，退格继续回写同一控制器', (tester) async {
      final obs = Obs<String>('');
      addTearDown(obs.dispose);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': '123456'};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(_host(ElInputOtp(length: 4, modelValue: obs)));
      await tester.pump();

      _editable(tester).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 40));
      expect(obs.value, '1234');

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump(const Duration(milliseconds: 40));
      expect(obs.value, '123');
      expect(_controller(tester).text, '123');
      await _unmount(tester);
    });

    testWidgets('mask 用掩码字符替代真实字符', (tester) async {
      await tester.pumpWidget(_host(ElInputOtp(value: '12', mask: true)));
      await tester.pumpAndSettle();

      expect(_cells(tester)[0].child, '•');
      expect(_cells(tester)[1].child, '•');
    });

    testWidgets('三种外观各自的边框形态', (tester) async {
      await tester.pumpWidget(_host(ElInputOtp(value: '', length: 1)));
      await tester.pumpAndSettle();
      expect(_cells(tester).first.style?.border?.borderTop.borderColor, _borderColor, reason: 'outlined 四边描边');

      await tester.pumpWidget(_host(ElInputOtp(value: '', length: 1, type: ElInputOtpType.filled)));
      await tester.pumpAndSettle();
      expect(_cells(tester).first.style?.backgroundColor, const Color(0xffebebeb), reason: 'filled 填充底');
      expect(_cells(tester).first.style?.border, isNull);

      await tester.pumpWidget(_host(ElInputOtp(value: '', length: 1, type: ElInputOtpType.underlined)));
      await tester.pumpAndSettle();
      final cell = _cells(tester).first;
      expect(cell.style?.border?.borderBottom.borderColor, _borderColor);
      expect(cell.style?.border?.borderTop.borderWidth, 0, reason: 'underlined 只有底线');
    });

    testWidgets('复用 ElInput border token 的局部覆写', (tester) async {
      const custom = Color(0xff123456);
      await tester.pumpWidget(
        _host(
          ElView(
            style: ElStyle(vars: {ElTokens.$borderColor: custom}),
            child: ElInputOtp(value: '', length: 1),
          ),
        ),
      );

      expect(_cells(tester).first.style?.border?.borderTop.borderColor, custom);
    });

    testWidgets('普通和紧凑模式同步格子边长、间距与字号，cellStyle 保持优先', (tester) async {
      for (final compact in [false, true]) {
        await tester.pumpWidget(
          _host(
            ElView(
              style: ElStyle(vars: {ElDesktopExt.$compact: compact}),
              child: ElInputOtp(value: '12', length: 2),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cells = _cells(tester);
        final first = find.byWidget(cells.first);
        final second = find.byWidget(cells.last);
        expect(tester.getSize(first), Size.square(compact ? 24 : 32));
        expect(tester.getTopLeft(second).dx - tester.getTopLeft(first).dx, compact ? 30 : 40);
        expect(tester.renderObject<ElRenderView>(first).targetStyleForTest.inheritedText.fontSize, compact ? 12 : 14);
      }

      await tester.pumpWidget(
        _host(
          ElInputOtp(
            value: '1',
            length: 1,
            style: ElStyle(vars: {ElDesktopExt.$compact: true}),
            cellStyle: ElStyle(width: 30, height: 30, fontSize: 18),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cell = find.byWidget(_cells(tester).first);
      expect(tester.getSize(cell), Size.square(30));
      expect(tester.renderObject<ElRenderView>(cell).targetStyleForTest.inheritedText.fontSize, 18);
    });

    testWidgets('disabled 不挂 editable、不进焦点链且不建立 IME', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              ElInputOtp(key: const ValueKey('first'), value: '', length: 1),
              ElInputOtp(key: const ValueKey('disabled'), value: '', length: 1, disabled: true, autofocus: true),
              ElInputOtp(key: const ValueKey('last'), value: '', length: 1),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(ElEditableView), findsNWidgets(2));
      expect(
        find.descendant(of: find.byKey(const ValueKey('disabled')), matching: find.byType(ElEditableView)),
        findsNothing,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final first = tester.widget<ElEditableView>(
        find.descendant(of: find.byKey(const ValueKey('first')), matching: find.byType(ElEditableView)),
      );
      expect(first.focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final last = tester.widget<ElEditableView>(
        find.descendant(of: find.byKey(const ValueKey('last')), matching: find.byType(ElEditableView)),
      );
      expect(last.focusNode!.hasFocus, isTrue, reason: 'Tab 必须跳过 disabled OTP');
      await _unmount(tester);
    });
  });

  group('ElInputOtp 语义', () {
    testWidgets('自定义单 code-unit maskCharacter 同步到底层 Editable 与语义', (tester) async {
      expect(() => ElInputOtp(mask: true, maskCharacter: 'ab'), throwsAssertionError);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(ElInputOtp(value: '12', mask: true, maskCharacter: '#', semanticLabel: '自定义验证码')),
        );
        await tester.pump();

        final editable = _editable(tester);
        expect(editable.style.obscureText, isTrue);
        expect(editable.style.obscuringCharacter, '#');
        expect(_textFieldNodes(tester).single.getSemanticsData().value, '##');
      } finally {
        semantics.dispose();
        await _unmount(tester);
      }
    });

    testWidgets('mask 整树只暴露一个文本框与掩码，明文不得泄漏', (tester) async {
      const secret = 'Q7X9';
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_host(ElInputOtp(value: secret, mask: true, semanticLabel: '安全验证码')));
        await tester.pump();

        final textFields = _textFieldNodes(tester);
        expect(textFields, hasLength(1), reason: '外层容器和视觉分格不得复制 Editable 文本框语义');
        final data = textFields.single.getSemanticsData();
        expect(data.label, '安全验证码');
        expect(data.value, '••••');
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.flagsCollection.isObscured, isTrue);
        expect(
          _exposedSemanticText(tester),
          unorderedEquals(const ['安全验证码', '••••']),
          reason: '明文格子、外层 value 或重复 label/value 都不得混入语义树',
        );
        expect(
          textFields.single.owner!.rootSemanticsNode!.toStringDeep(),
          isNot(contains(secret)),
          reason: '完整语义树调试信息也不得含有密码明文',
        );
      } finally {
        semantics.dispose();
        await _unmount(tester);
      }
    });

    testWidgets('非 mask 仍由唯一文本框暴露一次完整值', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_host(ElInputOtp(value: 'A7', semanticLabel: '验证码')));
        await tester.pump();

        final textFields = _textFieldNodes(tester);
        expect(textFields, hasLength(1));
        final data = textFields.single.getSemanticsData();
        expect(data.label, '验证码');
        expect(data.value, 'A7');
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.flagsCollection.isObscured, isFalse);
        expect(_exposedSemanticText(tester), unorderedEquals(const ['验证码', 'A7']), reason: '可视分格不应再把 A、7 拆成独立语义节点');
      } finally {
        semantics.dispose();
        await _unmount(tester);
      }
    });

    testWidgets('disabled + mask 仍是唯一禁用只读密码文本框，明文零泄漏', (tester) async {
      const secret = 'Z9K2';
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_host(ElInputOtp(value: secret, mask: true, disabled: true, semanticLabel: '禁用验证码')));
        await tester.pump();

        final textFields = _textFieldNodes(tester);
        expect(textFields, hasLength(1));
        final data = textFields.single.getSemanticsData();
        expect(data.label, '禁用验证码');
        expect(data.value, '••••');
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.flagsCollection.isReadOnly, isTrue);
        expect(data.flagsCollection.isObscured, isTrue);
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
        expect(_exposedSemanticText(tester), unorderedEquals(const ['禁用验证码', '••••']));
        expect(textFields.single.owner!.rootSemanticsNode!.toStringDeep(), isNot(contains(secret)));
      } finally {
        semantics.dispose();
        await _unmount(tester);
      }
    });
  });
}
