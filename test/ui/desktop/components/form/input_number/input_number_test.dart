import 'package:flutter_base/src/ui/desktop/components/basic/icon/index.dart';
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
    builder: (context, _) => Directionality(
      textDirection: TextDirection.ltr,
      child: ElDesktopTheme(
        child: ElView(style: const ElStyle(width: 600), child: child),
      ),
    ),
  );
}

/// 显示文本的真实出口在编辑器控制器上，不在 Text widget 里
String _displayed(WidgetTester tester) =>
    tester.widget<ElEditableView>(find.byType(ElEditableView)).controller!.text;

Finder _editor(String semanticLabel) => find.byWidgetPredicate(
  (widget) =>
      widget is ElEditableView && widget.style.semanticLabel == semanticLabel,
);

Future<void> _mouseTap(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.down(tester.getCenter(finder));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(_buttonFinder(icon), warnIfMissed: false);
  await tester.pumpAndSettle();
}

Finder _buttonFinder(IconData icon) => find
    .ancestor(
      of: find.byWidgetPredicate(
        (widget) => widget is ElIcon && widget.child == icon,
      ),
      matching: find.byType(ElButtonView),
    )
    .first;

ElButtonView _button(WidgetTester tester, IconData icon) =>
    tester.widget<ElButtonView>(_buttonFinder(icon));

List<SemanticsNode> _semanticsNodes(WidgetTester tester) {
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
  final result = <SemanticsNode>[];

  void collect(SemanticsNode node) {
    result.add(node);
    node.visitChildren((child) {
      collect(child);
      return true;
    });
  }

  collect(root);
  return result;
}

int _activeClientId(WidgetTester tester) {
  final call = tester.testTextInput.log.lastWhere(
    (entry) => entry.method == 'TextInput.setClient',
  );
  return (call.arguments as List<dynamic>).first as int;
}

Future<void> _sendTaggedAutofill(
  WidgetTester tester,
  String id,
  TextEditingValue value,
) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
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

