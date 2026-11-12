import 'package:example/src/pages/components/basic/button_group/index.dart';
import 'package:example/src/widgets/code_preview/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

String _source(int number) => 'lib/src/pages/components/basic/button_group/examples/example$number.dart';

Finder _section(int number) => find.byKey(ValueKey(_source(number)));

Finder _item(int number, String label) => find.descendant(
  of: _section(number),
  matching: find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == label || widget is ElView && widget.child == label,
  ),
);

Future<void> _open(WidgetTester tester, {double width = 1100, ElComponents? components}) async {
  await tester.runAsync(
    () => Future.wait([for (var number = 1; number <= 8; number++) rootBundle.loadString(_source(number))]),
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: components ?? el.desktopComponents,
      child: MaterialApp(home: ButtonGroupPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectSection(WidgetTester tester, String title) async {
  final row = find.descendant(
    of: find.byType(ElAnchor),
    matching: find.byWidgetPredicate((widget) => widget is ElButtonView && widget.child == title),
  );
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('移动窄屏使用 Material 演示并保留源码，全部小节正常布局', (tester) async {
    await _open(tester, width: 320, components: el.mobileComponents);
    expect(find.text('ButtonGroup 按钮组'), findsOneWidget);
    expect(find.text('当前品牌暂未支持按钮组，可展开源码查看用法。'), findsNothing);
    expect(find.byType(SegmentedButton<int>), findsWidgets);
    await tester.tap(_item(1, '下一页'));
    await tester.pumpAndSettle();
    expect(_item(1, '最近操作：下一页'), findsOneWidget);
    for (var number = 1; number <= 8; number++) {
      await Scrollable.ensureVisible(tester.element(_section(number)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '移动示例 $number');
    }
    await Scrollable.ensureVisible(tester.element(_section(1)));
    await tester.pumpAndSettle();
    final toggle = find.descendant(of: _section(1), matching: find.byKey(ValueKey('el-code-example-toggle')));
    await tester.tap(toggle);
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(tester.widget<ElCodePreview>(find.byType(ElCodePreview)).code, contains('ElButtonGroup('));
    expect(tester.takeException(), isNull);
  });

  testWidgets('目录定位后可操作普通、单选、多选、必选、禁用与图标示例', (tester) async {
    await _open(tester);
    expect(find.text('ButtonGroup 按钮组'), findsOneWidget);
    expect(find.text('目录'), findsOneWidget);
    await tester.tap(_item(1, '下一页'));
    await tester.pumpAndSettle();
    expect(_item(1, '最近操作：下一页'), findsOneWidget);

    await _selectSection(tester, '单选按钮组');
    await tester.tap(_item(3, '列表'));
    await tester.pumpAndSettle();
    expect(_item(3, '当前视图：列表'), findsOneWidget);
    await tester.tap(_item(3, '列表'));
    await tester.pumpAndSettle();
    expect(_item(3, '当前视图：未选择'), findsOneWidget);

    await _selectSection(tester, '多选按钮组');
    await tester.tap(_item(4, '斜体').first);
    await tester.pumpAndSettle();
    expect(_item(4, 'List：加粗、斜体'), findsOneWidget);
    expect(_item(4, 'Set：斜体'), findsOneWidget);
    await tester.tap(_item(4, '斜体').last);
    await tester.pumpAndSettle();
    expect(_item(4, 'Set：未选择'), findsOneWidget);

    await _selectSection(tester, '保留选中项');
    await tester.tap(_item(5, '周'));
    await tester.tap(_item(5, '已读'));
    await tester.pumpAndSettle();
    expect(_item(5, '统计周期：周'), findsOneWidget);
    expect(_item(5, '筛选条件：已读'), findsOneWidget);
    await tester.tap(_item(5, '收藏'));
    await tester.pumpAndSettle();
    await tester.tap(_item(5, '已读'));
    await tester.pumpAndSettle();
    expect(_item(5, '筛选条件：收藏'), findsOneWidget);

    await _selectSection(tester, '禁用状态');
    await tester.tap(_item(6, '查看').ancestorButton());
    await tester.pumpAndSettle();
    expect(_item(6, '当前操作：编辑'), findsOneWidget);
    await tester.tap(find.descendant(of: _section(6), matching: find.byType(ElSwitch)));
    await tester.pumpAndSettle();
    await tester.tap(_item(6, '查看'));
    await tester.pumpAndSettle();
    expect(_item(6, '当前操作：查看'), findsOneWidget);
    await tester.tap(_item(6, '删除').ancestorButton());
    await tester.pumpAndSettle();
    expect(_item(6, '当前操作：查看'), findsOneWidget);

    await _selectSection(tester, '图标按钮组');
    final center = find.descendant(
      of: _section(7),
      matching: find.byWidgetPredicate(
        (widget) => widget is ElButtonView && widget.semantics?.properties.label == '居中对齐',
      ),
    );
    await tester.tap(center);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(_item(7, '点击图标，调整这段文字的对齐方式。')).textAlign, TextAlign.center);

    await _selectSection(tester, '基础使用');
    expect(_item(1, '最近操作：下一页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏逐节排版且实际源码可展开，通栏份额与纵向高度生效', (tester) async {
    final source = (await tester.runAsync(() => rootBundle.loadString(_source(1))))!;
    await _open(tester, width: 320);
    expect(find.byType(ElAnchor), findsNothing);
    final scroll = tester.widget<ElScrollView>(find.byType(ElScrollView)).controller!;
    for (var number = 1; number <= 8; number++) {
      await Scrollable.ensureVisible(tester.element(_section(number)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '示例 $number');
    }
    final groups = find.descendant(of: _section(8), matching: find.byWidgetPredicate((w) => w is ElButtonGroup));
    final fullWidth = tester.getSize(groups.at(0)).width;
    expect(tester.getSize(groups.at(1)).width, fullWidth);
    final back = tester.getSize(_item(8, '返回').ancestorButton()).width;
    final confirm = tester.getSize(_item(8, '确认').ancestorButton()).width;
    expect(confirm, closeTo(back * 2, 0.01));
    expect(tester.getSize(groups.at(2)).height, 156);

    await Scrollable.ensureVisible(tester.element(_section(1)));
    await tester.pumpAndSettle();
    final toggle = find.descendant(of: _section(1), matching: find.byKey(ValueKey('el-code-example-toggle')));
    final delta = tester.getCenter(toggle).dy - 600;
    if (delta > 0) {
      scroll.jumpTo(scroll.offset + delta);
      await tester.pumpAndSettle();
    }
    await tester.tap(toggle);
    await tester.pump();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(
      tester.widget<ElCodeExample>(find.descendant(of: _section(1), matching: find.byType(ElCodeExample))).code,
      source,
    );
    expect(find.text(source), findsOneWidget);
    expect(find.text('无法读取示例源码'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

extension on Finder {
  Finder ancestorButton() => find.ancestor(of: this, matching: find.byType(ElButtonView)).first;
}
