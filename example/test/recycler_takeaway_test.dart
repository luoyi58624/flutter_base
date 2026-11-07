import 'dart:async';

import 'package:example/src/pages/examples/catalog.dart';
import 'package:example/src/pages/examples/recycler_view/takeaway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  bool dark = false,
  bool networkPhotos = false,
}) async {
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
        home: RecyclerTakeawayPage(networkPhotos: networkPhotos),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

rv.RecyclerView _recycler(WidgetTester tester) => tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));

Finder _menu(int id) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.identifier == 'takeaway-menu-$id'),
  matching: find.byType(ListView),
);

ScrollPosition _menuPosition(WidgetTester tester, int id) =>
    tester.state<ScrollableState>(find.descendant(of: _menu(id), matching: find.byType(Scrollable))).position;

Finder _row(rv.ViewHolder holder) => find.byWidget(holder.itemView);

String _title(WidgetTester tester, rv.ViewHolder holder) => tester
    .renderObject<RenderParagraph>(find.descendant(of: _row(holder), matching: find.byKey(ValueKey('takeaway-title'))))
    .text
    .toPlainText();

Iterable<RenderParagraph> _paragraphs(WidgetTester tester, Finder row) => tester.renderObjectList<RenderParagraph>(
  find.descendant(
    of: row,
    matching: find.byElementPredicate(
      (element) => element is RenderObjectElement && element.renderObject is RenderParagraph,
    ),
  ),
);

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
  test('复杂卡片紧接在外卖页之前', () {
    expect(recyclerExamples[4].key, 'recycler-cards');
    expect(recyclerExamples[5].key, 'recycler-takeaway');
  });

  testWidgets('一万家商家只挂载可见图文，网络图各不相同且断网留白', (tester) async {
    await _open(tester);
    final logoSize = tester.getSize(find.byKey(ValueKey('takeaway-atlas-logo')).first);
    await tester.tap(find.byKey(ValueKey('takeaway-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('takeaway-network-photos')));
    await tester.pumpAndSettle();
    final list = _recycler(tester);
    expect(list.getAdapter()!.getItemCount(), 10000);
    expect(list.getLayoutManager()!.getChildCount(), lessThan(8));
    final holder = list.findViewHolderForItemId(0)!;
    final urls = _urls(tester, _row(holder));
    expect(urls.length, greaterThan(2));
    expect(urls.every((url) => url.startsWith('https://picsum.photos/seed/takeaway-')), isTrue);
    expect(urls, contains('https://picsum.photos/seed/takeaway-shop-0/160/160'));
    expect(find.byType(Image).evaluate().length, lessThan(60));
    expect(_paragraphs(tester, _row(holder)).length, greaterThan(25));
    // flutter_test 默认拒绝网络，此处实际覆盖图片失败后的可用布局。
    expect(find.byIcon(Icons.restaurant_rounded), findsNothing);
    expect(tester.getSize(find.descendant(of: _row(holder), matching: find.byType(Image)).first), logoSize);
    Future<void> toggleCard() async {
      await tester.tap(find.byKey(ValueKey('takeaway-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('takeaway-render-card-mode')));
      await tester.pumpAndSettle();
    }

    await toggleCard();
    expect(_urls(tester, _row(holder)), isEmpty);
    await toggleCard();
    expect(_urls(tester, _row(holder)), urls);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('离线图集在快跳和切换容器后仍绘制当前商家的图块', (tester) async {
    await _open(tester);
    await tester.runAsync(() async {
      final context = tester.element(find.byType(RecyclerTakeawayPage));
      final stream = AssetImage('assets/recycler_cards/takeaway-food.webp')
          .resolve(createLocalImageConfiguration(context));
      final ready = Completer<void>();
      final listener = ImageStreamListener((info, _) {
        info.dispose();
        ready.complete();
      }, onError: (error, stack) => ready.completeError(error, stack));
      stream.addListener(listener);
      try {
        await ready.future;
      } finally {
        stream.removeListener(listener);
      }
    });
    await tester.pumpAndSettle();

    Finder inRow(rv.ViewHolder holder, String key) =>
        find.descendant(of: _row(holder), matching: find.byKey(ValueKey(key)));

    final list = _recycler(tester);
    expect(list.getLayoutManager()!.isItemPrefetchEnabled(), isFalse);
    final first = list.findViewHolderForItemId(0)!;
    expect(inRow(first, 'takeaway-atlas-logo'), paints..drawImageRect(source: Rect.fromLTWH(1086.5, 724.5, 361, 361)));
    expect(inRow(first, 'takeaway-atlas-dish-1'), paints..drawImageRect(source: Rect.fromLTWH(.5, .5, 361, 361)));

    for (final (position, logoTile, dishTile) in [(5001, 2, 3), (9301, 9, 0), (65, 2, 3)]) {
      list.scrollToPosition(position);
      await tester.pump(Duration(microseconds: 8333));
      final holder = list.findViewHolderForItemId(position)!;
      Rect tileRect(int tile) => Rect.fromLTWH(tile % 4 * 362 + .5, tile ~/ 4 * 362 + .5, 361, 361);
      expect(inRow(holder, 'takeaway-atlas-logo'), paints..drawImageRect(source: tileRect(logoTile)));
      expect(inRow(holder, 'takeaway-atlas-dish-1'), paints..drawImageRect(source: tileRect(dishTile)));
      expect(find.byType(Image), findsNothing);
    }
    for (final mode in ['listView', 'elScrollView']) {
      await _choose(tester, mode);
      expect(
        find.byKey(ValueKey('takeaway-atlas-logo')).first,
        paints..drawImageRect(source: Rect.fromLTWH(1086.5, 724.5, 361, 361)),
      );
      expect(find.byType(Image), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('移动密度以小字为主，首家完整卡片不超过 400 像素', (tester) async {
    await _open(tester);
    final holder = _recycler(tester).findViewHolderForItemId(0)!;
    final sizes = [
      for (final paragraph in _paragraphs(tester, _row(holder)))
        if (paragraph.text.style?.fontFamily != 'MaterialIcons') ?paragraph.text.style?.fontSize,
      for (final view in tester.widgetList<ElView>(find.descendant(of: _row(holder), matching: find.byType(ElView))))
        if (view.child is String) ?view.style?.fontSize,
    ];
    expect(sizes.where((size) => size <= 12).length / sizes.length, greaterThan(.75));
    final title = tester.renderObject<RenderParagraph>(
      find.descendant(of: _row(holder), matching: find.byKey(ValueKey('takeaway-title'))),
    );
    expect(title.text.style?.fontSize, 14);
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
    await _open(tester, networkPhotos: true);
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
    final dish = find.descendant(of: _row(first), matching: find.byKey(ValueKey('takeaway-dish-card'))).first;
    final price = tester
        .renderObject<RenderParagraph>(find.descendant(of: dish, matching: find.byKey(ValueKey('takeaway-dish-price'))))
        .text
        .toPlainText();
    await tester.tap(find.descendant(of: dish, matching: find.byType(IconButton)));
    await tester.pumpAndSettle();
    expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-total'))).child, price);

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

  testWidgets('菜单惯性中换绑立即停止旧活动，不覆盖另一家店的位置', (tester) async {
    await _open(tester);
    final list = _recycler(tester)..setItemViewCacheSize(0);
    (list.getLayoutManager()! as rv.LinearLayoutManager).setItemPrefetchEnabled(false);
    list.getRecycledViewPool().setMaxRecycledViews(0, 20);
    await tester.pumpAndSettle();
    final first = list.findViewHolderForItemId(0)!;
    final position = _menuPosition(tester, 0);
    await tester.fling(_menu(0), Offset(-160, 0), 900);
    await tester.pump(Duration(milliseconds: 16));
    expect(position.isScrollingNotifier.value, isTrue);
    final saved = position.pixels;
    list.scrollToPosition(5000);
    await tester.pump();
    expect(first.getItemId(), isNot(0));
    final rebound = _menuPosition(tester, first.getItemId());
    expect(rebound, same(position), reason: '跨店换绑复用同一个内层滚动宿主');
    expect(rebound.isScrollingNotifier.value, isFalse);
    expect(rebound.pixels, 0);
    await tester.pump(Duration(milliseconds: 200));
    expect(rebound.pixels, 0);
    list.scrollToPosition(0);
    await tester.pumpAndSettle();
    expect(_menuPosition(tester, 0).pixels, closeTo(saved, .1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('横向菜单按住但未移动时换店也结束旧手势', (tester) async {
    await _open(tester);
    final list = _recycler(tester)..setItemViewCacheSize(0);
    (list.getLayoutManager()! as rv.LinearLayoutManager).setItemPrefetchEnabled(false);
    await tester.pumpAndSettle();
    final first = list.findViewHolderForItemId(0)!;
    final position = _menuPosition(tester, 0);
    var cancelled = false;
    position.hold(() => cancelled = true);
    expect(position.isScrollingNotifier.value, isFalse);

    list.scrollToPosition(5000);
    await tester.pumpAndSettle();
    expect(first.getItemId(), isNot(0));
    expect(_menuPosition(tester, first.getItemId()), same(position));
    expect(cancelled, isTrue);
    expect(position.pixels, 0);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('长菜单末端经过短菜单复用后，仍恢复原来的末端位置', (tester) async {
    await _open(tester);
    final list = _recycler(tester)..setItemViewCacheSize(0);
    (list.getLayoutManager()! as rv.LinearLayoutManager).setItemPrefetchEnabled(false);
    list.getRecycledViewPool().setMaxRecycledViews(0, 20);
    list.scrollToPosition(2);
    await tester.pumpAndSettle();
    final long = _menuPosition(tester, 2);
    expect(tester.widget<ListView>(_menu(2)).childrenDelegate.estimatedChildCount, 12);
    expect(long.maxScrollExtent, closeTo(1200 - long.viewportDimension, .1), reason: '餐品数量变化必须更新滚动范围');
    long.jumpTo(long.maxScrollExtent);
    await tester.pumpAndSettle();
    final saved = long.pixels;
    list.scrollToPosition(4800);
    await tester.pumpAndSettle();
    expect(_menuPosition(tester, 4800).maxScrollExtent, lessThan(saved));
    list.scrollToPosition(2);
    await tester.pumpAndSettle();
    expect(_menuPosition(tester, 2).pixels, closeTo(saved, .1));
    expect(_menuPosition(tester, 2).isScrollingNotifier.value, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('分类筛选保持数据身份和同一批网络图片', (tester) async {
    await _open(tester, networkPhotos: true);
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
