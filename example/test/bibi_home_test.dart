import 'dart:ui' as ui;

import 'package:example/src/pages/examples/bibi/index.dart';
import 'package:example/src/pages/examples/index.dart';
import 'package:example/src/pages/examples/new_bibi_collapse/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/src/widgets/panel.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _inFeed(Finder matching, {int index = 1}) => find.descendant(of: _key('bibi-feed-$index'), matching: matching);

Future<void> _open(WidgetTester tester, {bool waitForData = true}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  tester.view.viewPadding = FakeViewPadding(top: 24, bottom: 16);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewPadding);
  await tester.pumpWidget(MaterialApp(home: BibiPage()));
  if (waitForData) await _finishInitialLoad(tester);
}

Future<void> _finishInitialLoad(WidgetTester tester) async {
  await tester.pump(Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

ElScrollView _feed(WidgetTester tester, {int index = 1}) =>
    tester.widget<ElScrollView>(_inFeed(find.byType(ElScrollView), index: index));

Finder _cards({int index = 1}) => _inFeed(find.byWidgetPredicate((widget) => widget is ElSliverList), index: index);
Key? _cardsKey(WidgetTester tester) => tester.widget(_cards()).key;

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
  for (final (name, page, tabs) in [
    ('Bibi 首页', BibiPage(), _key('bibi-tabs')),
    ('新版折叠 Bibi', NewBibiCollapsePage(), _key('bibi-collapse-channels')),
  ]) {
    testWidgets('$name 搜索栏可滑进状态栏区域，频道栏停在安全线下方', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = Size(780, 1688);
      tester.view.viewPadding = FakeViewPadding(top: 64);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewPadding);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery.removeViewPadding(
              context: context,
              removeTop: true,
              child: RepaintBoundary(key: boundaryKey, child: page),
            ),
          ),
        ),
      );
      await _finishInitialLoad(tester);

      Future<int> statusBarPixel() async => (await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          // 搜索栏左侧按钮在半折叠时经过这个点。
          return bytes.getUint8((24 * image.width + 32) * 4);
        } finally {
          image.dispose();
        }
      }))!;

      expect(tester.getTopLeft(tabs).dy, 32 + 58);
      expect(await statusBarPixel(), 255);

      final gesture = await tester.startGesture(Offset(195, 580));
      // 先越过拖动识别阈值，再让搜索栏移动到状态栏区域。
      await gesture.moveBy(Offset(0, -19));
      await tester.pump();
      await gesture.moveBy(Offset(0, -32));
      await tester.pump();
      expect(tester.getTopLeft(tabs).dy, inExclusiveRange(32, 60));
      expect(await statusBarPixel(), lessThan(255), reason: '折叠中的按钮应实际画到状态栏区域');

      await gesture.moveBy(Offset(0, -38));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(tabs).dy, 32);
      expect(await statusBarPixel(), 255);

      tester.view.viewPadding = FakeViewPadding(top: 80);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(tabs).dy, 40);
      expect(tester.takeException(), isNull);
    });
  }

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
    expect(_inFeed(find.byType(SliverPersistentHeader)), findsOneWidget);
    await tester.tap(find.text('我的').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(BibiPage), findsNothing);
  });

  testWidgets('慢拖只移动页头，按住不动时按 50% 吸附', (tester) async {
    await _open(tester);
    final expanded = _tabsY(tester);
    final short = await _holdDrag(tester, Offset(195, 580), Offset(0, -19), Offset(0, -8));
    expect(expanded - _tabsY(tester), inInclusiveRange(0.1, 28.99));
    expect(_body(tester), 0);
    await tester.pump(Duration(milliseconds: 160));
    await tester.pumpAndSettle();
    expect(_tabsY(tester), expanded);
    await short.up(timeStamp: Duration(milliseconds: 350));
    await tester.pump();

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
    expect(_cardsKey(tester), ValueKey('bibi-cards-0'));

    // 完全回收后的剩余反向位移会滚动正文，下一次取消测试先恢复到顶部。
    await tester.tap(find.text('首页').hitTestable());
    await tester.pumpAndSettle();
    final canceled = await _holdDrag(tester, Offset(195, 420), Offset(0, 90), Offset(0, 150));
    await canceled.cancel();
    await tester.pumpAndSettle();
    expect(_cardsKey(tester), ValueKey('bibi-cards-0'));
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
    expect(_cardsKey(tester), ValueKey('bibi-cards-0'));
    await tester.tap(find.text('首页').hitTestable());
    await tester.pumpAndSettle();
    expect(_body(tester), 0);
    expect(_cardsKey(tester), ValueKey('bibi-cards-1'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('触底显示圆形进度并追加一批卡片，下拉刷新恢复两批', (tester) async {
    await _open(tester);
    int slots() => tester.widget<ElSliverList>(_cards()).itemCount;
    final controller = _feed(tester).controller!;
    expect(slots(), 4);
    expect(tester.widget<ElSliverList>(_cards()).itemType, isNotNull);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(slots(), 4);
    final spinner = _inFeed(find.byType(CircularProgressIndicator));
    expect(spinner, findsOneWidget);
    await tester.pump(Duration(milliseconds: 100));
    expect(slots(), 6);
    expect(spinner, findsNothing);
    final appendedOffset = controller.offset;
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(appendedOffset, .01));
    expect(controller.position.extentAfter, greaterThan(0));

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.text('首页').hitTestable());
    await tester.pump();
    final pull = await tester.startGesture(Offset(195, 420));
    await pull.moveBy(Offset(0, 100));
    await pull.moveBy(Offset(0, 180));
    await tester.pump();
    await pull.up();
    await tester.pump(Duration(milliseconds: 100));
    expect(slots(), 6, reason: '刷新开始后，正在等待的追加不得写回');
    await tester.pumpAndSettle();
    expect(_cardsKey(tester), ValueKey('bibi-cards-1'));
    expect(slots(), 4);
    expect(controller.offset, 0);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    expect(slots(), 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首次选中才显示刷新器并加载，各频道分页互相独立', (tester) async {
    await _open(tester, waitForData: false);
    int slots(int index) => tester.widget<ElSliverList>(_cards(index: index)).itemCount;
    expect(slots(1), 0);
    final indicator = _inFeed(_key('bibi-refresh-indicator'));
    await tester.pump(Duration(milliseconds: 220));
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 1);
    expect(slots(1), 0);
    await _finishInitialLoad(tester);
    expect(slots(1), 4);
    expect(slots(2), 0);

    final recommendationTitle = find.text('职业选手的极限反打，第一视角复盘');
    expect(find.descendant(of: _cards(), matching: recommendationTitle), findsOneWidget);
    final recommendation = _feed(tester).controller!;
    recommendation.jumpTo(recommendation.position.maxScrollExtent);
    await tester.pump(Duration(milliseconds: 100));
    expect(slots(1), 6);

    await tester.tap(_key('bibi-channel-2'));
    final pager = _pager(tester);
    for (var frame = 0; frame < 60 && pager.position != 2; frame++) {
      await tester.pump(Duration(milliseconds: 16));
    }
    expect(pager.position, 2);
    await tester.pump();
    expect(slots(2), 0);
    await _finishInitialLoad(tester);
    expect(slots(2), 4);
    expect(slots(1), 6);
    expect(find.descendant(of: _cards(index: 2), matching: recommendationTitle), findsNothing);
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
    final banner = _inFeed(_key('bibi-banner-0'));
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

  testWidgets('卡片区跟手横移，页头保持固定且各频道保留自己的滚动位置', (tester) async {
    await _open(tester);
    final host = _inFeed(find.byType(ElScrollView));
    final grid = _inFeed(find.byWidgetPredicate((widget) => widget is ElSliverGrid));
    final cards = find.descendant(of: grid, matching: find.byType(ExamplePanel));
    expect(cards, findsNWidgets(6));
    final cover = find.descendant(of: cards.first, matching: find.byType(AspectRatio));
    final coverSize = tester.getSize(cover);
    expect(coverSize.aspectRatio, closeTo(5 / 4, .001));
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
    final tabs = _key('bibi-tabs');
    final header = tester.element(tabs);
    final headerRect = tester.getRect(tabs);
    final gesture = await _holdDrag(tester, Offset(300, 540), Offset(-55, 0), Offset(-180, 0));
    expect(_pager(tester).position, inInclusiveRange(1.01, 1.99));
    expect(tabs, findsOneWidget);
    expect(tester.getRect(tabs), headerRect);
    expect(tester.widget<ElSliverList>(_cards(index: 2)).itemCount, 0);
    await _releaseHeld(tester, gesture);
    await tester.pumpAndSettle();
    expect(_pager(tester).index, 2);
    expect(tester.element(tabs), same(header));
    expect(tester.getRect(tabs), headerRect);
    expect(_body(tester, index: 2), 0);
    await tester.tap(_key('bibi-channel-1'));
    await tester.pumpAndSettle();
    expect(_body(tester), closeTo(offset, .01));
    expect(_tabsY(tester), expanded - 58);

    final pager = _pager(tester);
    for (final index in [5, 6, 7]) {
      pager.jumpTo(index);
      await tester.pumpAndSettle();
    }
    expect(_key('bibi-feed-1'), findsNothing);
    pager.jumpTo(1);
    await tester.pump();
    expect(_body(tester), closeTo(offset, .01));
    expect(tester.widget<ElSliverList>(_cards()).itemCount, 4);
  });

  testWidgets('频道标签栏居中、滑块和文字颜色逐帧跟随拖动、回弹与点选', (tester) async {
    await _open(tester);
    final pager = _pager(tester);
    final tabs = _key('bibi-tabs');
    final indicator = _key('bibi-channel-indicator');
    final first = _key('bibi-channel-0');
    final next = _key('bibi-channel-1');
    await tester.tap(_key('bibi-channel-3'));
    await tester.pumpAndSettle();
    Color colorAt(int index) => tester
        .widget<Text>(find.descendant(of: _key('bibi-channel-$index'), matching: find.byType(Text)))
        .style!
        .color!;
    final selected = colorAt(3);
    final unselected = colorAt(4);
    final firstCenterBeforeDrag = tester.getCenter(first).dx;
    var fractionalFrames = 0;

    void expectFrame() {
      final page = pager.position;
      final firstCenter = tester.getCenter(first).dx;
      final step = tester.getCenter(next).dx - firstCenter;
      final viewport = tester.getRect(tabs);
      final indicatorCenter = tester.getCenter(indicator).dx;
      expect(indicatorCenter, closeTo(firstCenter + page * step, 0.01));
      expect(indicatorCenter, closeTo(viewport.center.dx - 19 / 2, 0.01));
      for (var index = 2; index <= 5; index++) {
        expect(colorAt(index), Color.lerp(selected, unselected, (page - index).abs().clamp(0.0, 1.0)));
      }
      if ((page - page.round()).abs() > .01) fractionalFrames++;
    }

    final gesture = await tester.startGesture(Offset(300, 540));
    await gesture.moveBy(Offset(-24, 0));
    for (var frame = 0; frame < 4; frame++) {
      await gesture.moveBy(Offset(-18, 0));
      await tester.pump(Duration(milliseconds: 16));
      expectFrame();
    }
    expect(pager.position, inExclusiveRange(3, 3.5));
    expect(fractionalFrames, 4);
    expect(tester.getCenter(first).dx, lessThan(firstCenterBeforeDrag));
    await tester.pump(Duration(milliseconds: 200));
    await gesture.up(timeStamp: Duration(milliseconds: 300));
    for (var frame = 0; frame < 18; frame++) {
      await tester.pump(Duration(milliseconds: 16));
      expectFrame();
    }
    await tester.pumpAndSettle();
    expect(pager.index, 3);
    expect(tester.getCenter(first).dx, closeTo(firstCenterBeforeDrag, 0.01));
    expect(fractionalFrames, greaterThan(4));

    fractionalFrames = 0;
    await tester.tap(_key('bibi-channel-4'));
    for (var frame = 0; frame < 18; frame++) {
      await tester.pump(Duration(milliseconds: 16));
      expectFrame();
    }
    await tester.pumpAndSettle();
    expect(pager.index, 4);
    expect(fractionalFrames, greaterThan(1));
    expectFrame();
  });

  testWidgets('末尾频道仅因频道栏横拖而移动，展开时随菜单边界回位', (tester) async {
    await _open(tester);
    await tester.tap(_key('bibi-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生活').hitTestable().last);
    await tester.pumpAndSettle();
    await _finishInitialLoad(tester);
    expect(_pager(tester).index, 9);
    final tab = _key('bibi-channel-5');
    final menu = _key('bibi-menu');
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
    final menuX = tester.getTopLeft(menu).dx;
    final reverse = await _holdDrag(tester, Offset(195, 540), Offset(0, 19), Offset(0, 7));
    final tabMove = tester.getTopLeft(tab).dx - revealed;
    expect(tabMove, greaterThan(0));
    expect(tabMove, lessThan(40));
    expect(tabMove, closeTo(tester.getTopLeft(menu).dx - menuX, 1));
    await _releaseHeld(tester, reverse);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
