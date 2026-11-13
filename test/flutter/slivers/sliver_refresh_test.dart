import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

final _scroll = find.byKey(ValueKey('scroll'));
final _content = find.byKey(ValueKey('content'));
final _indicator = find.byKey(ValueKey('indicator'));
final _androidDiskColor = Color(0xffeaf6ff);
final _androidDisk = find.byWidgetPredicate(
  (widget) => widget is ElView && widget.style?.backgroundColor == _androidDiskColor,
);
// ElView 的绘制变换体现在后代的全局坐标上。
final _androidDiskContent = find.descendant(of: _androidDisk, matching: find.byType(ElView)).first;

class _AndroidRefresher extends ElAndroidRefresher {
  _AndroidRefresher(this.capture) : super(bgColor: _androidDiskColor);

  final ValueChanged<ValueListenable<ElRefreshSnapshot>> capture;

  @override
  Widget buildIndicator(BuildContext context, ValueListenable<ElRefreshSnapshot> details) {
    capture(details);
    return super.buildIndicator(context, details);
  }
}

class _Fixture {
  _Fixture({
    this.movesContent = false,
    this.contentHeight = 1200,
    this.android = false,
    this.refreshImmediately = false,
  });

  final bool movesContent;
  final double contentHeight;
  final bool android;
  final bool refreshImmediately;

  final controller = ScrollController();
  final refreshController = ElRefreshController();
  final completer = Completer<void>();
  var refreshCount = 0;
  ValueListenable<ElRefreshSnapshot>? details;

  RefreshIndicatorStatus? get status => details!.value.status;
  double get pulled => details!.value.pulledExtent;

  Widget build({ElNestedScrollParent? parent, Future<void> Function()? reload}) {
    Widget scroll = ElScrollView.sliver(
      key: ValueKey('scroll'),
      controller: controller,
      physics: ClampingScrollPhysics(),
      slivers: [
        ElSliverRefresh(
          controller: refreshController,
          refresher: android
              ? _AndroidRefresher((value) => details = value)
              : ElCustomRefresher(
                  triggerExtent: 60,
                  movesContent: movesContent,
                  builder: (context, value) {
                    details = value;
                    return SizedBox.expand(key: ValueKey('indicator'));
                  },
                ),
          onRefresh: () {
            refreshCount++;
            if (refreshCount > 1 && reload != null) return reload();
            return refreshImmediately ? Future.value() : completer.future;
          },
        ),
        SliverToBoxAdapter(
          child: SizedBox(key: ValueKey('content'), height: contentHeight),
        ),
      ],
    );
    if (parent != null) scroll = ElNestedScroll(parent: parent, child: scroll);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ScrollConfiguration(
        behavior: ScrollBehavior().copyWith(overscroll: false, scrollbars: false),
        child: Center(child: SizedBox(width: 320, height: 460, child: scroll)),
      ),
    );
  }

  void dispose() {
    controller.dispose();
    if (!completer.isCompleted) completer.complete();
  }
}

/// 收起方向最多吃掉 50 像素的折叠头，用来观察协作顺序。
class _Header extends ElNestedScrollParent {
  double collapsed = 0;

  @override
  double onNestedPreScroll(double delta, ElScrollDeltaSource source) {
    if (delta >= 0) return 0;
    final consumed = math.max(delta, collapsed - 50);
    collapsed -= consumed;
    return consumed;
  }
}

Future<TestGesture> _drag(WidgetTester tester, List<double> motions) async {
  final gesture = await tester.startGesture(tester.getCenter(_scroll));
  for (final delta in motions) {
    await gesture.moveBy(Offset(0, delta));
    await tester.pump();
  }
  return gesture;
}

/// 正文起点相对视口起点的主轴距离，正值表示被推开。
double _contentShift(WidgetTester tester) => tester.getTopLeft(_content).dy - tester.getTopLeft(_scroll).dy;

