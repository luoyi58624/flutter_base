import 'package:example/src/pages/settings/el_scroll/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _scrollables(Axis axis) =>
    find.byWidgetPredicate((widget) => widget is Scrollable && axisDirectionToAxis(widget.axisDirection) == axis);

Finder _strip(int shop) => find.ancestor(of: find.text('Title - $shop · 1'), matching: _scrollables(.horizontal));

Finder _productPhoto(int shop, int product) => find.byWidgetPredicate(
  (widget) => widget is ElImage && (widget.src?.endsWith('-shop-${shop - 1}-product-${product - 1}/160/160') ?? false),
);

void main() {
  testWidgets('官方列表纵向滚动后显示对应店铺和商品，各店铺横向位置独立', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: ElScrollPage()));

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(ElSliverRefresh), findsNothing);
    expect(find.text('Title - 1 · 1'), findsOneWidget);
    expect(find.text('Title - 1 · 2'), findsOneWidget);
    expect(_productPhoto(1, 1), findsOneWidget);
    expect(_productPhoto(1, 2), findsOneWidget);

    final firstStrip = tester.state<ScrollableState>(_strip(1)).position;
    firstStrip.jumpTo(220);
    await tester.pumpAndSettle();
    expect(firstStrip.pixels, 220);

    final vertical = _scrollables(.vertical);
    final shopTitle = find.byWidgetPredicate(
      (widget) => widget is ElText && widget.data == 'Title - 12' && widget.style?.fontWeight == .w500,
    );
    await tester.scrollUntilVisible(shopTitle, 350, scrollable: vertical);
    await tester.pumpAndSettle();

    expect(find.text('Title - 1'), findsNothing);
    expect(find.text('Title - 12'), findsWidgets);
    expect(_productPhoto(12, 1), findsOneWidget);
    expect(tester.state<ScrollableState>(_strip(12)).position.pixels, 0);

    tester.state<ScrollableState>(vertical).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Title - 1 · 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
