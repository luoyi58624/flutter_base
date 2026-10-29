import 'package:flutter_base/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _checkbox(BuildContext context, ElCheckbox component, ElCheckboxState state) => ElView(
  style: ElStyle(width: 80, height: 24, bgColor: state.checked ? Color(0xff123456) : Color(0xffeeeeee)),
  child: component.label,
);
Widget _radio<T>(BuildContext context, ElRadio<T> component, ElRadioState state) => ElView(
  style: ElStyle(width: 80, height: 24, bgColor: state.checked ? Color(0xff123456) : Color(0xffeeeeee)),
  child: component.label,
);
ElComponentBuilders get _builders => ElComponentBuilders(checkboxBuilder: _checkbox, radioBuilder: _radio);
Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElComponentProvider(
    builders: _builders,
    child: ElView(
      style: ElStyle(alignment: .topLeft),
      child: child,
    ),
  ),
);

class _Model<T> extends ValueNotifier<T> {
  _Model(super.value);
  bool get listening => hasListeners;
}

class _CheckboxProbe extends ElCheckbox {
  _CheckboxProbe({required super.modelValue, required super.onChanged, required this.capture}) : super.toggle();
  final void Function(ValueNotifier<Object?>) capture;
  @override
  Widget obsBuilder(BuildContext context) {
    capture($obs);
    return super.obsBuilder(context);
  }
}

