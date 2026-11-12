import 'package:example/src/pages/components/list/list_tile/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

String _examplePath(int number) => 'lib/src/pages/components/list/list_tile/examples/example$number.dart';

Finder _example(int number) => find.byKey(ValueKey(_examplePath(number)));

Finder _tile(int number, String title) => find.descendant(
  of: _example(number),
  matching: find.byWidgetPredicate((widget) => widget is ElListTile && widget.title == title),
);

Finder _text(String text) => find.byWidgetPredicate(
  (widget) => widget is ElView && widget.child == text || widget is Text && widget.data == text,
);

Finder _switch(String label) => find.byWidgetPredicate((widget) => widget is ElSwitch && widget.semanticLabel == label);

Future<void> _openPage(WidgetTester tester, {required double width, required ElComponents components}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.runAsync(
    () => Future.wait([for (var number = 1; number <= 8; number++) rootBundle.loadString(_examplePath(number))]),
  );
  await tester.pumpWidget(
    ElComponentProvider(
      components: components,
      child: MaterialApp(home: ListTilePage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final controller = tester.widget<ElScrollView>(find.byType(ElScrollView)).controller!;
  final offset = controller.offset + tester.getCenter(target).dy - 420;
  controller.jumpTo(offset.clamp(controller.position.minScrollExtent, controller.position.maxScrollExtent).toDouble());
  await tester.pumpAndSettle();
}

Future<void> _openSection(WidgetTester tester, String title) async {
  final row = find.descendant(
    of: find.byType(ElAnchor),
    matching: find.byWidgetPredicate((widget) => widget is ElButtonView && widget.child == title),
  );
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('窄屏八个场景正常排版，展开和收起实际示例源码', (tester) async {
    await _openPage(tester, width: 320, components: el.mobileComponents);
    expect(find.text('ListTile 列表行'), findsOneWidget);
    expect(find.byType(ElAnchor), findsNothing);
    final source = (await tester.runAsync(() => rootBundle.loadString(_examplePath(1))))!;
    final toggle = find.descendant(of: _example(1), matching: find.byKey(ValueKey('el-code-example-toggle')));
    expect(find.text(source), findsNothing);

    await _reveal(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text(source), findsOneWidget);
    expect(find.text('无法读取示例源码'), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text(source), findsNothing);

    for (var number = 1; number <= 8; number++) {
      await Scrollable.ensureVisible(tester.element(_example(number)));
      await tester.pumpAndSettle();
      expect(_example(number), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '示例 $number');
    }
  });

  testWidgets('桌面目录使用移动列表预览，普通点击计数在章节切换后保留', (tester) async {
    await _openPage(tester, width: 1100, components: el.desktopComponents);
    expect(find.text('目录'), findsOneWidget);
    expect(
      tester.widget<ElAnchor>(find.byType(ElAnchor)).links,
      containsAllInOrder(['基础使用', '图标与副标题', '右侧内容与后缀', '禁用状态', '开关列表行', '弹出单选菜单', '多级菜单', '自定义样式']),
    );

    await _openSection(tester, '基础使用');
    final counter = _tile(1, '点击计数');
    expect(tester.widget<ElListTile>(counter).trailingText, '0 次');
    await tester.tap(counter);
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile>(counter).trailingText, '1 次');
    await _openSection(tester, '自定义样式');
    await _openSection(tester, '基础使用');
    expect(tester.widget<ElListTile>(counter).trailingText, '1 次');
    expect(tester.takeException(), isNull);
  });

  testWidgets('禁用控制同时阻止普通点击、开关和菜单，解除后恢复操作', (tester) async {
    await _openPage(tester, width: 1100, components: el.desktopComponents);
    await _openSection(tester, '禁用状态');
    final action = _tile(4, '禁用点击');
    final switcher = _tile(4, '禁用开关');
    final popup = _tile(4, '禁用菜单');
    expect(tester.widget<ElListTile>(action).disabled, isTrue);
    await tester.tap(action);
    await tester.tap(switcher);
    await tester.tap(popup);
    await tester.pumpAndSettle();
    expect(_text('已点击 0 次'), findsOneWidget);
    expect(tester.widget<ElListTile<bool>>(switcher).currentValue, isFalse);
    expect(_text('紧凑'), findsNothing);

    await tester.tap(_switch('禁用列表示例'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile>(action).disabled, isFalse);
    await tester.tap(action);
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    expect(_text('已点击 1 次'), findsOneWidget);
    expect(tester.widget<ElListTile<bool>>(switcher).currentValue, isTrue);
    await tester.tap(popup);
    await tester.pumpAndSettle();
    expect(_text('紧凑'), findsOneWidget);
    await tester.tap(_text('紧凑'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile<String>>(popup).currentValue, 'compact');
    expect(tester.takeException(), isNull);
  });

  testWidgets('两个通知行共享布尔模型，加载中的开关行不能切换', (tester) async {
    await _openPage(tester, width: 1100, components: el.desktopComponents);
    await _openSection(tester, '开关列表行');
    final notifications = _tile(5, '消息通知');
    final mirrored = _tile(5, '同步通知');
    expect(_text('通知已关闭'), findsOneWidget);
    await tester.tap(notifications);
    await tester.pumpAndSettle();
    expect(_text('通知已开启'), findsOneWidget);
    expect(tester.widget<ElListTile<bool>>(mirrored).currentValue, isTrue);
    await tester.tap(mirrored);
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile<bool>>(notifications).currentValue, isFalse);

    final cloud = _tile(5, '云端同步');
    final before = tester.widget<ElListTile<bool>>(cloud).currentValue;
    await tester.tap(_switch('加载中的开关'));
    // 加载动画持续运转，推进固定帧后直接验证阻止行为。
    await tester.pump();
    expect(tester.widget<ElListTile<bool>>(cloud).loading, isTrue);
    await tester.tap(cloud);
    await tester.pump();
    expect(tester.widget<ElListTile<bool>>(cloud).currentValue, before);
    await tester.tap(_switch('加载中的开关'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile<bool>>(cloud).loading, isFalse);
    await tester.tap(cloud);
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile<bool>>(cloud).currentValue, !before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('菜单选中值回写行文案，多级菜单只在选择叶子时提交', (tester) async {
    await _openPage(tester, width: 1100, components: el.desktopComponents);
    await _openSection(tester, '弹出单选菜单');
    final sort = _tile(6, '排序方式');
    expect(tester.widget<ElListTile<String>>(sort).currentValue, 'latest');
    await tester.tap(sort);
    await tester.pumpAndSettle();
    await tester.tap(_text('最早发布'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile<String>>(sort).currentValue, 'earliest');
    expect(_text('当前排序：最早发布'), findsOneWidget);

    await _openSection(tester, '多级菜单');
    final display = _tile(7, '显示设置');
    await tester.tap(display);
    await tester.pumpAndSettle();
    await tester.tap(_text('外观'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile<String>>(display).currentValue, 'system');
    // 禁用项不接收点击，在其位置模拟指针操作以验证模型保持不变。
    await tester.tapAt(tester.getCenter(_text('高对比度')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile<String>>(display).currentValue, 'system');
    await tester.tap(_text('深色'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElListTile<String>>(display).currentValue, 'dark');
    expect(_text('当前显示：深色'), findsOneWidget);
    expect(_text('高对比度'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
