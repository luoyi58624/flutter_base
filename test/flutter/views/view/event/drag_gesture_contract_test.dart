import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  setUp(EventDispatcher.debugReset);

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
        dragStartDistance: 3,
        onVerticalDragStart: (_) => phases.add('root-v-start'),
        onVerticalDragUpdate: (_) => phases.add('root-v-update'),
        onVerticalDragEnd: (_) => phases.add('root-v-end'),
      );
      host.leafDispatcher.event = ElEvent(
        dragStartDistance: 3,
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

    testWidgets('双轴组同挂:水平锥内的浅角拖拽激活水平组并锁轴', (tester) async {
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

    testWidgets('默认双轴判定以 45° 对半分且边界优先横向', (tester) async {
      final starts = <(Axis, AxisDirection?)>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onVerticalDragStart: (e) => starts.add((Axis.vertical, e.dragDirection)),
            onVerticalDragUpdate: (_) {},
            onVerticalDragEnd: (_) {},
            onHorizontalDragStart: (e) => starts.add((Axis.horizontal, e.dragDirection)),
            onHorizontalDragUpdate: (_) {},
            onHorizontalDragEnd: (_) {},
          ),
        ),
      );

      Future<void> drag(Offset offset) async {
        final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
        await gesture.down(tester.getCenter(find.byType(ElView)));
        await gesture.moveBy(offset);
        await gesture.up();
        await tester.pump();
      }

      await drag(const Offset(80, 46)); // 约 30°：横向
      await drag(const Offset(-80, -46));
      await drag(const Offset(80, 80)); // 45°：边界优先横向，避免误触关闭
      await drag(const Offset(-80, -80));
      await drag(const Offset(46, 80)); // 约 60°：垂直
      await drag(const Offset(-46, -80));

      expect(starts, <(Axis, AxisDirection?)>[
        (Axis.horizontal, AxisDirection.right),
        (Axis.horizontal, AxisDirection.left),
        (Axis.horizontal, AxisDirection.right),
        (Axis.horizontal, AxisDirection.left),
        (Axis.vertical, AxisDirection.down),
        (Axis.vertical, AxisDirection.up),
      ]);
    });

    testWidgets('默认单轴组按累计 45° 意图等待并允许转向后激活', (tester) async {
      final verticalStarts = <AxisDirection?>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            dragStartDistance: 0,
            onVerticalDragStart: (e) => verticalStarts.add(e.dragDirection),
            onVerticalDragUpdate: (_) {},
            onVerticalDragEnd: (_) {},
          ),
        ),
      );
      final vertical = await tester.createGesture(kind: PointerDeviceKind.touch);
      await vertical.down(tester.getCenter(find.byType(ElView)));
      await vertical.moveBy(const Offset(12, 10));
      expect(verticalStarts, isEmpty, reason: '横向占优的小步不能提前公开垂直 DragStart');
      await vertical.moveBy(const Offset(0, 10));
      expect(verticalStarts, <AxisDirection?>[AxisDirection.down]);
      await vertical.up();
      await tester.pump();

      final horizontalStarts = <AxisDirection?>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            dragStartDistance: 0,
            onHorizontalDragStart: (e) => horizontalStarts.add(e.dragDirection),
            onHorizontalDragUpdate: (_) {},
            onHorizontalDragEnd: (_) {},
          ),
        ),
      );
      final horizontal = await tester.createGesture(kind: PointerDeviceKind.touch);
      await horizontal.down(tester.getCenter(find.byType(ElView)));
      await horizontal.moveBy(const Offset(10, 12));
      expect(horizontalStarts, isEmpty, reason: '垂直占优的小步不能提前公开水平 DragStart');
      await horizontal.moveBy(const Offset(10, 0));
      expect(horizontalStarts, <AxisDirection?>[AxisDirection.right]);
      await horizontal.up();
      await tester.pump();
    });

    testWidgets('单轴未过启动距离的轻扫救援同样遵守默认 45° 意图', (tester) async {
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            dragStartDistance: 1000,
            onVerticalDragStart: (e) => phases.add(e.phase),
            onVerticalDragUpdate: (_) {},
            onVerticalDragEnd: (e) => phases.add(e.phase),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ElView));
      final horizontal = await tester.createGesture(kind: PointerDeviceKind.touch);
      await horizontal.down(center, timeStamp: Duration.zero);
      await horizontal.moveBy(const Offset(50, 10), timeStamp: const Duration(milliseconds: 10));
      await horizontal.moveBy(const Offset(50, 10), timeStamp: const Duration(milliseconds: 20));
      await horizontal.up(timeStamp: const Duration(milliseconds: 24));
      expect(phases, isEmpty, reason: '横向占优的短促轻扫不能被救援成垂直 fling');

      final vertical = await tester.createGesture(kind: PointerDeviceKind.touch);
      await vertical.down(center, timeStamp: const Duration(milliseconds: 100));
      await vertical.moveBy(const Offset(10, 50), timeStamp: const Duration(milliseconds: 110));
      await vertical.moveBy(const Offset(10, 50), timeStamp: const Duration(milliseconds: 120));
      await vertical.up(timeStamp: const Duration(milliseconds: 124));
      expect(phases, <ElEventPhase>[ElEventPhase.dragStart, ElEventPhase.dragEnd]);
      await tester.pump();
    });

    testWidgets('双轴组同挂:胜出水平轴启动阈为 pan slop,垂直仍 hit slop', (tester) async {
      final horizontalPhases = <ElEventPhase>[];
      final verticalPhases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onVerticalDragStart: (e) => verticalPhases.add(e.phase),
            onVerticalDragUpdate: (_) {},
            onVerticalDragEnd: (_) {},
            onHorizontalDragStart: (e) => horizontalPhases.add(e.phase),
            onHorizontalDragUpdate: (_) {},
            onHorizontalDragEnd: (_) {},
          ),
        ),
      );

      // 阈值从设备口径现算(测试环境 hit slop 18 / pan slop 36),不写字面值。
      final hitSlop = computeHitSlop(PointerDeviceKind.touch, null);
      final panSlop = computePanSlop(PointerDeviceKind.touch, null);

      // 纯水平起手(方向恒在水平锥内,与锥角取值无关):越过 hit slop 但未及
      // pan slop → 不激活——水平比垂直需要更长的确认距离(误触横滚防线)。
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byType(ElView)));
      await gesture.moveBy(Offset(hitSlop + 2, 0));
      await tester.pump();
      expect(horizontalPhases, isEmpty);

      // 继续水平推进越过 pan slop → 激活水平组。
      await gesture.moveBy(Offset(panSlop - hitSlop, 0));
      await tester.pump();
      expect(horizontalPhases, [ElEventPhase.dragStart]);
      expect(verticalPhases, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();

      // 纯垂直起手:越过 hit slop 即激活——垂直阈不受水平差异化影响。
      final gesture2 = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture2.down(tester.getCenter(find.byType(ElView)));
      await gesture2.moveBy(Offset(0, hitSlop + 2));
      await tester.pump();
      expect(verticalPhases, [ElEventPhase.dragStart]);
      await gesture2.up();
      await tester.pumpAndSettle();
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
            dragStartDistance: 200,
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
  });

  group('Drag chain coordination', () {
    testWidgets('axis-specific proposal locks the member to its first public DragStart group', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      var childHorizontalStarts = 0;
      var childHorizontalEnds = 0;
      var childVerticalStarts = 0;
      var parentHorizontalStarts = 0;
      var parentHorizontalEnds = 0;
      host.rootDispatcher.event = .new(
        dragStartDistance: 0,
        onHorizontalDragStart: (_) => parentHorizontalStarts++,
        onHorizontalDragEnd: (_) => parentHorizontalEnds++,
      );
      host.leafDispatcher.event = .new(
        dragStartDistance: 20,
        onHorizontalDragStart: (_) => childHorizontalStarts++,
        onHorizontalDragEnd: (_) => childHorizontalEnds++,
        onVerticalDragStart: (_) => childVerticalStarts++,
      );

      host.dispatch(const PointerDownEvent(pointer: 3, position: Offset.zero));
      host.dispatch(const PointerMoveEvent(pointer: 3, position: Offset(5, 0), delta: Offset(5, 0)));
      expect((childHorizontalStarts, parentHorizontalStarts), (1, 1));

      host.dispatch(const PointerMoveEvent(pointer: 3, position: Offset(5, 30), delta: Offset(0, 30)));
      expect(childVerticalStarts, 0, reason: '一次 pointer 手势只能有一个胜出回调组。');
      expect(childHorizontalStarts, 1);
      host.dispatch(const PointerUpEvent(pointer: 3, position: Offset(5, 30)));
      expect((childHorizontalEnds, parentHorizontalEnds), (1, 1));
    });

    testWidgets('child drag on another axis does not starve ancestor drag tracking', (tester) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      var parentDragStarts = 0;
      var childDragStarts = 0;

      host.rootDispatcher.event = .new(dragStartDistance: 3, onHorizontalDragStart: (_) => parentDragStarts++);
      host.leafDispatcher.event = .new(dragStartDistance: 3, onVerticalDragStart: (_) => childDragStarts++);

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

    testWidgets('DRAG-1: passive nested drags preserve descendant tap activation', (tester) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final parentPhases = <ElEventPhase>[];
      final childPhases = <ElEventPhase>[];
      host.rootDispatcher.event = .new(
        dragStartDistance: 3,
        onDragStart: (event) => parentPhases.add(event.phase),
        onDragUpdate: (event) => parentPhases.add(event.phase),
        onDragEnd: (event) => parentPhases.add(event.phase),
      );
      host.leafDispatcher.event = .new(
        dragStartDistance: 3,
        onTapDown: (event) => childPhases.add(event.phase),
        onTapUp: (event) => childPhases.add(event.phase),
        onTap: (event) => childPhases.add(event.phase),
        onDragStart: (event) => childPhases.add(event.phase),
        onDragUpdate: (event) => childPhases.add(event.phase),
        onDragEnd: (event) => childPhases.add(event.phase),
      );

      const down = PointerDownEvent(
        pointer: 1,
        position: Offset.zero,
        buttons: kPrimaryButton,
        timeStamp: Duration.zero,
      );
      const start = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 16),
      );
      const update = PointerMoveEvent(
        pointer: 1,
        position: Offset(28, 0),
        delta: Offset(8, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 32),
      );
      const up = PointerUpEvent(pointer: 1, position: Offset(28, 0), timeStamp: Duration(milliseconds: 64));

      for (final event in [down, start, update, up]) {
        host.dispatch(event);
      }

      expect(parentPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragUpdate,
        ElEventPhase.dragEnd,
      ], reason: '被动拖拽各自报告完整生命周期');
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.tapDown,
        ElEventPhase.dragStart,
        ElEventPhase.dragUpdate,
        ElEventPhase.dragEnd,
        ElEventPhase.tapUp,
        ElEventPhase.tap,
      ], reason: 'passive drag 只报告语义，不取消同节点 tap；实际消费者必须显式 eager');
      // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
      await tester.pump(Duration(milliseconds: 100));
    });

    testWidgets('DRAG-2: up-stage fling rescue cancels tap but preserves tapUp', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final phases = <ElEventPhase>[];
      void record(ElEventDetails event) => phases.add(event.phase);
      host.leafDispatcher.event = ElEvent(
        tapCancelDistance: 2,
        dragStartDistance: 100,
        onPointerDown: record,
        onTapDown: record,
        onPointerUp: record,
        onTapUp: record,
        onTap: record,
        onTapCancel: record,
        onDragStart: (event) {
          record(event);
          event.eagerGesture(cancelSelfTap: true);
        },
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

      expect(phases, hasLength(7));
      expect(phases.toSet(), <ElEventPhase>{
        ElEventPhase.pointerDown,
        ElEventPhase.tapDown,
        ElEventPhase.pointerUp,
        ElEventPhase.dragStart,
        ElEventPhase.tapCancel,
        ElEventPhase.dragEnd,
        ElEventPhase.tapUp,
      });
    });

    testWidgets('ancestor drag does not globally cancel descendant movement gesture', (tester) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final parentPhases = <ElEventPhase>[];
      final childPhases = <ElEventPhase>[];

      host.rootDispatcher.event = .new(
        dragStartDistance: 3,
        onDragStart: (event) => parentPhases.add(event.phase),
        onDragEnd: (event) => parentPhases.add(event.phase),
      );
      host.leafDispatcher.event = .new(
        longPressDelay: Duration(milliseconds: 30),
        dragStartDistance: 3,
        onLongPress: (event) => childPhases.add(event.phase),
        onTapUp: (event) => childPhases.add(event.phase),
        onTap: (event) => childPhases.add(event.phase),
        onDragStart: (event) => childPhases.add(event.phase),
      );

      const down = PointerDownEvent(
        pointer: 1,
        position: Offset.zero,
        buttons: kPrimaryButton,
        timeStamp: Duration.zero,
      );
      const start = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 16),
      );
      const up = PointerUpEvent(pointer: 1, position: Offset(20, 0), timeStamp: Duration(milliseconds: 64));

      host.directRoot(down);
      host.directLeaf(down);
      dispatchTestPointerInput(down);
      host.directRoot(start);
      host.directLeaf(start);
      dispatchTestPointerInput(start);
      await tester.pump(const Duration(milliseconds: 80));
      host.dispatch(up);

      expect(parentPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragEnd,
      ], reason: 'passive nested drag 可并存，但同一 dispatcher 的同相位回调不重复');
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.tapUp,
        ElEventPhase.tap,
      ], reason: '移动取消 longPress 等待，但 passive drag 不取消同节点 tap');
      // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
      await tester.pump(Duration(milliseconds: 100));
    });
  });
}
