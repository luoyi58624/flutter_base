import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Page { first, second }

Widget _segmented<T>(BuildContext context, ElSegmented<T> component) => Text('segmented:${component.currentValue}');
Widget _tabs<T>(BuildContext context, ElTabs<T> component) => Text('tabs:${component.currentValue}');
Widget _collapse<D>(BuildContext context, ElCollapse<D> component) => Text('collapse:${component.currentValue}');
Widget _slider<D>(BuildContext context, ElSlider<D> component) => Text('slider:${component.currentValue}');
Widget _calendar<D>(BuildContext context, ElCalendar<D> component) => Text('calendar:${component.currentValue}');
Widget _steps(BuildContext context, ElSteps component) => Text('steps:${component.currentValue}');
Widget _alert(BuildContext context, ElAlert component) => Column(
  mainAxisSize: .min,
  children: [
    Text('alert:${component.currentValue}|${component.type.name}|${component.semanticLabel}'),
    if (component.currentValue && component.closable)
      GestureDetector(
        // 测试品牌遵守 Web 的关闭顺序，公共声明本身不处理点击。
        onTap: () {
          component.currentValue = false;
          component.onClose?.call();
        },
        child: Text('关闭通知'),
      ),
  ],
);

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElComponentProvider(
    builders: ElComponents(
      segmented: _segmented,
      tabs: _tabs,
      collapse: _collapse,
      slider: _slider,
      calendar: _calendar,
      steps: _steps,
      alert: _alert,
    ),
    child: child,
  ),
);

