import 'dart:ui' show CheckedState, SemanticsAction, Tristate;

import 'package:flutter_base/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _checkbox(BuildContext context, ElCheckbox component, ElCheckboxState state) => ElView(
  style: ElStyle(width: 100, height: 32, backgroundColor: state.checked ? Color(0xff336699) : Color(0xffeeeeee)),
);
Widget _radio<T>(BuildContext context, ElRadio<T> component, ElRadioState state) => ElView(
  style: ElStyle(width: 100, height: 32, backgroundColor: state.checked ? Color(0xff336699) : Color(0xffeeeeee)),
);
Widget _button(BuildContext context, ElButton component, Obs<bool> model) => ElButtonView(
  onPressed: () => model.value = !model.value,
  focusNode: component.focusNode,
  disabled: component.disabled,
  toggled: model.value,
  style: ElStyle(width: 100, height: 32),
);
Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElComponentProvider(
    builders: ElComponents(button: _button, checkbox: _checkbox, radio: _radio),
    child: ElView(
      style: ElStyle(alignment: .topLeft),
      child: child,
    ),
  ),
);

class _Model extends ValueNotifier<bool> {
  _Model(super.value);
  bool get listening => hasListeners;
}

Widget _toggle(String kind, {ValueNotifier<bool>? model, ValueChanged<bool>? onChanged, bool disabled = false}) =>
    switch (kind) {
      'button' => ElButton.toggle(key: ValueKey('control'), modelValue: model, onChanged: onChanged, disabled: disabled),
      'checkbox' => ElCheckbox.toggle(
        key: ValueKey('control'),
        modelValue: model,
        onChanged: onChanged,
        disabled: disabled,
      ),
      _ => ElRadio.toggle(key: ValueKey('control'), modelValue: model, onChanged: onChanged, disabled: disabled),
    };

void main() {
  for (final kind in ['button', 'checkbox', 'radio']) {
    testWidgets('$kind 切换形态统一开关语义、点击和 Space 双向切换', (tester) async {
      final model = _Model(false);
      final changes = <bool>[];
      addTearDown(model.dispose);
      await tester.pumpWidget(_host(_toggle(kind, model: model, onChanged: changes.add)));
      final semantics = tester.ensureSemantics();
      try {
        var node = tester.getSemantics(find.byKey(ValueKey('control')));
        expect(node.flagsCollection.isToggled, Tristate.isFalse);
        expect(node.flagsCollection.isChecked, CheckedState.none);
        expect(node.flagsCollection.isInMutuallyExclusiveGroup, isFalse);
        await tester.tap(find.byKey(ValueKey('control')));
        await tester.pump();
        expect(model.value, isTrue);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        expect(model.value, isTrue);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(model.value, isFalse);
        node = tester.getSemantics(find.byKey(ValueKey('control')));
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(model.value, isTrue);
        expect(changes, [true, false, true]);
        await tester.pumpWidget(ElView());
        expect(model.listening, isFalse);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('$kind 切换形态不接入 FormItem，换绑和外部回灌保持 bool', (tester) async {
      final first = _Model(false);
      final second = _Model(true);
      final form = ValueNotifier<Map<String, dynamic>>({'choice': '原始字段'});
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(form.dispose);
      Widget scene(ValueNotifier<bool> model) => _host(
        ElForm(
          modelValue: form,
          child: ElFormItem(
            prop: 'choice',
            child: _toggle(kind, model: model),
          ),
        ),
      );
      await tester.pumpWidget(scene(first));
      await tester.tap(find.byKey(ValueKey('control')));
      await tester.pump();
      expect(first.value, isTrue);
      expect(form.value['choice'], '原始字段');
      await tester.pumpWidget(scene(second));
      await tester.pump();
      expect(first.listening, isFalse);
      second.value = false;
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('control')));
      await tester.pump();
      expect(second.value, isTrue);
      expect(form.value['choice'], '原始字段');
    });

    testWidgets('$kind 切换形态禁用后不可激活', (tester) async {
      final model = _Model(false);
      addTearDown(model.dispose);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_host(_toggle(kind, model: model, disabled: true)));
        await tester.tap(find.byKey(ValueKey('control')), warnIfMissed: false);
        await tester.pump();
        expect(model.value, isFalse);
        expect(
          tester.getSemantics(find.byKey(ValueKey('control'))).getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('普通 checkbox 半选与 radio 单选仍使用分组选项语义', (tester) async {
    final selection = ValueNotifier<List<String>>([]);
    final radio = ValueNotifier<String?>('a');
    addTearDown(selection.dispose);
    addTearDown(radio.dispose);
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElCheckboxGroup<String>(
              modelValue: selection,
              child: Wrap(
                children: [ElCheckbox(key: ValueKey('mixed'), label: 'a', indeterminate: true)],
              ),
            ),
            ElRadioGroup<String>(
              modelValue: radio,
              child: Wrap(
                children: [ElRadio(key: ValueKey('radio'), label: 'a')],
              ),
            ),
          ],
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    try {
      expect(tester.getSemantics(find.byKey(ValueKey('mixed'))).flagsCollection.isChecked, CheckedState.mixed);
      final node = tester.getSemantics(find.byKey(ValueKey('radio')));
      expect(node.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(node.flagsCollection.isToggled, Tristate.none);
      await tester.tap(find.byKey(ValueKey('radio')));
      await tester.pump();
      expect(radio.value, 'a');
      await tester.tap(find.byKey(ValueKey('mixed')));
      await tester.pump();
      expect(selection.value, ['a']);
    } finally {
      semantics.dispose();
    }
  });
}
