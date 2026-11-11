import 'package:example/src/pages/examples/bibi/index.dart';
import 'package:example/src/pages/examples/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/src/widgets/panel.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _inFeed(Finder matching, {int index = 1}) => find.descendant(of: _key('bibi-feed-$index'), matching: matching);

Future<void> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(390, 844), viewPadding: EdgeInsets.only(top: 24, bottom: 16)),
        child: BibiPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ElScroll _feed(WidgetTester tester, {int index = 1}) =>
    tester.widget<ElScroll>(_inFeed(find.byType(ElScroll), index: index));

Key? _rowsKey(WidgetTester tester) => tester.widget<SliverList>(_inFeed(find.byType(SliverList))).key;

double _body(WidgetTester tester, {int index = 1}) => _feed(tester, index: index).controller!.offset;
double _tabsY(WidgetTester tester) => tester.getTopLeft(_key('bibi-tabs')).dy;

ElTabController _pager(WidgetTester tester) => tester.widget<ElTabView>(_key('bibi-pager')).controller!;

Future<TestGesture> _holdDrag(WidgetTester tester, Offset origin, Offset first, Offset second) async {
  final gesture = await tester.startGesture(origin);
  await gesture.moveBy(first, timeStamp: Duration(milliseconds: 70));
  await tester.pump(Duration(milliseconds: 70));
  await gesture.moveBy(second, timeStamp: Duration(milliseconds: 150));
  await tester.pump(Duration(milliseconds: 150));
  return gesture;
}

Future<void> _releaseHeld(WidgetTester tester, TestGesture gesture) async {
  await tester.pump(Duration(milliseconds: 200));
  await gesture.up(timeStamp: Duration(milliseconds: 350));
  await tester.pump();
}

