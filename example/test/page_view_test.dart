// 测试沿用项目内部相对路径约定。
// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/pages/components/index.dart';
import '../lib/src/pages/components/view/page_view/index.dart';
import '../lib/src/widgets/view_card.dart';

void main() {
  test('分页示例登记在 View 视图分组', () {
    final group = componentCatalog.singleWhere((group) => group.title == 'View 视图');
    expect(group.children.any((page) => page.key == 'view-page-view' && page.data != null), isTrue);
  });

  for (final width in [390.0, 1100.0]) {
    testWidgets('分页示例标签切换、卡片选中与页面保活 width=$width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.mobileComponents,
          child: MaterialApp(home: PageViewPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ElPageView), findsOneWidget);
      expect(find.byType(ExampleViewCard).evaluate().length, lessThan(30));
      await tester.tap(find.byType(ExampleViewCard).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.tap(find.text('订单'));
      await tester.pumpAndSettle();
      final pages = tester.widget<ElPageView>(find.byType(ElPageView)).controller!;
      expect(pages.page, 1);
      await tester.tap(find.text('消息'));
      await tester.pumpAndSettle();
      expect(pages.page, 0);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    });
  }

  testWidgets('示例横向卡片带在原手势中交给分页并同步标签', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: PageViewPage()),
      ),
    );
    await tester.pumpAndSettle();
    final strip = find.byKey(PageStorageKey('page-strip-消息'));
    final scrollable = tester.state<ScrollableState>(find.descendant(of: strip, matching: find.byType(Scrollable)));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent - 50);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(strip));
    await gesture.moveBy(Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(Offset(-280, 0));
    await tester.pump();
    final pages = tester.widget<ElPageView>(find.byType(ElPageView)).controller!;
    expect(pages.page, greaterThan(.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pages.page, closeTo(1, .001));
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
