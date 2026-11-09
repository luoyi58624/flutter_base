import 'package:example/src/pages/examples.dart';
import 'package:example/src/pages/examples/sliver_takeaway/takeaway.dart';
import 'package:example/src/utils/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(navigatorKey: el.navigatorKey, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('示例目录用 ElSliver 滚动分组打开外卖页，并可换成网格', (tester) async {
    await _open(tester, ExamplesPage());
    expect(tester.widgetList<ElListGroup>(find.byType(ElListGroup)).map((group) => group.title), [
      '交互与视图',
      'RecyclerView',
      'ElSliver 滚动',
    ]);
    await tester.drag(find.byKey(PageStorageKey('advanced-examples')), Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('advanced-sliver-takeaway')));
    await tester.pumpAndSettle();

    expect(find.byType(TakeawaySliverPage), findsOneWidget);
    expect(find.byType(ElSliverRecyclerList), findsOneWidget);
    expect(RouterUtil.exampleRoutes().map((route) => route.path), contains('sliver-takeaway'));

    await tester.tap(find.byKey(ValueKey('takeaway-sliver-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('takeaway-sliver-grid')));
    await tester.pumpAndSettle();
    expect(find.byType(ElSliverRecyclerGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