void main() {
  testWidgets('示例目录生成可单独打开并返回的 Bibi 首页', (tester) async {
    final entry = advancedExamples.singleWhere((example) => example.key == 'bibi-home');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: entry.data!)),
            child: Text(entry.title),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Bibi 首页'));
    await tester.pumpAndSettle();
    expect(find.byType(BibiPage), findsOneWidget);
    expect(_pager(tester).length, 10);
    await tester.tap(find.text('我的').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(BibiPage), findsNothing);
  });

  testWidgets('慢拖只移动页头，50% 吸附且轻点不会取消吸附', (tester) async {
    await _open(tester);
    final expanded = _tabsY(tester);
    final short = await _holdDrag(tester, Offset(195, 580), Offset(0, -19), Offset(0, -8));
    expect(expanded - _tabsY(tester), inInclusiveRange(0.1, 28.99));
    expect(_body(tester), 0);
    await _releaseHeld(tester, short);
    await tester.pumpAndSettle();
    expect(_tabsY(tester), expanded);

    final long = await _holdDrag(tester, Offset(195, 580), Offset(0, -23), Offset(0, -32));
    expect(expanded - _tabsY(tester), inInclusiveRange(29, 57.99));
    expect(_body(tester), 0);
    await _releaseHeld(tester, long);
    await tester.pump(Duration(milliseconds: 16));
    await tester.tapAt(Offset(195, 580));
    await tester.pumpAndSettle();
    expect(_tabsY(tester), expanded - 58);
    expect(_body(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('短甩让同一次惯性跨过折叠边界并继续移动列表', (tester) async {
    await _open(tester);
    final expanded = _tabsY(tester);
    final gesture = await tester.startGesture(Offset(195, 580));
    // 约 36ms 的 42px 短甩，用接近触屏采样率的真实指针事件。
    for (var i = 1; i <= 6; i++) {
      await gesture.moveBy(Offset(0, -7), timeStamp: Duration(milliseconds: i * 6));
      await tester.pump(Duration(milliseconds: 6));
    }
    expect(expanded - _tabsY(tester), inInclusiveRange(0.1, 42));
    expect(_body(tester), 0);
    await gesture.up(timeStamp: Duration(milliseconds: 40));
    var sawBoundaryRemainder = false;
    for (var frame = 0; frame < 70; frame++) {
      final before = _tabsY(tester);
      await tester.pump(Duration(milliseconds: 8));
      if (_body(tester) > 0.01) {
        expect(_tabsY(tester), closeTo(expanded - 58, 0.01));
        if (before > expanded - 58 + 0.01) sawBoundaryRemainder = true;
      }
    }
    expect(_body(tester), greaterThan(58));
    expect(sawBoundaryRemainder, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('下拉反向撤销或取消手势，均不会触发刷新', (tester) async {
    await _open(tester);
    final first = await _holdDrag(tester, Offset(195, 420), Offset(0, 90), Offset(0, 150));
    expect(_body(tester), 0);
    await first.moveBy(Offset(0, -200), timeStamp: Duration(milliseconds: 230));
    await tester.pump();
    await first.up(timeStamp: Duration(milliseconds: 440));
    await tester.pumpAndSettle();
    expect(_rowsKey(tester), ValueKey('bibi-rows-0'));

    // 完全回收后的剩余反向位移会滚动正文，下一次取消测试先恢复到顶部。
    await tester.tap(find.text('首页').hitTestable());
    await tester.pumpAndSettle();
    final canceled = await _holdDrag(tester, Offset(195, 420), Offset(0, 90), Offset(0, 150));
    await canceled.cancel();
    await tester.pumpAndSettle();
    expect(_rowsKey(tester), ValueKey('bibi-rows-0'));
  });

  testWidgets('刷新中离开顶部会收起圆盘，回到顶部后才应用结果', (tester) async {
    await _open(tester);
    final pull = await _holdDrag(tester, Offset(195, 420), Offset(0, 90), Offset(0, 150));
    await _releaseHeld(tester, pull);
    await tester.flingFrom(Offset(195, 590), Offset(0, -160), 1800);
    await tester.pump(Duration(milliseconds: 200));
    final indicator = tester.widget<AnimatedOpacity>(_inFeed(_key('bibi-refresh-indicator')));
    expect(indicator.opacity, 0);
    await tester.pumpAndSettle();
    expect(_body(tester), greaterThan(0));
    expect(_rowsKey(tester), ValueKey('bibi-rows-0'));
    await tester.tap(find.text('首页').hitTestable());
    await tester.pumpAndSettle();
    expect(_body(tester), 0);
    expect(_rowsKey(tester), ValueKey('bibi-rows-1'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('退出页面会取消仍按着的刷新手势', (tester) async {
    await _open(tester);
    final pull = await _holdDrag(tester, Offset(195, 420), Offset(0, 90), Offset(0, 150));
    await tester.pumpWidget(SizedBox());
    await pull.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('轮播先消费横滑，从轮播首端向外滑才交给频道分页', (tester) async {
    await _open(tester);
    final banner = _inFeed(_key('bibi-banner'));
    final center = tester.getCenter(banner);
    await tester.flingFrom(center, Offset(-140, 0), 900);
    await tester.pumpAndSettle();
    expect(_pager(tester).index, 1);
    final inner = tester.widget<ElTabView>(find.descendant(of: banner, matching: find.byType(ElTabView))).controller!;
    expect(inner.index, 1);

    await tester.flingFrom(center, Offset(140, 0), 900);
    await tester.pumpAndSettle();
    expect(inner.index, 0);
    expect(_pager(tester).index, 1);

    await tester.flingFrom(center, Offset(140, 0), 900);
    await tester.pumpAndSettle();
    expect(_pager(tester).index, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('卡片区跟手横移并在换频道后保持纵向位置', (tester) async {
    await _open(tester);
    final host = _inFeed(find.byType(ElScroll));
    final cards = find.descendant(of: _inFeed(_key('bibi-row-0')), matching: find.byType(ExamplePanel));
    expect(cards, findsNWidgets(2));
    final boundaries = find.descendant(
      of: host,
      matching: find.byWidgetPredicate((widget) => widget is RepaintBoundary),
    );
    final firstBoundary = find.ancestor(of: cards.at(0), matching: boundaries);
    final secondBoundary = find.ancestor(of: cards.at(1), matching: boundaries);
    expect(firstBoundary, findsOneWidget);
    expect(secondBoundary, findsOneWidget);
    expect(tester.element(firstBoundary), isNot(same(tester.element(secondBoundary))));

    final expanded = _tabsY(tester);
    await tester.flingFrom(Offset(195, 600), Offset(0, -240), 800);
    await tester.pumpAndSettle();
    final offset = _body(tester);
    expect(offset, greaterThan(0));
    final gesture = await _holdDrag(tester, Offset(300, 540), Offset(-55, 0), Offset(-180, 0));
    expect(_pager(tester).position, inInclusiveRange(1.01, 1.99));
    expect(_tabsY(tester), expanded - 58);
    await _releaseHeld(tester, gesture);
    await tester.pumpAndSettle();
    expect(_pager(tester).index, 2);
    expect(_body(tester, index: 2), closeTo(offset, 0.01));
  });

  testWidgets('末尾频道仅因频道栏横拖而移动，展开时随菜单边界回位', (tester) async {
    await _open(tester);
    await tester.tap(_key('bibi-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生活').hitTestable().last);
    await tester.pumpAndSettle();
    expect(_pager(tester).index, 9);
    final tab = _key('bibi-channel-5');
    final initial = tester.getTopLeft(tab).dx;
    await tester.flingFrom(Offset(195, 600), Offset(0, -180), 900);
    await tester.pumpAndSettle();
    expect(_body(tester, index: 9), greaterThan(0));
    expect(tester.getTopLeft(tab).dx, closeTo(initial, 0.01));
    final tabs = tester.getRect(_key('bibi-tabs'));
    await tester.flingFrom(Offset(260, tabs.center.dy), Offset(-160, 0), 850);
    await tester.pumpAndSettle();
    final revealed = tester.getTopLeft(tab).dx;
    expect(revealed, closeTo(initial - 40, 1));
    final menuX = tester.getTopLeft(_key('bibi-menu')).dx;
    final reverse = await _holdDrag(tester, Offset(195, 540), Offset(0, 19), Offset(0, 7));
    final tabMove = tester.getTopLeft(tab).dx - revealed;
    expect(tabMove, greaterThan(0));
    expect(tabMove, lessThan(40));
    expect(tabMove, closeTo(tester.getTopLeft(_key('bibi-menu')).dx - menuX, 1));
    await _releaseHeld(tester, reverse);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
