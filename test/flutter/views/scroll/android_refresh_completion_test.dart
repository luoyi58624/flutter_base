import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _AndroidRefresher extends ElAndroidRefresher {
  _AndroidRefresher(this.capture);

  final ValueChanged<ElRefreshDetails> capture;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    capture(details);
    return super.buildIndicator(context, details);
  }
}

class _Fixture {
  _Fixture(this.onRefresh);

  final Future<void> Function() onRefresh;
  ElRefreshDetails? details;

  ElRefreshSnapshot get snapshot => details!.snapshot.value;

  Widget build() => Directionality(
    textDirection: .ltr,
    child: ScrollConfiguration(
      behavior: ScrollBehavior().copyWith(overscroll: false, scrollbars: false),
      child: Center(
        child: SizedBox(
          width: 320,
          height: 460,
          child: ElRefresh(
            refresher: _AndroidRefresher((value) => details = value),
            onRefresh: onRefresh,
            child: ElScroll.sliver(
              key: ValueKey('scroll'),
              physics: ClampingScrollPhysics(),
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 1200))],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _releaseRefresh(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('scroll'))));
  await gesture.moveBy(Offset(0, 35));
  await tester.pump();
  await gesture.moveBy(Offset(0, 240));
  await tester.pump();
  await gesture.up();
  await tester.pump(Duration(milliseconds: 1));
}

void main() {
  testWidgets('安卓空刷新回调仍完整停靠后再原地缩小', (tester) async {
    var refreshCount = 0;
    final fixture = _Fixture(() async => refreshCount++);
    await tester.pumpWidget(fixture.build());
    await _releaseRefresh(tester);

    expect(refreshCount, 1);
    expect(fixture.snapshot.status, RefreshIndicatorStatus.refresh);
    final spinner = find.byType(ElRefreshMaterialSpinner);
    final releasedCenter = tester.getCenter(spinner);
    final releasedExtent = fixture.snapshot.pulledExtent;
    expect(releasedExtent, greaterThan(fixture.snapshot.triggerExtent));

    await tester.pump(Duration(milliseconds: 100));
    expect(fixture.snapshot.status, RefreshIndicatorStatus.refresh);
    expect(fixture.snapshot.pulledExtent, lessThan(releasedExtent));
    expect(fixture.snapshot.pulledExtent, greaterThan(fixture.snapshot.triggerExtent));
    expect(tester.getCenter(spinner).dy, lessThan(releasedCenter.dy));
    expect(tester.getSize(spinner).width, 40);

    await tester.pump(Duration(milliseconds: 101));
    await tester.pump();
    expect(fixture.snapshot.status, RefreshIndicatorStatus.done);
    expect(fixture.snapshot.pulledExtent, fixture.snapshot.triggerExtent);
    final dockedCenter = tester.getCenter(spinner);
    expect(dockedCenter.dy, lessThan(releasedCenter.dy));

    await tester.pump(Duration(milliseconds: 75));
    expect(fixture.snapshot.status, RefreshIndicatorStatus.done);
    expect(tester.getCenter(spinner).dy, closeTo(dockedCenter.dy, 0.01));
    expect(tester.getRect(spinner).width, inExclusiveRange(0, 40));

    await tester.pump(Duration(milliseconds: 76));
    expect(fixture.snapshot.status, isNull);
    expect(spinner, findsNothing);
  });

  testWidgets('安卓停靠完成后仍等待刷新任务，任务完成才缩小', (tester) async {
    final refresh = Completer<void>();
    final fixture = _Fixture(() => refresh.future);
    await tester.pumpWidget(fixture.build());
    await _releaseRefresh(tester);
    await tester.pump(Duration(milliseconds: 250));

    expect(fixture.snapshot.status, RefreshIndicatorStatus.refresh);
    expect(fixture.snapshot.pulledExtent, fixture.snapshot.triggerExtent);
    refresh.complete();
    await tester.pump();
    expect(fixture.snapshot.status, RefreshIndicatorStatus.done);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 151));
    expect(fixture.snapshot.status, isNull);
  });

  testWidgets('安卓快速刷新在停靠途中卸载不会遗留动画回调', (tester) async {
    final fixture = _Fixture(() async {});
    await tester.pumpWidget(fixture.build());
    await _releaseRefresh(tester);
    await tester.pumpWidget(SizedBox.shrink());
    await tester.pump(Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
