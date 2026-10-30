import 'dart:async';

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _AndroidProbe extends ElAndroidRefresher {
  _AndroidProbe();
  late ElRefreshDetails details;
  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    this.details = details;
    return super.buildIndicator(context, details);
  }
}

class _IosProbe extends ElIosRefresher {
  _IosProbe();
  late ElRefreshDetails details;
  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    this.details = details;
    return super.buildIndicator(context, details);
  }
}

ElRefreshDetails _details(ElRefresher refresher) =>
    refresher is _IosProbe ? refresher.details : (refresher as _AndroidProbe).details;

Widget _shell({
  required ScrollController controller,
  required ScrollPhysics physics,
  required ElRefresher refresher,
  required Future<void> Function() onRefresh,
  Axis axis = Axis.vertical,
  bool reverse = false,
  ElRefreshEdge edge = ElRefreshEdge.leading,
  bool Function(ScrollNotification)? onNotification,
}) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(
      style: ElStyle(width: 300, height: 400),
      child: NotificationListener<ScrollNotification>(
        onNotification: onNotification,
        child: ElScrollView(
          controller: controller,
          physics: physics,
          axis: axis,
          reverse: reverse,
          refreshEdge: edge,
          scrollbar: ElNoScrollBar(),
          refresher: refresher,
          onRefresh: onRefresh,
          children: [ElView(style: ElStyle(width: 1000, height: 1600))],
        ),
      ),
    ),
  ),
);

