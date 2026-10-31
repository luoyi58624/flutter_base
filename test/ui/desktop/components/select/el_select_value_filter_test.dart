import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter/services.dart'
    show
        FilteringTextInputFormatter,
        TextEditingValue,
        TextSelection,
        LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(800, 600)),
    child: Directionality(
      textDirection: .ltr,
      child: ElDesktopTheme(
        child: Center(
          child: ElView(style: const ElStyle(width: 260), child: child),
        ),
      ),
    ),
  );
}

Finder _label(String value) => find.byWidgetPredicate(
  (widget) => widget is ElView && widget.child == value,
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(ElEditableView));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _query(WidgetTester tester, String value) async {
  final controller = tester
      .widget<ElEditableView>(find.byType(ElEditableView))
      .controller!;
  controller.replaceRange(0, controller.document.length, value);
  expect(controller.text, value, reason: '测试输入应已写入 editable controller');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  expect(controller.text, value, reason: 'Select query 状态应接住 editable 出站值');
}

void main() {
  test('option 校验：label 非空、value 唯一，null 简写仅接受 label is T', () {
    expect(
      () => ElSelect<int>(value: 1, children: [ElLabelModel<int>('一')]),
      throwsFlutterError,
    );
    expect(
      () => ElSelect<int>(
        value: 1,
        children: [ElLabelModel<int>('一', 1), ElLabelModel<int>('壹', 1)],
      ),
      throwsFlutterError,
    );
    expect(
      () =>
          ElSelect<String>(value: 'a', children: [ElLabelModel<String>('   ')]),
      throwsFlutterError,
    );
    expect(
      () => ElSelect<String>(value: 'a', children: [ElLabelModel<String>('a')]),
      returnsNormally,
    );
  });

  testWidgets('共享选择项保留 Widget 内容和禁用项，键盘跳过禁用值', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      _host(
        ElSelect<String>(
          value: 'a',
          onChanged: changes.add,
          children: [
            ElLabelModel('A', 'a'),
            ElSelectOption(
              ElView(child: '自定义禁用项'),
              'b',
              disabled: true,
              semanticLabel: 'B',
            ),
            ElSelectOption('C', 'c'),
          ],
        ),
      ),
    );
    await _open(tester);
    expect(_label('自定义禁用项'), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey<(String, int)>(('el-select-option', 1))),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(changes, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(changes, ['c']);
  });

  testWidgets('筛选 query 不污染 typed value 与表单字段，选择只提交 option value', (
    tester,
  ) async {
    final model = Obs<Map<String, dynamic>>({'city': 1});
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(
        ElForm(
          modelValue: model,
          child: ElFormItem(
            prop: 'city',
            child: ElSelect<int>(
              enableFilter: true,
              children: [ElLabelModel('杭州', 1), ElLabelModel('上海', 2)],
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<ElEditableView>(find.byType(ElEditableView))
          .style
          .inputConfiguration
          ?.autofillConfiguration
          .enabled,
      isFalse,
    );
    await _open(tester);
    await _query(tester, '上');

    expect(model.value['city'], 1);
    expect(
      model.value['city'],
      isA<int>(),
      reason: 'query 只能筛选，不能经内层 ElInput 抢写表单 prop',
    );
    expect(_label('杭州'), findsNothing);
    expect(_label('上海'), findsOneWidget);

    await tester.tap(_label('上海'));
    await tester.pump();
    expect(model.value['city'], 2);
    expect(model.value['city'], isA<int>());
  });

  testWidgets('受控 value 更新与 option 激活各触发一次 onChanged', (tester) async {
    var value = 1;
    final changes = <int>[];
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _host(
            ElSelect<int>(
              value: value,
              children: [
                ElLabelModel('一', 1),
                ElLabelModel('二', 2),
                ElLabelModel('三', 3),
              ],
              onChanged: (next) {
                changes.add(next);
                setState(() => value = next);
              },
            ),
          );
        },
      ),
    );

    await _open(tester);
    await tester.tap(_label('二'));
    await tester.pump();
    expect(value, 2);
    expect(changes, [2], reason: '一次 Enter/tap 激活只能走一次 option 值通道');
  });

  testWidgets('modelValue 双向更新且 onChanged 不重复', (tester) async {
    final model = Obs<int>(1);
    final changes = <int>[];
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(
        ElSelect<int>(
          modelValue: model,
          children: [ElLabelModel('一', 1), ElLabelModel('二', 2)],
          onChanged: changes.add,
        ),
      ),
    );

    await _open(tester);
    await tester.tap(_label('二'));
    await tester.pump();

    expect(model.value, 2);
    expect(changes, [2]);
  });

  testWidgets('选择收尾与外部值回灌不会把显示文本误当 query 重开菜单', (tester) async {
    late StateSetter update;
    var value = 1;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(
            ElSelect<int>(
              value: value,
              enableFilter: true,
              children: [ElLabelModel('一', 1), ElLabelModel('二', 2)],
              onChanged: (next) => setState(() => value = next),
            ),
          );
        },
      ),
    );

    await _open(tester);
    await tester.tap(_label('二'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('el-select-panel')), findsNothing);

    update(() => value = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('el-select-panel')), findsNothing);
  });

  testWidgets('option 慢按跨过退场时长仍先提交值，再以新值完成 blur 校验', (tester) async {
    final model = Obs<Map<String, dynamic>>({'city': ''});
    late ElFormState form;
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(
        ElForm(
          modelValue: model,
          rules: {
            'city': [ElRequiredFormRule(message: '请选择城市')],
          },
          child: Builder(
            builder: (context) {
              form = ElForm.of(context);
              return ElFormItem(
                prop: 'city',
                child: ElSelect<String>(
                  enableFilter: true,
                  children: [
                    ElLabelModel('杭州', 'hz'),
                    ElLabelModel('上海', 'sh'),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await _open(tester);

    final gesture = await tester.createGesture();
    await gesture.down(tester.getCenter(_label('杭州')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      _label('杭州'),
      findsOneWidget,
      reason: 'pointer up 前菜单不得因 trigger blur 提前摘除',
    );
    await gesture.up();
    await tester.pump();
    await gesture.removePointer();

    expect(model.value['city'], 'hz');
    expect(form.errorMessages['city'], isNull);
  });

  testWidgets('默认筛选忽略大小写，自定义筛选收到原 option 与原 query', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSelect<String>(
          value: 'alpha',
          enableFilter: true,
          children: [
            ElLabelModel('Alpha', 'alpha'),
            ElLabelModel('Beta', 'beta'),
          ],
        ),
      ),
    );
    await _open(tester);
    await _query(tester, 'ALP');
    expect(_label('Alpha'), findsOneWidget);
    expect(_label('Beta'), findsNothing);

    final calls = <String>[];
    await tester.pumpWidget(
      _host(
        ElSelect<String>(
          value: 'alpha',
          enableFilter: true,
          optionFilter: (option, query) {
            calls.add('${option.value}:$query');
            return option.value == 'beta';
          },
          children: [
            ElLabelModel('Alpha', 'alpha'),
            ElLabelModel('Beta', 'beta'),
          ],
        ),
      ),
    );
    await _open(tester);
    await _query(tester, '原样 Query');
    expect(_label('Alpha'), findsNothing);
    expect(_label('Beta'), findsOneWidget);
    expect(calls, containsAll(<String>['alpha:原样 Query', 'beta:原样 Query']));
  });

  testWidgets('inputFormatters 经内部 ElInput 的 editable 事务过滤 query', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ElSelect<String>(
          value: 'alpha',
          enableFilter: true,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Z]'))],
          children: [
            ElLabelModel('ALPHA', 'alpha'),
            ElLabelModel('BETA', 'beta'),
          ],
        ),
      ),
    );
    await _open(tester);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'aALP1',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();

    final controller = tester
        .widget<ElEditableView>(find.byType(ElEditableView))
        .controller!;
    expect(controller.text, 'ALP');
    expect(_label('ALPHA'), findsOneWidget);
    expect(_label('BETA'), findsNothing);
  });
}
