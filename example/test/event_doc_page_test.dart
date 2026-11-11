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
    expect(eventGroup.children.map((item) => item.title), ['基础使用', '阻止冒泡', '拖拽交互']);

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
    for (final section in basic.sections) {
      await loadSource(section);
    }
    final tapExample = find.byKey(ValueKey('event-basic-tap'));
    await tester.ensureVisible(tapExample);
    await tester.pumpAndSettle();
    expect(tapExample.hitTestable(), findsOneWidget);
    expect(find.descendant(of: tapExample, matching: find.text('点击或连击')), findsOneWidget);
    final tap = await tester.startGesture(tester.getCenter(tapExample));
    await tester.pump();
    expect(find.descendant(of: tapExample, matching: find.text('onTapDown')), findsOneWidget);
    await tap.up();
    await tester.pump(Duration(milliseconds: 350));
    expect(find.descendant(of: tapExample, matching: find.text('onTap')), findsOneWidget);

    final longPressExample = find.byKey(ValueKey('event-basic-long-press'));
    await tester.ensureVisible(longPressExample);
    await tester.pumpAndSettle();
    final longPress = await tester.startGesture(tester.getCenter(longPressExample));
    await tester.pump(Duration(milliseconds: 550));
    expect(find.descendant(of: longPressExample, matching: find.text('onLongPress')), findsOneWidget);
    await longPress.up();
    await backToCatalog();

    final propagation = await openPage('event-propagation', '阻止冒泡');
    final source = await loadSource(propagation.sections.single);
    Finder inner(bool stop) => find.byKey(ValueKey(('event-propagation-inner', stop)));
    Finder outer(bool stop) => find.byKey(ValueKey(('event-propagation-outer', stop)));

    await tester.tap(inner(false));
    await tester.pump();
    expect(find.descendant(of: inner(false), matching: find.text('1. 内层 onTap')), findsOneWidget);
    expect(tester.widget<Text>(outer(false)).data, '2. 外层 onTap');
    await tester.tap(inner(true));
    await tester.pump();
    expect(find.descendant(of: inner(true), matching: find.text('1. 内层 onTap')), findsOneWidget);
    expect(tester.widget<Text>(outer(true)).data, '外层等待点击');
    expect(tester.widget<Text>(outer(false)).data, '2. 外层 onTap');
    await tester.tap(outer(false));
    await tester.pump();
    expect(find.descendant(of: inner(false), matching: find.text('点击内层')), findsOneWidget);
    expect(tester.widget<Text>(outer(false)).data, '1. 外层 onTap');

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
    expect(find.text('等待拖动'), findsOneWidget);
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
    await tester.pumpWidget(SizedBox());
  });
}
