import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart' show ElDesktopExt;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => ElComponentProvider(
  components: el.mobileComponents,
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 320, child: child)),
    ),
  ),
);

void main() {
  testWidgets('桌面卡片显式内边距不叠加官方默认留白', (tester) async {
    for (final padding in <EdgeInsets?>[null, EdgeInsets.zero, EdgeInsets.all(8)]) {
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.desktopComponents,
          child: MaterialApp(
            home: Center(
              child: SizedBox(
                width: 94,
                height: 184,
                child: ElCard(
                  style: padding == null ? null : ElStyle(padding: padding),
                  child: SizedBox.expand(key: ValueKey('card-content')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inset = padding?.left ?? 20;
      expect(tester.getSize(find.byKey(ValueKey('card-content'))), Size(94 - inset * 2, 184 - inset * 2));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('官方输入替代接入原表单模型、校验、清空和外部回灌', (tester) async {
    final data = ValueNotifier<Map<String, dynamic>>({'name': ''});
    addTearDown(data.dispose);
    await tester.pumpWidget(
      _host(
        ElForm(
          modelValue: data,
          labelPosition: .top,
          rules: {
            'name': [ElRequiredFormRule(message: '姓名必填')],
          },
          child: Column(
            mainAxisSize: .min,
            children: [
              ElFormItem(prop: 'name', label: '姓名', child: ElInput(clearable: true)),
              Builder(
                builder: (context) => TextButton(onPressed: () => ElForm.of(context).validate(), child: Text('提交')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is ElView && w.child == '姓名必填'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '大肥鱼');
    await tester.pumpAndSettle();
    expect(data.value['name'], '大肥鱼');
    await tester.tap(find.byTooltip('清空输入'));
    await tester.pumpAndSettle();
    expect(data.value['name'], '');
    data.value = {'name': '外部姓名'};
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '外部姓名');
  });

  testWidgets('多选与单选的官方外观不重复执行公共选择逻辑', (tester) async {
    final checks = ValueNotifier<List<String>>(['甲']);
    final radio = ValueNotifier<String?>('甲');
    addTearDown(checks.dispose);
    addTearDown(radio.dispose);
    var changes = 0;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElCheckboxGroup<String>(
              modelValue: checks,
              max: 2,
              onChanged: (_) => changes++,
              child: Column(
                children: [
                  ElCheckbox(value: '甲', label: '甲'),
                  ElCheckbox(value: '乙', label: '乙'),
                  ElCheckbox(value: '丙', label: '丙'),
                ],
              ),
            ),
            ElRadioGroup<String>(
              modelValue: radio,
              child: Row(
                children: [
                  ElRadio<String>(value: '甲', label: '单甲'),
                  ElRadio<String>(value: '乙', label: '单乙'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(ElCheckbox).at(1));
    await tester.pumpAndSettle();
    expect(checks.value, ['甲', '乙']);
    expect(changes, 1);
    await tester.tap(find.byType(ElCheckbox).at(2));
    await tester.pumpAndSettle();
    expect(checks.value, ['甲', '乙']);
    await tester.tap(find.byType(ElRadio<String>).at(1));
    await tester.pumpAndSettle();
    expect(radio.value, '乙');
  });

  testWidgets('选择器同步业务值并跳过禁用候选', (tester) async {
    final value = ValueNotifier<String>('a');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      _host(
        ElSelect<String>(
          modelValue: value,
          children: [ElSelectOption('甲', 'a'), ElSelectOption('乙', 'b'), ElSelectOption('禁用候选', 'c', disabled: true)],
        ),
      ),
    );
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('乙').last);
    await tester.pumpAndSettle();
    expect(value.value, 'b');
    value.value = 'a';
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '甲');
  });

  testWidgets('自动补全使用官方候选层并回写文本和选中通知', (tester) async {
    final value = ValueNotifier<String>('');
    addTearDown(value.dispose);
    String? selected;
    await tester.pumpWidget(
      _host(
        ElAutocomplete<String>(
          modelValue: value,
          debounce: Duration.zero,
          fetchSuggestions: (query) async => [if (query.startsWith('A')) ElLabelModel('Apple', 'apple')],
          onSelected: (option) => selected = option.value,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'A');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple').last);
    await tester.pumpAndSettle();
    expect(value.value, 'Apple');
    expect(selected, 'apple');
  });

  testWidgets('折叠单选与多选保留现有模型及集合类型', (tester) async {
    final single = ValueNotifier<String?>('a');
    final multi = ValueNotifier<List<String>>(['a']);
    addTearDown(single.dispose);
    addTearDown(multi.dispose);
    final items = [
      ElCollapseItem(value: 'a', title: '面板甲', child: '内容甲'),
      ElCollapseItem(value: 'b', title: '面板乙', child: '内容乙'),
    ];
    await tester.pumpWidget(_host(ElCollapse<String?>.single(modelValue: single, children: items)));
    await tester.tap(find.text('面板乙'));
    await tester.pumpAndSettle();
    expect(single.value, 'b');
    single.value = null;
    await tester.pumpAndSettle();
    expect(find.text('内容乙').hitTestable(), findsNothing);
    await tester.pumpWidget(_host(ElCollapse<List<String>>.multi(modelValue: multi, children: items)));
    await tester.tap(find.text('面板乙'));
    await tester.pumpAndSettle();
    expect(multi.value, ['a', 'b']);
    expect(multi.value, isA<List<String>>());
  });

  testWidgets('页签同步业务模型、外部更新并阻止禁用项', (tester) async {
    final value = ValueNotifier<String>('a');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      _host(
        ElTabs<String>(
          modelValue: value,
          panes: [
            ElTabPane(value: 'a', label: '甲页', child: Text('甲内容')),
            ElTabPane(value: 'b', label: '乙页', child: Text('乙内容')),
            ElTabPane(value: 'c', label: '禁用页', disabled: true, child: Text('禁用内容')),
          ],
        ),
      ),
    );
    await tester.tap(find.text('乙页'));
    await tester.pumpAndSettle();
    expect(value.value, 'b');
    await tester.tap(find.text('禁用页'));
    await tester.pumpAndSettle();
    expect(value.value, 'b');
    value.value = 'a';
    await tester.pumpAndSettle();
    expect(find.text('甲内容').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分段选择、步骤与关闭通知使用同一个公共模型', (tester) async {
    final segment = ValueNotifier<int>(0);
    final step = ValueNotifier<int>(0);
    final visible = ValueNotifier<bool>(true);
    addTearDown(segment.dispose);
    addTearDown(step.dispose);
    addTearDown(visible.dispose);
    var closed = false;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElSegmented<int>(
              modelValue: segment,
              options: [
                ElSegmentedOption(value: 0, label: '分段甲'),
                ElSegmentedOption(value: 1, label: '分段乙'),
              ],
            ),
            ElSteps(
              modelValue: step,
              vertical: true,
              interactive: true,
              children: [
                ElStep(title: '第一步'),
                ElStep(title: '第二步'),
              ],
            ),
            ElAlert(modelValue: visible, title: '可关闭通知', closable: true, onClose: () => closed = !visible.value),
          ],
        ),
      ),
    );
    await tester.tap(find.text('分段乙'));
    await tester.pumpAndSettle();
    expect(segment.value, 1);
    await tester.tap(find.text('第二步'));
    await tester.pumpAndSettle();
    expect(step.value, 1);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(visible.value, isFalse);
    expect(closed, isTrue);
  });
}
