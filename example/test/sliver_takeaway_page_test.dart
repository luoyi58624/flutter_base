import 'package:example/src/pages/examples/index.dart';
import 'package:example/src/pages/examples/sliver_takeaway/index.dart';
import 'package:example/src/utils/router.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerScrollEvent;
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

Finder _scope(Element element) =>
    find.byElementPredicate((candidate) => identical(candidate, element), skipOffstage: false);

Element _slotOf(Element card) {
  var slot = card;
  var found = false;
  card.visitAncestorElements((ancestor) {
    if (ancestor.widget is ElSliverRecyclerList || ancestor.widget is ElSliverRecyclerGrid) {
      found = true;
      return false;
    }
    slot = ancestor;
    return true;
  });
  expect(found, isTrue);
  return slot;
}

class _ShopSnapshot {
  _ShopSnapshot(WidgetTester tester, this.card)
    : slot = _slotOf(card),
      cardWidget = card.widget,
      cardRender = card.renderObject! {
    final scope = _scope(card);
    final titleFinder = find.descendant(of: scope, matching: find.byKey(ValueKey('takeaway-title')));
    titleElement = tester.element(titleFinder);
    title = tester.renderObject(titleFinder);
    titleText = tester.widget<ElView>(titleFinder).child! as String;
    final semantics = tester.widget<Semantics>(
      find.descendant(
        of: scope,
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.identifier?.startsWith('takeaway-menu-') == true,
        ),
      ),
    );
    id = int.parse(semantics.properties.identifier!.substring('takeaway-menu-'.length));
    menu = tester.state<ScrollableState>(
      find.descendant(
        of: find.descendant(of: scope, matching: find.byType(ListView)),
        matching: find.byType(Scrollable),
      ),
    );
    Element? foundHost;
    card.visitAncestorElements((ancestor) {
      if (ancestor.widget.runtimeType.toString() == '_TakeawayCardHost') {
        foundHost = ancestor;
        return false;
      }
      return true;
    });
    expect(foundHost, isNotNull);
    host = foundHost!;
    hostWidget = host.widget;
    ChangeNotifier? signal;
    card.visitAncestorElements((ancestor) {
      if (ancestor.widget.runtimeType.toString() != '_StoreCard') return true;
      signal = (ancestor.widget as dynamic).store as ChangeNotifier;
      return false;
    });
    expect(signal, isNotNull);
    storeSignal = signal!;
    final logo = find.descendant(of: scope, matching: find.byKey(ValueKey('takeaway-photo-logo')));
    if (logo.evaluate().isNotEmpty) logoRender = tester.renderObject(logo);
    final dishPhoto = find.descendant(of: scope, matching: find.byKey(ValueKey('takeaway-photo-dish-0')));
    if (dishPhoto.evaluate().isNotEmpty) dishPhotoRender = tester.renderObject(dishPhoto);
  }

  final Element card;
  final Element slot;
  final Widget cardWidget;
  final RenderObject cardRender;
  late final Element host;
  late final Widget hostWidget;
  late final ChangeNotifier storeSignal;
  RenderObject? logoRender;
  RenderObject? dishPhotoRender;
  late final Element titleElement;
  late final RenderObject title;
  late final String titleText;
  late final int id;
  late final ScrollableState menu;
}

List<_ShopSnapshot> _shops(WidgetTester tester) => [
  for (final card in find.byKey(ValueKey('takeaway-shop-card')).evaluate()) _ShopSnapshot(tester, card),
];

ScrollController _vertical(WidgetTester tester) =>
    tester.widget<ElScrollView>(find.byKey(ValueKey('takeaway-sliver'))).controller!;

Set<String> _photoUrls(WidgetTester tester, _ShopSnapshot shop) => {
  for (final image in tester.widgetList<ElImageView>(
    find.descendant(of: _scope(shop.card), matching: find.byType(ElImageView)),
  ))
    if (image.src case final source? when source.startsWith('https://')) source,
};

Finder _addButtons(_ShopSnapshot shop) => find
    .descendant(
      of: _scope(shop.card),
      matching: find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == '加入购物车'),
    )
    .hitTestable();

Future<String> _addVisibleDish(WidgetTester tester, _ShopSnapshot shop) async {
  final button = _addButtons(shop).first;
  final dish = find.ancestor(of: button, matching: find.byKey(ValueKey('takeaway-dish-card')));
  final price =
      tester.widget<ElView>(find.descendant(of: dish, matching: find.byKey(ValueKey('takeaway-dish-price')))).child!
          as String;
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-count'))).child, '已选 1 份');
  expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-total'))).child, price);
  return price;
}

