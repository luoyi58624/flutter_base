import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _IosProbe extends ElIosRefresher {
  _IosProbe({super.triggerExtent});

  late ElRefreshDetails details;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    this.details = details;
    return super.buildIndicator(context, details);
  }
}

class _LongPullIos extends _IosProbe {
  @override
  double get triggerExtent => 260;
}

final _scroll = find.byKey(ValueKey('ios-scroll'));

class _Fixture {
  _Fixture({double? triggerExtent, _IosProbe? refresher})
    : refresher = refresher ?? _IosProbe(triggerExtent: triggerExtent);

  final _IosProbe refresher;
  final controller = ScrollController();
  final completion = Completer<void>();
  var refreshes = 0;

  ElRefreshSnapshot get snapshot => refresher.details.snapshot.value;

  Future<void> _refresh() {
    refreshes++;
    return completion.future;
  }

  Widget build() {
    Widget child = ElScrollView.sliver(
      key: ValueKey('ios-scroll'),
      controller: controller,
      physics: ClampingScrollPhysics(),
      slivers: [
        ElSliverRefresh(refresher: refresher, onRefresh: _refresh),
        SliverToBoxAdapter(child: SizedBox(height: 1200)),
      ],
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ScrollConfiguration(
        behavior: ScrollBehavior().copyWith(overscroll: false, scrollbars: false),
        child: Center(child: SizedBox(width: 320, height: 460, child: child)),
      ),
    );
  }

  void dispose() {
    controller.dispose();
    if (!completion.isCompleted) completion.complete();
  }
}

Future<TestGesture> _pullTo(WidgetTester tester, _Fixture fixture, double target, [TestGesture? gesture]) async {
  gesture ??= await tester.startGesture(tester.getCenter(_scroll));
  for (var step = 0; fixture.snapshot.pulledExtent < target && step < 200; step++) {
    await gesture.moveBy(Offset(0, (target - fixture.snapshot.pulledExtent).clamp(4.0, 24.0)));
    await tester.pump();
  }
  expect(fixture.snapshot.pulledExtent, greaterThanOrEqualTo(target));
  return gesture;
}

void main() {
  testWidgets('Sliver iOS 达到默认阈值后松手刷新并停靠原位', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());

    final gesture = await _pullTo(tester, fixture, 56);
    expect(fixture.snapshot.status, RefreshIndicatorStatus.drag);
    expect(fixture.snapshot.progress, lessThan(1));
    await _pullTo(tester, fixture, 60, gesture);
    expect(fixture.snapshot.pulledExtent, lessThan(64));
    expect(fixture.snapshot.status, RefreshIndicatorStatus.armed);
    expect(fixture.snapshot.progress, 1);
    expect(fixture.refreshes, 0);
    expect(fixture.refresher.maxPullExtent, 250, reason: '缩短触发距离不会连带缩短最大拉伸空间');

    await gesture.up();
    await tester.pump(Duration(milliseconds: 16));
    expect(fixture.refreshes, 1);
    expect(fixture.snapshot.status, RefreshIndicatorStatus.refresh);
    await tester.pump(Duration(seconds: 1));
    await tester.pump();
    expect(fixture.snapshot.pulledExtent, closeTo(60, 1));

    fixture.completion.complete();
    await tester.pumpAndSettle();
    expect(fixture.snapshot.status, isNull);
  });

  testWidgets('Sliver iOS 达标后回拉撤销，松手不刷新', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());
    final gesture = await _pullTo(tester, fixture, 60);
    expect(fixture.snapshot.status, RefreshIndicatorStatus.armed);
    await gesture.moveBy(Offset(0, -20));
    await tester.pump();
    expect(fixture.snapshot.status, RefreshIndicatorStatus.drag);
    expect(fixture.snapshot.progress, lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fixture.refreshes, 0);
    expect(fixture.snapshot.status, isNull);
  });

  testWidgets('Sliver iOS 显式触发距离不受默认值调整影响', (tester) async {
    final fixture = _Fixture(triggerExtent: 100);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());
    final gesture = await _pullTo(tester, fixture, 60);
    expect(fixture.snapshot.status, RefreshIndicatorStatus.drag);
    expect(fixture.snapshot.progress, lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fixture.refreshes, 0);
  });

  testWidgets('Sliver 继承 iOS 刷新器调大阈值后仍可拉到待释放状态', (tester) async {
    final fixture = _Fixture(refresher: _LongPullIos());
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());
    final gesture = await _pullTo(tester, fixture, 260);
    expect(fixture.snapshot.status, RefreshIndicatorStatus.armed);
    expect(fixture.refreshes, 0);
    await gesture.up();
    await tester.pump(Duration(milliseconds: 16));
    expect(fixture.refreshes, 1);
    fixture.completion.complete();
    await tester.pumpAndSettle();
    expect(fixture.snapshot.status, isNull);
  });
}
