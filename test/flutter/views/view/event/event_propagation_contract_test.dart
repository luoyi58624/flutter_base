import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show DragPointerLock;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  testWidgets('ROUTE-4/TAP-8: child DragStart proposal stops zero-threshold ancestor', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final buttonPhases = <ElEventPhase>[];
    final ancestorDragPhases = <ElEventPhase>[];
    final ancestorTapPhases = <ElEventPhase>[];

    host.rootDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 0),
      onDragStart: (event) => ancestorDragPhases.add(event.phase),
      onDragUpdate: (event) => ancestorDragPhases.add(event.phase),
      onDragEnd: (event) => ancestorDragPhases.add(event.phase),
      onDragCancel: (event) => ancestorDragPhases.add(event.phase),
      onTapUp: (event) => ancestorTapPhases.add(event.phase),
      onTap: (event) => ancestorTapPhases.add(event.phase),
    );
    host.leafDispatcher.hitBoundsContainsGlobal = (position) => position.dx >= 0 && position.dx < 200;
    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(),
      onTapDown: (event) => buttonPhases.add(event.phase),
      onTapUp: (event) => buttonPhases.add(event.phase),
      onTap: (event) => buttonPhases.add(event.phase),
      onTapCancel: (event) => buttonPhases.add(event.phase),
      onDragStart: (event) {
        buttonPhases.add(event.phase);
        event.stopPropagation();
      },
    );

    host.dispatch(_down(pointer: 1));
    // 祖先先达到阈值时必须从 target 提出 Start；子节点真实 stop 后立即建立
    // 边界，不依赖子节点自己的默认拖拽阈值。
    host.dispatch(_move(pointer: 1, x: 1, deltaX: 1, millis: 16));
    expect(buttonPhases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.dragStart]);
    expect(ancestorDragPhases, isEmpty);
    host.dispatch(_move(pointer: 1, x: 120, deltaX: 119, millis: 32));
    host.dispatch(_up(pointer: 1, x: 120, millis: 48));

    expect(ancestorDragPhases, isEmpty, reason: 'ancestor Drag 的 Start/Update/End/Cancel 全流必须为零');
    expect(ancestorTapPhases, <ElEventPhase>[
      ElEventPhase.tapUp,
      ElEventPhase.tap,
    ], reason: 'Drag route stop 不得清理祖先 Tap 状态');
    expect(buttonPhases, <ElEventPhase>[
      ElEventPhase.tapDown,
      ElEventPhase.dragStart,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
    ]);
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('ROUTE-4B: child DragStart.stop prevents ancestor DragProxy, lock and Tap cancellation', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    addTearDown(DragPointerLock.debugReset);
    DragPointerLock.debugReset();
    var proxyPreUpdates = 0;
    var proxyOverflows = 0;
    final parentDragPhases = <ElEventPhase>[];
    final parentTapPhases = <ElEventPhase>[];
    final childPhases = <ElEventPhase>[];

    host.rootDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      dragProxy: ElDragProxy(onDragPreUpdate: (_) => proxyPreUpdates++, onDragOverflow: (_) => proxyOverflows++),
      onDragStart: (event) => parentDragPhases.add(event.phase),
      onDragUpdate: (event) => parentDragPhases.add(event.phase),
      onDragEnd: (event) => parentDragPhases.add(event.phase),
      onTapUp: (event) => parentTapPhases.add(event.phase),
      onTap: (event) => parentTapPhases.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onTapDown: (event) => childPhases.add(event.phase),
      onTapUp: (event) => childPhases.add(event.phase),
      onTap: (event) => childPhases.add(event.phase),
      onTapCancel: (event) => childPhases.add(event.phase),
      onDragStart: (event) {
        childPhases.add(event.phase);
        event.stopPropagation();
      },
      onDragUpdate: (event) => childPhases.add(event.phase),
      onDragEnd: (event) => childPhases.add(event.phase),
    );

    host.dispatch(
      const PointerDownEvent(pointer: 2, position: Offset.zero, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton),
    );
    host.dispatch(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      ),
    );
    host.dispatch(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(30, 0),
        delta: Offset(10, 0),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      ),
    );
    host.dispatch(const PointerUpEvent(pointer: 2, position: Offset(30, 0), kind: PointerDeviceKind.mouse));

    expect(parentDragPhases, isEmpty);
    expect((proxyPreUpdates, proxyOverflows), (0, 0));
    expect(DragPointerLock.isActive, isFalse, reason: 'stop-only Drag 不得被提前组成复合管线。');
    expect(parentTapPhases, <ElEventPhase>[ElEventPhase.tapUp, ElEventPhase.tap]);
    expect(childPhases, <ElEventPhase>[
      ElEventPhase.tapDown,
      ElEventPhase.dragStart,
      ElEventPhase.dragUpdate,
      ElEventPhase.dragEnd,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
    ]);
  });

  testWidgets('ROUTE-2: raw down stop blocks the whole ancestor pointer interaction', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final childPhases = <ElEventPhase>[];
    final parentPhases = <ElEventPhase>[];

    host.rootDispatcher.event = ElEvent(
      onPointerDown: (event) => parentPhases.add(event.phase),
      onTapDown: (event) => parentPhases.add(event.phase),
      onPointerUp: (event) => parentPhases.add(event.phase),
      onTapUp: (event) => parentPhases.add(event.phase),
      onTap: (event) => parentPhases.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(
      onPointerDown: (event) {
        childPhases.add(event.phase);
        event.stopPropagation();
      },
      onTapDown: (event) => childPhases.add(event.phase),
      onPointerUp: (event) => childPhases.add(event.phase),
      onTapUp: (event) => childPhases.add(event.phase),
      onTap: (event) => childPhases.add(event.phase),
    );

    host.tap(pointer: 11, downTime: Duration.zero, upTime: const Duration(milliseconds: 16));

    expect(childPhases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.tapDown,
      ElEventPhase.pointerUp,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
    ]);
    expect(parentPhases, isEmpty, reason: 'PointerDown stop 后祖先失去整个 pointer 序列及其派生交互');
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('ROUTE-3A: TapDown stop blocks the ancestor Tap continuation', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final childPhases = <ElEventPhase>[];
    final parentPhases = <ElEventPhase>[];

    host.rootDispatcher.event = ElEvent(
      onPointerDown: (event) => parentPhases.add(event.phase),
      onTapDown: (event) => parentPhases.add(event.phase),
      onPointerUp: (event) => parentPhases.add(event.phase),
      onTapUp: (event) => parentPhases.add(event.phase),
      onTap: (event) => parentPhases.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(
      onTapDown: (event) {
        childPhases.add(event.phase);
        event.stopPropagation();
      },
      onTapUp: (event) => childPhases.add(event.phase),
      onTap: (event) => childPhases.add(event.phase),
    );

    host.tap(pointer: 12, downTime: Duration.zero, upTime: const Duration(milliseconds: 16));

    expect(childPhases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
    expect(parentPhases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.pointerUp,
    ], reason: 'TapDown stop 只截断祖先 Tap 家族，raw Pointer 仍正常投递');
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('ROUTE-3A-LONG: TapDown stop also blocks ancestor LongPress and Cancel', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final parentPhases = <ElEventPhase>[];
    host.rootDispatcher.event = ElEvent(
      config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
      onLongPress: (event) => parentPhases.add(event.phase),
      onTapCancel: (event) => parentPhases.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(onTapDown: (event) => event.stopPropagation());

    host.dispatch(const PointerDownEvent(pointer: 13, position: Offset.zero, buttons: kPrimaryButton));
    await tester.pump(const Duration(milliseconds: 30));
    host.dispatch(const PointerUpEvent(pointer: 13, position: Offset.zero));

    expect(parentPhases, isEmpty, reason: 'TapDown 截断后祖先不得再进入 LongPress，也不得收到 Tap 取消通知');
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('ROUTE-3B: TapUp stop blocks the ancestor TapUp and later Tap', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final childPhases = <ElEventPhase>[];
    final parentPhases = <ElEventPhase>[];

    host.rootDispatcher.event = ElEvent(
      onPointerDown: (event) => parentPhases.add(event.phase),
      onTapDown: (event) => parentPhases.add(event.phase),
      onPointerUp: (event) => parentPhases.add(event.phase),
      onTapUp: (event) => parentPhases.add(event.phase),
      onTap: (event) => parentPhases.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(
      onTapDown: (event) => childPhases.add(event.phase),
      onTapUp: (event) {
        childPhases.add(event.phase);
        event.stopPropagation();
      },
      onTap: (event) => childPhases.add(event.phase),
    );

    host.tap(pointer: 13, downTime: Duration.zero, upTime: const Duration(milliseconds: 16));

    expect(childPhases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
    expect(parentPhases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.tapDown,
      ElEventPhase.pointerUp,
    ], reason: 'TapUp stop 后祖先不能继续收到同一 Tap 家族的 Tap');
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('ROUTE-3C: DragDown stop blocks only the ancestor Drag family', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final childPhases = <ElEventPhase>[];
    final parentPhases = <ElEventPhase>[];

    host.rootDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onPointerDown: (event) => parentPhases.add(event.phase),
      onTapDown: (event) => parentPhases.add(event.phase),
      onTapUp: (event) => parentPhases.add(event.phase),
      onTap: (event) => parentPhases.add(event.phase),
      onDragDown: (event) => parentPhases.add(event.phase),
      onDragStart: (event) => parentPhases.add(event.phase),
      onDragUpdate: (event) => parentPhases.add(event.phase),
      onDragEnd: (event) => parentPhases.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onTapDown: (event) => childPhases.add(event.phase),
      onTapUp: (event) => childPhases.add(event.phase),
      onTap: (event) => childPhases.add(event.phase),
      onDragDown: (event) {
        childPhases.add(event.phase);
        event.stopPropagation();
      },
      onDragStart: (event) => childPhases.add(event.phase),
      onDragUpdate: (event) => childPhases.add(event.phase),
      onDragEnd: (event) => childPhases.add(event.phase),
    );

    host.dispatch(const PointerDownEvent(pointer: 14, position: Offset.zero, buttons: kPrimaryButton));
    host.dispatch(
      const PointerMoveEvent(
        pointer: 14,
        position: Offset(10, 0),
        delta: Offset(10, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 16),
      ),
    );
    host.dispatch(
      const PointerMoveEvent(
        pointer: 14,
        position: Offset(20, 0),
        delta: Offset(10, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 32),
      ),
    );
    host.dispatch(const PointerUpEvent(pointer: 14, position: Offset(20, 0), timeStamp: Duration(milliseconds: 48)));

    expect(parentPhases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.tapDown,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
    ]);
    expect(
      childPhases,
      containsAllInOrder(<ElEventPhase>[
        ElEventPhase.dragDown,
        ElEventPhase.tapDown,
        ElEventPhase.dragStart,
        ElEventPhase.dragUpdate,
        ElEventPhase.dragEnd,
        ElEventPhase.tapUp,
        ElEventPhase.tap,
      ]),
    );
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('ROUTE-3D: stop 后 eager 只补 raw PointerCancel，不补已截断 TapCancel', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    var parentPointerCancels = 0;
    var parentTapCancels = 0;
    host.rootDispatcher.event = ElEvent(
      onPointerDown: (_) {},
      onPointerCancel: (_) => parentPointerCancels++,
      onTapDown: (_) {},
      onTapCancel: (_) => parentTapCancels++,
    );
    host.leafDispatcher.event = ElEvent(
      onTapDown: (event) {
        event.stopPropagation();
        event.eagerGesture(cancelSelfTap: true);
      },
    );

    host.tap(pointer: 15, downTime: Duration.zero, upTime: const Duration(milliseconds: 16));

    expect(parentPointerCancels, 1, reason: '祖先已收到 raw PointerDown，eager 必须补 PointerCancel 清理副作用');
    expect(parentTapCancels, 0, reason: 'TapDown stop 已截断祖先 Tap 候选，不得补造 TapCancel');
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('ROUTE-COORD-1: localPosition matches the tapped offset inside the target', (tester) async {
    ElEventDetails? captured;
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: .new(onTap: (event) => captured = event),
      ),
    );

    await tester.tapAt(const Offset(35, 70));
    await tester.pump();

    expect(captured!.localPosition.dx, closeTo(35, 0.001));
    expect(captured!.localPosition.dy, closeTo(70, 0.001));
  });

  testWidgets('ROUTE-COORD-2: localPosition removes ancestor padding while globalPosition stays global', (
    tester,
  ) async {
    ElEventDetails? captured;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 40, 0, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: ElView(
              style: eventTestDefaultStyle,
              event: .new(onTap: (event) => captured = event),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(80, 90));
    await tester.pump();

    expect(captured!.globalPosition, const Offset(80, 90));
    expect(captured!.localPosition.dx, closeTo(50, 0.001));
    expect(captured!.localPosition.dy, closeTo(50, 0.001));
  });

  group('Mouse button semantic routing', () {
    testWidgets('nested right click does not bubble semantic secondary tap chain', (tester) async {
      var childPointerDowns = 0;
      var parentPointerDowns = 0;
      final childPhases = <ElEventPhase>[];
      final parentPhases = <ElEventPhase>[];

      await pumpEventView(
        tester,
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: .new(
            onPointerDown: (_) => parentPointerDowns++,
            onSecondaryTapDown: (event) => parentPhases.add(event.phase),
            onSecondaryTapUp: (event) => parentPhases.add(event.phase),
            onSecondaryTap: (event) => parentPhases.add(event.phase),
          ),
          child: ElView(
            style: const ElStyle(width: 40, height: 40),
            event: .new(
              onPointerDown: (_) => childPointerDowns++,
              onSecondaryTapDown: (event) => childPhases.add(event.phase),
              onSecondaryTapUp: (event) => childPhases.add(event.phase),
              onSecondaryTap: (event) => childPhases.add(event.phase),
            ),
          ),
        ),
      );

      await clickPointerButtonAt(tester, const Offset(20, 20), kSecondaryButton, pointer: 7);
      await tester.pump();

      expect(childPointerDowns, 1);
      expect(parentPointerDowns, 1, reason: 'raw onPointerDown still bubbles like a normal pointer event');
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.secondaryTapDown,
        ElEventPhase.secondaryTapUp,
        ElEventPhase.secondaryTap,
      ]);
      expect(parentPhases, isEmpty, reason: 'secondary tap is a buttons semantic chain; nearest target wins');
    });

    testWidgets('nested middle click does not bubble semantic tertiary tap chain', (tester) async {
      var childPointerDowns = 0;
      var parentPointerDowns = 0;
      final childPhases = <ElEventPhase>[];
      final parentPhases = <ElEventPhase>[];

      await pumpEventView(
        tester,
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: .new(
            onPointerDown: (_) => parentPointerDowns++,
            onTertiaryTapDown: (event) => parentPhases.add(event.phase),
            onTertiaryTapUp: (event) => parentPhases.add(event.phase),
            onTertiaryTap: (event) => parentPhases.add(event.phase),
          ),
          child: ElView(
            style: const ElStyle(width: 40, height: 40),
            event: .new(
              onPointerDown: (_) => childPointerDowns++,
              onTertiaryTapDown: (event) => childPhases.add(event.phase),
              onTertiaryTapUp: (event) => childPhases.add(event.phase),
              onTertiaryTap: (event) => childPhases.add(event.phase),
            ),
          ),
        ),
      );

      await clickPointerButtonAt(tester, const Offset(20, 20), kTertiaryButton, pointer: 7);
      await tester.pump();

      expect(childPointerDowns, 1);
      expect(parentPointerDowns, 1, reason: 'raw onPointerDown still bubbles like a normal pointer event');
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.tertiaryTapDown,
        ElEventPhase.tertiaryTapUp,
        ElEventPhase.tertiaryTap,
      ]);
      expect(parentPhases, isEmpty, reason: 'tertiary tap is a buttons semantic chain; nearest target wins');
    });

    testWidgets('nested forward and back buttons do not bubble semantic side-button chain', (tester) async {
      Future<void> expectNearestWins({
        required int button,
        required ElEventPhase down,
        required ElEventPhase up,
        required ElEventPhase tap,
      }) async {
        var childPointerDowns = 0;
        var parentPointerDowns = 0;
        final childPhases = <ElEventPhase>[];
        final parentPhases = <ElEventPhase>[];

        await pumpEventView(
          tester,
          ElView(
            style: const ElStyle(width: 100, height: 100),
            event: .new(
              onPointerDown: (_) => parentPointerDowns++,
              onForwardTapDown: (event) => parentPhases.add(event.phase),
              onForwardTapUp: (event) => parentPhases.add(event.phase),
              onForwardTap: (event) => parentPhases.add(event.phase),
              onBackTapDown: (event) => parentPhases.add(event.phase),
              onBackTapUp: (event) => parentPhases.add(event.phase),
              onBackTap: (event) => parentPhases.add(event.phase),
            ),
            child: ElView(
              style: const ElStyle(width: 40, height: 40),
              event: .new(
                onPointerDown: (_) => childPointerDowns++,
                onForwardTapDown: (event) => childPhases.add(event.phase),
                onForwardTapUp: (event) => childPhases.add(event.phase),
                onForwardTap: (event) => childPhases.add(event.phase),
                onBackTapDown: (event) => childPhases.add(event.phase),
                onBackTapUp: (event) => childPhases.add(event.phase),
                onBackTap: (event) => childPhases.add(event.phase),
              ),
            ),
          ),
        );

        await clickPointerButtonAt(tester, const Offset(20, 20), button, pointer: 7);
        await tester.pump();

        expect(childPointerDowns, 1);
        expect(parentPointerDowns, 1, reason: 'raw onPointerDown still bubbles like a normal pointer event');
        expect(childPhases, <ElEventPhase>[down, up, tap]);
        expect(parentPhases, isEmpty, reason: 'mouse side buttons are simple buttons semantic chains');
      }

      await expectNearestWins(
        button: kForwardMouseButton,
        down: ElEventPhase.forwardTapDown,
        up: ElEventPhase.forwardTapUp,
        tap: ElEventPhase.forwardTap,
      );
      await expectNearestWins(
        button: kBackMouseButton,
        down: ElEventPhase.backTapDown,
        up: ElEventPhase.backTapUp,
        tap: ElEventPhase.backTap,
      );
    });

    testWidgets('PointerDown stop blocks every ancestor mouse-button semantic family', (tester) async {
      var childPointerDowns = 0;
      var parentPointerDowns = 0;
      final parentPhases = <ElEventPhase>[];

      await pumpEventView(
        tester,
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: .new(
            onPointerDown: (_) => parentPointerDowns++,
            onSecondaryTapDown: (event) => parentPhases.add(event.phase),
            onSecondaryTapUp: (event) => parentPhases.add(event.phase),
            onSecondaryTap: (event) => parentPhases.add(event.phase),
            onTertiaryTapDown: (event) => parentPhases.add(event.phase),
            onTertiaryTapUp: (event) => parentPhases.add(event.phase),
            onTertiaryTap: (event) => parentPhases.add(event.phase),
            onForwardTapDown: (event) => parentPhases.add(event.phase),
            onForwardTapUp: (event) => parentPhases.add(event.phase),
            onForwardTap: (event) => parentPhases.add(event.phase),
            onBackTapDown: (event) => parentPhases.add(event.phase),
            onBackTapUp: (event) => parentPhases.add(event.phase),
            onBackTap: (event) => parentPhases.add(event.phase),
          ),
          child: ElView(
            style: const ElStyle(width: 40, height: 40),
            event: .new(
              onPointerDown: (event) {
                childPointerDowns++;
                event.stopPropagation();
              },
            ),
          ),
        ),
      );

      for (final button in <int>[kSecondaryButton, kTertiaryButton, kForwardMouseButton, kBackMouseButton]) {
        await clickPointerButtonAt(tester, const Offset(20, 20), button, pointer: 20 + childPointerDowns);
      }
      await tester.pump();

      expect(childPointerDowns, 4);
      expect(parentPointerDowns, 0);
      expect(parentPhases, isEmpty, reason: 'PointerDown stop 后祖先不得继续派生任何鼠标按键语义');
    });
  });

  group('Pointer events', () {
    testWidgets('down / move / up each fire with raw event', (tester) async {
      final captured = <ElEventPhase, Object?>{};
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onPointerDown: (e) => captured[e.phase] = e.originalEvent,
            onPointerMove: (e) => captured[e.phase] = e.originalEvent,
            onPointerUp: (e) => captured[e.phase] = e.originalEvent,
          ),
        ),
      );
      final gesture = await tester.startGesture(const Offset(10, 10));
      await gesture.moveBy(const Offset(5, 5));
      await gesture.up();
      await tester.pump();
      expect(captured[ElEventPhase.pointerDown], isA<PointerDownEvent>());
      expect(captured[ElEventPhase.pointerMove], isA<PointerMoveEvent>());
      expect(captured[ElEventPhase.pointerUp], isA<PointerUpEvent>());
    });

    testWidgets('move callback exposes non-zero delta', (tester) async {
      Offset? delta;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onPointerMove: (e) => delta ??= e.delta),
        ),
      );
      final gesture = await tester.startGesture(const Offset(10, 10));
      await gesture.moveBy(const Offset(3, 4));
      await gesture.up();
      await tester.pump();
      expect(delta, isNotNull);
      expect(delta!.dx, closeTo(3, 0.001));
      expect(delta!.dy, closeTo(4, 0.001));
    });
  });

  group('Pointer signal', () {
    testWidgets('wheel scroll triggers onPointerSignal', (tester) async {
      var signals = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onPointerSignal: (_) => signals++),
        ),
      );
      final pointer = TestPointer(9, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(50, 50)));
      await tester.sendEventToBinding(
        PointerScrollEvent(position: const Offset(50, 50), scrollDelta: const Offset(0, 10)),
      );
      await tester.pump();
      expect(signals, 1);
    });
  });

  group('Mouse Enter / Exit', () {
    testWidgets('hover into ElView fires onPointerEnter', (tester) async {
      var enters = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onPointerEnter: (_) => enters++),
        ),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(() => gesture.removePointer());
      await gesture.addPointer(location: const Offset(-10, -10));
      await tester.pump();
      await gesture.moveTo(const Offset(50, 50));
      await tester.pump();
      expect(enters, greaterThanOrEqualTo(1));
    });

    testWidgets('hover out of ElView fires onPointerExit', (tester) async {
      var exits = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onPointerExit: (_) => exits++),
        ),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(() => gesture.removePointer());
      await gesture.addPointer(location: const Offset(50, 50));
      await tester.pump();
      await gesture.moveTo(const Offset(500, 500));
      await tester.pump();
      expect(exits, greaterThanOrEqualTo(1));
    });
  });

  group('Bubble along RenderObject parent chain', () {
    testWidgets('child event bubbles to attached parent dispatcher', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);

      var parentCount = 0;
      var childCount = 0;
      host.rootDispatcher.event = .new(onFocus: (_) => parentCount++);
      host.leafDispatcher.event = .new(onFocus: (_) => childCount++);

      host.leafDispatcher.notifyFocusChanged(true);

      expect(childCount, 1);
      expect(parentCount, 1);
    });

    testWidgets('stopPropagation in child handler prevents parent dispatch', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);

      var parentCount = 0;
      var childCount = 0;
      host.rootDispatcher.event = .new(onFocus: (_) => parentCount++);
      host.leafDispatcher.event = .new(
        onFocus: (e) {
          childCount++;
          e.stopPropagation();
        },
      );

      host.leafDispatcher.notifyFocusChanged(true);

      expect(childCount, 1);
      expect(parentCount, 0);
    });

    testWidgets('bubbled focus does not suppress later direct parent focus', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);

      var parentCount = 0;
      var childCount = 0;
      host.rootDispatcher.event = .new(onFocus: (_) => parentCount++);
      host.leafDispatcher.event = .new(
        onFocus: (e) {
          childCount++;
          e.stopPropagation();
        },
      );

      host.leafDispatcher.notifyFocusChanged(true);
      host.rootDispatcher.notifyFocusChanged(true);

      expect(childCount, 1);
      expect(parentCount, 1);
    });

    testWidgets('parent without matching handler is skipped but bubble continues', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);

      var parentBlur = 0;
      var childFocus = 0;
      host.rootDispatcher.event = .new(onBlur: (_) => parentBlur++);
      host.leafDispatcher.event = .new(onFocus: (_) => childFocus++);

      host.leafDispatcher.notifyFocusChanged(true);

      expect(childFocus, 1);
      // parent only listens for blur, not focus
      expect(parentBlur, 0);
    });

    testWidgets('localPosition is rewritten per bubble hop', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);

      Offset? parentLocal;
      Offset? childLocal;
      host.rootDispatcher.event = .new(onFocus: (e) => parentLocal = e.localPosition);
      host.leafDispatcher.event = .new(onFocus: (e) => childLocal = e.localPosition);

      host.leafDispatcher.notifyFocusChanged(true);

      expect(childLocal, isNotNull);
      expect(parentLocal, isNotNull);
    });

    testWidgets('bubbled pointer marker does not suppress later parent pointer after event rewiring', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);

      var parentHovers = 0;
      var childHovers = 0;
      host.rootDispatcher.event = .new(onPointerDown: (_) {});
      host.leafDispatcher.event = .new(onPointerHover: (_) => childHovers++);

      const childHover = PointerHoverEvent(pointer: 1, position: Offset(4, 5));
      host.directLeaf(childHover);
      expect(childHovers, 1);

      host.rootDispatcher.event = .new(onPointerHover: (_) => parentHovers++);

      const parentHover = PointerHoverEvent(pointer: 1, position: Offset(8, 9));
      host.directRoot(parentHover);

      expect(parentHovers, 1);
    });

    testWidgets('descendant tap stopPropagation does not affect parent tapUp', (tester) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final parentPhases = <ElEventPhase>[];
      final childPhases = <ElEventPhase>[];
      host.rootDispatcher.event = .new(
        onPointerDown: (event) => parentPhases.add(event.phase),
        onTapDown: (event) => parentPhases.add(event.phase),
        onPointerUp: (event) => parentPhases.add(event.phase),
        onTapUp: (event) => parentPhases.add(event.phase),
        onTap: (event) => parentPhases.add(event.phase),
      );
      host.leafDispatcher.event = .new(
        onTapDown: (event) => childPhases.add(event.phase),
        onTapUp: (event) => childPhases.add(event.phase),
        onTap: (event) {
          childPhases.add(event.phase);
          event.stopPropagation();
        },
      );

      const down = PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero);
      const up = PointerUpEvent(pointer: 1, position: Offset.zero, timeStamp: Duration(milliseconds: 16));

      host.dispatch(down);
      host.dispatch(up);

      expect(childPhases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
      expect(parentPhases, <ElEventPhase>[
        ElEventPhase.pointerDown,
        ElEventPhase.tapDown,
        ElEventPhase.pointerUp,
        ElEventPhase.tapUp,
      ], reason: 'tap.stopPropagation is too late to affect ancestor tapUp');
      // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
      await tester.pump(Duration(milliseconds: 100));
    });

    testWidgets('pointerMove and dragUpdate skip bubbling but keep direct hit-test delivery', (tester) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      var parentPointerMoves = 0;
      var parentDragStarts = 0;
      var parentDragUpdates = 0;
      var childPointerMoves = 0;
      var childDragStarts = 0;
      var childDragUpdates = 0;
      host.rootDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onPointerMove: (_) => parentPointerMoves++,
        onDragStart: (_) => parentDragStarts++,
        onDragUpdate: (_) => parentDragUpdates++,
      );
      host.leafDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onPointerMove: (_) => childPointerMoves++,
        onDragStart: (_) => childDragStarts++,
        onDragUpdate: (_) => childDragUpdates++,
      );

      const down = PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero);
      const move = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        timeStamp: Duration(milliseconds: 16),
      );

      host.dispatch(down);
      host.directLeaf(move);
      expect(parentPointerMoves, 0, reason: 'pointerMove 仅由命中入口处理，不沿语义父链冒泡');
      host.directRoot(move);
      dispatchTestPointerInput(move);
      expect(childPointerMoves, 1);
      expect(parentPointerMoves, 1, reason: '祖先自己的命中输入独立于冒泡');
      expect(childDragStarts, 1);
      expect(parentDragStarts, 1, reason: '同一物理输入的冒泡和直接命中不能重复Start');
      expect(childDragUpdates, 0, reason: 'the first accepted move fires dragStart only');
      expect(parentDragUpdates, 0);

      const update = PointerMoveEvent(
        pointer: 1,
        position: Offset(28, 0),
        delta: Offset(8, 0),
        timeStamp: Duration(milliseconds: 32),
      );
      host.directLeaf(update);
      expect(parentPointerMoves, 1, reason: '高频raw输入不会替祖先制造命中投递');
      host.directRoot(update);
      dispatchTestPointerInput(update);
      expect(childPointerMoves, 2);
      expect(parentPointerMoves, 2);
      expect(childDragUpdates, 1);
      expect(parentDragUpdates, 1, reason: '祖先通过自己的真实命中路径接收更新');
      host.dispose();
    });

    testWidgets('pointerMove stopPropagation suppresses ancestor direct hit-test delivery', (tester) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      var parentPointerMoves = 0;
      var childPointerMoves = 0;
      host.rootDispatcher.event = .new(onPointerMove: (_) => parentPointerMoves++);
      host.leafDispatcher.event = .new(
        onPointerMove: (event) {
          childPointerMoves++;
          event.stopPropagation();
        },
      );

      const down = PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero);
      const move = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        timeStamp: Duration(milliseconds: 16),
      );
      host.dispatch(down);
      host.dispatch(move);

      expect(childPointerMoves, 1);
      expect(parentPointerMoves, 0, reason: 'explicit stopPropagation still owns this high-frequency frame');
    });

    testWidgets('dragStart still bubbles so ancestors can intercept a gesture sequence', (tester) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      var parentDragStarts = 0;
      var parentDragUpdates = 0;
      var childDragStarts = 0;
      var childDragUpdates = 0;
      host.rootDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) {
          parentDragStarts++;
          event.stopPropagation();
        },
        onDragUpdate: (_) => parentDragUpdates++,
      );
      host.leafDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (_) => childDragStarts++,
        onDragUpdate: (_) => childDragUpdates++,
      );

      host.dispatch(const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero));
      host.leafDispatcher.dispatchTestPointer(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(20, 0),
          delta: Offset(20, 0),
          timeStamp: Duration(milliseconds: 16),
        ),
        BoxHitTestEntry(host.nodes.last, Offset.zero),
        includeAncestors: false,
      );
      host.leafDispatcher.dispatchTestPointer(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(28, 0),
          delta: Offset(8, 0),
          timeStamp: Duration(milliseconds: 32),
        ),
        BoxHitTestEntry(host.nodes.last, Offset.zero),
        includeAncestors: false,
      );

      expect(childDragStarts, 1);
      expect(parentDragStarts, 1, reason: 'ancestor interception belongs on dragStart, not every dragUpdate');
      expect(childDragUpdates, 1);
      expect(parentDragUpdates, 0, reason: 'dragUpdate remains non-bubbling even after dragStart interception');
      host.dispose();
    });

    test('3 层冒泡：child fire → parent + grandparent 各一次', () {
      final host = DispatcherTestHost.chain(depth: 3);
      addTearDown(host.dispose);
      final gpD = host.dispatchers[0];
      final pD = host.dispatchers[1];
      final cD = host.dispatchers[2];

      var gp = 0;
      var p = 0;
      var c = 0;
      gpD.event = .new(onFocus: (_) => gp++);
      pD.event = .new(onFocus: (_) => p++);
      cD.event = .new(onFocus: (_) => c++);

      cD.notifyFocusChanged(true);

      expect(c, 1);
      expect(p, 1);
      expect(gp, 1);
    });

    test('中层 handler 内 stopPropagation 阻断祖父', () {
      final host = DispatcherTestHost.chain(depth: 3);
      addTearDown(host.dispose);
      final gpD = host.dispatchers[0];
      final pD = host.dispatchers[1];
      final cD = host.dispatchers[2];

      var gp = 0;
      var p = 0;
      var c = 0;
      gpD.event = .new(onFocus: (_) => gp++);
      pD.event = .new(
        onFocus: (e) {
          p++;
          e.stopPropagation();
        },
      );
      cD.event = .new(onFocus: (_) => c++);

      cD.notifyFocusChanged(true);

      expect(c, 1);
      expect(p, 1);
      expect(gp, 0);
    });
  });

  group('ElView event risk coverage', () {
    testWidgets('nested ElView tap bubbles to parent exactly once', (tester) async {
      var childTaps = 0;
      var parentTaps = 0;

      await pumpEventView(
        tester,
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: .new(onTap: (_) => parentTaps++),
          child: ElView(
            style: const ElStyle(width: 40, height: 40),
            event: .new(onTap: (_) => childTaps++),
          ),
        ),
      );

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();

      expect(childTaps, 1);
      expect(parentTaps, 1, reason: '父级只能收到一次子级冒泡，不能再被 Flutter hit-test 路径重复触发。');
    });

    testWidgets('child stopPropagation prevents parent tap in real ElView tree', (tester) async {
      var childTaps = 0;
      var parentTaps = 0;

      await pumpEventView(
        tester,
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: .new(onTap: (_) => parentTaps++),
          child: ElView(
            style: const ElStyle(width: 40, height: 40),
            event: .new(
              onTap: (e) {
                childTaps++;
                e.stopPropagation();
              },
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();

      expect(childTaps, 1);
      expect(parentTaps, 0);
    });

    testWidgets('ROUTE-FOCUS-1: Tab enters nested targets after their focusable ancestor', (tester) async {
      final outer = FocusNode(debugLabel: 'outer');
      final inner1 = FocusNode(debugLabel: 'inner-1');
      final inner2 = FocusNode(debugLabel: 'inner-2');
      final next = FocusNode(debugLabel: 'next');
      addTearDown(outer.dispose);
      addTearDown(inner1.dispose);
      addTearDown(inner2.dispose);
      addTearDown(next.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTraversalGroup(
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  children: <Widget>[
                    ElView(
                      style: const ElStyle(width: 220, height: 110, bgColor: Color(0xFFCCCCCC)),
                      focusNode: outer,
                      child: Row(
                        children: <Widget>[
                          ElView(
                            style: eventTestDefaultStyle,
                            focusNode: inner1,
                          ),
                          ElView(
                            style: eventTestDefaultStyle,
                            focusNode: inner2,
                          ),
                        ],
                      ),
                    ),
                    ElView(
                      style: eventTestDefaultStyle,
                      focusNode: next,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      outer.requestFocus();
      await tester.pump();
      expect(outer.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(inner1.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(inner2.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(next.hasPrimaryFocus, isTrue);
    });
  });
}

PointerDownEvent _down({required int pointer}) {
  return PointerDownEvent(
    pointer: pointer,
    position: Offset.zero,
    kind: PointerDeviceKind.touch,
    timeStamp: Duration.zero,
  );
}

PointerMoveEvent _move({required int pointer, required double x, required double deltaX, required int millis}) {
  return PointerMoveEvent(
    pointer: pointer,
    position: Offset(x, 0),
    delta: Offset(deltaX, 0),
    kind: PointerDeviceKind.touch,
    timeStamp: Duration(milliseconds: millis),
  );
}

PointerUpEvent _up({required int pointer, required double x, required int millis}) {
  return PointerUpEvent(
    pointer: pointer,
    position: Offset(x, 0),
    kind: PointerDeviceKind.touch,
    timeStamp: Duration(milliseconds: millis),
  );
}