void main() {
  group('ElInputNumber 值通道', () {
    testWidgets('value 受控：显示传入值', (tester) async {
      await tester.pumpWidget(_host(ElInputNumber(value: 7)));
      expect(_displayed(tester), '7');
    });

    testWidgets('modelValue 双向：点 +/- 写回 obs', (tester) async {
      final obs = Obs<num?>(3);
      await tester.pumpWidget(_host(ElInputNumber(modelValue: obs)));

      await _tapIcon(tester, ElIcons.plus);
      expect(obs.value, 4);
      expect(_displayed(tester), '4');

      await _tapIcon(tester, ElIcons.minus);
      expect(obs.value, 3);
    });

    testWidgets('prop 从祖先 ElForm 取值，无需 value/modelValue', (tester) async {
      final model = Obs<Map<String, dynamic>>({'count': 5});
      await tester.pumpWidget(
        _host(
          ElForm(
            modelValue: model,
            child: ElFormItem(
              prop: 'count',
              label: '数量',
              child: ElInputNumber(),
            ),
          ),
        ),
      );

      expect(_displayed(tester), '5', reason: '首帧就该是表单值');

      await _tapIcon(tester, ElIcons.plus);
      expect(model.value['count'], 6, reason: '步进要写回表单 map');
    });

    testWidgets('表单里是 int 也能绑（JSON 常见）', (tester) async {
      final model = Obs<Map<String, dynamic>>({'count': 2});
      await tester.pumpWidget(
        _host(
          ElForm(
            modelValue: model,
            child: ElFormItem(
              prop: 'count',
              label: '数量',
              child: ElInputNumber(),
            ),
          ),
        ),
      );
      expect(_displayed(tester), '2');
    });
  });

  group('ElInputNumber 边界与精度', () {
    testWidgets('max 钳制且到顶后加号锁禁用', (tester) async {
      final obs = Obs<num?>(9);
      await tester.pumpWidget(_host(ElInputNumber(modelValue: obs, max: 10)));

      await _tapIcon(tester, ElIcons.plus);
      expect(obs.value, 10);

      await _tapIcon(tester, ElIcons.plus);
      expect(obs.value, 10, reason: '到顶不再增长');
      expect(
        (_button(tester, ElIcons.plus).event?.disabled ?? false),
        isTrue,
        reason: '到顶应锁禁用，而非静默吞点击',
      );
    });

    testWidgets('空值起步取 min', (tester) async {
      final obs = Obs<num?>(null);
      await tester.pumpWidget(_host(ElInputNumber(modelValue: obs, min: 3)));

      await _tapIcon(tester, ElIcons.plus);
      expect(obs.value, 3, reason: '空态点 + 落到最小可用值');
    });

    testWidgets('小数 step 按 precision 收口', (tester) async {
      final obs = Obs<num?>(1);
      await tester.pumpWidget(
        _host(ElInputNumber(modelValue: obs, step: 0.1, precision: 1)),
      );

      await _tapIcon(tester, ElIcons.plus);
      expect(obs.value, 1.1, reason: '不该出 1.1000000000000001');
      expect(_displayed(tester), '1.1');
    });

    testWidgets('stepStrictly 吸附到 step 整数倍', (tester) async {
      final obs = Obs<num?>(7);
      await tester.pumpWidget(
        _host(ElInputNumber(modelValue: obs, step: 5, stepStrictly: true)),
      );

      await _tapIcon(tester, ElIcons.plus);
      expect(obs.value, 10, reason: '7 + 5 = 12 → 吸附到最近的 5 的倍数');
    });

    testWidgets('disabled 时钮不响应', (tester) async {
      final obs = Obs<num?>(1);
      await tester.pumpWidget(
        _host(ElInputNumber(modelValue: obs, disabled: true)),
      );

      await _tapIcon(tester, ElIcons.plus);
      expect(obs.value, 1);
    });

    testWidgets('残缺文本不炸也不跳值', (tester) async {
      final obs = Obs<num?>(5);
      await tester.pumpWidget(_host(ElInputNumber(modelValue: obs)));

      tester
              .widget<ElEditableView>(find.byType(ElEditableView))
              .controller!
              .text =
          '-';
      await tester.pump();
      expect(obs.value, 5, reason: "手输途中的 '-' 要保留当前值，不抛 FormatException");
    });

    testWidgets('controlsPosition.right 出上下两钮', (tester) async {
      await tester.pumpWidget(
        _host(
          ElInputNumber(
            value: 1,
            controlsPosition: ElInputNumberControls.right,
          ),
        ),
      );
      expect(_buttonFinder(ElIcons.arrowUp), findsOneWidget);
      expect(_buttonFinder(ElIcons.arrowDown), findsOneWidget);
    });

    testWidgets('controls: false 不出钮', (tester) async {
      await tester.pumpWidget(_host(ElInputNumber(value: 1, controls: false)));
      expect(find.byType(ElButtonView), findsNothing);
    });
  });

  group('ElInputNumber draft 失焦收口', () {
    testWidgets("真实 pointer blur 把 '-' 回退到模型值，保持同一 editor 与单 caret", (
      tester,
    ) async {
      final value = Obs<num?>(5);
      final changes = <num?>[];
      final nextFocus = FocusNode(debugLabel: 'input-number-pointer-next');
      addTearDown(value.dispose);
      addTearDown(nextFocus.dispose);
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              ElInputNumber(
                modelValue: value,
                onChanged: changes.add,
                semanticLabel: '数字',
              ),
              ElInput(
                value: 'next',
                focusNode: nextFocus,
                semanticLabel: '下一个',
              ),
            ],
          ),
        ),
      );
      final numberFinder = _editor('数字');
      await _mouseTap(tester, numberFinder);
      final editorBefore = tester.widget<ElEditableView>(numberFinder);
      final controller = editorBefore.controller!;
      final numberFocus = editorBefore.focusNode!;
      expect(numberFocus.hasFocus, isTrue);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '-',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      expect(controller.text, '-');
      expect(value.value, 5);
      expect(changes, isEmpty);

      await _mouseTap(tester, _editor('下一个'));
      await tester.pump();

      final editorAfter = tester.widget<ElEditableView>(numberFinder);
      expect(
        identical(editorAfter.controller, controller),
        isTrue,
        reason: 'blur 只能收口同一 editable，不能换 controller',
      );
      expect(controller.text, '5');
      expect(controller.hasActiveImeComposition, isFalse);
      expect(controller.selections.single, isTrue);
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
      expect(value.value, 5);
      expect(changes, isEmpty, reason: '回退到既有模型值不应伪造 onChange');
      expect(numberFocus.hasFocus, isFalse);
      expect(nextFocus.hasFocus, isTrue, reason: 'draft 收口不得抢回 pointer 已交出的焦点');
    });

    testWidgets("Tab blur 把 '.' 规范化且保持标准焦点遍历", (tester) async {
      final value = Obs<num?>(5);
      final changes = <num?>[];
      final nextFocus = FocusNode(debugLabel: 'input-number-tab-next');
      addTearDown(value.dispose);
      addTearDown(nextFocus.dispose);
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              ElInputNumber(
                modelValue: value,
                onChanged: changes.add,
                semanticLabel: '数字',
              ),
              ElInput(
                value: 'next',
                focusNode: nextFocus,
                semanticLabel: '下一个',
              ),
            ],
          ),
        ),
      );
      final numberFinder = _editor('数字');
      await _mouseTap(tester, numberFinder);
      final controller = tester
          .widget<ElEditableView>(numberFinder)
          .controller!;
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '.',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(nextFocus.hasFocus, isTrue);
      expect(controller.text, '5');
      expect(controller.selections.single, isTrue);
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
      expect(value.value, 5);
      expect(changes, isEmpty);
    });

    testWidgets('活动 IME 的越界 draft 在 pointer blur 后钳制模型与正文且只 change 一次', (
      tester,
    ) async {
      final value = Obs<num?>(5);
      final changes = <num?>[];
      final nextFocus = FocusNode(debugLabel: 'input-number-ime-next');
      addTearDown(value.dispose);
      addTearDown(nextFocus.dispose);
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              ElInputNumber(
                modelValue: value,
                max: 10,
                onChanged: changes.add,
                semanticLabel: '数字',
              ),
              ElInput(
                value: 'next',
                focusNode: nextFocus,
                semanticLabel: '下一个',
              ),
            ],
          ),
        ),
      );
      final numberFinder = _editor('数字');
      await _mouseTap(tester, numberFinder);
      final editorBefore = tester.widget<ElEditableView>(numberFinder);
      final controller = editorBefore.controller!;

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '999',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 0, end: 3),
        ),
      );
      await tester.pump();
      expect(controller.text, '999');
      expect(controller.hasActiveImeComposition, isTrue);
      expect(value.value, 5, reason: 'compositionend 前不能把候选中间态写入模型');
      expect(changes, isEmpty);

      await _mouseTap(tester, _editor('下一个'));
      await tester.pump();

      final editorAfter = tester.widget<ElEditableView>(numberFinder);
      expect(identical(editorAfter.controller, controller), isTrue);
      expect(controller.text, '10');
      expect(controller.hasActiveImeComposition, isFalse);
      expect(controller.selections.single, isTrue);
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
      expect(value.value, 10);
      expect(changes, [10], reason: 'IME 提交与 blur 规范化必须汇成一次模型 change');
      expect(nextFocus.hasFocus, isTrue);
    });
  });

  group('ElInputNumber 语义', () {
    testWidgets('semanticLabel 只落在唯一 ElEditableView 文本框，步进按钮标签独立', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ElInputNumber(value: 12, semanticLabel: '数量', autofillHints: null),
        ),
      );

      try {
        final editable = tester.widget<ElEditableView>(
          find.byType(ElEditableView),
        );
        expect(editable.style.semanticLabel, '数量');
        expect(
          editable.style.inputConfiguration?.autofillConfiguration.enabled,
          isFalse,
        );

        final nodes = _semanticsNodes(tester);
        final textFields = nodes
            .where(
              (node) => node.getSemanticsData().flagsCollection.isTextField,
            )
            .toList();
        expect(textFields, hasLength(1), reason: '复合数字框只能暴露一个真实文本框节点');
        expect(textFields.single.label, '数量');
        expect(textFields.single.value, '12');
        expect(
          nodes.where((node) => node.label == '数量'),
          hasLength(1),
          reason: '外层不得再制造同名空壳语义节点',
        );

        final buttons = nodes
            .where((node) => node.getSemanticsData().flagsCollection.isButton)
            .toList();
        expect(buttons, hasLength(2));
        expect(
          buttons.map((node) => node.label),
          unorderedEquals(const ['减少', '增加']),
        );
        expect(
          buttons.every((node) => !node.label.contains('数量')),
          isTrue,
          reason: '文本框标签不得串到加减按钮',
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('默认 Autofill tagged 回填经过数字解析与 max 钳制，值通道只提交一次', (tester) async {
      final trigger = ElEditableController(text: 'user', singleLine: true);
      final triggerFocus = FocusNode(debugLabel: 'number-autofill-trigger');
      final value = Obs<num?>(1);
      final changes = <num?>[];
      addTearDown(trigger.dispose);
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
                    controller: trigger,
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
                ElInputNumber(
                  modelValue: value,
                  max: 10,
                  precision: 0,
                  onChanged: changes.add,
                ),
              ],
            ),
          ),
        ),
      );
      triggerFocus.requestFocus();
      await tester.pump();
      final fields =
          (tester.testTextInput.setClientArgs!['fields'] as List<dynamic>)
              .cast<Map<dynamic, dynamic>>();
      final number = fields.singleWhere(
        (field) =>
            ((field['autofill'] as Map<dynamic, dynamic>)['hints']
                    as List<dynamic>)
                .isEmpty,
      );
      final numberId =
          (number['autofill'] as Map<dynamic, dynamic>)['uniqueIdentifier']
              as String;

      await _sendTaggedAutofill(
        tester,
        numberId,
        const TextEditingValue(
          text: '999',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();

      expect(value.value, 10);
      expect(changes, [10]);
      expect(triggerFocus.hasFocus, isTrue);
      final numberEditor = tester.widget<ElEditableView>(
        find.byWidgetPredicate(
          (widget) =>
              widget is ElEditableView &&
              widget
                      .style
                      .inputConfiguration
                      ?.autofillConfiguration
                      .autofillHints
                      .isEmpty ==
                  true,
        ),
      );
      expect(numberEditor.controller!.text, '10');
    });

    testWidgets('disabled 数字框仍暴露唯一禁用只读文本框语义', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(ElInputNumber(value: 12, disabled: true, semanticLabel: '禁用数量')),
      );
      try {
        final nodes = _semanticsNodes(tester);
        final textFields = nodes
            .where(
              (node) => node.getSemanticsData().flagsCollection.isTextField,
            )
            .toList();
        expect(textFields, hasLength(1));
        final data = textFields.single.getSemanticsData();
        expect(data.label, '禁用数量');
        expect(data.value, '12');
        expect(data.flagsCollection.isReadOnly, isTrue);
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      } finally {
        semantics.dispose();
      }
    });
  });
}
