import 'package:example/main.dart';
import 'package:example/src/pages/components/doc_page.dart';
import 'package:example/src/pages/components/index.dart';
import 'package:example/src/router/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';
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

    Future<ComponentDocPage> openPage(String key, String title) async {
      final catalog = find.byKey(PageStorageKey('component-catalog'));
      final scrollable = find.descendant(of: catalog, matching: find.byType(Scrollable));
      final position = tester.state<ScrollableState>(scrollable.first).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('component-$key')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/components/$key');
      final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
      expect(page.title, title);
      expect(find.text('本页目录'), findsNothing);
      return page;
    }

    Future<String> loadSource(ComponentDocSection section) async {
      final source = (await tester.runAsync(() => rootBundle.loadString(section.source)))!;
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
    await backToCatalog();

    final propagation = await openPage('event-propagation', '阻止冒泡');
    final source = await loadSource(propagation.sections.single);
    Finder blockWithLabel(String label) =>
        find.byWidgetPredicate((widget) => widget is ElView && widget.child == label);

    final output = <String>[];
    final originalPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null && message.endsWith('收到点击')) output.add(message);
    };
    try {
      await tester.tap(blockWithLabel('点击内层，继续冒泡'));
      expect(output, ['内层收到点击', '外层收到点击']);
      output.clear();
      await tester.tap(blockWithLabel('点击内层，截断传播'));
      expect(output, ['内层收到点击']);
    } finally {
      debugPrint = originalPrint;
    }

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
    final gesture = await tester.startGesture(tester.getCenter(block));
    await gesture.moveBy(Offset(0, 8));
    await gesture.moveBy(Offset(0, 32));
    await tester.pump();
    expect(tester.getTopLeft(block).dy, greaterThan(initial.dy));
    expect(tester.getTopLeft(area), initialArea);

    await gesture.moveBy(Offset(600, 600));
    await tester.pump();
    expect(tester.getBottomRight(block), tester.getBottomRight(area));
    await gesture.moveBy(Offset(-900, -900));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(block), tester.getTopLeft(area));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
