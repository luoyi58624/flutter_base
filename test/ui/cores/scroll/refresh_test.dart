import 'dart:async';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/virtual_test_host.dart';

class _Refresh extends ElRefresher {
  const _Refresh() : super();
  @override
  double get triggerExtent => 100;
  @override
  double get refreshingExtent => 60;
  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) =>
      const ElView(style: ElStyle(width: 20, height: 20));
}

class _Observer extends StatefulWidget {
  const _Observer({super.key, required this.axis});
  final Axis axis;
  @override
  State<_Observer> createState() => _ObserverState();
}

class _ObserverState extends State<_Observer> with ElScrollMixin<_Observer> {
  int starts = 0;
  int ends = 0;
  @override
  void onInputStart(ElScrollSessionDetails details) {
    super.onInputStart(details);
    starts++;
  }

  @override
  void onInputEnd(ElScrollSessionDetails details) {
    super.onInputEnd(details);
    ends++;
  }

  @override
  Widget build(BuildContext context) => ElView(
    style: ElStyle(
      width: widget.axis == Axis.horizontal ? 2000 : 300,
      height: widget.axis == Axis.vertical ? 2000 : 300,
    ),
  );
}

class _CoordinatedRefreshInputRefresh extends ElRefresher {
  const _CoordinatedRefreshInputRefresh(this.capture) : super(movesContent: false);
  final ValueChanged<ElRefreshDetails> capture;
  @override
  double get triggerExtent => 100;
  @override
  double get refreshingExtent => 60;
  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    capture(details);
    return const ElView(style: ElStyle(width: 20, height: 20));
  }
}

class _Header extends StatefulWidget {
  const _Header({super.key, this.child, this.axis = Axis.vertical});
  final Widget? child;
  final Axis axis;
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with ElScrollMixin<_Header> {
  double value = 50;
  @override
  Object get scrollInputSlot => #header;
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    final accepted = rest.clamp(-value, 100 - value);
    value += accepted;
    return rest - accepted;
  }

  @override
  Widget build(BuildContext context) =>
      widget.child ??
      ElView(
        style: ElStyle(
          width: widget.axis == Axis.horizontal ? 2000 : 240,
          height: widget.axis == Axis.vertical ? 2000 : 240,
        ),
      );
}

Widget _frame(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(style: const ElStyle(width: 240, height: 240), child: child),
  ),
);

/// 还原示例页 card_list 形态：top padding + 刷新完成时 setState 重置条数
/// （80 → 40）触发重建。改常驻 children 施加同一"完成期重建"
/// 压力面（builder 虚拟形态随 M3 恢复）。
class _ExampleShell extends StatefulWidget {
  const _ExampleShell({required this.refresher, required this.controller, required this.registerComplete});

  final ElRefresher refresher;
  final ScrollController controller;
  final void Function(void Function() complete) registerComplete;

  @override
  State<_ExampleShell> createState() => _ExampleShellState();
}

class _ExampleShellState extends State<_ExampleShell> {
  int itemCount = 80;

  Future<void> handleRefresh() {
    final completer = Completer<void>();
    widget.registerComplete(() {
      setState(() => itemCount = 40);
      completer.complete();
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return ElScrollView(
      controller: widget.controller,
      padding: const EdgeInsets.only(top: 8),
      refresher: widget.refresher,
      onRefresh: handleRefresh,
      children: [for (var i = 0; i < itemCount; i++) SizedBox(height: 40, child: const SizedBox.shrink())],
    );
  }
}

/// 固定高指示器（小间隙裁剪测试用）：28 高，key 可定位。
Widget _buildFixedIndicator(BuildContext context, ElRefreshDetails details) {
  return IgnorePointer(
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(key: const ValueKey('fixed-indicator'), height: 28, child: const SizedBox.shrink()),
    ),
  );
}

/// clamping 形制：指示器浮在内容之上（原 ElAndroidRefresher 层级），
/// 拉出期整棵内容子树退出命中路径（他指按下拿不到卡片）。
final class _ClampingRefresher extends ElRefresher {
  const _ClampingRefresher() : super(movesContent: false);

  @override
  double get triggerExtent => 100.0;

  @override
  double get refreshingExtent => 100.0;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    return IgnorePointer(
      child: ValueListenableBuilder<ElRefreshSnapshot>(
        valueListenable: details.snapshot,
        builder: (context, snapshot, _) {
          if (snapshot.status == null) return const SizedBox.shrink();
          return const SizedBox.expand();
        },
      ),
    );
  }
}

/// 无上限变体（其余与文本刷新器同参）。
final class _UncappedRefresher extends ElRefresher {
  const _UncappedRefresher() : super();

  @override
  double get triggerExtent => 70.0;
  @override
  double get refreshingExtent => 70.0;
  @override
  double? get maxPullExtent => null;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) =>
      const IgnorePointer(child: SizedBox.expand());
}

