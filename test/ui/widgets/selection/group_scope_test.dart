import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _radio<T>(BuildContext context, ElRadio<T> component, ElRadioState state) => Text('${component.value}');

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElComponentProvider(
    builders: ElComponentBuilders(radioBuilder: _radio),
    child: ElView(
      style: ElStyle(alignment: .topLeft),
      child: child,
    ),
  ),
);

void main() {
  testWidgets('组外 maybeOf 返回 null', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            expect(ElCheckboxGroup.maybeOf(context), isNull);
            expect(ElRadioGroup.maybeOf(context), isNull);
            return SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('多选上下文订阅模型变化，公开操作遵循数量限制与整组禁用', (tester) async {
    final model = ValueNotifier<List<String>>(['a']);
    addTearDown(model.dispose);
    late ElCheckboxGroupScope scope;
    var builds = 0;
    final probe = Builder(
      builder: (context) {
        scope = ElCheckboxGroup.maybeOf(context)!;
        builds++;
        return Text('${scope.value}');
      },
    );
    Widget scene({bool disabled = false}) =>
        _host(ElCheckboxGroup<String>(modelValue: model, min: 1, max: 2, disabled: disabled, children: [probe]));

    await tester.pumpWidget(scene());
    expect(scope.value, ['a']);
    expect(scope.min, 1);
    expect(scope.max, 2);
    expect(scope.isLast, isTrue);
    expect(scope.limitReached(true), isTrue);
    expect(() => scope.value.add('b'), throwsUnsupportedError);

    scope.setSelected('a', false);
    expect(model.value, ['a']);
    final initialBuilds = builds;
    scope.setSelected('b', true);
    await tester.pump();
    expect(model.value, ['a', 'b']);
    expect(scope.value, ['a', 'b']);
    expect(builds, greaterThan(initialBuilds));
    expect(scope.limitReached(false), isTrue);
    scope.setSelected('c', true);
    expect(model.value, ['a', 'b']);
    scope.setSelected('a', false);
    await tester.pump();
    expect(model.value, ['b']);

    model.value = ['c'];
    await tester.pump();
    expect(scope.value, ['c']);
    await tester.pumpWidget(scene(disabled: true));
    expect(scope.disabled, isTrue);
    scope.setSelected('b', true);
    expect(model.value, ['c']);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('单选上下文订阅变化，只选择已登记且启用的选项', (tester) async {
    final model = ValueNotifier<String?>('a');
    addTearDown(model.dispose);
    late ElRadioGroupScope scope;
    var builds = 0;
    final probe = Builder(
      builder: (context) {
        scope = ElRadioGroup.maybeOf(context)!;
        builds++;
        return Text('${scope.value}');
      },
    );
    final children = <Widget>[ElRadio(value: 'a'), ElRadio(value: 'b', disabled: true), ElRadio(value: 'c'), probe];
    Widget scene({bool disabled = false}) =>
        _host(ElRadioGroup<String>(modelValue: model, disabled: disabled, children: children));

    await tester.pumpWidget(scene());
    await tester.pumpAndSettle();
    expect(scope.value, 'a');
    expect(scope.isLast, isTrue);
    final initialBuilds = builds;
    scope.select('c');
    await tester.pump();
    expect(model.value, 'c');
    expect(scope.value, 'c');
    expect(builds, greaterThan(initialBuilds));
    scope.select('b');
    scope.select('missing');
    expect(model.value, 'c');

    model.value = null;
    await tester.pump();
    expect(scope.value, isNull);
    await tester.pumpWidget(scene(disabled: true));
    await tester.pumpAndSettle();
    expect(scope.disabled, isTrue);
    scope.select('a');
    expect(model.value, isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('嵌套分组读取最近上下文，isLast 按直接布局项计算', (tester) async {
    final checks = <ElCheckboxGroupScope>[];
    final radios = <ElRadioGroupScope>[];
    Widget checkProbe() => Builder(
      builder: (context) {
        checks.add(ElCheckboxGroup.maybeOf(context)!);
        return SizedBox();
      },
    );
    Widget radioProbe() => Builder(
      builder: (context) {
        radios.add(ElRadioGroup.maybeOf(context)!);
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
              children: [
                checkProbe(),
                ElCheckboxGroup<String>(value: ['inner'], children: [checkProbe()]),
              ],
            ),
            ElRadioGroup<String>(
              value: 'outer',
              children: [
                radioProbe(),
                ElRadioGroup<String>(value: 'inner', children: [radioProbe()]),
              ],
            ),
          ],
        ),
      ),
    );
    expect(checks.map((scope) => scope.value), [
      ['outer'],
      ['inner'],
    ]);
    expect(checks.map((scope) => scope.isLast), [false, true]);
    expect(radios.map((scope) => scope.value), ['outer', 'inner']);
    expect(radios.map((scope) => scope.isLast), [false, true]);
  });
}
