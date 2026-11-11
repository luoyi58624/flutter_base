import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  group('Drag', () {
    testWidgets('onDragDown 在按下时触发且单独声明不会启动 Drag 生命周期', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final phases = <ElEventPhase>[];
      Object? originalEvent;
      host.leafDispatcher.event = ElEvent(
        onDragDown: (event) {
          phases.add(event.phase);
          originalEvent = event.originalEvent;
        },
      );

      const down = PointerDownEvent(pointer: 70, position: Offset(12, 16), buttons: kPrimaryButton);
      host.dispatch(down);
      host.dispatch(
        const PointerMoveEvent(pointer: 70, position: Offset(80, 16), delta: Offset(68, 0), buttons: kPrimaryButton),
      );
      host.dispatch(const PointerUpEvent(pointer: 70, position: Offset(80, 16)));

      expect(phases, <ElEventPhase>[ElEventPhase.dragDown]);
      expect(originalEvent, same(down));
    });

    testWidgets('phases are start → update+ → end', (tester) async {
      // 用 createGesture 分步驱动：第 1 个 moveBy 让拖拽状态跨过 hit slop
      // 进入 accepted（仅 fire onStart，无 onUpdate），第 2 个 moveBy 在 accepted
      // state 触发 onUpdate。这是 onlyAcceptDragOnThreshold=true 后的精确语义。
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onDragStart: (e) => phases.add(e.phase),
            onDragUpdate: (e) => phases.add(e.phase),
            onDragEnd: (e) => phases.add(e.phase),
          ),
        ),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byType(ElView)));
      await gesture.moveBy(const Offset(40, 0)); // 跨 PanSlop=36 → accept + onStart
      await gesture.moveBy(const Offset(20, 0)); // accepted state → onUpdate
      await gesture.up();
      await tester.pumpAndSettle();
      expect(phases.first, ElEventPhase.dragStart);
      expect(phases.last, ElEventPhase.dragEnd);
      expect(phases.where((p) => p == ElEventPhase.dragUpdate).length, greaterThanOrEqualTo(1));
    });

    testWidgets('onDragUpdate exposes non-zero delta and growing dragOffset', (tester) async {
      final deltas = <Offset>[];
      final offsets = <Offset>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onDragStart: (_) {},
            onDragUpdate: (e) {
              deltas.add(e.delta);
              offsets.add(e.dragOffset);
            },
            onDragEnd: (_) {},
          ),
        ),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byType(ElView)));
      await gesture.moveBy(const Offset(40, 0)); // cross slop → accept
      await gesture.moveBy(const Offset(20, 0)); // onUpdate fire
      await gesture.moveBy(const Offset(20, 0)); // 再 fire onUpdate
      await gesture.up();
      await tester.pumpAndSettle();
      expect(deltas, isNotEmpty);
      expect(deltas.any((d) => d.dx != 0), isTrue);
      expect(offsets.last.dx, greaterThan(0));
    });

    testWidgets('onDragStart exposes direction inferred after threshold', (tester) async {
      final directions = <AxisDirection?>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onVerticalDragStart: (e) => directions.add(e.dragDirection),
            onVerticalDragUpdate: (e) => directions.add(e.dragDirection),
            onVerticalDragEnd: (_) {},
          ),
        ),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byType(ElView)));
      await gesture.moveBy(const Offset(0, -40));
      await gesture.moveBy(const Offset(0, -20));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(directions, isNotEmpty);
      expect(directions.every((direction) => direction == AxisDirection.up), isTrue);
    });

    testWidgets('onDragEnd carries non-zero velocity for fast drag', (tester) async {
      Velocity? captured;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onDragStart: (_) {}, onDragUpdate: (_) {}, onDragEnd: (e) => captured = e.velocity),
        ),
      );
      await tester.fling(find.byType(ElView), const Offset(60, 0), 1000);
      await tester.pumpAndSettle();
      expect(captured, isNotNull);
      expect(captured!.pixelsPerSecond.dx, isNot(0));
    });

    testWidgets('slow dragEnd below native min fling velocity reports zero velocity', (tester) async {
      Velocity? captured;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onDragStart: (_) {}, onDragUpdate: (_) {}, onDragEnd: (e) => captured = e.velocity),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byType(ElView)));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.pixelsPerSecond, Offset.zero);
    });

    testWidgets('free drag dragEnd primaryVelocity is null', (tester) async {
      ElEventDetails? captured;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onDragStart: (_) {}, onDragUpdate: (_) {}, onDragEnd: (e) => captured = e),
        ),
      );

      await tester.fling(find.byType(ElView), const Offset(60, 20), 1000);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.velocity.pixelsPerSecond.distance, greaterThan(0));
      expect(captured!.primaryVelocity, isNull);
    });

    testWidgets('onVerticalDrag* 时纯水平拖不触发 dragStart', (tester) async {
      // bug 1（轴向拖拽未生效）回归：启用垂直拖拽后，
      // 纯水平拖不应被识别。
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onVerticalDragStart: (e) => phases.add(e.phase),
            onVerticalDragUpdate: (e) => phases.add(e.phase),
            onVerticalDragEnd: (e) => phases.add(e.phase),
          ),
        ),
      );
      await tester.drag(find.byType(ElView), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(phases, isEmpty);
    });

    testWidgets('onVerticalDrag* 时垂直拖正常触发完整阶段', (tester) async {
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onVerticalDragStart: (e) => phases.add(e.phase),
            onVerticalDragUpdate: (e) => phases.add(e.phase),
            onVerticalDragEnd: (e) => phases.add(e.phase),
          ),
        ),
      );
      await tester.drag(find.byType(ElView), const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(phases.first, ElEventPhase.dragStart);
      expect(phases.last, ElEventPhase.dragEnd);
    });

    testWidgets('同一 pointer 已公开纵向 DragStart 后不得补启动横向 DragStart', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final phases = <String>[];
      host.rootDispatcher.event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onVerticalDragStart: (_) => phases.add('root-v-start'),
        onVerticalDragUpdate: (_) => phases.add('root-v-update'),
        onVerticalDragEnd: (_) => phases.add('root-v-end'),
      );
      host.leafDispatcher.event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onHorizontalDragStart: (_) => phases.add('leaf-h-start'),
        onHorizontalDragUpdate: (_) => phases.add('leaf-h-update'),
        onHorizontalDragEnd: (_) => phases.add('leaf-h-end'),
      );

      host.dispatch(const PointerDownEvent(pointer: 171, position: Offset.zero, buttons: kPrimaryButton));
      host.dispatch(
        const PointerMoveEvent(pointer: 171, position: Offset(0, 10), delta: Offset(0, 10), buttons: kPrimaryButton),
      );
      host.dispatch(
        const PointerMoveEvent(pointer: 171, position: Offset(10, 10), delta: Offset(10, 0), buttons: kPrimaryButton),
      );
      host.dispatch(
        const PointerMoveEvent(pointer: 171, position: Offset(20, 10), delta: Offset(10, 0), buttons: kPrimaryButton),
      );
      host.dispatch(const PointerUpEvent(pointer: 171, position: Offset(20, 10)));

      expect(phases, containsAllInOrder(<String>['root-v-start', 'root-v-end']));
      expect(phases, isNot(contains('leaf-h-start')), reason: '纵向 Drag 已公开后，同一 pointer 不得再补启动横向 Drag');
    });

    testWidgets('onVerticalDrag* reports primaryVelocity and removes cross-axis velocity', (tester) async {
      ElEventDetails? captured;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onVerticalDragStart: (_) {},
            onVerticalDragUpdate: (_) {},
            onVerticalDragEnd: (e) => captured = e,
          ),
        ),
      );

      await tester.fling(find.byType(ElView), const Offset(40, 80), 1000);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.velocity.pixelsPerSecond.dx, 0);
      expect(captured!.velocity.pixelsPerSecond.dy, isNot(0));
      expect(captured!.primaryVelocity, captured!.velocity.pixelsPerSecond.dy);
    });

    testWidgets('onVerticalDrag* removes cross-axis dragUpdate delta', (tester) async {
      final updates = <ElEventDetails>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onVerticalDragStart: (_) {}, onVerticalDragUpdate: updates.add, onVerticalDragEnd: (_) {}),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byType(ElView)));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(12, 20));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(updates, hasLength(1));
      expect(updates.single.delta, const Offset(0, 20));
      expect(updates.single.localDelta, const Offset(0, 20));
      expect(updates.single.dragOffset.dx, 0);
      expect(updates.single.dragOffset.dy, greaterThan(0));
    });

    testWidgets('双轴组同挂时，水平先越过容差可独占本次拖拽', (tester) async {
      final horizontalPhases = <ElEventPhase>[];
      final verticalPhases = <ElEventPhase>[];
      final updates = <ElEventDetails>[];
      Axis? startAxis;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            // pinned 锥角:测试断言接线不断言默认手感值。
            config: const ElEventConfig(dragHorizontalAngle: 0.5),
            onVerticalDragStart: (e) => verticalPhases.add(e.phase),
            onVerticalDragUpdate: (e) => verticalPhases.add(e.phase),
            onVerticalDragEnd: (e) => verticalPhases.add(e.phase),
            onHorizontalDragStart: (e) {
              horizontalPhases.add(e.phase);
              startAxis = e.dragAxis;
            },
            onHorizontalDragUpdate: (e) {
              horizontalPhases.add(e.phase);
              updates.add(e);
            },
            onHorizontalDragEnd: (e) => horizontalPhases.add(e.phase),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byType(ElView)));
      // atan2(20, 60) ≈ 0.32 rad,落在 ±0.5 水平捕获锥内;2D 距离 63 过双轴
      // 水平阈(pan slop)。
      await gesture.moveBy(const Offset(60, 20));
      await tester.pump();
      // 锁轴后交叉轴分量被投影丢弃。
      await gesture.moveBy(const Offset(30, 10));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(horizontalPhases.first, ElEventPhase.dragStart);
      expect(horizontalPhases.last, ElEventPhase.dragEnd);
      expect(startAxis, Axis.horizontal);
      expect(verticalPhases, isEmpty);
      expect(updates.single.delta, const Offset(30, 0));
      expect(updates.single.dragOffset.dy, 0);
    });

    testWidgets('单水平轴组:启动阈仍为 hit slop,不受双轴水平差异化影响', (tester) async {
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onHorizontalDragStart: (e) => phases.add(e.phase),
            onHorizontalDragUpdate: (_) {},
            onHorizontalDragEnd: (_) {},
          ),
        ),
      );

      final hitSlop = computeHitSlop(PointerDeviceKind.touch, null);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byType(ElView)));
      await gesture.moveBy(Offset(hitSlop + 2, 0));
      await tester.pump();
      expect(phases, [ElEventPhase.dragStart]);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('dragStartDistance 大于拖动距离时不触发', (tester) async {
      // bug 1（dragStartDistance 未生效）回归：gestureSettings.touchSlop=200
      // 让拖拽状态在 200px 之内不接受拖动。
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(dragStartDistance: 200),
            onDragStart: (e) => phases.add(e.phase),
            onDragUpdate: (e) => phases.add(e.phase),
            onDragEnd: (e) => phases.add(e.phase),
          ),
        ),
      );
      await tester.drag(find.byType(ElView), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(phases, isEmpty);
    });

    testWidgets('dragMaxFlingVelocity clamp fling 速度', (tester) async {
      // bug 1（fling clamp 未生效）回归：fling 5000px/s 实际 captured 应被
      // 限制在 100 附近。
      Velocity? captured;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(dragMaxFlingVelocity: 100),
            onDragStart: (_) {},
            onDragUpdate: (_) {},
            onDragEnd: (e) => captured = e.velocity,
          ),
        ),
      );
      await tester.fling(find.byType(ElView), const Offset(80, 0), 5000);
      await tester.pumpAndSettle();
      expect(captured, isNotNull);
      // 浮点松弛：clamp 到 100 含微小误差
      expect(captured!.pixelsPerSecond.distance, lessThanOrEqualTo(100.5));
      // 仍保持方向（x 为正）
      expect(captured!.pixelsPerSecond.dx, greaterThan(0));
    });

    testWidgets('dragMinFlingVelocity 高于实际速度时归零', (tester) async {
      // bug 1（fling clamp 未生效）回归：min=1e6 高于任何实际 fling 速度,
      // velocity 应归零。
      Velocity? captured;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(dragMinFlingVelocity: 1000000),
            onDragStart: (_) {},
            onDragUpdate: (_) {},
            onDragEnd: (e) => captured = e.velocity,
          ),
        ),
      );
      await tester.fling(find.byType(ElView), const Offset(60, 0), 500);
      await tester.pumpAndSettle();
      expect(captured, isNotNull);
      expect(captured!.pixelsPerSecond.distance, 0);
    });

    testWidgets('dragMinFlingDistance 高于拖动距离时归零', (tester) async {
      Velocity? captured;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(dragMinFlingDistance: 1000),
            onDragStart: (_) {},
            onDragUpdate: (_) {},
            onDragEnd: (e) => captured = e.velocity,
          ),
        ),
      );

      await tester.fling(find.byType(ElView), const Offset(80, 0), 5000);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.pixelsPerSecond.distance, 0);
    });
  });

  group('Drag chain coordination', () {
    testWidgets('child drag on another axis does not starve ancestor drag tracking', (tester) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      var parentDragStarts = 0;
      var childDragStarts = 0;

      host.rootDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onHorizontalDragStart: (_) => parentDragStarts++,
      );
      host.leafDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onVerticalDragStart: (_) => childDragStarts++,
      );

      const down = PointerDownEvent(
        pointer: 1,
        position: Offset.zero,
        buttons: kPrimaryButton,
        timeStamp: Duration.zero,
      );
      const move = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 16),
      );

      host.dispatch(down);
      host.dispatch(move);

      expect(childDragStarts, 0);
      expect(parentDragStarts, 1);
    });

    testWidgets('短快划低于 Flutter 拖拽容差时按点击结算', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final phases = <ElEventPhase>[];
      void record(ElEventDetails event) => phases.add(event.phase);
      host.leafDispatcher.event = ElEvent(
        config: ElEventConfig(
          tapCancelDistance: 2,
          dragStartDistance: 100,
          dragMinFlingDistance: 1,
          dragMinFlingVelocity: 10,
        ),
        onPointerDown: record,
        onTapDown: record,
        onPointerUp: record,
        onTapUp: record,
        onTap: record,
        onTapCancel: record,
        onDragStart: record,
        onDragEnd: record,
      );

      host.dispatch(const PointerDownEvent(pointer: 2, position: Offset.zero, timeStamp: Duration.zero));
      host.dispatch(
        const PointerMoveEvent(
          pointer: 2,
          position: Offset(4, 0),
          delta: Offset(4, 0),
          timeStamp: Duration(milliseconds: 4),
        ),
      );
      host.dispatch(const PointerUpEvent(pointer: 2, position: Offset(4, 0), timeStamp: Duration(milliseconds: 8)));

      expect(phases, <ElEventPhase>[
        ElEventPhase.pointerDown,
        ElEventPhase.pointerUp,
        ElEventPhase.tapDown,
        ElEventPhase.tapUp,
        ElEventPhase.tap,
      ]);
    });
  });
}
