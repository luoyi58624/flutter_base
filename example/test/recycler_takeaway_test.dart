import 'package:example/src/pages/examples/catalog.dart';
import 'package:example/src/pages/examples/recycler_view/takeaway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, {double width = 390, double scale = 1, bool dark = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RecyclerTakeawayPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

rv.RecyclerView _recycler(WidgetTester tester) => tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));

Finder _menu(int id) => find.byKey(ValueKey('takeaway-menu-list-$id'));

ScrollPosition _menuPosition(WidgetTester tester, int id) =>
    tester.state<ScrollableState>(find.descendant(of: _menu(id), matching: find.byType(Scrollable))).position;

Finder _row(rv.ViewHolder holder) => find.byWidget(holder.itemView);

String _title(WidgetTester tester, rv.ViewHolder holder) =>
    tester.widget<ElView>(find.descendant(of: _row(holder), matching: find.byKey(ValueKey('takeaway-title')))).child
        as String;

Set<String> _urls(WidgetTester tester, Finder scope) => {
  for (final image in tester.widgetList<Image>(find.descendant(of: scope, matching: find.byType(Image))))
    if (image.image case ResizeImage(imageProvider: final NetworkImage source)) source.url,
};

Future<void> _choose(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(ValueKey('takeaway-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('takeaway-mode-$mode')));
  await tester.pumpAndSettle();
}

void main() {
  test('外卖页在第五项，复杂卡片仍在第四项', () {
    expect(recyclerExamples[3].key, 'recycler-cards');
    expect(recyclerExamples[4].key, 'recycler-takeaway');
  });

  testWidgets('一万家商家只挂载可见图文，Faker 图片各不相同且断网有占位', (tester) async {
    await _open(tester);
    final list = _recycler(tester);
    expect(list.getAdapter()!.getItemCount(), 10000);
    expect(list.getLayoutManager()!.getChildCount(), lessThan(8));
    final holder = list.findViewHolderForItemId(0)!;
    final urls = _urls(tester, _row(holder));
    expect(urls.length, greaterThan(2));
    expect(urls.every((url) => url.startsWith('https://picsum.photos/seed/takeaway-')), isTrue);
    expect(urls, contains('https://picsum.photos/seed/takeaway-shop-0/160/160'));
    expect(find.byType(Image).evaluate().length, lessThan(60));
    expect(find.descendant(of: _row(holder), matching: find.byType(ElView)).evaluate().length, greaterThan(25));
    // flutter_test 默认拒绝网络，此处实际覆盖图片失败后的可用布局。
    expect(find.byIcon(Icons.restaurant_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('移动密度以小字为主，首家完整卡片不超过 400 像素', (tester) async {
    await _open(tester);
    final holder = _recycler(tester).findViewHolderForItemId(0)!;
    final words = tester
        .widgetList<ElView>(find.descendant(of: _row(holder), matching: find.byType(ElView)))
        .where((view) => view.child is String && view.style?.fontSize != null)
        .toList();
    expect(words.where((view) => view.style!.fontSize! <= 12).length / words.length, greaterThan(.75));
    final title = tester.widget<ElView>(
      find.descendant(of: _row(holder), matching: find.byKey(ValueKey('takeaway-title'))),
    );
    expect(title.style!.fontSize, 14);
    expect(tester.getSize(_row(holder)).height, lessThan(400));
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('使用品牌卡片底色，店标红包与信息商品按参考图对齐', (tester) async {
    await _open(tester);
    final holder = _recycler(tester).findViewHolderForItemId(0)!;
    Finder inside(Finder finder) => find.descendant(of: _row(holder), matching: finder);
    final cards = tester.widgetList<ElCard>(inside(find.byType(ElCard))).toList();
    expect(cards.length, greaterThan(3));
    expect(cards.every((card) => card.style?.backgroundColor == null), isTrue);
    final logo = tester.getRect(inside(find.byKey(ValueKey('takeaway-shop-logo'))));
    final coupon = inside(find.byKey(ValueKey('takeaway-coupon')));
    final couponBefore = tester.getRect(coupon);
    final title = tester.getRect(inside(find.byKey(ValueKey('takeaway-title'))));
    final firstDish = tester.getRect(inside(find.byKey(ValueKey('takeaway-dish-card'))).first);
    expect(couponBefore.left, closeTo(logo.left, .1));
    expect(firstDish.left, closeTo(title.left, .1));
    await tester.drag(_menu(0), Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(coupon).left, closeTo(couponBefore.left, .1));
    expect(_menuPosition(tester, 0).pixels, greaterThan(40));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  for (final mode in ['recyclerView', 'listView', 'elScrollView']) {
    testWidgets('$mode 内层横向独立滚动，外层仍可纵向滚动且购物车可操作', (tester) async {
      await _open(tester);
      if (mode != 'recyclerView') await _choose(tester, mode);
      final before = _menuPosition(tester, 0).pixels;
      await tester.drag(_menu(0), Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(_menuPosition(tester, 0).pixels, greaterThan(before + 40));
      final add = find
          .byWidgetPredicate((widget) => widget is IconButton && widget.tooltip?.startsWith('加入') == true)
          .hitTestable()
          .first;
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-count'))).child, '已选 1 份');
      expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-total'))).child, isNot('¥0.0'));
      await tester.tap(find.byKey(ValueKey('takeaway-cart-clear')));
      await tester.pumpAndSettle();
      expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-count'))).child, '已选 0 份');
      final vertical = mode == 'recyclerView'
          ? _recycler(tester).controller!
          : mode == 'listView'
          ? tester.widget<ListView>(find.byKey(ValueKey('official-takeaway-list'))).controller!
          : tester.widget<ElScrollView>(find.byKey(ValueKey('el-takeaway-list'))).controller!;
      expect(vertical.offset, 0, reason: '横向拖动不能推动外层纵向列表');
      await tester.drag(find.byKey(ValueKey('takeaway-title')).hitTestable().first, Offset(0, -280));
      await tester.pumpAndSettle();
      expect(vertical.offset, greaterThan(30));
      expect(find.byKey(ValueKey('takeaway-title')).evaluate().length, lessThan(20));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    });
  }

  testWidgets('holder 换绑保持卡片结构，菜单按商家保存且不会带入另一家店', (tester) async {
    await _open(tester);
    final list = _recycler(tester)..setItemViewCacheSize(0);
    (list.getLayoutManager()! as rv.LinearLayoutManager).setItemPrefetchEnabled(false);
    list.getRecycledViewPool().setMaxRecycledViews(0, 20);
    await tester.pumpAndSettle();
    final first = list.findViewHolderForItemId(0)!;
    final originalTitle = _title(tester, first);
    final element = _row(first).evaluate().single;
    await tester.drag(_menu(0), Offset(-260, 0));
    await tester.pumpAndSettle();
    final savedOffset = _menuPosition(tester, 0).pixels;
    final savedUrls = _urls(tester, _row(first));
    expect(savedOffset, greaterThan(100));

    list.scrollToPosition(5000);
    await tester.pumpAndSettle();
    expect(first.getItemId(), isNot(0));
    expect(_row(first).evaluate().single, same(element));
    expect(_title(tester, first), isNot(originalTitle));
    expect(_menuPosition(tester, first.getItemId()).pixels, 0);
    expect(_urls(tester, _row(first)).intersection(savedUrls), isEmpty);

    list.scrollToPosition(0);
    await tester.pumpAndSettle();
    final restored = list.findViewHolderForItemId(0)!;
    expect(_title(tester, restored), originalTitle);
    expect(_urls(tester, _row(restored)), savedUrls);
    expect(_menuPosition(tester, 0).pixels, closeTo(savedOffset, .1));
    await _choose(tester, 'listView');
    expect(_menuPosition(tester, 0).pixels, closeTo(savedOffset, .1));
    await _choose(tester, 'elScrollView');
    expect(_menuPosition(tester, 0).pixels, closeTo(savedOffset, .1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('分类筛选保持数据身份和同一批 Faker 图片', (tester) async {
    await _open(tester);
    final original = _urls(tester, _row(_recycler(tester).findViewHolderForItemId(0)!));
    await tester.tap(find.byKey(ValueKey('takeaway-category-0')));
    await tester.pumpAndSettle();
    expect(_recycler(tester).getAdapter()!.getItemCount(), 1250);
    expect(_urls(tester, _row(_recycler(tester).findViewHolderForItemId(0)!)), original);
    await tester.tap(find.byKey(ValueKey('takeaway-category--1')));
    await tester.pumpAndSettle();
    expect(_recycler(tester).getAdapter()!.getItemCount(), 10000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('窄屏大字和宽屏暗色都能布局', (tester) async {
    for (final config in [(320.0, 1.6, false), (1280.0, 1.0, true)]) {
      await _open(tester, width: config.$1, scale: config.$2, dark: config.$3);
      expect(_menu(0), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    }
  });
}
