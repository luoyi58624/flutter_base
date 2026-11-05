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
  for (var i = _layout(list).findFirstVisibleItemPosition(); i <= _layout(list).findLastVisibleItemPosition(); i++)
    ?list.findViewHolderForAdapterPosition(i),
};

Finder _check(WidgetTester tester, int id) {
  final title = find.text('条目 ${(id + 1).toString().padLeft(5, '0')}').hitTestable();
  final row = find.ancestor(of: title, matching: find.byType(Row)).first;
  return find.descendant(of: row, matching: find.byType(ElCheckbox));
}

bool _checked(WidgetTester tester, int id) {
  final checkbox = tester.widget<ElCheckbox>(_check(tester, id));
  return (checkbox.modelValue?.value ?? checkbox.value) as bool;
}

String _selected(WidgetTester tester) => tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data!;
String _latestLabel(WidgetTester tester) {
  final badge = tester.widget<Badge>(
    find.descendant(of: find.byKey(ValueKey('chat-menu')), matching: find.byType(Badge)),
  );
  return badge.isLabelVisible ? '${(badge.label! as Text).data} 条新消息' : '最新消息';
}

Future<void> _choose(WidgetTester tester, String page, String action) async {
  await tester.tap(find.byKey(ValueKey('$page-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('$page-$action')));
  await tester.pumpAndSettle();
}

Future<void> _locate(WidgetTester tester, String input) async {
  await _choose(tester, 'selection', 'locate-menu');
  await tester.enterText(find.byKey(ValueKey('selection-index-input')), input);
  await tester.tap(find.byKey(ValueKey('selection-locate')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('示例目录以 RecyclerView 分组展示四个入口，两端共用深度路由', (tester) async {
    await _open(tester, ExamplesPage());
    expect(find.byWidgetPredicate((w) => w is ElListGroup && w.title == 'RecyclerView'), findsOneWidget);
    expect(recyclerExamples.map((page) => page.key), [
      'recycler-text',
      'recycler-selection',
      'recycler-chat',
      'recycler-cards',
    ]);
    expect(
      RouterUtil.exampleRoutes().map((route) => route.path),
      containsAll(['recycler-text', 'recycler-selection', 'recycler-chat', 'recycler-cards']),
    );
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
    final list = _list(tester)..setItemViewCacheSize(0);
    _layout(list).setItemPrefetchEnabled(false);
    await tester.pumpAndSettle();
    expect(list.getAdapter()!.getItemCount(), 10000);
    expect(_layout(list).getChildCount(), lessThan(15));
    expect(find.byType(ElCheckbox).evaluate().length, lessThan(20));
    final initialHolders = _visibleHolders(list);
    await tester.tap(_check(tester, 0));
    await tester.pumpAndSettle();
    await tester.tap(_check(tester, 2));
    await tester.pumpAndSettle();
    expect(_selected(tester), '2 / 10000');
    expect(_checked(tester, 0), isTrue);
    expect(_checked(tester, 1), isFalse);
    await _choose(tester, 'selection', 'last');
    expect(find.text('条目 10000').hitTestable(), findsOneWidget);
    expect(_checked(tester, 9999), isFalse);
    final rebound = initialHolders.intersection(_visibleHolders(list));
    expect(rebound, isNotEmpty);
    expect(rebound.every((holder) => holder.getItemId() >= 9980), isTrue);
    await tester.tap(_check(tester, 9999));
    await tester.pumpAndSettle();
    expect(_selected(tester), '3 / 10000');
    await _choose(tester, 'selection', 'first');
    expect(_checked(tester, 0), isTrue);
    expect(_checked(tester, 2), isTrue);
    await _choose(tester, 'selection', 'clear');
    expect(_selected(tester), '0 / 10000');
    expect(_checked(tester, 0), isFalse);
    await _choose(tester, 'selection', 'last');
    expect(_checked(tester, 9999), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('四个页面通过真实两端品牌路由打开，窄屏选框可交互', (tester) async {
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
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.byType(rv.RecyclerView), findsOneWidget);
        expect(_list(tester).getAdapter()!.getItemCount(), 10000);
        if (page.key == 'recycler-selection') {
          expect(_checked(tester, 0), isFalse);
          await tester.tap(_check(tester, 0));
          await tester.pumpAndSettle();
          expect(_checked(tester, 0), isTrue);
          expect(_selected(tester), '1 / 10000');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(SizedBox());
      }
    }
  });

  testWidgets('序号定位通过菜单弹窗完成，越界夹紧且无效输入不改变列表', (tester) async {
    await _open(tester, RecyclerSelectionPage());
    await _locate(tester, '4321');
    expect(find.text('条目 04321').hitTestable(), findsOneWidget);
    expect(_list(tester).findViewHolderForAdapterPosition(4320)!.getItemId(), 4320);
    await _locate(tester, '20000');
    expect(find.text('条目 10000').hitTestable(), findsOneWidget);
    await _locate(tester, '无效');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('条目 10000').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天首屏从末端显示一万条变高消息，发送和接收时跟随底部', (tester) async {
    await _open(tester, RecyclerChatPage());
    final list = _list(tester);
    expect(list.getAdapter()!.getItemCount(), 10000);
    expect(_layout(list).findLastVisibleItemPosition(), 9999);
    expect(_layout(list).getChildCount(), lessThan(15));
    expect(
      list.findViewHolderForAdapterPosition(9999)!.getItemViewType(),
      isNot(list.findViewHolderForAdapterPosition(9998)!.getItemViewType()),
    );
    await tester.enterText(find.byKey(ValueKey('chat-composer')), '这是刚发送的一条独立消息');
    await tester.tap(find.byKey(ValueKey('chat-send')));
    await tester.pumpAndSettle();
    expect(list.getAdapter()!.getItemCount(), 10001);
    expect(_layout(list).findLastVisibleItemPosition(), 10000);
    expect(find.text('这是刚发送的一条独立消息').hitTestable(), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(ValueKey('chat-composer'))).controller!.text, isEmpty);
    expect(_latestLabel(tester), '最新消息');
    await _choose(tester, 'chat', 'receive');
    expect(list.getAdapter()!.getItemCount(), 10002);
    expect(_layout(list).findLastVisibleItemPosition(), 10001);
    expect(list.findViewHolderForItemId(10001), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天阅读中插入历史和追加消息均保留锚点，菜单可回到底部', (tester) async {
    await _open(tester, RecyclerChatPage());
    final list = _list(tester);
    final layout = _layout(list);
    layout.scrollToPositionWithOffset(4000, 20);
    await tester.pumpAndSettle();
    final anchor = list.findViewHolderForAdapterPosition(4000)!;
    final id = anchor.getItemId();
    final before = tester.getTopLeft(find.byWidget(anchor.itemView)).dy;
    await _choose(tester, 'chat', 'load-earlier');
    expect(list.getAdapter()!.getItemCount(), 10050);
    expect(list.findViewHolderForItemId(id), same(anchor));
    expect(anchor.getBindingAdapterPosition(), 4050);
    expect(tester.getTopLeft(find.byWidget(anchor.itemView)).dy, closeTo(before, .1));
    await _choose(tester, 'chat', 'receive');
    expect(_latestLabel(tester), '1 条新消息');
    expect(tester.getTopLeft(find.byWidget(anchor.itemView)).dy, closeTo(before, .1));
    await _choose(tester, 'chat', 'receive');
    expect(_latestLabel(tester), '2 条新消息');
    await _choose(tester, 'chat', 'latest');
    expect(layout.findLastVisibleItemPosition(), 10051);
    expect(_latestLabel(tester), '最新消息');
    expect(tester.takeException(), isNull);
  });

  testWidgets('大工具栏已移入导航菜单，列表获得主要高度且变高气泡在宽窄屏不溢出', (tester) async {
    await _open(tester, RecyclerSelectionPage());
    expect(tester.getSize(find.byType(rv.RecyclerView)).height, greaterThan(740));
    expect(find.byKey(ValueKey('selection-first')), findsNothing);
    for (final width in [320.0, 1000.0]) {
      await _open(tester, RecyclerChatPage(key: ValueKey(width)), width: width);
      expect(tester.getSize(find.byType(rv.RecyclerView)).height, greaterThan(650));
      final heights = _visibleHolders(_list(tester))
          .map((h) => tester.getSize(find.byWidget(h.itemView)).height)
          .toSet();
      expect(heights.length, greaterThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    }
  });

  testWidgets('复选菜单切换真实 ListView 和 RecyclerView 时保持同一万条数据与选择状态', (tester) async {
    await _open(tester, RecyclerSelectionPage());
    await tester.tap(_check(tester, 0));
    await tester.pumpAndSettle();
    await _choose(tester, 'selection', 'mode-listView');
    expect(find.byType(rv.RecyclerView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.widget<ListView>(find.byType(ListView)).childrenDelegate.estimatedChildCount, 10000);
    expect(_checked(tester, 0), isTrue);
    await tester.tap(_check(tester, 1));
    await tester.pumpAndSettle();
    expect(_selected(tester), '2 / 10000');
    await _choose(tester, 'selection', 'last');
    expect(find.text('条目 10000').hitTestable(), findsOneWidget);
    await _locate(tester, '4321');
    expect(find.text('条目 04321').hitTestable(), findsOneWidget);
    await _choose(tester, 'selection', 'mode-recyclerView');
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(rv.RecyclerView), findsOneWidget);
    expect(_checked(tester, 0), isTrue);
    expect(_checked(tester, 1), isTrue);
    expect(_selected(tester), '2 / 10000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天切换容器保留真实新增消息，官方列表发送和接收同样跟随底部', (tester) async {
    await _open(tester, RecyclerChatPage());
    await tester.enterText(find.byKey(ValueKey('chat-composer')), 'RV发出的消息');
    await tester.tap(find.byKey(ValueKey('chat-send')));
    await tester.pumpAndSettle();
    await _choose(tester, 'chat', 'mode-listView');
    expect(find.byType(rv.RecyclerView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('RV发出的消息').hitTestable(), findsOneWidget);
    await tester.enterText(find.byKey(ValueKey('chat-composer')), 'ListView发出的消息');
    await tester.tap(find.byKey(ValueKey('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('ListView发出的消息').hitTestable(), findsOneWidget);
    expect(tester.widget<ListView>(find.byType(ListView)).controller!.offset, closeTo(0, .01));
    await _choose(tester, 'chat', 'receive');
    expect(tester.widget<Text>(find.byKey(ValueKey('chat-count'))).data, '10003 条');
    await _choose(tester, 'chat', 'mode-recyclerView');
    expect(_list(tester).getAdapter()!.getItemCount(), 10003);
    expect(_layout(_list(tester)).findLastVisibleItemPosition(), 10002);
    expect(tester.takeException(), isNull);
  });

  testWidgets('官方聊天阅读旧消息时加载历史和接收消息均保持实际文本位置', (tester) async {
    await _open(tester, RecyclerChatPage());
    await _choose(tester, 'chat', 'mode-listView');
    final controller = tester.widget<ListView>(find.byType(ListView)).controller!;
    controller.jumpTo(750);
    await tester.pumpAndSettle();
    final textFinder = find
        .byWidgetPredicate((w) => w is Text && (w.data?.startsWith('消息 #') ?? false))
        .hitTestable()
        .first;
    final text = tester.widget<Text>(textFinder).data!;
    final before = tester.getTopLeft(find.text(text)).dy;
    await _choose(tester, 'chat', 'load-earlier');
    expect(tester.widget<Text>(find.byKey(ValueKey('chat-count'))).data, '10050 条');
    expect(tester.getTopLeft(find.text(text)).dy, closeTo(before, .1));
    await _choose(tester, 'chat', 'receive');
    expect(_latestLabel(tester), '1 条新消息');
    expect(tester.getTopLeft(find.text(text)).dy, closeTo(before, .1));
    await _choose(tester, 'chat', 'latest');
    expect(controller.offset, closeTo(0, .01));
    expect(_latestLabel(tester), '最新消息');
    expect(tester.takeException(), isNull);
  });
}
