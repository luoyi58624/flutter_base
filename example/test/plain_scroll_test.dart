import 'package:example/src/pages/examples/recycler_view/text.dart';
import 'package:example/src/pages/examples/sliver_recycler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _item(int index) => find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'Item - $index');

Future<void> _chooseText(WidgetTester tester) async {
  await tester.tap(find.byKey(ValueKey('text-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('text-mode-plain')));
  await tester.pump();
  await tester.pump(Duration(milliseconds: 100));
}

void main() {
  testWidgets('纯文本普通滚动先挂 100 条，距末端 200px 再追加 100 条', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: RecyclerTextPage()),
      ),
    );
    await tester.pumpAndSettle();
    await _chooseText(tester);

    expect(_item(0), findsOneWidget);
    expect(_item(99), findsOneWidget);
    expect(_item(100), findsNothing);
    expect(find.byType(ElListView), findsNothing);

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

  testWidgets('Sliver 对照的普通滚动按批追加，虚拟列表仍是一万条', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: ElSliverRecyclerExamplePage()));
    await tester.pumpAndSettle();
    expect(tester.widget<ElSliverRecyclerList>(find.byType(ElSliverRecyclerList)).itemCount, 10000);

    await tester.tap(find.byType(PopupMenuButton<Enum>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<Enum>, '纯文本'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<Enum>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<Enum>, '普通滚动'));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));

    expect(find.byType(ElSliverRecyclerList), findsNothing);
    expect(find.text('Item - 1'), findsOneWidget);
    expect(find.text('Item - 100'), findsOneWidget);
    expect(find.text('Item - 101'), findsNothing);

    final scroll = tester.widget<ElScrollView>(find.byType(ElScrollView));
    scroll.controller!.jumpTo(scroll.controller!.position.maxScrollExtent - 100);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    expect(find.text('Item - 200'), findsOneWidget);
    expect(find.text('Item - 201'), findsNothing);
  });
}