void main() {
  group('安卓圆盘', () {
    testWidgets('回调立即完成仍先滑到停靠位，再原地缩小', (tester) async {
      final fixture = _Fixture(android: true, refreshImmediately: true);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());
      final gesture = await _drag(tester, [35, 240]);
      final releasedCenter = tester.getCenter(_androidDiskContent).dy;
      final releasedExtent = fixture.pulled;
      await gesture.up();
      await tester.pump();

      expect(fixture.refreshCount, 1);
      expect(fixture.status, RefreshIndicatorStatus.refresh);
      expect(tester.getCenter(_androidDiskContent).dy, closeTo(releasedCenter, 0.01));

      await tester.pump(Duration(milliseconds: 100));
      expect(fixture.status, RefreshIndicatorStatus.refresh);
      expect(fixture.pulled, inExclusiveRange(fixture.details!.value.triggerExtent, releasedExtent));
      expect(tester.getCenter(_androidDiskContent).dy, lessThan(releasedCenter));
      expect(tester.getRect(_androidDiskContent).width, 40);

      await tester.pump(Duration(milliseconds: 101));
      await tester.pump(Duration.zero);
      expect(fixture.status, RefreshIndicatorStatus.done);
      expect(fixture.pulled, fixture.details!.value.triggerExtent);
      final dockedCenter = tester.getCenter(_androidDiskContent).dy;

      await tester.pump(Duration(milliseconds: 75));
      expect(fixture.status, RefreshIndicatorStatus.done);
      expect(tester.getCenter(_androidDiskContent).dy, closeTo(dockedCenter, 0.01));
      expect(tester.getRect(_androidDiskContent).width, inExclusiveRange(0, 40));

      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
      expect(_androidDisk, findsNothing);
    });

    testWidgets('停靠完成后继续等回调，回调完成才收起', (tester) async {
      final fixture = _Fixture(android: true);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());
      final gesture = await _drag(tester, [35, 240]);
      await gesture.up();
      await tester.pump();
      await tester.pump(Duration(milliseconds: 250));

      expect(fixture.status, RefreshIndicatorStatus.refresh);
      expect(fixture.pulled, fixture.details!.value.triggerExtent);
      fixture.completer.complete();
      await tester.pump();
      expect(fixture.status, RefreshIndicatorStatus.done);
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
    });

    testWidgets('立即完成后在停靠途中卸载会取消动画', (tester) async {
      final fixture = _Fixture(android: true, refreshImmediately: true);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());
      final gesture = await _drag(tester, [35, 240]);
      await gesture.up();
      await tester.pump();
      await tester.pumpWidget(SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('悬浮式', () {
    testWidgets('未达阈值、拉回阈值内、取消都不触发刷新，正文位置不动', (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());
      expect(fixture.status, isNull);

      final first = await _drag(tester, [35, 35]);
      expect(fixture.status, RefreshIndicatorStatus.armed);
      expect(fixture.pulled, 70);
      expect(fixture.controller.offset, 0);
      expect(_contentShift(tester), 0);
      expect(tester.getRect(_indicator), tester.getRect(_scroll), reason: '指示器铺满视口');

      await first.moveBy(Offset(0, -25));
      await tester.pump();
      expect(fixture.status, RefreshIndicatorStatus.drag);
      await first.up();
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
      expect(fixture.pulled, 0);

      final second = await _drag(tester, [35, 65]);
      expect(fixture.status, RefreshIndicatorStatus.armed);
      await second.cancel();
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
      expect(fixture.refreshCount, 0);
    });

    testWidgets('armed 松手触发一次刷新，完成后收起', (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());

      final gesture = await _drag(tester, [35, 65]);
      await gesture.up();
      expect(fixture.refreshCount, 1);
      expect(fixture.status, RefreshIndicatorStatus.refresh);
      await tester.pumpAndSettle();
      expect(fixture.pulled, 60, reason: '停在 refreshingExtent');
      expect(fixture.controller.offset, 0);

      fixture.completer.complete();
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
      expect(fixture.pulled, 0);
      expect(fixture.refreshCount, 1);
    });

    testWidgets('正文先回到顶，同一段位移的余量才进入刷新；反向先收回拉距', (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());
      fixture.controller.jumpTo(30);
      await tester.pump();

      final gesture = await _drag(tester, [25, 50]);
      expect(fixture.controller.offset, 0);
      expect(fixture.pulled, closeTo(45, 0.01));
      await gesture.moveBy(Offset(0, -20));
      await tester.pump();
      expect(fixture.pulled, closeTo(25, 0.01));
      expect(fixture.controller.offset, 0);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(fixture.refreshCount, 0);
    });

    testWidgets('惯性撞到顶部不会拉出刷新', (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());
      fixture.controller.jumpTo(300);
      await tester.pump();
      final seen = <RefreshIndicatorStatus?>[];
      fixture.details!.addListener(() => seen.add(fixture.status));

      await tester.fling(_scroll, Offset(0, 200), 2000);
      await tester.pumpAndSettle();
      expect(fixture.controller.offset, 0);
      expect(seen, isEmpty);
      expect(fixture.refreshCount, 0);
    });

    testWidgets('内容不足一屏也能拉出', (tester) async {
      final fixture = _Fixture(contentHeight: 40);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());
      expect(fixture.controller.position.maxScrollExtent, 0);

      final gesture = await _drag(tester, [35, 65]);
      expect(fixture.status, RefreshIndicatorStatus.armed);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
    });

    testWidgets('控制器显示并程序触发一次完整刷新', (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());

      fixture.refreshController.show();
      fixture.refreshController.show();
      expect(fixture.refreshCount, 1);
      await tester.pumpAndSettle();
      expect(fixture.status, RefreshIndicatorStatus.refresh);
      expect(fixture.pulled, 60);

      fixture.completer.complete();
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
    });

    testWidgets('关闭后旧请求完成不会收起新一轮刷新', (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final second = Completer<void>();
      await tester.pumpWidget(fixture.build(reload: () => second.future));

      fixture.refreshController.show();
      await tester.pumpAndSettle();
      fixture.refreshController.close();
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);

      fixture.refreshController.show();
      fixture.completer.complete();
      await tester.pumpAndSettle();
      expect(fixture.refreshCount, 2);
      expect(fixture.status, RefreshIndicatorStatus.refresh);

      second.complete();
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
      await tester.pumpWidget(SizedBox.shrink());
      fixture.refreshController.show();
      fixture.refreshController.close();
      expect(fixture.refreshCount, 2);
    });

    testWidgets('外层折叠头：拉出排在它之后，收回排在它之前', (tester) async {
      final fixture = _Fixture();
      final header = _Header();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build(parent: header));

      final gesture = await _drag(tester, [40, 40]);
      expect(fixture.pulled, 80);
      await gesture.moveBy(Offset(0, -30));
      await tester.pump();
      expect(fixture.pulled, 50);
      expect(header.collapsed, 0, reason: '拉距收完之前折叠头不动');

      await gesture.moveBy(Offset(0, -60));
      await tester.pump();
      expect(fixture.status, isNull);
      expect(header.collapsed, 10);
      expect(fixture.controller.offset, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fixture.refreshCount, 0);
    });
  });

  group('内容让位式', () {
    testWidgets('间隙是真实占位：正文被推开而滚动位置不越界，松手停靠，完成后收回', (tester) async {
      final fixture = _Fixture(movesContent: true);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());

      final gesture = await _drag(tester, [100, 100]);
      expect(fixture.status, RefreshIndicatorStatus.armed);
      expect(fixture.pulled, inExclusiveRange(60, 150), reason: '带阻尼，且不超过 maxPullExtent');
      expect(fixture.controller.offset, 0);
      expect(_contentShift(tester), closeTo(fixture.pulled, 0.01));
      expect(tester.getRect(_indicator), tester.getRect(_scroll));

      await gesture.up();
      expect(fixture.refreshCount, 1);
      await tester.pumpAndSettle();
      expect(fixture.pulled, 60);
      expect(_contentShift(tester), closeTo(60, 0.01));
      expect(fixture.controller.position.maxScrollExtent, closeTo(60 + 1200 - 460, 0.01));

      fixture.completer.complete();
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
      expect(_contentShift(tester), 0);
      expect(fixture.controller.offset, 0);
    });

    testWidgets('刷新期间正文已经滚走，完成收回时屏幕上的正文不跳', (tester) async {
      final fixture = _Fixture(movesContent: true);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());

      final gesture = await _drag(tester, [100, 100]);
      await gesture.up();
      await tester.pumpAndSettle();
      fixture.controller.jumpTo(160);
      await tester.pump();
      expect(_contentShift(tester), closeTo(-100, 0.01));

      fixture.completer.complete();
      await tester.pumpAndSettle();
      expect(fixture.status, isNull);
      expect(_contentShift(tester), closeTo(-100, 0.01));
      expect(fixture.controller.offset, closeTo(100, 0.01));
    });
  });
}
