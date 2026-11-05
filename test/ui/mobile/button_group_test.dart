import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Period { day, week }

Widget _host(Widget child) => ElComponentProvider(
  components: el.mobileComponents,
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

Finder get _material => find.byType(SegmentedButton<int>);

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(TextButton, label));
  await tester.pumpAndSettle();
}

List<ElButtonGroupItem> _items({VoidCallback? onWeek}) => [
  ElButtonGroupItem(value: _Period.day, child: '日'),
  ElButtonGroupItem(value: _Period.week, child: '周', onPressed: onWeek),
];

void main() {
  testWidgets('普通组直接使用 Material，重复激活只有条目回调且不保留选择', (tester) async {
    var calls = 0;
    final payload = Text('操作');
    await tester.pumpWidget(
      _host(
        ElButtonGroup<int>(
          children: [
            ElButtonGroupItem(value: '重复身份', child: payload, onPressed: () => calls++),
            ElButtonGroupItem(value: '重复身份', child: Icons.add, semanticLabel: '添加'),
          ],
        ),
      ),
    );
    expect(find.byWidget(payload), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    await _tap(tester, '操作');
    await _tap(tester, '操作');
    expect(calls, 2);
    expect(tester.widget<SegmentedButton<int>>(_material).selected, isEmpty);
    expect(find.bySemanticsLabel('添加'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单选可取消，通知一次并在条目回调前更新模型', (tester) async {
    final model = ValueNotifier<_Period?>(null);
    addTearDown(model.dispose);
    final changes = <_Period?>[];
    final observed = <_Period?>[];
    await tester.pumpWidget(
      _host(
        ElButtonGroup<_Period?>.single(
          modelValue: model,
          onChanged: changes.add,
          children: _items(onWeek: () => observed.add(model.value)),
        ),
      ),
    );
    await _tap(tester, '周');
    expect(model.value, _Period.week);
    expect(changes, [_Period.week]);
    expect(observed, [_Period.week]);
    await _tap(tester, '周');
    expect(model.value, isNull);
    expect(changes, [_Period.week, null]);
    expect(observed, [_Period.week, null]);
    model.value = _Period.day;
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<int>>(_material).selected, {0});
  });

  testWidgets('必选及非空单选保留选择，重复点击仍通知条目', (tester) async {
    final model = ValueNotifier<_Period?>(_Period.week);
    addTearDown(model.dispose);
    var calls = 0;
    final changes = <_Period?>[];
    await tester.pumpWidget(
      _host(
        ElButtonGroup<_Period?>.single(
          modelValue: model,
          mandatory: true,
          onChanged: changes.add,
          children: _items(onWeek: () => calls++),
        ),
      ),
    );
    await _tap(tester, '周');
    expect(model.value, _Period.week);
    expect(changes, isEmpty);
    expect(calls, 1);
    await tester.pumpWidget(_host(ElButtonGroup<_Period>.single(value: _Period.week, children: _items())));
    await _tap(tester, '周');
    expect(tester.widget<SegmentedButton<int>>(_material).selected, {1});
    expect(tester.takeException(), isNull);
  });

  testWidgets('多选 List 和 Set 保留窄元素类型及原集合，必选保留最后一项', (tester) async {
    final initial = [_Period.day];
    final list = ValueNotifier<List<_Period>>(initial);
    final initialSet = {_Period.week};
    final set = ValueNotifier<Set<_Period>>(initialSet);
    addTearDown(list.dispose);
    addTearDown(set.dispose);
    await tester.pumpWidget(_host(ElButtonGroup<List<_Period>>.multi(modelValue: list, children: _items())));
    await _tap(tester, '周');
    expect(list.value, [_Period.day, _Period.week]);
    expect(list.value, isA<List<_Period>>());
    expect(initial, [_Period.day]);
    await _tap(tester, '日');
    expect(list.value, [_Period.week]);
    await tester.pumpWidget(
      _host(ElButtonGroup<Set<_Period>>.multi(modelValue: set, mandatory: true, children: _items())),
    );
    await _tap(tester, '周');
    expect(set.value, {_Period.week});
    await _tap(tester, '日');
    expect(set.value, {_Period.day, _Period.week});
    expect(set.value, isA<Set<_Period>>());
    expect(initialSet, {_Period.week});
  });

  testWidgets('整组和条目禁用阻止模型与回调，外部值仍可同步', (tester) async {
    final model = ValueNotifier<int?>(0);
    addTearDown(model.dispose);
    var calls = 0;
    Widget group(bool disabled) => ElButtonGroup<int?>.single(
      modelValue: model,
      disabled: disabled,
      children: [
        ElButtonGroupItem(child: '可用', onPressed: () => calls++),
        ElButtonGroupItem(child: '禁用', disabled: true, onPressed: () => calls++),
      ],
    );
    await tester.pumpWidget(_host(group(false)));
    await _tap(tester, '禁用');
    expect(model.value, 0);
    expect(calls, 0);
    await tester.pumpWidget(_host(group(true)));
    await _tap(tester, '可用');
    expect(model.value, 0);
    expect(calls, 0);
    model.value = 1;
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<int>>(_material).selected, {1});
    expect(tester.widget<SegmentedButton<int>>(_material).onSelectionChanged, isNull);
  });

  testWidgets('value 回灌不通知，替换外部模型后解除旧模型监听', (tester) async {
    final changes = <int?>[];
    List<ElButtonGroupItem> items() => [ElButtonGroupItem(child: '甲'), ElButtonGroupItem(child: '乙')];
    await tester.pumpWidget(_host(ElButtonGroup<int?>.single(value: 0, onChanged: changes.add, children: items())));
    await tester.pumpWidget(_host(ElButtonGroup<int?>.single(value: 1, onChanged: changes.add, children: items())));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(tester.widget<SegmentedButton<int>>(_material).selected, {1});
    final first = ValueNotifier<int?>(0);
    final second = ValueNotifier<int?>(1);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(_host(ElButtonGroup<int?>.single(modelValue: first, children: items())));
    await tester.pumpWidget(_host(ElButtonGroup<int?>.single(modelValue: second, children: items())));
    await _tap(tester, '甲');
    expect(second.value, 0);
    first.value = 1;
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<int>>(_material).selected, {0});
  });

  testWidgets('通栏等分、纵向有界高度、显式颜色和根样式生效', (tester) async {
    Widget group(Axis axis) => ElButtonGroup<int>.single(
      value: 0,
      type: .error,
      bgColor: Colors.teal,
      axis: axis,
      block: true,
      style: ElStyle(opacity: .8),
      children: [
        ElButtonGroupItem(child: '甲'),
        ElButtonGroupItem(child: '乙', flex: 2),
      ],
    );
    await tester.pumpWidget(_host(SizedBox(width: 280, child: group(.horizontal))));
    expect(tester.getSize(_material).width, 280);
    final buttons = find.descendant(of: _material, matching: find.byType(TextButton));
    expect(tester.getSize(buttons.first).width, tester.getSize(buttons.last).width);
    final native = tester.widget<SegmentedButton<int>>(_material);
    expect(native.style!.backgroundColor!.resolve({WidgetState.selected}), Colors.teal);
    expect(find.byWidgetPredicate((widget) => widget is ElView && widget.style?.opacity == .8), findsOneWidget);
    await tester.pumpWidget(_host(SizedBox(height: 160, child: group(.vertical))));
    expect(tester.widget<SegmentedButton<int>>(_material).direction, Axis.vertical);
    expect(tester.getSize(_material).height, 160);
    await tester.pumpWidget(_host(Column(mainAxisSize: .min, children: [group(.vertical)])));
    expect(tester.getSize(_material).height.isFinite, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('指针激活和 Tab 均保留外部焦点，选中及图标名称语义可读', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            Focus(focusNode: focus, child: SizedBox()),
            ElButtonGroup<int?>.single(
              value: 0,
              children: [
                ElButtonGroupItem(child: Icons.add, semanticLabel: '添加'),
                ElButtonGroupItem(child: '更多'),
              ],
            ),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await _tap(tester, '更多');
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focus.hasPrimaryFocus, isTrue);
    expect(find.bySemanticsLabel('添加'), findsOneWidget);
    expect(
      tester.getSemantics(find.widgetWithText(TextButton, '更多')).getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.bySemanticsLabel('更多'), findsOneWidget);
  });
}
