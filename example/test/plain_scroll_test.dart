import 'package:example/src/widgets/plain_scroll.dart';
import 'package:example/src/pages/examples/sliver_recycler/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _item(int index) => find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'Item - $index');

void main() {
  testWidgets('纯文本普通滚动先挂 100 条，距末端 200px 再追加 100 条', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(
          home: Scaffold(
            body: ExamplePlainScroll(
              key: ValueKey('text-plain-list'),
              maxCount: 10000,
              controller: controller,
              itemBuilder: (context, index) => ElView(child: 'Item - $index'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(Duration(milliseconds: 100));

    expect(_item(0), findsOneWidget);
    expect(_item(99), findsOneWidget);
    expect(_item(100), findsNothing);

    final scroll = tester.widget<ElScrollView>(
      find.descendant(of: find.byKey(ValueKey('text-plain-list')), matching: find.byType(ElScrollView)),
    );
    scroll.controller!.jumpTo(scroll.controller!.position.maxScrollExtent - 100);
    await tester.pump();
    expect(_item(100), findsNothing);
    await tester.pump(Duration(milliseconds: 100));
    expect(_item(199), findsOneWidget);
    expect(_item(200), findsNothing);
  });

  testWidgets('Sliver 对照只提供官方列表与回收列表两种模式', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ElSliverRecyclerExamplePage(initialContent: .text)));
    await tester.pumpAndSettle();
    expect(tester.widget<ElSliverList>(find.byWidgetPredicate((widget) => widget is ElSliverList)).itemCount, 10000);
    await tester.tap(find.byType(PopupMenuButton<Enum>));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckedPopupMenuItem<Enum>, '普通滚动'), findsNothing);
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<Enum>, 'SliverList'));
    await tester.pumpAndSettle();
    expect(find.byType(SliverList), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is ElSliverList), findsNothing);
    expect(find.text('Item - 1'), findsOneWidget);
  });
}