void main() {
  for (final bouncing in [false, true]) {
    for (final ios in [false, true]) {
      testWidgets('bouncing=$bouncing ios=$ios 接住惯性越界后反甩，间隙未闭合也应延续向内动量', (tester) async {
        final controller = ElScrollController();
        final ElRefresher refresher = ios ? _IosProbe() : _AndroidProbe();
        await tester.pumpWidget(
          _shell(
            controller: controller,
            physics: bouncing ? ElBouncingScrollPhysics() : ElClampingScrollPhysics(),
            refresher: refresher,
            onRefresh: () async {},
          ),
        );
        var stamp = Duration.zero;
        if (bouncing) {
          controller.jumpTo(100);
          await tester.pump();
          (controller.position as ScrollPositionWithSingleContext).goBallistic(-12000);
          for (var i = 0; i < 30 && controller.offset > -150; i++) {
            await tester.pump(Duration(milliseconds: 16));
          }
          stamp = tester.binding.currentSystemFrameTimeStamp;
        }
        final gesture = await tester.createGesture();
        await gesture.down(Offset(150, 200), timeStamp: stamp);
        Future<void> move(double delta) async {
          stamp += Duration(milliseconds: 16);
          await gesture.moveBy(Offset(0, delta), timeStamp: stamp);
          await tester.pump(Duration(milliseconds: 16));
        }

        await move(30);
        await move(40);
        for (var i = 0; i < 4; i++) {
          await move(-12);
        }
        final releasedAt = controller.offset;
        await gesture.up(timeStamp: stamp + Duration(milliseconds: 1));
        for (var i = 0; i < 55; i++) {
          await tester.pump(Duration(milliseconds: 16));
        }
        final afterRelease = controller.offset;
        await tester.pumpAndSettle();
        await tester.pumpWidget(SizedBox.shrink());
        controller.dispose();
        if (bouncing) expect(releasedAt, lessThan(-20), reason: '录屏回归：松手时仍有惯性越界留下的间隙');
        expect(afterRelease, greaterThan(20), reason: '向内甩动应穿过边界继续滚，不能被刷新收回动画截停');
      });
      for (final armed in [false, true]) {
        testWidgets('bouncing=$bouncing ios=$ios armed=$armed 下拉后反向回到正文，松手惯性不能被刷新吞掉', (tester) async {
          final controller = ElScrollController();
          final ElRefresher refresher = ios ? _IosProbe() : _AndroidProbe();
          var refreshes = 0;
          await tester.pumpWidget(
            _shell(
              controller: controller,
              physics: bouncing ? ElBouncingScrollPhysics() : ElClampingScrollPhysics(),
              refresher: refresher,
              onRefresh: () async {
                refreshes++;
              },
            ),
          );
          var stamp = Duration.zero;
          final gesture = await tester.createGesture();
          await gesture.down(Offset(150, 180), timeStamp: stamp);
          Future<void> move(double delta) async {
            stamp += Duration(milliseconds: 16);
            await gesture.moveBy(Offset(0, delta), timeStamp: stamp);
            await tester.pump(Duration(milliseconds: 16));
          }

          await move(30);
          await move(armed ? 160 : 40);
          final pullStatus = _details(refresher).snapshot.value.status;
          await move(armed ? -260 : -80);
          final recovered = _details(refresher).snapshot.value;
          for (var i = 0; i < 4; i++) {
            await move(-30);
          }
          final releasedAt = controller.offset;
          await gesture.up(timeStamp: stamp + Duration(milliseconds: 1));
          for (var i = 0; i < 8; i++) {
            await tester.pump(Duration(milliseconds: 16));
          }
          final afterRelease = controller.offset;
          await tester.pumpAndSettle();
          await tester.pumpWidget(SizedBox.shrink());
          controller.dispose();

          expect(pullStatus, armed ? RefreshIndicatorStatus.armed : RefreshIndicatorStatus.drag);
          expect(releasedAt, greaterThan(80));
          expect(afterRelease, greaterThan(releasedAt + 20), reason: '反向回到正文后，松手必须沿容器物理继续惯性滚动');
          expect(recovered.status, isNull, reason: '真实间隙归零必须在同一拖拽中清除旧刷新状态');
          expect(recovered.pulledExtent, 0);
          expect(refreshes, 0, reason: '已经撤回的 armed 不能在松手时误触发刷新');
        });
      }
      for (final axis in Axis.values) {
        for (final reverse in [false, true]) {
          for (final edge in ElRefreshEdge.values) {
            testWidgets('bouncing=$bouncing ios=$ios $axis reverse=$reverse $edge 下拉与停靠独立于物理', (tester) async {
              final controller = ElScrollController();
              final physics = bouncing ? ElBouncingScrollPhysics() : ElClampingScrollPhysics();
              final ElRefresher refresher = ios ? _IosProbe() : _AndroidProbe();
              final completed = Completer<void>();
              var refreshes = 0;
              await tester.pumpWidget(
                _shell(
                  controller: controller,
                  physics: physics,
                  refresher: refresher,
                  axis: axis,
                  reverse: reverse,
                  edge: edge,
                  onRefresh: () {
                    refreshes++;
                    return completed.future;
                  },
                ),
              );
              final boundary = edge == .leading
                  ? controller.position.minScrollExtent
                  : controller.position.maxScrollExtent;
              controller.jumpTo(boundary);
              await tester.pump();
              expect(_details(refresher).physics, same(physics));
              final sign =
                  (edge == .leading ? 1.0 : -1.0) *
                  (axisDirectionIsReversed(controller.position.axisDirection) ? -1.0 : 1.0);
              Offset delta(double distance) =>
                  axis == .vertical ? Offset(0, distance * sign) : Offset(distance * sign, 0);
              final gesture = await tester.startGesture(Offset(150, 200));
              for (var i = 0; i < 9; i++) {
                await gesture.moveBy(delta(40));
                await tester.pump(Duration(milliseconds: 16));
              }
              expect(_details(refresher).snapshot.value.progress, 1);
              expect(refreshes, 0);
              if (ios) {
                expect((controller.offset - boundary).abs(), greaterThan(100));
              } else {
                expect(controller.offset, boundary);
              }
              await gesture.up(timeStamp: Duration(seconds: 2));
              for (var i = 0; i < 45; i++) {
                await tester.pump(Duration(milliseconds: 16));
              }
              expect(refreshes, 1);
              expect(controller.offset, closeTo(boundary + (ios ? (edge == .leading ? -60 : 60) : 0), .5));
              completed.complete();
              await tester.pumpAndSettle();
              expect(controller.offset, closeTo(boundary, .01));
              expect(_details(refresher).snapshot.value.status, isNull);
              await tester.pumpWidget(SizedBox.shrink());
              controller.dispose();
            });
          }
        }
      }

      testWidgets('bouncing=$bouncing ios=$ios 惯性保留边界效果，触摸立即接管', (tester) async {
        final controller = ElScrollController();
        final physics = bouncing ? ElBouncingScrollPhysics() : ElClampingScrollPhysics();
        final ElRefresher refresher = ios ? _IosProbe() : _AndroidProbe();
        var overscrolls = 0;
        var refreshes = 0;
        await tester.pumpWidget(
          _shell(
            controller: controller,
            physics: physics,
            refresher: refresher,
            onRefresh: () async {
              refreshes++;
            },
            onNotification: (notification) {
              if (notification is OverscrollNotification && notification.velocity != 0) overscrolls++;
              return false;
            },
          ),
        );
        controller.jumpTo(100);
        await tester.pump();
        (controller.position as ScrollPositionWithSingleContext).goBallistic(-2000);
        for (var i = 0; i < 20 && (bouncing ? controller.offset >= 0 : overscrolls == 0); i++) {
          await tester.pump(Duration(milliseconds: 16));
        }
        if (bouncing) {
          expect(controller.offset, lessThan(0), reason: '惯性必须继续真实回弹');
        } else {
          expect(overscrolls, greaterThan(0), reason: '惯性越界必须保留拉伸输入');
          expect(controller.offset, 0);
        }
        expect(_details(refresher).snapshot.value.status, isNull);
        expect(refreshes, 0);
        final gesture = await tester.startGesture(Offset(150, 100));
        final held = controller.offset;
        await gesture.moveBy(Offset(0, 30));
        await gesture.moveBy(Offset(0, 40));
        await tester.pump(Duration(milliseconds: 16));
        expect(_details(refresher).snapshot.value.pulledExtent, greaterThan(0));
        if (!ios) expect(controller.offset, held, reason: '圆盘下拉不得加深原有惯性越界');
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(controller.offset, closeTo(0, .01));
        expect(refreshes, 0);
        expect(_details(refresher).snapshot.value.status, isNull);
        await tester.pumpWidget(SizedBox.shrink());
        controller.dispose();
      });
    }
  }
  for (final bouncing in [false, true]) {
    for (final ios in [false, true]) {
      for (final initialInner in [0.0, 40.0]) {
        testWidgets('bouncing=$bouncing ios=$ios start=$initialInner 内层下拉先刷新，外层不抢手势', (tester) async {
          final outer = ElScrollController();
          final inner = ElScrollController();
          final completed = Completer<void>();
          final ElRefresher refresher = ios ? _IosProbe() : _AndroidProbe();
          var refreshes = 0;
          await tester.pumpWidget(
            Directionality(
              textDirection: .ltr,
              child: Align(
                alignment: .topLeft,
                child: ElView(
                  style: ElStyle(width: 300, height: 320),
                  child: ElScrollView(
                    controller: outer,
                    physics: ElClampingScrollPhysics(),
                    scrollbar: ElNoScrollBar(),
                    children: [
                      ElView(style: ElStyle(height: 100)),
                      ElView(
                        style: ElStyle(height: 240),
                        child: ElScrollView(
                          controller: inner,
                          physics: bouncing ? ElBouncingScrollPhysics() : ElClampingScrollPhysics(),
                          scrollbar: ElNoScrollBar(),
                          refresher: refresher,
                          onRefresh: () {
                            refreshes++;
                            return completed.future;
                          },
                          children: [ElView(style: ElStyle(height: 1000))],
                        ),
                      ),
                      ElView(style: ElStyle(height: 1000)),
                    ],
                  ),
                ),
              ),
            ),
          );
          outer.jumpTo(100);
          inner.jumpTo(initialInner);
          await tester.pump();
          final gesture = await tester.startGesture(Offset(140, 60));
          await gesture.moveBy(Offset(0, 30));
          for (var i = 0; i < 9; i++) {
            await gesture.moveBy(Offset(0, 40));
            await tester.pump(Duration(milliseconds: 16));
          }
          expect(outer.offset, 100, reason: '内层刷新边界必须先于外层正文消费');
          expect(inner.offset, ios ? lessThan(-100) : 0);
          expect(_details(refresher).snapshot.value.progress, 1);
          await gesture.up(timeStamp: Duration(seconds: 1));
          await tester.pump(Duration(milliseconds: 300));
          expect(refreshes, 1);
          completed.complete();
          await tester.pumpAndSettle();
          expect(outer.offset, 100);
          expect(inner.offset, closeTo(0, .01));
          inner.jumpTo(inner.position.maxScrollExtent);
          await tester.pump();
          final upward = await tester.startGesture(Offset(140, 160));
          await upward.moveBy(Offset(0, -30));
          await upward.moveBy(Offset(0, -40));
          expect(outer.offset, greaterThan(100), reason: '非刷新边仍须允许普通嵌套交接');
          await upward.up(timeStamp: Duration(seconds: 3));
          await tester.pumpAndSettle();
          await tester.pumpWidget(SizedBox.shrink());
          outer.dispose();
          inner.dispose();
        });
      }
    }
  }
}