/// 官方弹簧变体（settleSpring 关闭，退回 Flutter 过阻尼弹簧）。
final class _OfficialSpringRefresher extends ElRefresher {
  const _OfficialSpringRefresher() : super();

  @override
  double get triggerExtent => 70.0;
  @override
  double get refreshingExtent => 70.0;
  @override
  SpringDescription? get settleSpring => null;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) =>
      const IgnorePointer(child: SizedBox.expand());
}

/// 记录状态流转序列的无视觉探针。
final class _ProbeRefresher extends ElRefresher {
  _ProbeRefresher({super.movesContent = false});

  final List<RefreshIndicatorStatus?> statuses = <RefreshIndicatorStatus?>[];
  ElRefreshSnapshot? lastSnapshot;

  @override
  double get triggerExtent => 64.0;

  @override
  double get refreshingExtent => 48.0;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    return IgnorePointer(
      child: ValueListenableBuilder<ElRefreshSnapshot>(
        valueListenable: details.snapshot,
        builder: (context, snapshot, _) {
          lastSnapshot = snapshot;
          if (statuses.isEmpty || statuses.last != snapshot.status) statuses.add(snapshot.status);
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// 引擎行为测试的默认形态刷新器（替代已迁 element_plus 的 iOS 形制）：
/// WebKit 弹簧 / bouncing 物理 / trigger 100 / 停靠 60 / 上限 2.5×。
///
/// 形制专项测试见 element_plus 的 test/refresher/；本类只当"带默认策略的
/// 无视觉刷新器"载体，测的是引擎机制不是皮肤。
final class _DefaultRefresher extends ElRefresher {
  const _DefaultRefresher() : super();

  @override
  double get triggerExtent => 100.0;

  @override
  double get refreshingExtent => 60.0;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    return IgnorePointer(
      child: ValueListenableBuilder<ElRefreshSnapshot>(
        valueListenable: details.snapshot,
        builder: (context, snapshot, _) {
          if (snapshot.status == null) return const SizedBox.shrink();
          return const SizedBox(key: ValueKey('test-refresher-indicator'), child: SizedBox.expand());
        },
      ),
    );
  }
}

void main() {
  group('协同刷新停靠', () {
    for (final axis in Axis.values) {
      for (final direction in axis == Axis.horizontal ? TextDirection.values : [TextDirection.ltr]) {
        for (final reverse in [false, true]) {
          for (final edge in ElRefreshEdge.values) {
            for (final earlyCompletion in [false, true]) {
              testWidgets('$axis $direction reverse=$reverse $edge early=$earlyCompletion 协同刷新完成回位', (tester) async {
                final controller = ElScrollController();
                addTearDown(controller.dispose);
                final observer = GlobalKey<_ObserverState>();
                final completion = Completer<void>();
                var refreshes = 0;
                await tester.pumpWidget(
                  Directionality(
                    textDirection: direction,
                    child: Align(
                      alignment: .topLeft,
                      child: ElView(
                        style: const ElStyle(width: 300, height: 300),
                        child: ElScrollView(
                          axis: axis,
                          controller: controller,
                          reverse: reverse,
                          refreshEdge: edge,
                          refresher: const _Refresh(),
                          onRefresh: () {
                            refreshes++;
                            return completion.future;
                          },
                          scrollbar: const ElNoScrollBar(),
                          children: [_Observer(key: observer, axis: axis)],
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pump();
                final boundary = edge == ElRefreshEdge.leading
                    ? controller.position.minScrollExtent
                    : controller.position.maxScrollExtent;
                controller.jumpTo(boundary);
                await tester.pump();
                final sign =
                    (edge == ElRefreshEdge.leading ? 1.0 : -1.0) *
                    (axisDirectionIsReversed(controller.position.axisDirection) ? -1 : 1);
                Offset delta(double value) => axis == Axis.vertical ? Offset(0, sign * value) : Offset(sign * value, 0);
                final gesture = await tester.startGesture(const Offset(150, 100));
                await gesture.moveBy(delta(30));
                for (var i = 0; i < 4; i++) {
                  await gesture.moveBy(delta(80));
                }
                await gesture.up(timeStamp: const Duration(seconds: 1));
                if (earlyCompletion) {
                  for (var frame = 0; frame < 10 && refreshes == 0; frame++) {
                    await tester.pump(const Duration(milliseconds: 16));
                  }
                  expect(controller.position.isScrollingNotifier.value, isTrue);
                } else {
                  await tester.pumpAndSettle();
                  expect(controller.offset, closeTo(boundary + (edge == ElRefreshEdge.leading ? -60 : 60), 1));
                }
                expect(refreshes, 1);
                expect(observer.currentState!.starts, 1);
                expect(observer.currentState!.ends, 1);
                completion.complete();
                await tester.pumpAndSettle();
                expect(controller.offset, closeTo(boundary, .01));
                expect(controller.position.outOfRange, isFalse);
                expect(controller.position.isScrollingNotifier.value, isFalse);
                expect(observer.currentState!.starts, 1);
                expect(observer.currentState!.ends, 1);
                expect(tester.takeException(), isNull);
              });
            }
          }
        }
      }
    }
  });

  group('协同刷新输入', () {
    for (final axis in Axis.values) {
      for (final reverse in [false, true]) {
        for (final edge in ElRefreshEdge.values) {
          for (final direction in axis == Axis.horizontal ? TextDirection.values : [TextDirection.ltr]) {
            testWidgets('$axis reverse=$reverse $edge $direction 刷新边缘预算与恢复方向一致', (tester) async {
              final controller = ElScrollController();
              addTearDown(controller.dispose);
              late ElRefreshDetails refresh;
              final key = GlobalKey<_HeaderState>();
              await tester.pumpWidget(
                Directionality(
                  textDirection: direction,
                  child: Align(
                    alignment: .topLeft,
                    child: ElView(
                      style: const ElStyle(width: 240, height: 240),
                      child: ElScrollView(
                        axis: axis,
                        reverse: reverse,
                        controller: controller,
                        refreshEdge: edge,
                        refresher: _CoordinatedRefreshInputRefresh((value) => refresh = value),
                        onRefresh: () async {},
                        scrollbar: const ElNoScrollBar(),
                        children: [_Header(key: key, axis: axis)],
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              final boundary = edge == ElRefreshEdge.leading
                  ? controller.position.minScrollExtent
                  : controller.position.maxScrollExtent;
              controller.jumpTo(boundary);
              await tester.pump();
              final inverted = axisDirectionIsReversed(controller.position.axisDirection);
              final pullSign = (edge == ElRefreshEdge.leading ? 1.0 : -1.0) * (inverted ? -1 : 1);
              Offset delta(double value) =>
                  axis == Axis.vertical ? Offset(0, value * pullSign) : Offset(value * pullSign, 0);
              final gesture = await tester.startGesture(const Offset(120, 100));
              await gesture.moveBy(delta(30));
              await gesture.moveBy(delta(20));
              expect(key.currentState!.value, 50 - pullSign * 20);
              expect(refresh.snapshot.value.pulledExtent, 0);
              await gesture.moveBy(delta(40));
              expect(key.currentState!.value, pullSign > 0 ? 0 : 100);
              expect(refresh.snapshot.value.pulledExtent, 10);
              await gesture.moveBy(delta(-6));
              expect(refresh.snapshot.value.pulledExtent, 4);
              expect(key.currentState!.value, pullSign > 0 ? 0 : 100);
              await gesture.up(timeStamp: const Duration(seconds: 1));
              await tester.pumpAndSettle();
              expect(refresh.snapshot.value.pulledExtent, 0);
              expect(controller.offset, boundary);
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }

    for (final nested in [false, true]) {
      testWidgets('nested=$nested 新刷新只接最终余量，已有拉出优先于 header', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final outerHeader = GlobalKey<_HeaderState>();
        final innerHeader = GlobalKey<_HeaderState>();
        late ElRefreshDetails refresh;
        var refreshes = 0;
        await tester.pumpWidget(
          _frame(
            ElScrollView(
              controller: controller,
              refresher: _CoordinatedRefreshInputRefresh((value) => refresh = value),
              onRefresh: () async => refreshes++,
              scrollbar: const ElNoScrollBar(),
              children: [
                _Header(
                  key: outerHeader,
                  child: nested
                      ? ElView(
                          style: const ElStyle(height: 240),
                          child: ElScrollView(
                            physics: const ElClampingScrollPhysics(),
                            scrollbar: const ElNoScrollBar(),
                            children: [_Header(key: innerHeader)],
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        final gesture = await tester.startGesture(const Offset(120, 100));
        await gesture.moveBy(const Offset(0, 30));
        await gesture.moveBy(const Offset(0, 20));
        expect(outerHeader.currentState!.value, 30);
        expect(refresh.snapshot.value.pulledExtent, 0);
        await gesture.moveBy(Offset(0, nested ? 90 : 40));
        expect(outerHeader.currentState!.value, 0);
        if (nested) expect(innerHeader.currentState!.value, 0);
        expect(refresh.snapshot.value.pulledExtent, 10);
        await gesture.moveBy(const Offset(0, -6));
        expect(refresh.snapshot.value.pulledExtent, 4);
        expect(outerHeader.currentState!.value, 0);
        if (nested) expect(innerHeader.currentState!.value, 0);
        await gesture.up(timeStamp: const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(refresh.snapshot.value.pulledExtent, 0);
        expect(refreshes, 0);
        expect(controller.offset, 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('空正文也能下拉刷新，取消不触发 armed 的刷新请求', (tester) async {
      late ElRefreshDetails refresh;
      var refreshes = 0;
      await tester.pumpWidget(
        _frame(
          ElScrollView(
            refresher: _CoordinatedRefreshInputRefresh((value) => refresh = value),
            onRefresh: () async => refreshes++,
            scrollbar: const ElNoScrollBar(),
            children: const [],
          ),
        ),
      );
      await tester.pump();
      final gesture = await tester.startGesture(const Offset(120, 80));
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 120));
      expect(refresh.snapshot.value.pulledExtent, 120);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(refreshes, 0);
      expect(refresh.snapshot.value.pulledExtent, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('刷新结束回落', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 300, height: 400, child: child),
        ),
      );
    }

    Future<void> pullAndRelease(WidgetTester tester) async {
      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      for (var i = 0; i < 14; i++) {
        await gesture.moveBy(const Offset(0, 48));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
    }

    Future<void> expectMonotonicReturnAndSettle(
      WidgetTester tester,
      ScrollController controller, {
      required Finder indicator,
      int frames = 90,
    }) async {
      final trace = <double>[controller.position.pixels];
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        trace.add(controller.position.pixels);
      }
      for (var i = 1; i < trace.length; i++) {
        expect(
          trace[i],
          greaterThanOrEqualTo(trace[i - 1] - 0.01),
          reason:
              '结束段第 $i 帧回退（回弹）：${trace[i - 1].toStringAsFixed(2)} → ${trace[i].toStringAsFixed(2)}；'
              '全程 $trace',
        );
        expect(trace[i], lessThanOrEqualTo(0.01), reason: '结束段第 $i 帧越过顶边冲进内容区；全程 $trace');
      }
      expect(trace.last, closeTo(0.0, 0.01), reason: '送回必须落在真实边界');
      // 终态再泵 30 帧：不许出现二次回弹 / 指示器复现。
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(controller.position.pixels, closeTo(0.0, 0.01), reason: '终态第 $i 帧 pixels 漂移（二次回弹）');
      }
      expect(indicator, findsNothing, reason: '终态指示器必须卸载');
    }

    testWidgets('示例页还原（默认形态）：完成时重置条数重建，送回不回弹', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late void Function() completeRefresh;
      await tester.pumpWidget(
        wrap(
          _ExampleShell(
            refresher: const _DefaultRefresher(),
            controller: controller,
            registerComplete: (c) => completeRefresh = c,
          ),
        ),
      );
      await tester.pump();

      await pullAndRelease(tester);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.position.pixels, closeTo(-60.0, 1.0), reason: '默认停靠位 = -60');

      completeRefresh();
      await tester.pump();
      expect(controller.position.pixels, closeTo(-60.0, 1.0), reason: '重建帧停靠内容被模型修正钉回 0（闪跳）');
      await expectMonotonicReturnAndSettle(
        tester,
        controller,
        indicator: find.byKey(const ValueKey('test-refresher-indicator')),
      );
    });
  });

  group('刷新层序', () {
    Widget shell({
      required ScrollController controller,
      required ElRefresher refresher,
      Future<void> Function()? onRefresh,
      bool reverse = false,
      ElRefreshEdge edge = ElRefreshEdge.leading,
    }) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 400,
            child: ElScrollView(
              controller: controller,
              reverse: reverse,
              refresher: refresher,
              onRefresh: onRefresh ?? () async {},
              refreshEdge: edge,
              children: [for (var i = 0; i < 40; i++) SizedBox(height: 40, child: const SizedBox.shrink())],
            ),
          ),
        ),
      );
    }

    List<RenderObject> hostPaintOrder(WidgetTester tester) {
      final result = <RenderObject>[];
      tester.renderObject(find.byType(RefreshHost)).visitChildrenForSemantics(result.add);
      return result;
    }

    bool containsRender(RenderObject root, RenderObject target) {
      for (RenderObject? node = target; node != null; node = node.parent) {
        if (identical(node, root)) return true;
      }
      return false;
    }

    Future<TestGesture> pullOut(WidgetTester tester, {int steps = 14}) async {
      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(const Offset(0, 48));
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    testWidgets('bouncing 刷新器沉在内容之下：指示器先绘制且被间隙裁剪包裹', (tester) async {
      final refreshers = <ElRefresher>[
        const _DefaultRefresher(),
        ElCustomRefresher(
          triggerExtent: 64,
          movesContent: true,
          builder: (context, details) => const IgnorePointer(child: SizedBox.expand()),
        ),
      ];
      for (final refresher in refreshers) {
        final controller = ScrollController();
        await tester.pumpWidget(shell(controller: controller, refresher: refresher));
        await tester.pump();

        final order = hostPaintOrder(tester);
        expect(order, hasLength(2));
        // 首位 = 最底层：指示器；末位：滚动内容。列表回位时盖过指示器。
        expect(order.first, isA<RenderRefreshGapClip>(), reason: '$refresher 的指示器必须垫底且被间隙裁剪包裹');
        expect(order.last, isNot(isA<RenderRefreshGapClip>()), reason: '滚动内容层不得混入指示器');
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });

    testWidgets('clamping 刷新器指示器浮在内容之上：指示器后绘制、无间隙裁剪', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: const ElCustomRefresher(
            triggerExtent: 100,
            refreshingExtent: 100,
            movesContent: false,
            builder: _buildFixedIndicator,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RefreshGapClip), findsNothing, reason: 'clamping 指示器不参与间隙裁剪');
      final order = hostPaintOrder(tester);
      expect(order, hasLength(2));
      final indicator = tester.renderObject(find.byKey(const ValueKey('fixed-indicator')));
      expect(containsRender(order.last, indicator), isTrue, reason: '指示器必须在内容之上');
      expect(containsRender(order.first, indicator), isFalse, reason: '滚动内容必须垫底');

      // 行为面：clamping 拉出期内容钉在边界（pixels 恒 0），指示器独立浮出于
      // 首行之上——只有浮在内容上层才可能可见。
      final gesture = await pullOut(tester);
      expect(controller.position.pixels, 0.0, reason: 'clamping 内容不位移');
      expect(find.byKey(const ValueKey('fixed-indicator')), findsOneWidget);
      await gesture.up();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    testWidgets('间隙裁剪逐帧贴合：拉出/停靠/收起全程不越入内容区', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late void Function() completeRefresh;
      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: const _DefaultRefresher(),
          onRefresh: () {
            final completer = Completer<void>();
            completeRefresh = completer.complete;
            return completer.future;
          },
        ),
      );
      await tester.pump();

      RenderRefreshGapClip clip() => tester.renderObject<RenderRefreshGapClip>(find.byType(RefreshGapClip));
      double gap() => -controller.position.pixels;

      // 拖拽期：裁剪条带 = 视口顶部起、高度恰为内容让出的间隙，逐帧跟手。
      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      for (var i = 0; i < 14; i++) {
        await gesture.moveBy(const Offset(0, 48));
        await tester.pump(const Duration(milliseconds: 16));
        final rect = clip().clipRect;
        expect(rect.top, 0.0);
        expect(rect.width, 300.0);
        expect(rect.height, closeTo(gap(), 0.5), reason: '拖拽第 $i 帧裁剪条带必须贴合实际间隙');
      }
      await gesture.up();

      // 停靠段：pulled 先于内容收到 44，裁剪只会比实际间隙更保守（≤），
      // 决不越入内容区。
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(clip().clipRect.height, lessThanOrEqualTo(gap() + 0.5), reason: '停靠第 $i 帧裁剪越入内容区（指示器会画到列表上）');
      }

      // 收起段：弹簧送回中 pulled 在通知里逐帧跟随真实间隙，裁剪条带与内容
      // 间隙全程一致——间隙塌缩与列表盖过指示器完全同步（弹簧精确落点带
      // overdamped 长尾，泵足 100 帧）。
      completeRefresh();
      await tester.pump();
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(clip().clipRect.height, closeTo(gap(), 0.5), reason: '收起第 $i 帧裁剪条带与内容间隙脱钩');
      }
      expect(clip().clipRect.isEmpty, isTrue, reason: '收起完成后裁剪条带归零，指示器不可见');
    });

    testWidgets('小间隙：指示器固定高、裁剪条带矮于指示器底缘（被列表盖住逐渐揭示）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: const ElCustomRefresher(
            triggerExtent: 100,
            refreshingExtent: 60,
            movesContent: true,
            builder: _buildFixedIndicator,
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      // 小幅拉出：间隙 < 指示器底缘。
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final gapNow = -controller.position.pixels;
      expect(gapNow, greaterThan(4.0));
      expect(gapNow, lessThan(28.0), reason: '小间隙控制在指示器高度 28 内');
      // 裁剪不改变布局几何：指示器仍完整挂载。
      expect(find.byKey(const ValueKey('fixed-indicator')), findsOneWidget);
      final clip = tester.renderObject<RenderRefreshGapClip>(find.byType(RefreshGapClip));
      expect(clip.clipRect.height, closeTo(gapNow, 0.5));
      expect(clip.clipRect.height, lessThan(28.0), reason: '小间隙时指示器超出条带的部分被列表盖住');
      await gesture.up();
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    testWidgets('reverse + trailing（聊天形态）：裁剪条带挂视觉顶部', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: const _DefaultRefresher(),
          reverse: true,
          edge: ElRefreshEdge.trailing,
        ),
      );
      await tester.pump();
      // reverse 列表初始停在 min 边（视觉底部）；先滚到 max 边（视觉顶部）。
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      for (var i = 0; i < 14; i++) {
        await gesture.moveBy(const Offset(0, 48));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final clip = tester.renderObject<RenderRefreshGapClip>(find.byType(RefreshGapClip));
      final gap = controller.position.pixels - controller.position.maxScrollExtent;
      expect(gap, greaterThan(0.0), reason: 'trailing 边越界拉出');
      expect(clip.clipRect.top, 0.0, reason: 'trailing+reverse 的间隙在视觉顶部');
      expect(clip.clipRect.height, closeTo(gap, 0.5));
      await gesture.up();
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
  });

  group('下拉期间指针抑制', () {
    Widget shell({
      required ScrollController controller,
      required List<int> taps,
      required Future<void> Function() onRefresh,
    }) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 400,
            child: ElScrollView(
              controller: controller,
              refresher: const _ClampingRefresher(),
              onRefresh: onRefresh,
              children: [
                for (var i = 0; i < 20; i++)
                  ElView(
                    key: ValueKey('card-$i'),
                    style: const ElStyle(width: 300, height: 200),
                    event: ElEvent(onTap: (_) => taps.add(i)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('下拉把指示器拉出来再放回去：抬手不得激活卡片', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final taps = <int>[];
      var refreshes = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          taps: taps,
          onRefresh: () async {
            refreshes++;
          },
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(const Offset(150, 100), kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(0, kTouchSlop + 1));
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // 再放回去（指示器收回，手指回到起点附近，仍在同一张卡边界内）。
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(taps, isEmpty, reason: '下拉刷新手势不得落成卡片点击');
      expect(refreshes, 0, reason: '未达触发阈值，不该刷新');
    });

    testWidgets('下拉拉出后直接松手（未达阈值）：抬手不得激活卡片', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final taps = <int>[];
      await tester.pumpWidget(shell(controller: controller, taps: taps, onRefresh: () async {}));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(const Offset(150, 100), kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(0, kTouchSlop + 1));
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 3; i++) {
        await gesture.moveBy(const Offset(0, 15));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(taps, isEmpty);
    });

    testWidgets('拉出期他指触摸：内容退出命中路径', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final taps = <int>[];
      await tester.pumpWidget(shell(controller: controller, taps: taps, onRefresh: () async {}));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(const Offset(150, 100), pointer: 21, kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(0, kTouchSlop + 1));
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // 拉出期整棵内容子树必须退出命中路径（他指按下拿不到卡片）。
      final card = tester.renderObject(find.byKey(const ValueKey('card-1')));
      final targets = tester.hitTestOnBinding(const Offset(150, 300)).path.map((e) => e.target).toList();
      expect(targets, isNot(contains(card)), reason: '拉出期内容退出命中路径');

      await tester.tapAt(const Offset(150, 300), pointer: 22, kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 16));
      expect(taps, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('没拉动时卡片照常可点', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final taps = <int>[];
      await tester.pumpWidget(shell(controller: controller, taps: taps, onRefresh: () async {}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('card-0')), kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 32));
      expect(taps, [0]);
    });
  });

  group('刷新弹簧与上限', () {
    void Function()? completeRefresh;

    Widget shell(
      ScrollController controller,
      ElRefresher refresher, {
      bool reverse = false,
      ElRefreshEdge edge = ElRefreshEdge.leading,
    }) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 400,
            child: ElScrollView(
              controller: controller,
              reverse: reverse,
              refresher: refresher,
              onRefresh: () {
                final completer = Completer<void>();
                completeRefresh = completer.complete;
                return completer.future;
              },
              refreshEdge: edge,
              children: [for (var i = 0; i < 40; i++) SizedBox(height: 40, child: const SizedBox.shrink())],
            ),
          ),
        ),
      );
    }

    Future<TestGesture> dragOut(WidgetTester tester, {int steps = 20, double step = 48}) async {
      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(Offset(0, step));
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    testWidgets('maxPullExtent = null 解除上限：恢复官方橡皮筋深拉', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller, const _UncappedRefresher()));
      await tester.pump();

      final gesture = await dragOut(tester);
      expect(-controller.position.pixels, greaterThan(200.0), reason: 'null 上限必须能突破默认 175 封顶');
      await gesture.up();
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      completeRefresh?.call();
      completeRefresh = null;
      for (var i = 0; i < 130; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    testWidgets('默认刷新器上限 250：深拉封顶', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller, const _DefaultRefresher()));
      await tester.pump();

      final gesture = await dragOut(tester, steps: 30);
      expect(-controller.position.pixels, lessThanOrEqualTo(250.5), reason: '默认 2.5× 拉出封顶');
      expect(-controller.position.pixels, greaterThan(230.0));
      await gesture.up();
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      completeRefresh?.call();
      completeRefresh = null;
      for (var i = 0; i < 130; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    testWidgets('reverse + trailing（聊天形态）：上限对称作用于 max 侧', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        shell(controller, const _DefaultRefresher(), reverse: true, edge: ElRefreshEdge.trailing),
      );
      await tester.pump();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      final gesture = await dragOut(tester);
      final over = controller.position.pixels - controller.position.maxScrollExtent;
      expect(over, lessThanOrEqualTo(250.5), reason: 'trailing 边拉出同样封顶');
      expect(over, greaterThan(230.0));
      await gesture.up();
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      completeRefresh?.call();
      completeRefresh = null;
      for (var i = 0; i < 130; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    testWidgets('WebKit 弹簧 vs 官方弹簧：停靠收束快一倍多（λ=20 vs 9.1）', (tester) async {
      // 同一动作分别在两种弹簧下执行，采停靠贴合时刻。
      Future<int> framesToDock(ElRefresher refresher, {required double dock}) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(shell(controller, refresher));
        await tester.pump();
        final gesture = await dragOut(tester);
        // 静置几帧再松手：速度归零，弹簧从静止出发，计时可比。
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        var frames = -1;
        for (var i = 0; i < 90; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (frames < 0 && (controller.position.pixels + dock).abs() <= 0.5) frames = i;
        }
        expect(frames, greaterThanOrEqualTo(0), reason: '90 帧内必须停靠到位');
        completeRefresh?.call();
        completeRefresh = null;
        for (var i = 0; i < 140; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpWidget(const SizedBox.shrink());
        return frames;
      }

      final webkitFrames = await framesToDock(const _DefaultRefresher(), dock: 60.0);
      final officialFrames = await framesToDock(const _OfficialSpringRefresher(), dock: 70.0);
      expect(webkitFrames, lessThanOrEqualTo(30), reason: 'WebKit 临界阻尼 ~350ms 内贴合停靠位');
      expect(officialFrames - webkitFrames, greaterThan(8), reason: '官方过阻尼弹簧必须显著更慢（对照组证明弹簧真的换掉了）');
    });
  });

  group('刷新生命周期', () {
    Widget shell({
      required ScrollController controller,
      required ElRefresher refresher,
      required Future<void> Function() onRefresh,
      ElRefreshEdge edge = ElRefreshEdge.leading,
      bool reverse = false,
      ScrollPhysics physics = const ClampingScrollPhysics(),
    }) {
      final children = [
        for (var i = 0; i < 40; i++)
          SizedBox(key: ValueKey('refresh-row-$i'), height: 40, child: const SizedBox.shrink()),
      ];
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 400,
            child: ElScrollView(
              controller: controller,
              reverse: reverse,
              physics: physics,
              refresher: refresher,
              onRefresh: onRefresh,
              refreshEdge: edge,
              children: children,
            ),
          ),
        ),
      );
    }

    Future<void> dragFromCenter(WidgetTester tester, Offset offset, {int steps = 8}) async {
      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(offset / steps.toDouble());
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      // up 派发 ScrollEnd → 回弹动画启动需要一帧，再给足动画时长。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    }

    testWidgets('拉过阈值松手触发刷新，Future 完成后收起回 idle', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final probe = _ProbeRefresher();
      var refreshCount = 0;
      late void Function() completeRefresh;

      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: probe,
          onRefresh: () {
            refreshCount++;
            final completer = Completer<void>();
            completeRefresh = completer.complete;
            return completer.future;
          },
        ),
      );
      await tester.pump();

      // 顶部越界下拉 120px（阈值 64）
      await dragFromCenter(tester, const Offset(0, 120));
      await tester.pump();
      expect(refreshCount, 1);
      expect(probe.statuses, contains(RefreshIndicatorStatus.drag));
      expect(probe.statuses, contains(RefreshIndicatorStatus.armed));
      expect(probe.lastSnapshot!.status, RefreshIndicatorStatus.refresh);

      // 停靠动画推进
      await tester.pump(const Duration(milliseconds: 300));
      expect(probe.lastSnapshot!.pulledExtent, closeTo(probe.refreshingExtent, 1.0));

      completeRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(probe.lastSnapshot!.status, null);
      expect(probe.lastSnapshot!.pulledExtent, 0.0);
    });

    testWidgets('未达阈值松手不触发，收回 idle', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final probe = _ProbeRefresher();
      var refreshCount = 0;

      await tester.pumpWidget(shell(controller: controller, refresher: probe, onRefresh: () async => refreshCount++));
      await tester.pump();

      await dragFromCenter(tester, const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 300));
      expect(refreshCount, 0);
      expect(probe.statuses, contains(RefreshIndicatorStatus.drag));
      expect(probe.statuses, isNot(contains(RefreshIndicatorStatus.armed)));
      expect(probe.lastSnapshot!.status, null);
      expect(probe.lastSnapshot!.pulledExtent, 0.0);
    });

    testWidgets('列表中部滚动不触发任何刷新状态', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final probe = _ProbeRefresher();

      await tester.pumpWidget(shell(controller: controller, refresher: probe, onRefresh: () async {}));
      await tester.pump();
      controller.jumpTo(400);
      await tester.pump();

      await dragFromCenter(tester, const Offset(0, 120));
      // 中部下拉只是普通滚动，无越界 → 无状态流转
      expect(probe.statuses.where((s) => s != null), isEmpty);
      // 收尾：等 fling 弹道飞完再销毁树
      await tester.pumpAndSettle();
    });

    testWidgets('reverse + trailing 边：聊天页视觉顶部下拉触发', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final probe = _ProbeRefresher();
      var refreshCount = 0;

      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: probe,
          onRefresh: () async => refreshCount++,
          reverse: true,
          edge: ElRefreshEdge.trailing,
        ),
      );
      await tester.pump();
      // reverse 列表滚到 max（= 视觉顶部，最早消息处）
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      // 视觉顶部继续下拉 = pixels 越过 max
      await dragFromCenter(tester, const Offset(0, 120));
      await tester.pump();
      expect(refreshCount, 1);
      expect(probe.lastSnapshot!.edge, ElRefreshEdge.trailing);
      // reverse(up) + trailing 挂靠视觉顶部
      expect(probe.lastSnapshot!.anchoredAtViewportStart, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('bouncing 物理：越界像素直接映射拉出距离', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final probe = _ProbeRefresher(movesContent: true);
      var refreshCount = 0;

      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: probe,
          onRefresh: () async => refreshCount++,
          physics: const BouncingScrollPhysics(),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      for (var i = 0; i < 10; i++) {
        // bouncing 物理对越界施加摩擦（位移远小于手指行程），拖距要大
        await gesture.moveBy(const Offset(0, 36));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // 拖住不放时已有拉出距离（bouncing 直接位移）
      expect(probe.lastSnapshot!.pulledExtent, greaterThan(64.0));
      await gesture.up();
      // 松手触发刷新，等待停靠和刷新完成后的回位。
      await tester.pumpAndSettle();
      expect(refreshCount, 1);
      expect(probe.lastSnapshot!.status, null);
    });

    testWidgets('悬浮式自定义刷新器兼容 bouncing 容器', (tester) async {
      // 容器保留 bouncing，手指越界行程由悬浮指示器消费。
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var refreshCount = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: ElCustomRefresher(
            triggerExtent: 100,
            refreshingExtent: 60,
            movesContent: false,
            builder: (context, details) => const IgnorePointer(child: SizedBox.expand()),
          ),
          onRefresh: () async => refreshCount++,
          physics: const BouncingScrollPhysics(),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
        // clamping 特征：越界期间 pixels 恒为 0，不产生负位移
        expect(controller.position.pixels, 0.0);
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(refreshCount, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('内容让位式刷新器在 clamping 容器中产生真实负位移', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var refreshCount = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: const _DefaultRefresher(),
          onRefresh: () async => refreshCount++,
          // 容器保留 clamping，仅刷新拉出允许内容让位。
          physics: const ClampingScrollPhysics(),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(150, 200), kind: PointerDeviceKind.touch);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 36));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // bouncing 特征：越界产生真实负位移
      expect(controller.position.pixels, lessThan(0.0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(refreshCount, 1);
    });

    testWidgets('ElCustomRefresher 闭包式构造支持独立悬浮策略', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var refreshCount = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          refresher: ElCustomRefresher(
            triggerExtent: 50,
            movesContent: false,
            builder: (context, details) => IgnorePointer(
              child: ValueListenableBuilder<ElRefreshSnapshot>(
                valueListenable: details.snapshot,
                builder: (context, s, _) => s.status == null
                    ? const SizedBox.shrink()
                    : Align(alignment: Alignment.topCenter, child: Text('拉了${s.pulledExtent.round()}px')),
              ),
            ),
          ),
          onRefresh: () async => refreshCount++,
        ),
      );
      await tester.pump();

      await dragFromCenter(tester, const Offset(0, 100));
      await tester.pump();
      expect(refreshCount, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('虚拟滚动挂载同一 refresher 体系并可触发', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final probe = _ProbeRefresher();
      var refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 400,
              child: buildVirtualTestView(
                controller: controller,
                refresher: probe,
                onRefresh: () async => refreshCount++,
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(key: ValueKey('vrefresh-row-$i'), height: 40, child: const SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await dragFromCenter(tester, const Offset(0, 120));
      await tester.pump();
      expect(refreshCount, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(probe.lastSnapshot!.status, null);
    });
  });
}
