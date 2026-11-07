import 'package:example/src/pages/examples/recycler_view/orders.dart';
import 'package:example/src/pages/examples/recycler_view/scroll_mode.dart';
import 'package:example/src/pages/examples/recycler_view/social_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _open(WidgetTester tester, Widget page, {double width = 390, double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        home: page,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

rv.RecyclerView _recycler(WidgetTester tester) => tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));

Future<void> _mode(WidgetTester tester, RecyclerExampleScrollMode mode) async {
  await _tap(tester, _key('comparison-mode-menu'));
  await _tap(tester, _key('comparison-mode-${mode.name}'));
}

Finder _socialCard(int id) => find
    .ancestor(
      of: find.byWidgetPredicate((widget) => widget is Text && widget.data?.endsWith(' · 动态 #${id + 1}') == true),
      matching: _key('social-post-card'),
    )
    .hitTestable();

Finder _orderCard(int id) => find.ancestor(of: find.text('订单 #$id'), matching: _key('orders-card')).hitTestable();

Finder _within(Finder card, Finder child) => find.descendant(of: card, matching: child);

String _summary(WidgetTester tester) => tester.widget<Text>(_key('orders-summary')).data!;

void main() {
  testWidgets('动态流在真实变高、九宫格和投票之间复用，三种模式共享记录状态', (tester) async {
    await _open(tester, RecyclerSocialFeedPage());
    final list = _recycler(tester)..setItemViewCacheSize(0);
    final adapter = list.getAdapter()!;
    final layout = list.getLayoutManager()! as rv.LinearLayoutManager;
    layout.setItemPrefetchEnabled(false);
    await tester.pumpAndSettle();
    expect(adapter.getItemCount(), 10000);
    expect([for (var i = 0; i < 4; i++) adapter.getItemViewType(i)], [0, 1, 2, 3]);

    final article = _socialCard(0);
    final height = tester.getSize(article).height;
    await _tap(tester, _within(article, _key('social-expand')));
    expect(tester.getSize(article).height, greaterThan(height));
    await _tap(tester, _within(article, _key('social-like')));

    list.scrollToPosition(1);
    await tester.pumpAndSettle();
    expect(_within(_socialCard(1), find.byType(Image)), findsNWidgets(9));
    list.scrollToPosition(3);
    await tester.pumpAndSettle();
    await _tap(tester, _within(_socialCard(3), _key('social-vote-0')));
    expect(_within(_socialCard(3), find.text('河边慢走 · 39 票')), findsOneWidget);
    list.scrollToPosition(1000);
    await tester.pumpAndSettle();
    expect(layout.getChildCount(), lessThan(20));
    list.scrollToPosition(3);
    await tester.pumpAndSettle();
    expect(_within(_socialCard(3), find.text('河边慢走 · 39 票')), findsOneWidget);

    for (final mode in [RecyclerExampleScrollMode.listView, RecyclerExampleScrollMode.elScrollView]) {
      await _mode(tester, mode);
      expect(find.byType(rv.RecyclerView), findsNothing);
      expect(_key(mode == .listView ? 'comparison-official-list' : 'comparison-el-list'), findsOneWidget);
      expect(_within(article, find.text('收起长文')), findsOneWidget);
      expect(_within(article, find.byIcon(Icons.favorite_rounded)), findsOneWidget);
    }
    await _mode(tester, .recyclerView);
    expect(_within(article, find.text('收起长文')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('万条订单的定向更新保留卡片，三种真实容器头部增删后保留阅读行', (tester) async {
    await _open(tester, RecyclerOrdersPage());
    final list = _recycler(tester);
    final first = _orderCard(10000);
    final firstElement = tester.element(first);
    final progress = _within(first, find.byType(LinearProgressIndicator));
    final initialProgress = tester.widget<LinearProgressIndicator>(progress).value!;
    await _tap(tester, _within(first, _key('orders-select')));
    await _tap(tester, _key('orders-update'));
    expect(_summary(tester), '共 10000 单 · 已选 1 单 · 已更新 1 批');
    expect(tester.widget<LinearProgressIndicator>(progress).value, closeTo(initialProgress + .11, .001));
    expect(tester.element(first), same(firstElement));

    for (final mode in RecyclerExampleScrollMode.values.reversed) {
      if (mode != .recyclerView) await _mode(tester, mode);
      expect(tester.widget<Checkbox>(_within(first, _key('orders-select'))).value, isTrue);
      expect(tester.widget<LinearProgressIndicator>(progress).value, closeTo(initialProgress + .11, .001));
      final controller = switch (mode) {
        .recyclerView => list.controller!,
        .listView => tester.widget<ListView>(_key('comparison-official-list')).controller!,
        .elScrollView => tester.widget<ElScrollView>(_key('comparison-el-list')).controller!,
      };
      controller.jumpTo(64 * 128 + 24.0);
      await tester.pumpAndSettle();
      final anchor = _orderCard(9936);
      final top = tester.getTopLeft(anchor).dy;
      await _tap(tester, _key('orders-insert'));
      expect(_summary(tester), '共 10024 单 · 已选 1 单 · 已更新 1 批');
      expect(tester.getTopLeft(anchor).dy, closeTo(top, .5));
      await _tap(tester, _key('orders-remove'));
      expect(_summary(tester), '共 10000 单 · 已选 1 单 · 已更新 1 批');
      expect(tester.getTopLeft(anchor).dy, closeTo(top, .5));
    }

    await _mode(tester, .recyclerView);
    await _tap(tester, _key('orders-remove'));
    expect(_summary(tester), '共 9976 单 · 已选 0 单 · 已更新 1 批');
    expect(tester.takeException(), isNull);
  });

  testWidgets('订单压力跑固定 32 批并随滚动窗口推进，结束后不再继续', (tester) async {
    await _open(tester, RecyclerOrdersPage());
    final list = _recycler(tester);
    list.scrollToPosition(400);
    await tester.pumpAndSettle();
    final row = _orderCard(9600);
    final progress = _within(row, find.byType(LinearProgressIndicator));
    final previous = tester.widget<LinearProgressIndicator>(progress).value!;
    await tester.tap(_key('orders-live'));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 250));
    expect(tester.widget<LinearProgressIndicator>(progress).value, isNot(previous));
    expect(_summary(tester), '共 10000 单 · 已选 0 单 · 已更新 1 批');
    await tester.pump(Duration(milliseconds: 7750));
    await tester.pumpAndSettle();
    expect(find.text('实时更新 8 秒'), findsOneWidget);
    expect(_summary(tester), '共 10000 单 · 已选 0 单 · 已更新 32 批');
    await tester.pump(Duration(seconds: 1));
    expect(_summary(tester), '共 10000 单 · 已选 0 单 · 已更新 32 批');
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏动态流与窄屏大字订单保留可操作的内容区域', (tester) async {
    await _open(tester, RecyclerSocialFeedPage(), width: 1100);
    expect(tester.getSize(find.byType(rv.RecyclerView)).width, 760);
    expect(_within(_socialCard(0), _key('social-expand')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _open(tester, RecyclerOrdersPage(), width: 320, textScale: 1.6);
    expect(_within(_orderCard(10000), _key('orders-select')).hitTestable(), findsOneWidget);
    await _tap(tester, _key('orders-update'));
    expect(_summary(tester), '共 10000 单 · 已选 0 单 · 已更新 1 批');
    expect(tester.takeException(), isNull);
  });
}
