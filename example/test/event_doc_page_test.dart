import 'package:example/main.dart';
import 'package:example/src/pages/components/index.dart';
import 'package:example/src/router/index.dart';
import 'package:example/src/widgets/docs_page/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('窄屏移动目录按顺序打开事件文档，示例可操作且可展开实际源码', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(320, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final eventGroup = componentCatalog.last;
    expect(eventGroup.title, 'Event 事件');
    expect(eventGroup.children.map((item) => item.title), ['基础使用', '阻止冒泡', '拖拽交互', '高级示例']);

    routingConfig.isMobile = true;
    router.go('/components');
    await tester.pumpWidget(App());
    await tester.pumpAndSettle();

    Future<DocsPage> openPage(String key, String title) async {
      final catalog = find.byKey(PageStorageKey('component-catalog'));
      final scrollable = find.descendant(of: catalog, matching: find.byType(Scrollable));
      final position = tester.state<ScrollableState>(scrollable.first).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('component-$key')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/components/$key');
      final page = tester.widget<DocsPage>(find.byType(DocsPage));
      expect(page.title, title);
      expect(find.text('目录'), findsNothing);
      return page;
    }

    Future<String> loadSource(DocsSection section) async {
      final source = (await tester.runAsync(() => rootBundle.loadString(section.source!)))!;
      expect(source, contains('ElEvent('), reason: section.source);
      return source;
    }

    Future<void> backToCatalog() async {
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ComponentPage), findsOneWidget);
    }

    final basic = await openPage('event-basic', '基础使用');
    expect(basic.description, isNull);
    expect(basic.sections.map((section) => section.title).take(7), ['原始指针', '按压', '悬停', '连击', '拖拽', '缩放', '旋转']);
    for (final section in basic.sections) {
      expect(section.description, isNull);
      await loadSource(section);
    }
    final tapExample = find.byKey(ValueKey('event-basic-press'));
    await tester.ensureVisible(tapExample);
    await tester.pumpAndSettle();
    expect(tapExample.hitTestable(), findsOneWidget);
    final tap = await tester.startGesture(tester.getCenter(tapExample));
    await tester.pump();
    expect(find.text('onTapDown'), findsOneWidget);
    await tap.up();
    await tester.pump(Duration(milliseconds: 350));
    expect(find.text('onTap'), findsOneWidget);

    final longPressExample = find.byKey(ValueKey('event-basic-press'));
    await tester.ensureVisible(longPressExample);
    await tester.pumpAndSettle();
    final longPress = await tester.startGesture(tester.getCenter(longPressExample));
    await tester.pump(Duration(milliseconds: 550));
    expect(find.text('onLongPress'), findsOneWidget);
    await longPress.up();
    await backToCatalog();

    final propagation = await openPage('event-propagation', '阻止冒泡');
    final source = await loadSource(propagation.sections.single);
    final inner = find.byKey(ValueKey('event-propagation-inner'));
    final outer = find.byKey(ValueKey('event-propagation-outer'));
    String count(String target) => tester.widget<Text>(find.byKey(ValueKey('event-propagation-$target-count'))).data!;
    await tester.tap(inner);
    await tester.pump();
    expect((count('inner'), count('outer')), ('1', '1'));
    await tester.tap(find.byKey(ValueKey('event-propagation-toggle')));
    await tester.pumpAndSettle();
    expect((count('inner'), count('outer')), ('1', '1'), reason: '切换开关不应触发内外层点击');
    await tester.tap(inner);
    await tester.pumpAndSettle();
    expect((count('inner'), count('outer')), ('2', '1'));
    await tester.tapAt(tester.getTopLeft(outer) + Offset(12, 12));
    await tester.pump();
    expect((count('inner'), count('outer')), ('2', '2'));
    await tester.tap(find.byKey(ValueKey('event-propagation-reset')));
    await tester.pumpAndSettle();
    expect((count('inner'), count('outer')), ('0', '0'));

    await tester.tap(find.byKey(ValueKey('el-code-example-toggle')));
    await tester.pumpAndSettle();
    expect(find.text(source), findsOneWidget);
    expect(find.text('无法读取示例源码'), findsNothing);
    await backToCatalog();

    final drag = await openPage('event-drag', '拖拽交互');
    await loadSource(drag.sections.single);
    tester.view.physicalSize = Size(320, 400);
    await tester.pumpAndSettle();
    final area = find.byKey(ValueKey('event-drag-area'));
    final block = find.byKey(ValueKey('event-drag-block'));
    final scrollable = find.ancestor(of: area, matching: find.byType(Scrollable)).first;
    final scrollPosition = tester.state<ScrollableState>(scrollable).position;
    expect(scrollPosition.maxScrollExtent, greaterThan(0));
    final initialArea = tester.getTopLeft(area);
    final initial = tester.getTopLeft(block);
    expect(find.text('—'), findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(block));
    await gesture.moveBy(Offset(0, 8));
    await gesture.moveBy(Offset(0, 32));
    await tester.pump();
    expect(tester.getTopLeft(block).dy, greaterThan(initial.dy));
    expect(tester.getTopLeft(area), initialArea);
    expect(find.text('onDragUpdate'), findsOneWidget);

    await gesture.moveBy(Offset(600, 600));
    await tester.pump();
    expect(tester.getBottomRight(block), tester.getBottomRight(area));
    await gesture.moveBy(Offset(-900, -900));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(block), tester.getTopLeft(area));
    expect(find.text('onDragEnd'), findsOneWidget);
    final canceledDrag = await tester.startGesture(tester.getCenter(block));
    await canceledDrag.moveBy(Offset(0, 20));
    await canceledDrag.cancel();
    await tester.pumpAndSettle();
    expect(find.text('onDragCancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await backToCatalog();

    final advanced = await openPage('event-advanced', '高级示例');
    expect(advanced.description, isNull);
    expect(advanced.sections.take(4).map((section) => section.title), ['文本选择与外层点击', '鼠标框选与卡片点击', '编辑选区与按压', '卡片拖放与点击']);
    for (final section in advanced.sections) {
      expect(section.description, isNull);
      await loadSource(section);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