void main() {
  testWidgets('label 只显示文案，组优先记录 value，缺省时回退 label', (tester) async {
    final checks = ValueNotifier<List<Object>>([]);
    final radio = ValueNotifier<Object?>(null);
    addTearDown(checks.dispose);
    addTearDown(radio.dispose);
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElCheckboxGroup<Object>(
              modelValue: checks,
              children: [
                ElCheckbox(key: ValueKey('explicit-check'), value: 7, label: '七号选项'),
                ElCheckbox(key: ValueKey('fallback-check'), label: '标签值'),
              ],
            ),
            ElRadioGroup<Object>(
              modelValue: radio,
              children: [
                ElRadio(value: 9, label: '九号选项', key: ValueKey('explicit-radio')),
                ElRadio(label: '标签单选', key: ValueKey('fallback-radio')),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('explicit-check')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('fallback-check')));
    await tester.pump();
    expect(checks.value, [7, '标签值']);
    expect(find.byWidgetPredicate((widget) => widget is ElView && widget.child == '七号选项'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('explicit-radio')));
    await tester.pump();
    expect(radio.value, 9);
    await tester.tap(find.byKey(ValueKey('fallback-radio')));
    await tester.pump();
    expect(radio.value, '标签单选');
  });

  testWidgets('继承多选框可继续复用普通绑定基类与 obsBuilder 值通道', (tester) async {
    final model = _Model(false);
    addTearDown(model.dispose);
    final changes = <bool>[];
    late ValueNotifier<Object?> internal;
    final ElModelValue<Object?> field = _CheckboxProbe(
      modelValue: model,
      onChanged: changes.add,
      capture: (value) => internal = value,
    );
    await tester.pumpWidget(_host(field));
    internal.value = true;
    await tester.pump();
    expect(model.value, isTrue);
    expect(changes, [true]);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is ElView &&
            (widget.semantics?.properties.checked != null || widget.semantics?.properties.toggled != null),
      ),
    );
    await tester.pump();
    expect(model.value, isFalse);
    expect(changes, [true, false]);
    await tester.pumpWidget(ElView());
    expect(model.listening, isFalse);
  });

  testWidgets('toggle 不接入外层分组的值或禁用规则', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElCheckboxGroup<String>(
              value: [],
              disabled: true,
              children: [ElCheckbox.toggle(key: ValueKey('check'), value: false, onChanged: (_) => changes++)],
            ),
            ElRadioGroup<String>(
              disabled: true,
              children: [ElRadio<String>.toggle(key: ValueKey('radio'), value: false, onChanged: (_) => changes++)],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('check')), warnIfMissed: false);
    await tester.tap(find.byKey(ValueKey('radio')), warnIfMissed: false);
    await tester.pump();
    expect(changes, 2);
    expect(
      tester
          .widgetList<ElView>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is ElView &&
                  (widget.semantics?.properties.checked != null || widget.semantics?.properties.toggled != null),
            ),
          )
          .every((view) => view.event?.disabled != true),
      isTrue,
    );
  });

  test('外观登记支持合并和清空，没有分组 Builder', () {
    expect(_builders.merge(ElComponentBuilders()), _builders);
    expect(_builders.copyWith(checkboxBuilder: null).checkboxBuilder, isNull);
    expect(_builders.copyWith(radioBuilder: null).radioBuilder, isNull);
  });

  testWidgets('通用多选分组保持集合类型、数量限制和独立的外观选择', (tester) async {
    final model = _Model<List<String>>(['a']);
    addTearDown(model.dispose);
    ElCheckboxState? secondState;
    Widget alternate(BuildContext context, ElCheckbox component, ElCheckboxState state) {
      secondState = state;
      return _checkbox(context, component, state);
    }

    await tester.pumpWidget(
      _host(
        ElCheckboxGroup<String>(
          modelValue: model,
          min: 1,
          max: 2,
          children: [
            ElCheckbox(key: ValueKey('a'), value: 'a', label: 'A'),
            ElComponentProvider(
              builders: _builders.copyWith(checkboxBuilder: alternate),
              child: ElCheckbox(key: ValueKey('b'), value: 'b', label: 'B'),
            ),
            ElCheckbox(key: ValueKey('c'), value: 'c', label: 'C'),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('b')));
    await tester.pump();
    expect(model.value, ['a', 'b']);
    expect(model.value, isA<List<String>>());
    expect(secondState!.checked, isTrue);
    await tester.tap(find.byKey(ValueKey('c')), warnIfMissed: false);
    await tester.pump();
    expect(model.value, ['a', 'b']);
    await tester.tap(find.byKey(ValueKey('a')));
    await tester.pump();
    expect(model.value, ['b']);
    expect(secondState!.disabled, isTrue);
    await tester.pumpWidget(ElView());
    expect(model.listening, isFalse);
  });

  testWidgets('仅依赖 el_ui 的分组表单不让叶子回写 bool 或独立模型', (tester) async {
    final form = _Model<Map<String, dynamic>>({
      'checks': <String>['a'],
      'radio': null,
    });
    addTearDown(form.dispose);
    await tester.pumpWidget(
      _host(
        ElForm(
          modelValue: form,
          child: Column(
            mainAxisSize: .min,
            children: [
              ElFormItem(
                prop: 'checks',
                child: ElCheckboxGroup<String>(
                  children: [ElCheckbox(key: ValueKey('check'), label: 'b')],
                ),
              ),
              ElFormItem(
                prop: 'radio',
                child: ElRadioGroup<String>(
                  children: [ElRadio<String>(key: ValueKey('radio'), label: 'b')],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('check')));
    await tester.pump();
    expect(form.value['checks'], ['a', 'b']);
    await tester.tap(find.byKey(ValueKey('radio')));
    await tester.pump();
    expect(form.value['radio'], 'b');
  });

  testWidgets('嵌套单选重排后保持内部焦点和方向键顺序', (tester) async {
    final model = _Model<int?>(3);
    addTearDown(model.dispose);
    Widget scene(List<int> order) => _host(
      ElRadioGroup<int>(
        modelValue: model,
        children: [
          for (final value in order)
            ElView(
              key: ValueKey(value),
              child: ElRadio<int>(key: ValueKey('radio-$value'), value: value, disabled: value == 2, label: '$value'),
            ),
        ],
      ),
    );
    await tester.pumpWidget(scene([1, 2, 3]));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ElView>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is ElView &&
                  (widget.semantics?.properties.checked != null || widget.semantics?.properties.toggled != null),
            ),
          )
          .where((view) => view.focusNode?.skipTraversal == false),
      hasLength(1),
    );
    await tester.tap(find.byKey(ValueKey('radio-1')));
    await tester.pump();
    final firstFocus = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(model.value, 3);
    await tester.pumpWidget(scene([3, 2, 1]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('radio-3')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(model.value, 1);
    expect(FocusManager.instance.primaryFocus, same(firstFocus));
    await tester.pumpWidget(ElView());
    await tester.pump();
    expect(model.listening, isFalse);
  });

  testWidgets('公开声明的身份互换不会撞上上一帧的注册信息', (tester) async {
    Widget scene(bool swapped) => _host(
      ElRadioGroup<String>(
        value: 'a',
        children: [
          ElView(
            key: ValueKey(1),
            child: ElRadio(value: swapped ? 'b' : 'a'),
          ),
          ElView(
            key: ValueKey(2),
            child: ElRadio(value: swapped ? 'a' : 'b'),
          ),
        ],
      ),
    );
    await tester.pumpWidget(scene(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(scene(true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('只替换外观实现时选择和交互仍由通用宿主提供', (tester) async {
    final model = _Model(false);
    addTearDown(model.dispose);
    Widget first(BuildContext context, ElCheckbox component, ElCheckboxState state) =>
        ElView(style: ElStyle(width: 80, height: 24), child: 'first');
    Widget second(BuildContext context, ElCheckbox component, ElCheckboxState state) =>
        ElView(style: ElStyle(width: 80, height: 24), child: state.checked ? 'checked' : 'empty');
    Widget scene(Widget Function(BuildContext, ElCheckbox, ElCheckboxState) builder) => _host(
      ElComponentProvider(
        builders: _builders.copyWith(checkboxBuilder: builder),
        child: ElCheckbox.toggle(key: ValueKey('field'), modelValue: model),
      ),
    );
    await tester.pumpWidget(scene(first));
    await tester.tap(find.byKey(ValueKey('field')));
    await tester.pump();
    expect(model.value, isTrue);
    await tester.pumpWidget(scene(second));
    await tester.pump();
    expect(model.value, isTrue);
    await tester.tap(find.byKey(ValueKey('field')));
    await tester.pump();
    expect(model.value, isFalse);
  });
}
