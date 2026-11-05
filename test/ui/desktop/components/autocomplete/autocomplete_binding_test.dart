import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(size: Size(800, 600)),
  child: Directionality(
    textDirection: .ltr,
    child: ElComponentProvider(
      components: el.desktopComponents,
      child: Overlay.wrap(
        clipBehavior: Clip.none,
        alwaysSizeToContent: true,
        child: ElView(
          style: const ElStyle(width: 560, height: 420, alignment: .center),
          child: ElView(style: const ElStyle(width: 280), child: child),
        ),
      ),
    ),
  ),
);

Future<void> _focus(WidgetTester tester, FocusNode node) async {
  node.requestFocus();
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String text) async {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _settleQuery(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

Finder _option(int index) => find.byKey(ValueKey<(String, int)>(('el-autocomplete-option', index)));

Finder _text(String value) => find.byWidgetPredicate((widget) => widget is ElView && widget.child == value);

Widget _decoyPrefix(ElEditableController controller) => ElView(
  style: const ElStyle(width: 52, height: 24),
  child: ElEditableView(
    controller: controller,
    style: ElEditableStyle(softWrap: false, semanticLabel: 'prefix decoy'),
  ),
);

void main() {
  testWidgets('自动补全输入与候选同步普通和紧凑模式', (tester) async {
    for (final compact in [false, true]) {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _host(
          ElAutocomplete<String>(
            key: ValueKey(compact),
            value: 'a',
            focusNode: focusNode,
            debounce: Duration.zero,
            style: ElStyle(vars: {ElDesktopExt.$compact: compact}),
            fetchSuggestions: (_) => [ElLabelModel('Alpha', 'a')],
          ),
        ),
      );
      await _focus(tester, focusNode);
      await _settleQuery(tester);
      expect(tester.getSize(_option(0)).height, compact ? 32 : 36);
      expect(editableTextStyleOf(tester.element(find.byType(ElEditableView)))?.fontSize, compact ? 13 : 14);
    }
  });

  testWidgets('唯一后端：可编辑态只有一个 ElEditableView，禁用态不挂输入旁路', (tester) async {
    await tester.pumpWidget(
      _host(ElAutocomplete<String>(value: '', fetchSuggestions: (_) => [ElLabelModel('alpha', 'a')])),
    );

    expect(find.byType(ElEditableView), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);

    await tester.pumpWidget(
      _host(
        ElAutocomplete<String>(
          value: 'disabled',
          disabled: true,
          fetchSuggestions: (_) => [ElLabelModel('alpha', 'a')],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ElEditableView), findsNothing);
    expect(find.byType(EditableText), findsNothing);

    final focusNode = FocusNode();
    var requests = 0;
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      _host(
        ElAutocomplete<String>(
          value: 'read only',
          readOnly: true,
          focusNode: focusNode,
          debounce: Duration.zero,
          fetchSuggestions: (_) {
            requests++;
            return [ElLabelModel('alpha', 'a')];
          },
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(ElEditableView), findsOneWidget);
    expect(requests, 0, reason: 'readOnly 可选择复制，但不得请求或选择候选');
    expect(find.byKey(const ValueKey<String>('el-autocomplete-panel')), findsNothing);
  });

  testWidgets('受控 value：键入与选择各写回一次，item/header/footer 真实挂载', (tester) async {
    final focusNode = FocusNode();
    final changes = <String>[];
    final selected = <ElLabelModel<String>>[];
    var value = '';
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(
          ElAutocomplete<String>(
            value: value,
            focusNode: focusNode,
            debounce: Duration.zero,
            triggerOnFocus: false,
            fetchSuggestions: (query) => [ElLabelModel('$query-alpha', 'a'), ElLabelModel('$query-beta', 'b')],
            header: const ElView(child: '候选头'),
            footer: const ElView(child: '候选尾'),
            itemBuilder: (context, item, active) => ElView(child: '${item.label}:${active ? 'active' : 'idle'}'),
            onChanged: (next) {
              changes.add(next);
              setState(() => value = next);
            },
            onSelected: selected.add,
          ),
        ),
      ),
    );
    await _focus(tester, focusNode);
    await _type(tester, 'q');
    await _settleQuery(tester);

    expect(value, 'q');
    expect(changes, ['q']);
    expect(_text('候选头'), findsOneWidget);
    expect(_text('候选尾'), findsOneWidget);
    expect(_text('q-alpha:idle'), findsOneWidget);

    await tester.tap(_option(0));
    await tester.pump();
    await tester.pump();
    expect(value, 'q-alpha');
    expect(changes, ['q', 'q-alpha']);
    expect(selected.map((item) => item.value), ['a']);
    expect(focusNode.hasFocus, isTrue);
    final controller = tester.widget<ElEditableView>(find.byType(ElEditableView)).controller!;
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.extentOffset, 'q-alpha'.length);
  });

  testWidgets('prefix 中的 decoy Editable 不会截获指针候选提交', (tester) async {
    final model = Obs<String>('');
    final focusNode = FocusNode();
    final decoy = ElEditableController(text: 'decoy', singleLine: true);
    addTearDown(model.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(decoy.dispose);

    await tester.pumpWidget(
      _host(
        ElAutocomplete<String>(
          modelValue: model,
          focusNode: focusNode,
          prefix: _decoyPrefix(decoy),
          debounce: Duration.zero,
          highlightFirst: true,
          fetchSuggestions: (_) => [ElLabelModel('alpha', 'a'), ElLabelModel('beta', 'b')],
        ),
      ),
    );
    await _focus(tester, focusNode);
    await _settleQuery(tester);
    expect(find.byType(ElEditableView), findsNWidgets(2));

    await tester.tap(_option(1));
    await tester.pump();
    await tester.pump();
    expect(model.value, 'beta');
    expect(decoy.text, 'decoy', reason: '候选点击只能写 ElAutocomplete 主输入的稳定 control');
  });

  testWidgets('prefix 中的 decoy Editable 不会截获 Enter 候选提交', (tester) async {
    final model = Obs<String>('');
    final focusNode = FocusNode();
    final decoy = ElEditableController(text: 'decoy', singleLine: true);
    addTearDown(model.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(decoy.dispose);

    await tester.pumpWidget(
      _host(
        ElAutocomplete<String>(
          modelValue: model,
          focusNode: focusNode,
          prefix: _decoyPrefix(decoy),
          debounce: Duration.zero,
          highlightFirst: true,
          fetchSuggestions: (_) => [ElLabelModel('alpha', 'a'), ElLabelModel('beta', 'b')],
        ),
      ),
    );
    await _focus(tester, focusNode);
    await _settleQuery(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(model.value, 'alpha');
    expect(decoy.text, 'decoy', reason: '键盘提交不能依赖 Element DFS 的第一个 ElEditableView');
  });

  testWidgets('modelValue 双向绑定：键入、候选提交与外部回灌均不重复通知', (tester) async {
    final model = Obs<String>('seed');
    final focusNode = FocusNode();
    final changes = <String>[];
    addTearDown(model.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        ElAutocomplete<String>(
          modelValue: model,
          focusNode: focusNode,
          debounce: Duration.zero,
          triggerOnFocus: false,
          fetchSuggestions: (query) => [ElLabelModel('$query-result', 'r')],
          onChanged: changes.add,
        ),
      ),
    );
    await _focus(tester, focusNode);
    await _type(tester, 'next');
    await _settleQuery(tester);
    expect(model.value, 'next');
    expect(changes, ['next']);

    await tester.tap(_option(0));
    await tester.pump();
    expect(model.value, 'next-result');
    expect(changes, ['next', 'next-result']);

    model.value = 'external';
    await tester.pump();
    await tester.pump();
    expect(tester.widget<ElEditableView>(find.byType(ElEditableView)).controller!.text, 'external');
    expect(changes, ['next', 'next-result', 'external']);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey<String>('el-autocomplete-panel')), findsNothing);
  });

  testWidgets('候选提交复用 Editable 事务：maxLength 字素截断只回写一次', (tester) async {
    final model = Obs<String>('');
    final focusNode = FocusNode();
    final changes = <String>[];
    final selected = <String?>[];
    addTearDown(model.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        ElAutocomplete<String>(
          modelValue: model,
          focusNode: focusNode,
          debounce: Duration.zero,
          maxLength: 5,
          highlightFirst: true,
          fetchSuggestions: (_) => [ElLabelModel('A👍🏽B', 'accepted')],
          onChanged: changes.add,
          onSelected: (item) => selected.add(item.value),
        ),
      ),
    );
    await _focus(tester, focusNode);
    await _settleQuery(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(model.value, 'A👍🏽');
    expect(changes, ['A👍🏽'], reason: '候选必须先经 Editable maxLength 策略，再向模型提交最终值一次');
    expect(selected, ['accepted']);
    final controller = tester.widget<ElEditableView>(find.byType(ElEditableView)).controller!;
    expect(controller.lastChangeSet?.source, EditableEditSource.keyboard);
    expect(controller.undoDepth, 1);
    controller.undoEdit();
    await tester.pump();
    expect(model.value, '');
    expect(changes, ['A👍🏽', '']);
  });

  testWidgets('候选提交被 Editable 拦截器拒绝时模型、选中通知与弹层状态零污染', (tester) async {
    final model = Obs<String>('');
    final focusNode = FocusNode();
    final changes = <String>[];
    final selected = <String?>[];
    addTearDown(model.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        ElAutocomplete<String>(
          modelValue: model,
          focusNode: focusNode,
          debounce: Duration.zero,
          highlightFirst: true,
          inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => oldValue)],
          fetchSuggestions: (_) => [ElLabelModel('blocked', 'blocked')],
          onChanged: changes.add,
          onSelected: (item) => selected.add(item.value),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await _settleQuery(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(model.value, '');
    expect(changes, isEmpty);
    expect(selected, isEmpty);
    expect(find.byKey(const ValueKey<String>('el-autocomplete-panel')), findsOneWidget);
  });

  testWidgets('ElForm prop：输入值只经外层 String 通道写回并触发 change/blur 校验', (tester) async {
    final model = Obs<Map<String, dynamic>>({'name': ''});
    final focusNode = FocusNode();
    late ElFormState form;
    addTearDown(model.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        ElForm(
          modelValue: model,
          rules: {
            'name': [ElRequiredFormRule(message: '必填')],
          },
          child: Builder(
            builder: (context) {
              form = ElForm.of(context);
              return ElFormItem(
                prop: 'name',
                child: ElAutocomplete<String>(
                  focusNode: focusNode,
                  debounce: Duration.zero,
                  triggerOnFocus: false,
                  fetchSuggestions: (query) => [ElLabelModel('$query-user', 'u')],
                ),
              );
            },
          ),
        ),
      ),
    );
    await _focus(tester, focusNode);
    await _type(tester, 'alice');
    expect(model.value['name'], 'alice');
    expect(model.value['name'], isA<String>());
    expect(form.errorMessages['name'], isNull);

    await _type(tester, '');
    focusNode.unfocus();
    await tester.pump();
    await tester.pump();
    expect(model.value['name'], '');
    expect(form.errorMessages['name'], '必填');
  });
}
