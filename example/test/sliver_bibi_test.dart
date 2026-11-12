import 'package:example/src/pages/examples/index.dart';
import 'package:example/src/pages/examples/sliver_bibi/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart' show ElScrollView, ElTabController, ElTabView;
import 'package:flutter_test/flutter_test.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _inFeed(int index, Finder matching) => find.descendant(of: _key('sliver-bibi-feed-$index'), matching: matching);

Future<SliverBibiPageState> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(390, 844), viewPadding: EdgeInsets.only(top: 24, bottom: 16)),
        child: SliverBibiPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<SliverBibiPageState>(find.byType(SliverBibiPage));
}

double _bannerY(WidgetTester tester) => tester.getTopLeft(_inFeed(1, _key('bibi-banner'))).dy;

double _tabsBottom(WidgetTester tester) => tester.getBottomLeft(_key('bibi-tabs')).dy;

Future<TestGesture> _slowDrag(WidgetTester tester, Offset first, Offset second) async {
  final gesture = await tester.startGesture(Offset(195, 530));
  await gesture.moveBy(first, timeStamp: Duration(milliseconds: 70));
  await tester.pump(Duration(milliseconds: 70));
  await gesture.moveBy(second, timeStamp: Duration(milliseconds: 150));
  await tester.pump(Duration(milliseconds: 150));
  return gesture;
}

