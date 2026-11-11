import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  home: ElComponentProvider(
    components: el.mobileComponents,
    child: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  ),
);

Finder copy(String value) => find.byWidgetPredicate(
  (widget) => widget is ElView && widget.child == value || widget is Text && widget.data == value,
);

void main() {
  testWidgets('日期换月自动收敛到月末，外部模型同步滚轮', (tester) async {
    final model = ValueNotifier(DateTime(2024, 1, 31));
    addTearDown(model.dispose);
    await tester.pumpWidget(host(ElDatePicker(modelValue: model, min: DateTime(2024), max: DateTime(2025, 12, 31))));
    final wheels = tester.widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView)).toList();
    (wheels[1].controller! as FixedExtentScrollController).jumpToItem(1);
    await tester.pumpAndSettle();
    expect(model.value, DateTime(2024, 2, 29));
    model.value = DateTime(2025, 2, 28);
    await tester.pumpAndSettle();
    expect(
      (tester.widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView)).first.controller!
              as FixedExtentScrollController)
          .selectedItem,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('时间上界收敛分钟，禁选滚轮不能选中', (tester) async {
    final time = ValueNotifier(Duration(hours: 17, minutes: 45));
    addTearDown(time.dispose);
    await tester.pumpWidget(
      host(
        ElTimePicker(modelValue: time, min: Duration(hours: 9), max: Duration(hours: 18, minutes: 30), minuteStep: 15),
      ),
    );
    final wheel = tester.widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView)).first;
    (wheel.controller! as FixedExtentScrollController).jumpToItem(9);
    await tester.pumpAndSettle();
    expect(time.value, Duration(hours: 18, minutes: 30));
    final value = ValueNotifier(['a']);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      host(
        ElPicker<String>(
          modelValue: value,
          columns: [
            [ElMenuOption('A', 'a'), ElMenuOption('B', 'b', disabled: true), ElMenuOption('C', 'c')],
          ],
        ),
      ),
    );
    (tester.widget<ListWheelScrollView>(find.byType(ListWheelScrollView)).controller! as FixedExtentScrollController)
        .jumpToItem(1);
    await tester.pumpAndSettle();
    expect(value.value, ['c']);
  });

  testWidgets('级联更换父项更新下级业务值', (tester) async {
    final model = ValueNotifier(['zj', 'hz']);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      host(
        ElPicker<String>(
          modelValue: model,
          options: [
            ElMenuOption('浙江', 'zj', children: [ElMenuOption('杭州', 'hz')]),
            ElMenuOption('江苏', 'js', children: [ElMenuOption('南京', 'nj'), ElMenuOption('苏州', 'sz')]),
          ],
        ),
      ),
    );
    (tester.widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView)).first.controller!
            as FixedExtentScrollController)
        .jumpToItem(1);
    await tester.pumpAndSettle();
    expect(model.value, ['js', 'nj']);
  });

  testWidgets('日期范围不能跨越禁用日期', (tester) async {
    final model = ValueNotifier(<DateTime>[]);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      host(ElCalendar.range(modelValue: model, month: DateTime(2026, 11), disabledDate: (day) => day.day == 13)),
    );
    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.text('14'));
    await tester.pump();
    expect(model.value, [DateTime(2026, 11, 14)]);
    await tester.tap(find.text('16'));
    await tester.pump();
    expect(model.value, [DateTime(2026, 11, 14), DateTime(2026, 11, 16)]);
  });

  testWidgets('折叠保留输入状态，标签页按原内容高度布局', (tester) async {
    final collapse = ValueNotifier<String?>('first');
    addTearDown(collapse.dispose);
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: Column(
            children: [
              ElCollapse.single(
                modelValue: collapse,
                children: [
                  ElCollapseItem(
                    value: 'first',
                    title: '面板',
                    child: ElInput(value: '保留输入'),
                  ),
                ],
              ),
              ElTabs<String>(
                value: 'one',
                panes: [
                  ElTabPane(
                    value: 'one',
                    label: '第一项',
                    child: SizedBox(height: 80, child: Text('短内容')),
                  ),
                  ElTabPane(
                    value: 'two',
                    label: '第二项',
                    child: SizedBox(height: 150, child: Text('长内容')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<ElEditableView>(find.byType(ElEditableView)).controller;
    await tester.tapAt(tester.getCenter(copy('面板')));
    await tester.pump();
    expect(collapse.value, isNull);
    await tester.tapAt(tester.getCenter(copy('面板')));
    await tester.pump();
    expect(tester.widget<ElEditableView>(find.byType(ElEditableView)).controller, same(editor));
    await tester.tapAt(tester.getCenter(copy('第二项')));
    await tester.pumpAndSettle();
    expect(find.text('长内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('上传取消和重试回传原文件，弹层返回业务值并继承品牌', (tester) async {
    final busy = ElUploadFile(id: '1', name: '旅行.png', status: .uploading, progress: 45);
    final failed = ElUploadFile(id: '2', name: '笔记.txt', status: .error);
    ElUploadFile? canceled, retried;
    String? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Column(
            mainAxisSize: .min,
            children: [
              ElUpload(files: [busy, failed], onCancel: (file) => canceled = file, onRetry: (file) => retried = file),
              ElButton(
                child: '打开弹层',
                onPressed: () async {
                  result = await el.dialog<String>(
                    context,
                    title: '确认',
                    child: Text('内容'),
                    footer: Builder(
                      builder: (context) => ElButton(child: '完成', onPressed: () => Navigator.of(context).pop('done')),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(copy('取消'));
    await tester.pump();
    expect(canceled, same(busy));
    await tester.tap(copy('重试'));
    await tester.pump();
    expect(retried, same(failed));
    await tester.tap(copy('打开弹层'));
    await tester.pumpAndSettle();
    expect(find.byType(ElDialog), findsOneWidget);
    await tester.tap(copy('完成'));
    await tester.pumpAndSettle();
    expect(result, 'done');
    expect(tester.takeException(), isNull);
  });
}
