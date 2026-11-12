import 'package:example/src/pages/settings/el_scroll/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _scrollables(Axis axis, {bool skipOffstage = true}) => find.byWidgetPredicate(
  (widget) => widget is Scrollable && axisDirectionToAxis(widget.axisDirection) == axis,
  skipOffstage: skipOffstage,
);

Finder _inStrip(ScrollableState strip, Finder matching) => find.descendant(
  of: find.byElementPredicate((element) => identical(element, strip.context), skipOffstage: false),
  matching: matching,
);

Finder _productPhoto(int index) => find.byWidgetPredicate(
  (widget) => widget is ElImage && (widget.src?.endsWith('-product-$index/160/160') ?? false),
  skipOffstage: false,
);

void main() {
  testWidgets('纵向换绑时复用横向滚动容器并更新店铺和商品', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: ElScrollPage()));

    expect(find.text('Title - 1'), findsWidgets);
    expect(find.text('Title - 1 · 1'), findsOneWidget);
    expect(find.text('Title - 1 · 2'), findsOneWidget);

    final oldPhotos = <ScrollableState, String?>{};
    for (final strip in tester.stateList<ScrollableState>(_scrollables(.horizontal, skipOffstage: false))) {
      final firstPhoto = tester.widget<ElImage>(_inStrip(strip, _productPhoto(0))).src;
      final secondPhoto = tester.widget<ElImage>(_inStrip(strip, _productPhoto(1))).src;
      expect(firstPhoto, isNot(secondPhoto));
      oldPhotos[strip] = firstPhoto;
      strip.position.jumpTo(220);
    }
    await tester.pumpAndSettle();
    expect(oldPhotos.keys, isNotEmpty);
    expect(oldPhotos.keys.map((strip) => strip.position.pixels), everyElement(220));

    final vertical = tester.state<ScrollableState>(_scrollables(.vertical)).position;
    vertical.jumpTo(18000);
    await tester.pumpAndSettle();

    expect(find.text('Title - 1'), findsNothing);
    final reused = tester.stateList<ScrollableState>(_scrollables(.horizontal)).where(oldPhotos.containsKey);
    expect(reused, isNotEmpty);
    for (final strip in reused) {
      expect(strip.position.pixels, 0);
      final photo = tester.widget<ElImage>(_inStrip(strip, _productPhoto(0)));
      expect(photo.src, isNot(oldPhotos[strip]));
      final row = int.parse(RegExp(r'shop-(\d+)-product-0').firstMatch(photo.src!)!.group(1)!);
      expect(find.text('Title - ${row + 1}'), findsWidgets);
      expect(_inStrip(strip, find.text('Title - ${row + 1} · 1')), findsOneWidget);
    }

    vertical.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Title - 1 · 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
