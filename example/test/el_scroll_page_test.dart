import 'package:example/src/pages/settings/el_scroll/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _scrollables(Axis axis, {bool skipOffstage = true}) => find.byWidgetPredicate(
  (widget) => widget is Scrollable && axisDirectionToAxis(widget.axisDirection) == axis,
  skipOffstage: skipOffstage,
);

Finder _strip(int shop) => find.ancestor(of: find.text('Title - $shop · 1'), matching: _scrollables(.horizontal));

Finder _productPhoto(int shop, int product) => find.byWidgetPredicate(
  (widget) =>
      widget is ElImageView && (widget.src?.endsWith('-shop-${shop - 1}-product-${product - 1}/160/160') ?? false),
);

Future<void> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 320);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(home: ElScrollPage()));
}

void main() {
  testWidgets('官方列表纵向滚动后显示对应店铺和商品，各店铺横向位置独立', (tester) async {
    await _open(tester);

    expect(find.byType(CustomScrollView), findsWidgets);
    expect(find.byType(ElScrollView), findsNothing);
    expect(find.byWidgetPredicate((widget) => widget is ElSliverList), findsNothing);
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

  testWidgets('关闭官方开关后使用回收子项和下拉刷新，换绑时更新图文并重置横向位置', (tester) async {
    await _open(tester);
    final modeSwitch = find.byType(Switch);
    final refresh = find.byType(ElSliverRefresh, skipOffstage: false);
    expect(refresh, findsNothing);
    await tester.tap(modeSwitch);
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.byWidgetPredicate((widget) => widget is ElSliverList), findsOneWidget);
    expect(refresh, findsOneWidget);
    expect(find.text('Title - 1 · 1'), findsOneWidget);

    await tester.drag(_scrollables(.vertical), Offset(0, 240));
    await tester.pump();
    expect(find.byType(ElSliverRefresh), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ElSliverRefresh), findsNothing);

    final initialStrips = tester.stateList<ScrollableState>(_scrollables(.horizontal, skipOffstage: false)).toSet();
    for (final strip in initialStrips) {
      strip.position.jumpTo(220);
    }
    await tester.pumpAndSettle();

    final vertical = tester.state<ScrollableState>(_scrollables(.vertical)).position;
    vertical.jumpTo(18000);
    await tester.pumpAndSettle();

    expect(find.text('Title - 1'), findsNothing);
    final reused = tester.stateList<ScrollableState>(_scrollables(.horizontal)).where(initialStrips.contains);
    expect(reused, isNotEmpty);
    for (final strip in reused) {
      expect(strip.position.pixels, 0);
      final scope = find.byElementPredicate((element) => identical(element, strip.context));
      final photo = tester.widget<ElImageView>(
        find.descendant(
          of: scope,
          matching: find.byWidgetPredicate(
            (widget) => widget is ElImageView && (widget.src?.endsWith('-product-0/160/160') ?? false),
          ),
        ),
      );
      final shop = int.parse(RegExp(r'shop-(\d+)-product-0').firstMatch(photo.src!)!.group(1)!) + 1;
      expect(find.descendant(of: scope, matching: find.text('Title - $shop · 1')), findsOneWidget);
    }

    await tester.tap(modeSwitch);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is ElSliverList), findsNothing);
    expect(refresh, findsNothing);
    expect(find.text('Title - 1 · 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
