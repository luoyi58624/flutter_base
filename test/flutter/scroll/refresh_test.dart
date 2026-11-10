import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _body(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: ScrollConfiguration(
    behavior: ScrollBehavior().copyWith(overscroll: false, scrollbars: false),
    child: Center(child: SizedBox(width: 320, height: 460, child: child)),
  ),
);

class _Fixture {
  _Fixture({bool useElController = false}) : controller = useElController ? ElScrollController() : ScrollController();

  final ScrollController controller;
  final refreshed = <int>[];
  final completer = Completer<void>();
  ElRefreshDetails? details;
  ElRefresher get refresher => ElCustomRefresher(
    triggerExtent: 60,
    movesContent: false,
    builder: (context, details) {
      this.details = details;
      return SizedBox.expand(key: ValueKey('refresh-layer'));
    },
  );

  Widget build() => _body(
    ElRefresh(
      refresher: refresher,
      onRefresh: () {
        refreshed.add(1);
        return completer.future;
      },
      child: ElScroll.sliver(
        key: ValueKey('scroll'),
        controller: controller,
        physics: ClampingScrollPhysics(),
        slivers: [SliverToBoxAdapter(child: SizedBox(height: 1200))],
      ),
    ),
  );

  void dispose() {
    controller.dispose();
    if (!completer.isCompleted) completer.complete();
  }
}

Future<TestGesture> _drag(WidgetTester tester, List<double> motions) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('scroll'))));
  for (final delta in motions) {
    await gesture.moveBy(Offset(0, delta));
    await tester.pump();
  }
  return gesture;
}

