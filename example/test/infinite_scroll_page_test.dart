import 'package:example/src/pages/components/advanced/infinite_scroll/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _finishRequest(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('无限滚动演示可下拉刷新、切换网格和空态、重试失败页', variant: TargetPlatformVariant({TargetPlatform.android}), (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(320, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(scrollBehavior: ElScrollBehavior(), home: InfiniteScrollPage()),
      ),
    );
    await _finishRequest(tester);

    final demo = find.byWidgetPredicate((widget) => widget is ElInfiniteScroll);
    final scrollable = find.descendant(of: demo, matching: find.byType(Scrollable));
    ScrollPosition position() => tester.state<ScrollableState>(scrollable).position;
    expect(find.text('商品 1 · 陶瓷马克杯'), findsOneWidget);

    final pull = await tester.startGesture(tester.getTopLeft(demo) + Offset(120, 72));
    await pull.moveBy(Offset(0, 35));
    await tester.pump();
    await pull.moveBy(Offset(0, 200));
    await tester.pump();
    await pull.up();
    await _finishRequest(tester);
    expect(find.text('商品 1 · 亚麻收纳袋'), findsOneWidget);

    position().jumpTo(position().maxScrollExtent);
    await tester.pump();
    await tester.pump();
    position().jumpTo(position().maxScrollExtent);
    await tester.pump();
    expect(find.text('正在加载商品…'), findsOneWidget);
    await _finishRequest(tester);
    expect(find.text('商品 13 · 亚麻收纳袋'), findsOneWidget);

    await tester.tap(find.text('网格'));
    await _finishRequest(tester);
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('商品 13 · 亚麻收纳袋'), findsOneWidget);

    await tester.tap(find.text('空数据'));
    await _finishRequest(tester);
    expect(find.text('暂无商品，可以下拉刷新。'), findsOneWidget);

    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模拟失败'));
    await _finishRequest(tester);
    position().jumpTo(position().maxScrollExtent);
    await _finishRequest(tester);
    position().jumpTo(position().maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载失败，点击重试'));
    await _finishRequest(tester);
    expect(find.text('商品 13 · 陶瓷马克杯'), findsOneWidget);
    expect(find.text('加载失败，点击重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
