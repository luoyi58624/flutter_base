import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(alignment: .topLeft, child: child),
);

void main() {
  testWidgets('组外 maybeOf 返回 null，of 要求分组祖先', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            expect(ElCheckboxGroup.maybeOf(context), isNull);
            expect(ElRadioGroup.maybeOf(context), isNull);
            expect(() => ElCheckboxGroup.of(context), throwsAssertionError);
            expect(() => ElRadioGroup.of(context), throwsAssertionError);
            return SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('多选 Scope 直接读写模型，保持集合类型并提供增删与数量标志', (tester) async {
    final model = ValueNotifier<List<String>>(['a']);
    addTearDown(model.dispose);
    late ElCheckboxGroupScope scope;
    var builds = 0;
    await tester.pumpWidget(
      _host(
        ElCheckboxGroup<String>(
          modelValue: model,
          min: 1,
          max: 2,
          child: Builder(
            builder: (context) {
              scope = ElCheckboxGroup.of(context);
              builds++;
              return Text('${scope.modelValue}');
            },
          ),
        ),
      ),
    );
    expect(scope.hasElement('a'), isTrue);
    expect(scope.disabledRemove, isTrue);
    final before = builds;
    scope.addElement('b');
    await tester.pump();
    expect(model.value, ['a', 'b']);
    expect(model.value, isA<List<String>>());
    expect(scope.disabledAdd, isTrue);
    expect(builds, greaterThan(before));
    scope.removeElement('a');
    await tester.pump();
    expect(model.value, ['b']);
    scope.modelValue = 'c';
    await tester.pump();
    expect(model.value, ['b', 'c']);
    scope.modelValue = 'c';
    await tester.pump();
    expect(model.value, ['b']);
    scope.modelValue = ['x', 'y'];
    await tester.pump();
    expect(model.value, ['x', 'y']);
    scope.clear();
    await tester.pump();
    expect(model.value, isEmpty);
    model.value = ['external'];
    await tester.pump();
    expect(scope.modelValue, ['external']);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('listen false 不订阅重建，Scope 仍可读取实时模型', (tester) async {
    final checks = ValueNotifier<List<String>>([]);
    final radio = ValueNotifier<String?>(null);
    addTearDown(checks.dispose);
    addTearDown(radio.dispose);
    var checkBuilds = 0, radioBuilds = 0;
    late ElCheckboxGroupScope checkScope;
    late ElRadioGroupScope radioScope;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElCheckboxGroup<String>(
              modelValue: checks,
              child: Builder(
                builder: (context) {
                  checkBuilds++;
                  checkScope = ElCheckboxGroup.of(context, listen: false);
                  return SizedBox();
                },
              ),
            ),
            ElRadioGroup<String>(
              modelValue: radio,
              child: Builder(
                builder: (context) {
                  radioBuilds++;
                  radioScope = ElRadioGroup.of(context, listen: false);
                  return SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
    checks.value = ['a'];
    radio.value = 'b';
    await tester.pump();
    expect(checkBuilds, 1);
    expect(radioBuilds, 1);
    expect(checkScope.modelValue, ['a']);
    expect(radioScope.modelValue, 'b');
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('自定义单选无需登记，required false 支持取消且回调包含 null', (tester) async {
    final model = ValueNotifier<String?>(null);
    final changes = <String?>[];
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(
        ElRadioGroup<String>(
          modelValue: model,
          required: false,
          onChanged: changes.add,
          child: Builder(
            builder: (context) {
              final scope = ElRadioGroup.of(context);
              return ElButtonView(
                key: ValueKey('custom-option'),
                onPressed: () => scope.modelValue = 'custom',
                child: scope.modelValue ?? 'empty',
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('custom-option')));
    await tester.pump();
    expect(model.value, 'custom');
    await tester.tap(find.byKey(ValueKey('custom-option')));
    await tester.pump();
    expect(model.value, isNull);
    expect(changes, ['custom', null]);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('嵌套分组查询最近同类祖先', (tester) async {
    final checks = <ElCheckboxGroupScope>[];
    final radios = <ElRadioGroupScope>[];
    Widget checkProbe() => Builder(
      builder: (context) {
        checks.add(ElCheckboxGroup.of(context));
        return SizedBox();
      },
    );
    Widget radioProbe() => Builder(
      builder: (context) {
        radios.add(ElRadioGroup.of(context));
        return SizedBox();
      },
    );
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElCheckboxGroup<String>(
              value: ['outer'],
              child: Column(
                mainAxisSize: .min,
                children: [
                  checkProbe(),
                  ElCheckboxGroup<String>(value: ['inner'], child: checkProbe()),
                ],
              ),
            ),
            ElRadioGroup<String>(
              value: 'outer',
              child: Column(
                mainAxisSize: .min,
                children: [
                  radioProbe(),
                  ElRadioGroup<String>(value: 'inner', child: radioProbe()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    expect(checks.map((scope) => scope.modelValue), [
      ['outer'],
      ['inner'],
    ]);
    expect(radios.map((scope) => scope.modelValue), ['outer', 'inner']);
  });

  testWidgets('可直接组合官方 Radio，Tab 与方向键由官方分组处理', (tester) async {
    final model = ValueNotifier<String?>('a');
    final first = FocusNode(), last = FocusNode();
    addTearDown(model.dispose);
    addTearDown(first.dispose);
    addTearDown(last.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElRadioGroup<String>(
            modelValue: model,
            child: Column(
              children: [
                Radio<Object?>(value: 'a', focusNode: first),
                Radio<Object?>(value: 'disabled', enabled: false),
                Radio<Object?>(value: 'b', focusNode: last),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(first.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(model.value, 'b');
    expect(last.hasFocus, isTrue);
    await tester.pumpWidget(SizedBox());
  });
}
