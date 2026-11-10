import 'package:example/src/mobile/app.dart';
import 'package:example/src/pages/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ElExampleApp(networkDelay: Duration.zero, replyDelay: Duration.zero));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('推荐列表追加内容后可刷新回首批数据', (tester) async {
    await _open(tester);
    final home = find.byKey(PageStorageKey('home-list'));
    int count() => _itemCount(tester, home);
    final initial = count();
    await tester.drag(home, Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(count(), greaterThan(initial));
    tester.widget<ElRefresh>(find.ancestor(of: home, matching: find.byType(ElRefresh)).first).onRefresh();
    await tester.pump(Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(count(), initial);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('四栏使用移动主题并在我的保留旧示例入口', (tester) async {
    await _open(tester);
    expect(find.byType(ElComponentProvider), findsOneWidget);
    expect(find.byType(ElScroll), findsWidgets);
    for (final tab in ['分类', '消息', '我的']) {
      await tester.tap(find.byKey(ValueKey('tab-$tab')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('page-$tab')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(ValueKey('setting-组件示例')));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('tab-我的')), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('推荐详情与分类定位使用新滚动容器', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(ValueKey('article-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('detail-title')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('tab-分类')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('category-3')));
    await tester.pumpAndSettle();
    final scroll = _scrollable(tester, find.byKey(ValueKey('category-list')));
    expect(scroll.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('聊天发送后追加回复，反向列表保持贴底', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(ValueKey('tab-消息')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('message-0')));
    await tester.pumpAndSettle();
    final input = tester.widget<ElEditableView>(find.byKey(ValueKey('chat-input')));
    final chat = find.byKey(ValueKey('chat-list'));
    final count = _itemCount(tester, chat);
    input.controller!.text = '测试消息';
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('send-message')));
    await tester.pumpAndSettle();
    expect(input.controller!.text, isEmpty);
    expect(tester.widget<ElScroll>(chat).reverse, isTrue);
    expect(_itemCount(tester, chat), count + 2);
    expect(_scrollable(tester, chat).position.pixels, closeTo(0, 0.1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}

/// 读取 [host] 内最近的官方滚动状态。
ScrollableState _scrollable(WidgetTester tester, Finder host) =>
    tester.state<ScrollableState>(find.descendant(of: host, matching: find.byType(Scrollable)).first);

/// 读取 [host] 内官方回收列表声明的条目数量。
int _itemCount(WidgetTester tester, Finder host) {
  final list = tester.widget<SliverList>(find.descendant(of: host, matching: find.byType(SliverList)));
  return (list.delegate as SliverChildBuilderDelegate).childCount!;
}