void main() {
  testWidgets('ElScrollController 直接挂载时 Widget 刷新正常分账', (tester) async {
    final fixture = _Fixture(useElController: true);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());
    final gesture = await _drag(tester, [35, 65]);
    expect(fixture.details!.snapshot.value.status, RefreshIndicatorStatus.armed);
    await gesture.up();
    await tester.pump(Duration(milliseconds: 1));
    expect(fixture.refreshed, [1]);
    fixture.completer.complete();
    await tester.pumpAndSettle();
    expect(fixture.controller.offset, 0);
  });

  testWidgets('Widget 刷新器接入官方拖拽；未达阈值、反向撤销及取消不触发', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());

    final first = await _drag(tester, [35, 35]);
    expect(fixture.details!.snapshot.value.status, RefreshIndicatorStatus.armed);
    expect(fixture.controller.offset, 0);
    await first.moveBy(Offset(0, -25));
    await tester.pump();
    expect(fixture.details!.snapshot.value.status, RefreshIndicatorStatus.drag);
    await first.up();
    await tester.pumpAndSettle();
    expect(fixture.refreshed, isEmpty);
    expect(fixture.details!.snapshot.value.status, isNull);

    final second = await _drag(tester, [35, 65]);
    expect(fixture.details!.snapshot.value.status, RefreshIndicatorStatus.armed);
    await second.cancel();
    expect(fixture.details!.snapshot.value.status, anyOf(isNull, RefreshIndicatorStatus.canceled), reason: '真实取消不能触发 refresh');
    await tester.pumpAndSettle();
    expect(fixture.refreshed, isEmpty);
    expect(fixture.details!.snapshot.value.status, isNull);
  });

  testWidgets('松手触发一次刷新；新滚动不破坏标准 ScrollPosition', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());

    final gesture = await _drag(tester, [35, 65]);
    expect(fixture.details!.snapshot.value.status, RefreshIndicatorStatus.armed);
    await gesture.up();
    await tester.pump(Duration(milliseconds: 1));
    expect(fixture.refreshed, [1]);
    expect(fixture.details!.snapshot.value.status, RefreshIndicatorStatus.refresh);
    fixture.completer.complete();
    await tester.pumpAndSettle();
    expect(fixture.details!.snapshot.value.status, isNull);
    expect(fixture.controller.offset, 0);
  });

  testWidgets('内容让位刷新直接使用官方 position 越界，松手后停靠并收回', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final future = Completer<void>();
    addTearDown(() { if (!future.isCompleted) future.complete(); });
    ElRefreshDetails? details;
    var count = 0;
    await tester.pumpWidget(_body(ElRefresh(
      refresher: ElCustomRefresher(
        triggerExtent: 60,
        movesContent: true,
        builder: (context, value) {
          details = value;
          return SizedBox.expand();
        },
      ),
      onRefresh: () { count++; return future.future; },
      child: ElScroll.sliver(key: ValueKey('scroll'), controller: controller, physics: ClampingScrollPhysics(), slivers: [
        SliverToBoxAdapter(child: SizedBox(height: 1200)),
      ]),
    )));
    final drag = await _drag(tester, [40, 60]);
    expect(controller.offset, lessThan(0));
    expect(details!.snapshot.value.pulledExtent, greaterThan(60));
    expect(details!.snapshot.value.status, RefreshIndicatorStatus.armed);
    await drag.up();
    await tester.pump(Duration(milliseconds: 1));
    expect(count, 1);
    future.complete();
    await tester.pumpAndSettle();
    expect(details!.snapshot.value.status, isNull);
    expect(controller.offset, closeTo(0, 1));
  });

  testWidgets('内容短于视口时仍可从顶部下拉刷新', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    ElRefreshDetails? details;
    await tester.pumpWidget(_body(ElRefresh(
      refresher: ElCustomRefresher(
        triggerExtent: 60,
        movesContent: false,
        builder: (context, value) { details = value; return SizedBox.expand(); },
      ),
      onRefresh: () async {},
      child: ElScroll.sliver(
        key: ValueKey('scroll'), controller: controller, physics: ClampingScrollPhysics(),
        slivers: [SliverToBoxAdapter(child: SizedBox(height: 40))],
      ),
    )));
    expect(controller.position.maxScrollExtent, 0);
    final gesture = await _drag(tester, [35, 65]);
    expect(details!.snapshot.value.status, RefreshIndicatorStatus.armed);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(details!.snapshot.value.status, isNull);
  });

  testWidgets('反向列表的 leading 刷新：在实际 min 边向外拖动能触发', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    ElRefreshDetails? details;
    await tester.pumpWidget(_body(ElRefresh(
      axisDirection: AxisDirection.up,
      refresher: ElCustomRefresher(
        triggerExtent: 60,
        movesContent: false,
        builder: (context, value) { details = value; return SizedBox.expand(); },
      ),
      onRefresh: () async {},
      child: ElScroll.sliver(
        key: ValueKey('scroll'), reverse: true, controller: controller,
        physics: ClampingScrollPhysics(),
        slivers: [SliverToBoxAdapter(child: SizedBox(height: 1200))],
      ),
    )));
    final drag = await _drag(tester, [-35, -65]);
    expect(details!.snapshot.value.status, RefreshIndicatorStatus.armed);
    expect(controller.offset, 0);
    await drag.cancel();
    await tester.pumpAndSettle();
    expect(details!.snapshot.value.status, isNull);
  });

  testWidgets('正文在 trailing 边向外拖动触发刷新，不把拉距写进正文位置', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    ElRefreshDetails? details;
    await tester.pumpWidget(_body(ElRefresh(
      edge: ElRefreshEdge.trailing,
      refresher: ElCustomRefresher(
        triggerExtent: 60, movesContent: false,
        builder: (context, value) { details = value; return SizedBox.expand(); },
      ),
      onRefresh: () async {},
      child: ElScroll.sliver(
        key: ValueKey('scroll'), controller: controller, physics: ClampingScrollPhysics(),
        slivers: [SliverToBoxAdapter(child: SizedBox(height: 1200))],
      ),
    )));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final drag = await _drag(tester, [-35, -65]);
    expect(details!.snapshot.value.status, RefreshIndicatorStatus.armed);
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 0.01));
    await drag.cancel();
    await tester.pumpAndSettle();
    expect(details!.snapshot.value.status, isNull);
  });

  testWidgets('正文向回滚动直到顶后，同一笔余量进入刷新，反向先回收圆盘', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());
    fixture.controller.jumpTo(30);
    await tester.pump();

    final gesture = await _drag(tester, [25, 50]);
    expect(fixture.controller.offset, 0);
    expect(fixture.details!.snapshot.value.pulledExtent, greaterThan(0));
    await gesture.moveBy(Offset(0, -20));
    await tester.pump();
    expect(fixture.controller.offset, 0);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(fixture.refreshed, isEmpty);
  });
}