Future<void> _releaseSlowly(WidgetTester tester, TestGesture gesture) async {
  await tester.pump(Duration(milliseconds: 200));
  await gesture.up(timeStamp: Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

Future<void> _collapseHeader(WidgetTester tester, SliverBibiPageState state) async {
  await tester.flingFrom(Offset(195, 540), Offset(0, -160), 900);
  await tester.pumpAndSettle();
  expect(state.debugHeaderOffset, closeTo(58, 0.01));
}

void main() {
  testWidgets('入口是官方 CustomScrollView + SliverList，没有 ElScrollView', (tester) async {
    final entry = advancedExamples.singleWhere((page) => page.key == 'sliver-bibi');
    expect(entry.title, 'Bibi Sliver 对照');
    final state = await _open(tester);
    expect(state.debugScrollPixels, 0);
    expect(find.byType(ElScrollView), findsNothing);
    expect(_inFeed(1, find.byType(CustomScrollView)), findsOneWidget);
    expect(_inFeed(1, find.byType(SliverList)), findsOneWidget);
    expect(_inFeed(1, find.byType(SliverToBoxAdapter)), findsOneWidget);
  });

  testWidgets('慢拖只消费搜索栏行程，正文几何连续且位置无跳变，释放后吸附', (tester) async {
    final state = await _open(tester);
    final initialBannerY = _bannerY(tester);
    expect(initialBannerY, closeTo(_tabsBottom(tester), 0.1));
    final gesture = await _slowDrag(tester, Offset(0, -20), Offset(0, -6));
    expect(state.debugHeaderOffset, inExclusiveRange(0, 29));
    expect(state.debugScrollPixels, 0);
    expect(_bannerY(tester) + state.debugHeaderOffset, closeTo(initialBannerY, 0.01));
    expect(_bannerY(tester), closeTo(_tabsBottom(tester), 0.01));
    await _releaseSlowly(tester, gesture);
    expect(state.debugHeaderOffset, closeTo(0, 0.01));
    expect(state.debugScrollPixels, closeTo(0, 0.01));

    final long = await _slowDrag(tester, Offset(0, -26), Offset(0, -35));
    expect(state.debugHeaderOffset, inExclusiveRange(29, 58));
    expect(state.debugScrollPixels, 0);
    expect(_bannerY(tester) + state.debugHeaderOffset, closeTo(initialBannerY, 0.01));
    await _releaseSlowly(tester, long);
    expect(state.debugHeaderOffset, closeTo(58, 0.01));
    expect(state.debugScrollPixels, closeTo(0, 0.01));
    expect(_bannerY(tester), closeTo(_tabsBottom(tester), 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('一次短甩直接跨越搜索栏 58px 和正文，惯性期间没有几何突变', (tester) async {
    final state = await _open(tester);
    final initialBannerY = _bannerY(tester);
    final gesture = await tester.startGesture(Offset(195, 550));
    for (var i = 1; i <= 6; i++) {
      await gesture.moveBy(Offset(0, -7), timeStamp: Duration(milliseconds: i * 6));
      await tester.pump(Duration(milliseconds: 6));
    }
    expect(state.debugHeaderOffset, inExclusiveRange(0, 58));
    await gesture.up(timeStamp: Duration(milliseconds: 40));
    bool crossed = false;
    for (var i = 0; i < 70; i++) {
      await tester.pump(Duration(milliseconds: 8));
      if (state.debugScrollPixels > 0.01) crossed = true;
      if (_inFeed(1, _key('bibi-banner')).evaluate().isNotEmpty) {
        expect(_bannerY(tester) + state.debugScrollPixels + state.debugHeaderOffset, closeTo(initialBannerY, 0.05));
      }
      if (crossed) expect(state.debugHeaderOffset, closeTo(58, 0.01));
    }
    expect(crossed, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('刷新只在完全展开的顶部激活：拖拽逐像素跟手、反向先收回再滚动', (tester) async {
    final state = await _open(tester);
    final initialBannerY = _bannerY(tester);
    final gesture = await _slowDrag(tester, Offset(0, 90), Offset(0, 140));
    final armed = state.debugRefreshSnapshot(1)!;
    expect(armed.status, RefreshIndicatorStatus.armed);
    expect(armed.pulledExtent, greaterThan(128));
    expect(state.debugScrollPixels, 0);
    expect(state.debugHeaderOffset, 0);
    expect(_bannerY(tester), closeTo(initialBannerY, 0.01));

    await gesture.moveBy(Offset(0, 36), timeStamp: Duration(milliseconds: 240));
    await tester.pump();
    expect(state.debugRefreshSnapshot(1)!.pulledExtent - armed.pulledExtent, closeTo(36, 0.01));
    expect(state.debugScrollPixels, 0);

    await gesture.moveBy(Offset(0, -155), timeStamp: Duration(milliseconds: 280));
    await tester.pump();
    final reversed = state.debugRefreshSnapshot(1)!;
    expect(reversed.pulledExtent, closeTo(armed.pulledExtent + 36 - 155, 0.02));
    expect(reversed.status, RefreshIndicatorStatus.drag);
    expect(state.debugScrollPixels, 0);
    await _releaseSlowly(tester, gesture);
    expect(state.debugRefreshSnapshot(1)!.status, isNull);
    expect(_inFeed(1, _key('sliver-bibi-rows-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('下拉刷新指示器锚定正文视口顶部，不额外叠加搜索栏 58px', (tester) async {
    final state = await _open(tester);
    final gesture = await _slowDrag(tester, Offset(0, 100), Offset(0, 140));
    expect(state.debugRefreshSnapshot(1)!.status, RefreshIndicatorStatus.armed);
    final scroll = _inFeed(1, find.byType(CustomScrollView));
    final indicator = _inFeed(1, _key('sliver-bibi-refresh-indicator'));
    final scrollTop = tester.getTopLeft(scroll).dy;
    expect(tester.getTopLeft(indicator).dy, closeTo(scrollTop, 0.01));
    expect(tester.getTopLeft(indicator).dy, closeTo(tester.getTopLeft(_inFeed(1, _key('bibi-banner'))).dy, 0.01));
    expect(tester.getSize(indicator), tester.getSize(scroll));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('达到阈值却收到取消事件时不刷新；触发后离开顶部不能立即换数据', (tester) async {
    final state = await _open(tester);
    final canceled = await _slowDrag(tester, Offset(0, 100), Offset(0, 140));
    expect(state.debugRefreshSnapshot(1)!.status, RefreshIndicatorStatus.armed);
    await canceled.cancel();
    await tester.pumpAndSettle();
    expect(state.debugRefreshSnapshot(1)!.status, isNull);
    expect(_inFeed(1, _key('sliver-bibi-rows-0')), findsOneWidget);

    final pull = await _slowDrag(tester, Offset(0, 100), Offset(0, 140));
    expect(state.debugRefreshSnapshot(1)!.status, RefreshIndicatorStatus.armed);
    await tester.pump(Duration(milliseconds: 200));
    await pull.up(timeStamp: Duration(milliseconds: 450));
    await tester.pump();
    expect(state.debugRefreshSnapshot(1)!.status, RefreshIndicatorStatus.refresh);
    expect(state.debugHeaderOffset, 0);
    // 请求仍未结束就离开顶部，禁止在用户浏览中更新数据。
    await tester.flingFrom(Offset(195, 550), Offset(0, -220), 1600);
    final flingReleaseOffset = state.debugScrollPixels;
    await tester.pump(Duration(milliseconds: 16));
    await tester.pump(Duration(milliseconds: 16));
    expect(state.debugScrollPixels, greaterThan(flingReleaseOffset));
    await tester.pump(Duration(milliseconds: 650));
    await tester.pumpAndSettle();
    expect(state.debugScrollPixels, greaterThan(0));
    expect(_inFeed(1, _key('sliver-bibi-rows-0')), findsOneWidget);
    await tester.tap(find.text('首页').hitTestable());
    await tester.pumpAndSettle();
    expect(state.debugScrollPixels, 0);
    expect(_inFeed(1, _key('sliver-bibi-rows-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('只要搜索栏还未完全展开，反向拖动不会提前激活刷新', (tester) async {
    final state = await _open(tester);
    final scroll = tester.widget<CustomScrollView>(_inFeed(1, find.byType(CustomScrollView)));
    await _collapseHeader(tester, state);
    scroll.controller!.jumpTo(100);
    await tester.pump();
    expect(state.debugHeaderOffset, 58);
    final gesture = await _slowDrag(tester, Offset(0, 25), Offset(0, 25));
    expect(state.debugHeaderOffset, inExclusiveRange(0, 58));
    expect(state.debugScrollPixels, closeTo(100, 0.01));
    expect(state.debugRefreshSnapshot(1)!.status, isNull);
    await _releaseSlowly(tester, gesture);
    expect(tester.takeException(), isNull);
  });

  testWidgets('横向频道拖动保留正文阅读位置，Sliver 页面互相独立', (tester) async {
    final state = await _open(tester);
    final scroll = tester.widget<CustomScrollView>(_inFeed(1, find.byType(CustomScrollView)));
    await _collapseHeader(tester, state);
    scroll.controller!.jumpTo(260);
    await tester.pumpAndSettle();
    final previous = state.debugScrollPixels;
    expect(previous, closeTo(260, 0.1));

    final pager = tester.widget<ElTabView>(_key('sliver-bibi-pager')).controller!;
    expect(pager, isA<ElTabController>());
    await tester.flingFrom(Offset(300, 520), Offset(-210, 0), 900);
    await tester.pumpAndSettle();
    expect(pager.index, 2);
    expect(state.debugScrollPixels, closeTo(previous, 0.5));
    expect(state.debugHeaderOffset, 58);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正文滚到 500px 时，双向拖拽依然优先推动搜索栏；余量才修改正文', (tester) async {
    final state = await _open(tester);
    await _collapseHeader(tester, state);
    final viewport = _inFeed(1, find.byType(CustomScrollView));
    final controller = tester.widget<CustomScrollView>(viewport).controller!;
    controller.jumpTo(500);
    await tester.pump();
    expect(state.debugHeaderOffset, 58);
    final layoutSize = tester.getSize(viewport);
    final initialViewportTop = tester.getTopLeft(viewport).dy;

    final down = await _slowDrag(tester, Offset(0, 24), Offset(0, 18));
    expect(state.debugHeaderOffset, closeTo(40, 0.01));
    expect(state.debugScrollPixels, closeTo(500, 0.01));
    expect(tester.getTopLeft(viewport).dy + state.debugHeaderOffset, closeTo(initialViewportTop + 58, 0.01));
    expect(tester.getSize(viewport), layoutSize);
    await down.moveBy(Offset(0, 65), timeStamp: Duration(milliseconds: 220));
    await tester.pump(Duration(milliseconds: 70));
    expect(state.debugHeaderOffset, 0);
    expect(state.debugScrollPixels, closeTo(475, 0.01));
    expect(tester.getSize(viewport), layoutSize);
    await _releaseSlowly(tester, down);

    final up = await _slowDrag(tester, Offset(0, -24), Offset(0, -18));
    expect(state.debugHeaderOffset, closeTo(18, 0.01));
    expect(state.debugScrollPixels, closeTo(475, 0.01));
    await up.moveBy(Offset(0, -65), timeStamp: Duration(milliseconds: 220));
    await tester.pump(Duration(milliseconds: 70));
    expect(state.debugHeaderOffset, 58);
    expect(state.debugScrollPixels, closeTo(500, 0.01));
    expect(tester.getTopLeft(viewport).dy, closeTo(initialViewportTop, 0.01));
    expect(tester.getSize(viewport), layoutSize);
    await _releaseSlowly(tester, up);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正文在 500px 时短甩，惯性先展开搜索栏再继续滚动正文', (tester) async {
    final state = await _open(tester);
    await _collapseHeader(tester, state);
    final scroll = tester.widget<CustomScrollView>(_inFeed(1, find.byType(CustomScrollView)));
    scroll.controller!.jumpTo(500);
    await tester.pump();
    final gesture = await tester.startGesture(Offset(195, 540));
    for (var i = 1; i <= 6; i++) {
      await gesture.moveBy(Offset(0, 7), timeStamp: Duration(milliseconds: i * 6));
      await tester.pump(Duration(milliseconds: 6));
    }
    expect(state.debugHeaderOffset, inExclusiveRange(0, 58));
    expect(state.debugScrollPixels, closeTo(500, 0.01));
    await gesture.up(timeStamp: Duration(milliseconds: 40));
    var crossed = false;
    for (var frame = 0; frame < 70; frame++) {
      await tester.pump(Duration(milliseconds: 8));
      if (state.debugScrollPixels < 499.99) {
        crossed = true;
        expect(state.debugHeaderOffset, closeTo(0, 0.01));
      }
    }
    expect(crossed, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('正文在顶部而搜索栏收起时，短甩仍能展开，不因正文到边界而终止弹道', (tester) async {
    final state = await _open(tester);
    await _collapseHeader(tester, state);
    final scroll = tester.widget<CustomScrollView>(_inFeed(1, find.byType(CustomScrollView)));
    scroll.controller!.jumpTo(0);
    await tester.pump();
    final gesture = await tester.startGesture(Offset(195, 540));
    for (var i = 1; i <= 6; i++) {
      await gesture.moveBy(Offset(0, 7), timeStamp: Duration(milliseconds: i * 6));
      await tester.pump(Duration(milliseconds: 6));
    }
    expect(state.debugHeaderOffset, inExclusiveRange(0, 58));
    await gesture.up(timeStamp: Duration(milliseconds: 40));
    await tester.pumpAndSettle();
    expect(state.debugHeaderOffset, closeTo(0, 0.01));
    expect(state.debugScrollPixels, closeTo(0, 0.01));
    expect(state.debugRefreshSnapshot(1)!.status, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索栏吸附过程中轻点卡片，不会把吸附停在半程', (tester) async {
    final state = await _open(tester);
    final drag = await _slowDrag(tester, Offset(0, -26), Offset(0, -34));
    expect(state.debugHeaderOffset, inExclusiveRange(29, 58));
    await tester.pump(Duration(milliseconds: 200));
    await drag.up(timeStamp: Duration(milliseconds: 450));
    await tester.pump(Duration(milliseconds: 16));
    await tester.tapAt(Offset(195, 540));
    await tester.pumpAndSettle();
    expect(state.debugHeaderOffset, closeTo(58, 0.01));
    expect(state.debugScrollPixels, closeTo(0, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('轮播优先横向拖动；轮播在首端向外滑，频道才接管', (tester) async {
    final state = await _open(tester);
    final banner = _inFeed(1, _key('bibi-banner'));
    final center = tester.getCenter(banner);
    final pager = tester.widget<ElTabView>(_key('sliver-bibi-pager')).controller!;
    final inner = tester.widget<ElTabView>(find.descendant(of: banner, matching: find.byType(ElTabView))).controller!;
    await tester.flingFrom(center, Offset(-140, 0), 900);
    await tester.pumpAndSettle();
    expect(inner.index, 1);
    expect(pager.index, 1);
    await tester.flingFrom(center, Offset(140, 0), 900);
    await tester.pumpAndSettle();
    expect(inner.index, 0);
    expect(pager.index, 1);
    await tester.flingFrom(center, Offset(140, 0), 900);
    await tester.pumpAndSettle();
    expect(pager.index, 0);
    expect(state.debugHeaderOffset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单次拖拽跨越展开边界时，剩余位移同事件进入刷新且反向完整回收', (tester) async {
    final state = await _open(tester);
    final scroll = tester.widget<CustomScrollView>(_inFeed(1, find.byType(CustomScrollView)));
    scroll.controller!.jumpTo(22);
    await tester.pump();
    final gesture = await tester.startGesture(Offset(195, 510));
    // 第一笔跨 slop 只负责启动官方 recognizer，第二笔才是要验证的单次更新。
    await gesture.moveBy(Offset(0, 22), timeStamp: Duration(milliseconds: 40));
    await tester.pump(Duration(milliseconds: 40));
    await gesture.moveBy(Offset(0, 95), timeStamp: Duration(milliseconds: 110));
    await tester.pump(Duration(milliseconds: 70));
    final firstPull = state.debugRefreshSnapshot(1)!.pulledExtent;
    expect(state.debugScrollPixels, closeTo(0, 0.01));
    expect(firstPull, greaterThan(0));
    expect(state.debugHeaderOffset, 0);
    await gesture.moveBy(Offset(0, -35), timeStamp: Duration(milliseconds: 180));
    await tester.pump(Duration(milliseconds: 70));
    expect(state.debugRefreshSnapshot(1)!.pulledExtent, closeTo(firstPull - 35, 0.01));
    expect(state.debugScrollPixels, 0);
    await gesture.moveBy(Offset(0, -150), timeStamp: Duration(milliseconds: 250));
    await tester.pump(Duration(milliseconds: 70));
    expect(state.debugRefreshSnapshot(1)!.pulledExtent, 0);
    expect(state.debugScrollPixels, greaterThan(0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(_inFeed(1, _key('sliver-bibi-rows-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('仍按住刷新拖拽时卸载页面，后续 Cancel 不会访问死宿主', (tester) async {
    final state = await _open(tester);
    final gesture = await _slowDrag(tester, Offset(0, 100), Offset(0, 140));
    expect(state.debugRefreshSnapshot(1)!.status, RefreshIndicatorStatus.armed);
    await tester.pumpWidget(SizedBox());
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
