import 'package:example/src/pages/examples.dart';
import 'package:example/src/pages/examples/catalog.dart';
import 'package:example/src/pages/examples/recycler_view/chat.dart';
import 'package:example/src/pages/examples/recycler_view/selection.dart';
import 'package:example/src/utils/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _open(WidgetTester tester, Widget page, {double width = 390}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
}

rv.RecyclerView _list(WidgetTester tester) => tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));

rv.LinearLayoutManager _layout(rv.RecyclerView list) => list.getLayoutManager()! as rv.LinearLayoutManager;

Set<rv.ViewHolder> _visibleHolders(rv.RecyclerView list) => {
  for (
    var position = _layout(list).findFirstVisibleItemPosition();
    position <= _layout(list).findLastVisibleItemPosition();
    position++
  )
    ?list.findViewHolderForAdapterPosition(position),
};

bool _checked(WidgetTester tester, int id) =>
    tester.widget<ElCheckbox>(find.byKey(ValueKey('selection-check-$id')).hitTestable()).value as bool;

Object? _latestLabel(WidgetTester tester) => tester.widget<ElButton>(find.byKey(ValueKey('chat-latest'))).child;

void main() {
  testWidgets('示例目录以 RecyclerView 分组展示两个入口，两端共用深度路由', (tester) async {
    await _open(tester, ExamplesPage());
    expect(find.byWidgetPredicate((widget) => widget is ElListGroup && widget.title == 'RecyclerView'), findsOneWidget);
    expect(find.byKey(ValueKey('advanced-recycler-selection')), findsOneWidget);
    expect(find.byKey(ValueKey('advanced-recycler-chat')), findsOneWidget);
    expect(recyclerExamples.map((page) => page.key), ['recycler-selection', 'recycler-chat']);
    expect(RouterUtil.exampleRoutes().map((route) => route.path), containsAll(['recycler-selection', 'recycler-chat']));

    await tester.ensureVisible(find.byKey(ValueKey('advanced-recycler-selection')));
    await tester.tap(find.byKey(ValueKey('advanced-recycler-selection')));
    await tester.pumpAndSettle();
    expect(find.byType(RecyclerSelectionPage), findsOneWidget);
    expect(_list(tester).getAdapter()!.getItemCount(), 10000);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ValueKey('advanced-recycler-chat')));
    await tester.tap(find.byKey(ValueKey('advanced-recycler-chat')));
    await tester.pumpAndSettle();
    expect(find.byType(RecyclerChatPage), findsOneWidget);
  });

  testWidgets('万条记录按需挂载，复用同一 holder 后复选状态不丢失也不串行', (tester) async {
    await _open(tester, RecyclerSelectionPage());
    final list = _list(tester);
    list.setItemViewCacheSize(0);
    _layout(list).setItemPrefetchEnabled(false);
    await tester.pumpAndSettle();
    expect(list.getAdapter()!.getItemCount(), 10000);
    expect(_layout(list).getChildCount(), lessThan(12));
    expect(find.byType(ElCheckbox).evaluate().length, lessThan(20));
    final initialHolders = _visibleHolders(list);

    await tester.tap(find.byKey(ValueKey('selection-check-0')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('selection-check-2')));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 / 10000'), findsOneWidget);
    expect(_checked(tester, 0), isTrue);
    expect(_checked(tester, 1), isFalse);

    await tester.tap(find.byKey(ValueKey('selection-last')));
    await tester.pumpAndSettle();
    expect(find.text('条目 10000').hitTestable(), findsOneWidget);
    expect(_checked(tester, 9999), isFalse);
    final rebound = initialHolders.intersection(_visibleHolders(list));
    expect(rebound, isNotEmpty, reason: '至少一个原首屏 holder 必须实际绑定到末端记录，验证跨数据项复用');
    expect(rebound.every((holder) => holder.getItemId() >= 9990), isTrue);
    await tester.tap(find.byKey(ValueKey('selection-check-9999')));
    await tester.pumpAndSettle();
    expect(find.text('已选 3 / 10000'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('selection-first')));
    await tester.pumpAndSettle();
    expect(_checked(tester, 0), isTrue);
    expect(_checked(tester, 1), isFalse);
    expect(_checked(tester, 2), isTrue);
    await tester.tap(find.byKey(ValueKey('selection-clear')));
    await tester.pumpAndSettle();
    expect(find.text('已选 0 / 10000'), findsOneWidget);
    expect(_checked(tester, 0), isFalse);
    await tester.tap(find.byKey(ValueKey('selection-last')));
    await tester.pumpAndSettle();
    expect(_checked(tester, 9999), isFalse, reason: '清空也应更新离屏记录的业务状态');
    expect(find.byType(ElCheckbox).evaluate().length, lessThan(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('两个 RecyclerView 页面都能通过共同路由直接打开', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final page in recyclerExamples) {
        if (width == 320 && page.key == 'recycler-chat') continue;
        final router = GoRouter(
          navigatorKey: RouterUtil.rootNavigatorKey,
          initialLocation: '/examples/${page.key}',
          routes: [
            GoRoute(path: '/examples', builder: (context, state) => ExamplesPage(), routes: RouterUtil.exampleRoutes()),
          ],
        );
        addTearDown(router.dispose);
        // 通过真实路由安装品牌预设，宽屏不能沿用测试辅助函数中的 mobileComponents。
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.byType(rv.RecyclerView), findsOneWidget);
        expect(_list(tester).getAdapter()!.getItemCount(), 10000);
        expect(
          find.byType(page.key == 'recycler-selection' ? RecyclerSelectionPage : RecyclerChatPage),
          findsOneWidget,
        );
        if (page.key == 'recycler-selection') {
          expect(_checked(tester, 0), isFalse);
          await tester.tap(find.byKey(ValueKey('selection-check-0')).hitTestable());
          await tester.pumpAndSettle();
          expect(_checked(tester, 0), isTrue, reason: '$width 宽度的品牌预设应能实际切换复选状态');
          expect(find.text('已选 1 / 10000'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(SizedBox());
      }
    }
  });

  testWidgets('索引定位使用不同记录的真实内容，越界输入安全夹紧', (tester) async {
    await _open(tester, RecyclerSelectionPage());
    await tester.enterText(find.byKey(ValueKey('selection-index-input')), '4321');
    await tester.tap(find.byKey(ValueKey('selection-locate')));
    await tester.pumpAndSettle();
    expect(find.text('条目 04321').hitTestable(), findsOneWidget);
    expect(_list(tester).findViewHolderForAdapterPosition(4320)!.getItemId(), 4320);
    await tester.enterText(find.byKey(ValueKey('selection-index-input')), '20000');
    await tester.tap(find.byKey(ValueKey('selection-locate')));
    await tester.pumpAndSettle();
    expect(find.text('条目 10000').hitTestable(), findsOneWidget);
    await tester.enterText(find.byKey(ValueKey('selection-index-input')), '无效');
    await tester.tap(find.byKey(ValueKey('selection-locate')));
    await tester.pumpAndSettle();
    expect(find.text('条目 10000').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天首屏从末端显示一万条变高消息，发送和收到新消息时跟随底部', (tester) async {
    await _open(tester, RecyclerChatPage());
    final list = _list(tester);
    expect(list.getAdapter()!.getItemCount(), 10000);
    expect(_layout(list).findLastVisibleItemPosition(), 9999);
    expect(_layout(list).getChildCount(), lessThan(12));
    expect(
      find.byWidgetPredicate((widget) => widget.key.toString().contains('chat-message-')).evaluate().length,
      lessThan(24),
    );
    final outgoing = list.findViewHolderForAdapterPosition(9999)!;
    final incoming = list.findViewHolderForAdapterPosition(9998)!;
    expect(outgoing.getItemViewType(), isNot(incoming.getItemViewType()));

    await tester.enterText(find.byKey(ValueKey('chat-composer')), '这是刚发送的一条独立消息');
    await tester.tap(find.byKey(ValueKey('chat-send')));
    await tester.pumpAndSettle();
    expect(list.getAdapter()!.getItemCount(), 10001);
    expect(_layout(list).findLastVisibleItemPosition(), 10000);
    expect(find.text('这是刚发送的一条独立消息').hitTestable(), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(ValueKey('chat-composer'))).controller!.text, isEmpty);
    expect(_latestLabel(tester), '最新消息');
    await tester.tap(find.byKey(ValueKey('chat-receive')));
    await tester.pumpAndSettle();
    expect(list.getAdapter()!.getItemCount(), 10002);
    expect(_layout(list).findLastVisibleItemPosition(), 10001);
    expect(find.byKey(ValueKey('chat-message-10001')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天阅读中插入历史和追加新消息均保留锚点，未读按钮可回到底部', (tester) async {
    await _open(tester, RecyclerChatPage());
    final list = _list(tester);
    final layout = _layout(list);
    layout.scrollToPositionWithOffset(4000, 20);
    await tester.pumpAndSettle();
    final anchor = list.findViewHolderForAdapterPosition(4000)!;
    final anchorId = anchor.getItemId();
    final before = tester.getTopLeft(find.byWidget(anchor.itemView)).dy;
    await tester.tap(find.byKey(ValueKey('chat-load-earlier')));
    await tester.pumpAndSettle();
    expect(list.getAdapter()!.getItemCount(), 10050);
    expect(list.findViewHolderForItemId(anchorId), same(anchor));
    expect(anchor.getBindingAdapterPosition(), 4050);
    expect(tester.getTopLeft(find.byWidget(anchor.itemView)).dy, closeTo(before, .1));

    await tester.tap(find.byKey(ValueKey('chat-receive')));
    await tester.pumpAndSettle();
    expect(list.getAdapter()!.getItemCount(), 10051);
    expect(_latestLabel(tester), '1 条新消息');
    expect(tester.getTopLeft(find.byWidget(anchor.itemView)).dy, closeTo(before, .1));
    expect(layout.findLastVisibleItemPosition(), lessThan(4100));
    await tester.tap(find.byKey(ValueKey('chat-receive')));
    await tester.pumpAndSettle();
    expect(_latestLabel(tester), '2 条新消息');
    await tester.tap(find.byKey(ValueKey('chat-latest')));
    await tester.pumpAndSettle();
    expect(layout.findLastVisibleItemPosition(), 10051);
    expect(_latestLabel(tester), '最新消息');
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天使用变高气泡，窄屏和桌面宽度均不溢出', (tester) async {
    for (final width in [320.0, 1000.0]) {
      await _open(tester, RecyclerChatPage(key: ValueKey(width)), width: width);
      final list = _list(tester);
      final holders = _visibleHolders(list);
      final heights = holders.map((holder) => tester.getSize(find.byWidget(holder.itemView)).height).toSet();
      expect(heights.length, greaterThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    }
  });
}