void main() {
  testWidgets('通知通过公共bool模型控制显示并将语义类型交给品牌', (tester) async {
    final defaults = ElAlert();
    await tester.pumpWidget(_host(defaults));
    expect(defaults.currentValue, isTrue);
    expect(defaults.closable, isFalse);
    expect(identical(defaults.icon, ElEmptyWidget.instance), isTrue);

    final model = ValueNotifier(true);
    addTearDown(model.dispose);
    final events = <String>[];
    final alert = ElAlert(
      modelValue: model,
      onChanged: (value) => events.add('change:$value'),
      type: .error,
      semanticLabel: '消息',
      closable: true,
      icon: null,
      onClose: () => events.add('close:${model.value}'),
    );
    await tester.pumpWidget(_host(alert));
    expect(find.text('alert:true|error|消息'), findsOneWidget);
    expect(events, isEmpty);
    await tester.tap(find.text('关闭通知'));
    await tester.pump();
    expect(alert.currentValue, isFalse);
    expect(model.value, isFalse);
    expect(events, ['change:false', 'close:false']);

    model.value = true;
    await tester.pump();
    expect(find.text('关闭通知'), findsOneWidget);
    model.value = false;
    await tester.pump();
    expect(events, ['change:false', 'close:false', 'change:true', 'change:false']);
    expect(find.text('关闭通知'), findsNothing);
  });

  testWidgets('分段与页签保留枚举泛型和公共模型单次通知', (tester) async {
    final model = ValueNotifier(_Page.first);
    addTearDown(model.dispose);
    final changes = <_Page>[];
    final segmented = ElSegmented<_Page>(
      modelValue: model,
      onChanged: changes.add,
      options: [
        ElSegmentedOption(value: _Page.first, label: '第一项'),
        ElSegmentedOption(value: _Page.second, label: '第二项', disabled: true),
      ],
    );
    await tester.pumpWidget(_host(segmented));
    expect(find.text('segmented:_Page.first'), findsOneWidget);
    segmented.currentValue = _Page.second;
    await tester.pump();
    expect(model.value, _Page.second);
    expect(changes, [_Page.second]);

    final tabs = ElTabs<_Page>(
      modelValue: model,
      onChanged: changes.add,
      swipeable: false,
      panes: [
        ElTabPane(value: _Page.first, label: '第一项', child: Text('正文一')),
        ElTabPane(value: _Page.second, label: '第二项', disabled: true, child: Text('正文二')),
      ],
    );
    await tester.pumpWidget(_host(tabs));
    expect(find.text('tabs:_Page.second'), findsOneWidget);
    model.value = _Page.first;
    await tester.pump();
    expect(tabs.currentValue, _Page.first);
    expect(changes, [_Page.second, _Page.first]);
    expect(tabs.swipeable, isFalse);
    expect(tabs.panes.last.disabled, isTrue);
  });

  testWidgets('折叠组单项用null全部收起，多项保留完整业务列表', (tester) async {
    final singleModel = ValueNotifier<_Page?>(_Page.first);
    final multiModel = ValueNotifier<List<_Page>>([_Page.first]);
    addTearDown(singleModel.dispose);
    addTearDown(multiModel.dispose);
    final children = [
      ElCollapseItem(value: _Page.first, title: '第一项', child: Text('正文')),
      ElCollapseItem(value: _Page.second, title: '第二项'),
    ];
    final single = ElCollapse<_Page?>.single(modelValue: singleModel, children: children);
    await tester.pumpWidget(_host(single));
    single.currentValue = null;
    await tester.pump();
    expect(singleModel.value, isNull);
    expect(find.text('collapse:null'), findsOneWidget);

    final original = multiModel.value;
    final multi = ElCollapse<List<_Page>>.multi(modelValue: multiModel, children: children);
    await tester.pumpWidget(_host(multi));
    multi.currentValue = [_Page.second];
    await tester.pump();
    expect(multi.currentValue, isA<List<_Page>>());
    expect(multiModel.value, [_Page.second]);
    expect(original, [_Page.first]);
    expect(single.mode, ElModelValueType.single);
    expect(multi.mode, ElModelValueType.multi);
  });

  testWidgets('步骤使用索引模型并传递Web的状态和交互声明', (tester) async {
    final steps = ElSteps(
      status: .error,
      vertical: true,
      interactive: true,
      children: [
        ElStep(title: '开始'),
        ElStep(title: '结束', disabled: true),
      ],
    );
    await tester.pumpWidget(_host(steps));
    expect(steps.currentValue, 0);
    expect(find.text('steps:0'), findsOneWidget);
    steps.currentValue = 1;
    await tester.pump();
    expect(find.text('steps:1'), findsOneWidget);
    expect(steps.status, ElStepStatus.error);
    expect(steps.vertical && steps.interactive, isTrue);
    expect(steps.children.last.disabled, isTrue);
  });

  testWidgets('滑块保留单值与范围完整泛型，声明不排序或归一化业务模型', (tester) async {
    final slider = ElSlider<double>(min: 10, max: 20);
    await tester.pumpWidget(_host(slider));
    expect(slider.currentValue, 10);
    slider.currentValue = 15;
    await tester.pump();
    expect(find.text('slider:15.0'), findsOneWidget);

    final original = <double>[80, 20];
    final model = ValueNotifier(original);
    addTearDown(model.dispose);
    final range = ElSlider<List<double>>.range(
      modelValue: model,
      step: null,
      marks: [
        ElSliderMark(value: 20, label: '低'),
        ElSliderMark(value: 80, label: '高'),
      ],
      valueLabelDisplay: .on,
      valueLabelFormat: (value, index) => '$index:$value',
    );
    await tester.pumpWidget(_host(range));
    expect(range.isRange, isTrue);
    expect(range.currentValue, same(original));
    expect(original, [80, 20]);
    range.currentValue = <double>[20, 80];
    await tester.pump();
    expect(model.value, isA<List<double>>());
    expect(model.value, [20, 80]);
    expect(original, [80, 20]);
    expect(range.valueLabelFormat!(20, 0), '0:20.0');
  });

  testWidgets('日历保留单日与部分范围模型，完成选择通知由品牌另行发出', (tester) async {
    final date = DateTime(2026, 11, 1);
    final single = ElCalendar<DateTime?>(value: date);
    await tester.pumpWidget(_host(single));
    expect(single.currentValue, date);
    single.currentValue = null;
    await tester.pump();
    expect(find.text('calendar:null'), findsOneWidget);

    final model = ValueNotifier<List<DateTime>>([]);
    addTearDown(model.dispose);
    final changes = <List<DateTime>>[];
    final selections = <List<DateTime>>[];
    final range = ElCalendar<List<DateTime>>.range(
      modelValue: model,
      onChanged: changes.add,
      onSelect: selections.add,
      month: date,
      min: date,
      max: date.add(Duration(days: 30)),
      disabledDate: (date) => date.weekday == DateTime.sunday,
    );
    await tester.pumpWidget(_host(range));
    range.currentValue = [date];
    await tester.pump();
    expect(model.value, [date]);
    range.currentValue = [date, date.add(Duration(days: 2))];
    await tester.pump();
    expect(changes.length, 2);
    expect(selections, isEmpty);
    expect(model.value, isA<List<DateTime>>());
    expect(range.disabledDate!(date), isTrue);
    expect(range.firstDayOfWeek, DateTime.monday);
  });

  test('声明拒绝不匹配的绑定形态', () {
    expect(() => ElCollapse<_Page>.single(children: []), throwsAssertionError);
    expect(() => ElCollapse<int>.multi(value: 1, children: []), throwsAssertionError);
    expect(() => ElSlider<int>(value: 1), throwsAssertionError);
    expect(() => ElSlider<double>.range(value: 1), throwsAssertionError);
    expect(() => ElCalendar<DateTime?>.range(value: DateTime(2026)), throwsAssertionError);
    expect(() => ElSlider<double>(marks: 'all'), throwsAssertionError);
  });
}