void main() {
  testWidgets('Sliver 外卖页 Windows 鼠标渐进滚动只消费一次，横向菜单独立且卸载停止动画', (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await _open(tester, TakeawaySliverPage());
      final vertical = _vertical(tester);
      Offset verticalPoint() => tester.getCenter(find.byKey(ValueKey('takeaway-title')).hitTestable().first);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          timeStamp: Duration(seconds: 1),
          position: verticalPoint(),
          scrollDelta: Offset(0, 120),
        ),
      );
      expect(vertical.offset, 0, reason: '滚轮应交给现有平滑器，不能同时由官方 Scrollable 立即直跳。');
      // Ticker 首帧建立 elapsed=0，再验证下一帧真实推进而未直接抵达终点。
      await tester.pump();
      await tester.pump(Duration(milliseconds: 16));
      expect(vertical.offset, greaterThan(0));
      expect(vertical.offset, lessThan(120));
      await tester.pumpAndSettle();
      expect(vertical.offset, closeTo(120, .01), reason: '同一个 wheel 事件只能消费一次 120 像素。');

      final shop = _shops(tester).firstWhere(
        (shop) =>
            find.descendant(of: _scope(shop.card), matching: find.byType(ListView)).hitTestable().evaluate().isNotEmpty,
      );
      final menu = find.descendant(of: _scope(shop.card), matching: find.byType(ListView));
      final horizontal = shop.menu.position;
      final horizontalBefore = horizontal.pixels;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          timeStamp: Duration(seconds: 2),
          position: tester.getCenter(menu),
          scrollDelta: Offset(120, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(horizontal.pixels, closeTo(horizontalBefore + 120, .01));
      expect(vertical.offset, closeTo(120, .01), reason: '菜单的横向滚轮不得再推动外层纵向视口。');

      await tester.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          timeStamp: Duration(seconds: 3),
          position: verticalPoint(),
          scrollDelta: Offset(0, 120),
        ),
      );
      await tester.pump();
      await tester.pump(Duration(milliseconds: 16));
      expect(vertical.offset, greaterThan(120));
      expect(vertical.offset, lessThan(240));
      expect(vertical.position.isScrollingNotifier.value, isTrue);

      await tester.pumpWidget(SizedBox.shrink());
      await tester.pump(Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, 0, reason: '退出页面必须释放仍在活动的平滑滚动 ticker。');
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('Sliver 外卖页换店与同序号分类筛选更新图文和加购数据', (tester) async {
    await _open(tester, TakeawaySliverPage(networkPhotos: true));
    final initial = _shops(tester).singleWhere((shop) => shop.id == 0);
    final initialUrls = _photoUrls(tester, initial);
    expect(initialUrls, contains('https://picsum.photos/seed/takeaway-shop-0/160/160'));

    _vertical(tester).jumpTo(20000);
    await tester.pumpAndSettle();
    final distant = _shops(tester).firstWhere((shop) => _addButtons(shop).evaluate().isNotEmpty);
    final distantUrls = _photoUrls(tester, distant);
    expect(distant.id, greaterThan(0));
    expect(distant.titleText, contains('${distant.id + 1}店'));
    expect(distantUrls, contains('https://picsum.photos/seed/takeaway-shop-${distant.id}/160/160'));
    expect(distantUrls.intersection(initialUrls), isEmpty);
    expect(
      distantUrls.every(
        (url) => url.contains('takeaway-shop-${distant.id}/') || url.contains('takeaway-dish-${distant.id}-'),
      ),
      isTrue,
    );
    await _addVisibleDish(tester, distant);
    await tester.tap(find.byKey(ValueKey('takeaway-cart-clear')));
    await tester.pumpAndSettle();

    _vertical(tester).jumpTo(0);
    await tester.pumpAndSettle();
    final zero = _shops(tester).singleWhere((shop) => shop.id == 0);
    expect(_photoUrls(tester, zero), initialUrls);
    await tester.tap(find.byKey(ValueKey('takeaway-category-1')));
    await tester.pumpAndSettle();
    final filtered = _shops(tester).singleWhere((shop) => shop.id == 1);
    expect(_vertical(tester).offset, 0);
    expect(tester.widget<ElSliverRecyclerList>(find.byType(ElSliverRecyclerList)).itemCount, 1250);
    expect(filtered.slot, same(zero.slot), reason: '筛选发生在同一个位置 0，不能只靠序号数值变化刷新数据。');
    expect(filtered.title, same(zero.title));
    expect(filtered.titleText, contains('粉面'));
    expect(filtered.titleText, contains('2店'));
    final filteredUrls = _photoUrls(tester, filtered);
    expect(filteredUrls, contains('https://picsum.photos/seed/takeaway-shop-1/160/160'));
    expect(filteredUrls.intersection(initialUrls), isEmpty);
    await _addVisibleDish(tester, filtered);

    await tester.tap(find.byKey(ValueKey('takeaway-category--1')));
    await tester.pumpAndSettle();
    final restored = _shops(tester).singleWhere((shop) => shop.id == 0);
    expect(tester.widget<ElSliverRecyclerList>(find.byType(ElSliverRecyclerList)).itemCount, 10000);
    expect(restored.titleText, initial.titleText);
    expect(_photoUrls(tester, restored), initialUrls);
    await tester.tap(find.byKey(ValueKey('takeaway-cart-clear')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-count'))).child, '已选 0 份');
    expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-total'))).child, '¥0.0');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sliver 外卖页换店停止旧菜单活动，返回后恢复各自菜单位置', (tester) async {
    await _open(tester, TakeawaySliverPage());
    // 最后一个活跃槽会优先回收复用；菜单即使在卡片下半部，也已真实挂接和布局。
    final original = _shops(tester).last;
    final position = original.menu.position as ScrollPositionWithSingleContext;
    position.jumpTo(160);
    await tester.pump();
    position.goBallistic(900);
    await tester.pump(Duration(milliseconds: 16));
    expect(position.isScrollingNotifier.value, isTrue);
    final saved = position.pixels;
    expect(saved, greaterThan(100));

    _vertical(tester).jumpTo(20000);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final rebound = _shops(tester).singleWhere((shop) => identical(shop.slot, original.slot));
    expect(rebound.id, isNot(original.id));
    expect(rebound.menu, same(original.menu));
    expect(rebound.menu.position, same(position));
    expect(position.isScrollingNotifier.value, isFalse);
    expect(position.pixels, 0);
    await tester.pump(Duration(milliseconds: 200));
    expect(position.pixels, 0, reason: '旧商家的惯性不能继续推动新商家的菜单。');

    _vertical(tester).jumpTo(0);
    await tester.pumpAndSettle();
    final restored = _shops(tester).singleWhere((shop) => shop.id == original.id);
    expect(restored.titleText, original.titleText);
    expect(restored.menu.position.pixels, closeTo(saved, .1));
    expect(restored.menu.position.isScrollingNotifier.value, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
    await tester.pump(Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sliver 实际外卖页跨商家换绑保留卡片 Element、菜单 State 和 RenderObject', (tester) async {
    await _open(tester, TakeawaySliverPage());
    final before = {for (final shop in _shops(tester)) shop.slot: shop};
    expect(before, isNotEmpty);
    final signals = {for (final shop in before.values) shop.storeSignal};
    _vertical(tester).jumpTo(20000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rebound = _shops(tester)
        .where((shop) => before.containsKey(shop.slot) && before[shop.slot]!.id != shop.id)
        .toList();
    expect(rebound, isNotEmpty, reason: '必须真正让同一个 Sliver 槽位绑定另一家商店，不能只检查原商家的缓存。');

    for (final shop in rebound) {
      final previous = before[shop.slot]!;
      expect(shop.titleText, isNot(previous.titleText));
      expect(shop.titleText, contains('${shop.id + 1}店'));
      expect(shop.host, same(previous.host), reason: '换店不能因为商家 ID Key 而卸载整张业务卡片。');
      expect(shop.hostWidget, same(previous.hostWidget), reason: '滚动只切换数据绑定，不能重新创建外层 Host。');
      signals.add(shop.storeSignal);
      expect(shop.card, same(previous.card));
      expect(shop.cardWidget, same(previous.cardWidget), reason: '固定卡片外壳应保留原 Widget。');
      expect(shop.cardRender, same(previous.cardRender));
      expect(shop.titleElement, same(previous.titleElement));
      expect(shop.title, same(previous.title));
      expect(previous.logoRender, isNotNull);
      expect(previous.dishPhotoRender, isNotNull);
      expect(shop.logoRender, same(previous.logoRender));
      expect(shop.dishPhotoRender, same(previous.dishPhotoRender));
      expect(shop.storeSignal, same(previous.storeSignal));
      expect(shop.menu, same(previous.menu), reason: '横向菜单 State 必须跨商家复用。');
      expect(previous.card.mounted, isTrue);
    }

    await tester.pumpWidget(SizedBox.shrink());
    for (final signal in signals) {
      expect(() => ChangeNotifier.debugAssertNotDisposed(signal), throwsFlutterError);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('示例目录打开外卖页，并可换成网格', (tester) async {
    await _open(tester, ExamplesPage());
    expect(tester.widgetList<ElListGroup>(find.byType(ElListGroup)).map((group) => group.title), contains('新版滚动'));
    await tester.ensureVisible(find.byKey(ValueKey('advanced-sliver-takeaway')));
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
