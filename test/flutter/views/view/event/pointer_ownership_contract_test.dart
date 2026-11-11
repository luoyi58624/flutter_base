import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  testWidgets('OWN-1: descendant eager drag ends the competing press and ancestor input', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    var parentPointerMoves = 0;
    var parentPointerCancels = 0;
    var parentLongPresses = 0;
    var parentDragStarts = 0;
    var parentTapDowns = 0;
    var parentTapCancels = 0;
    ElEventCancelReason? parentCancelReason;
    ElEventCancelReason? parentPointerCancelReason;
    var childDragStarts = 0;
    final childTapPhases = <ElEventPhase>[];

    host.rootDispatcher.event = .new(
      config: const ElEventConfig(longPressDelay: Duration(milliseconds: 30), dragStartDistance: 3),
      onPointerMove: (_) => parentPointerMoves++,
      onPointerCancel: (event) {
        parentPointerCancels++;
        parentPointerCancelReason = event.cancelReason;
        expect(event.originalEvent, isA<PointerCancelEvent>());
      },
      onLongPress: (_) => parentLongPresses++,
      onDragStart: (_) => parentDragStarts++,
      onTapDown: (_) => parentTapDowns++,
      onTapCancel: (event) {
        parentTapCancels++;
        parentCancelReason = event.cancelReason;
      },
    );
    host.leafDispatcher.event = .new(
      config: const ElEventConfig(dragStartDistance: 3),
      onTapDown: (event) => childTapPhases.add(event.phase),
      onTapUp: (event) => childTapPhases.add(event.phase),
      onTap: (event) => childTapPhases.add(event.phase),
      onTapCancel: (event) => childTapPhases.add(event.phase),
      onDragStart: (event) {
        childDragStarts++;
        event.eagerGesture();
      },
    );

    const down = PointerDownEvent(pointer: 1, position: Offset.zero, buttons: kPrimaryButton, timeStamp: Duration.zero);
    const start = PointerMoveEvent(
      pointer: 1,
      position: Offset(20, 0),
      delta: Offset(20, 0),
      buttons: kPrimaryButton,
      timeStamp: Duration(milliseconds: 16),
    );

    host.dispatch(down);
    host.dispatch(start);
    host.dispatch(const PointerUpEvent(pointer: 1, position: Offset(20, 0), timeStamp: Duration(milliseconds: 32)));
    await tester.pump(const Duration(milliseconds: 80));

    expect(childDragStarts, 1);
    expect(childTapPhases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapCancel]);
    expect(parentTapDowns, 1);
    expect(parentPointerCancels, 1, reason: 'eager loser 必须先收到合成 PointerCancel 以清理 raw 副作用');
    expect(parentPointerCancelReason, ElEventCancelReason.otherGestureAccepted);
    expect(parentTapCancels, 1, reason: 'active loser 必须在失权时恰好收到一次自身 cancel');
    expect(parentCancelReason, ElEventCancelReason.otherGestureAccepted);
    expect(parentPointerMoves, 1, reason: '起拖的原始移动先于 Flutter 的获胜回调');
    expect(parentDragStarts, 0, reason: 'the ancestor primary gesture chain was canceled by the child drag');
    expect(parentLongPresses, 0, reason: 'a child drag winner must cancel the ancestor pending long press');
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('OWN-2: ancestor eager drag cancels active descendant tap', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    host.rootDispatcher.event = _dragEvent('ancestor', trace, eager: true);
    host.leafDispatcher.event = _tapEvent('child', trace);

    host.dispatch(_down(pointer: 2));
    host.dispatch(_move(pointer: 2, x: 4, deltaX: 4, millis: 16));
    host.dispatch(_up(pointer: 2, x: 4, millis: 32));

    expect(trace, hasLength(4));
    expect(trace.toSet(), <String>{'child:tapDown', 'child:tapCancel', 'ancestor:dragStart', 'ancestor:dragEnd'});
  });

  testWidgets('OWN-3: cancelSelfTap settles each active press once and preserves the winner release', (tester) async {
    final host = DispatcherTestHost.chain(depth: 3);
    addTearDown(host.dispose);
    final trace = <String>[];
    host.dispatchers[0].event = _tapEvent('ancestor', trace);
    host.dispatchers[1].event = _tapEvent(
      'winner',
      trace,
    ).copyWith(onPointerMove: (ElEventDetails event) => event.eagerGesture(cancelSelfTap: true));
    host.dispatchers[2].event = _tapEvent('descendant', trace);

    host.dispatch(_down(pointer: 3));
    await tester.pump();
    host.dispatch(_move(pointer: 3, x: 4, deltaX: 4, millis: 16));
    host.dispatch(_up(pointer: 3, x: 4, millis: 32));

    expect(trace, hasLength(7));
    expect(trace.toSet(), <String>{
      'descendant:tapDown',
      'winner:tapDown',
      'ancestor:tapDown',
      'descendant:tapCancel',
      'winner:tapCancel',
      'ancestor:tapCancel',
      'winner:tapUp',
    });
  });

  testWidgets('OWN-4: pointerDown eager keeps the winner raw route and tapUp', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final winnerPhases = <ElEventPhase>[];
    final loserPhases = <ElEventPhase>[];
    void recordWinner(ElEventDetails event) => winnerPhases.add(event.phase);
    void recordLoser(ElEventDetails event) => loserPhases.add(event.phase);

    host.rootDispatcher.event = ElEvent(
      config: _dragConfig,
      onPointerDown: recordLoser,
      onPointerMove: recordLoser,
      onPointerUp: recordLoser,
      onTapDown: recordLoser,
      onTapUp: recordLoser,
      onTap: recordLoser,
      onTapCancel: recordLoser,
      onDragStart: recordLoser,
      onDragUpdate: recordLoser,
      onDragEnd: recordLoser,
    );
    host.leafDispatcher.event = ElEvent(
      config: _dragConfig,
      onPointerDown: (event) {
        recordWinner(event);
        event.eagerGesture(cancelSelfTap: true);
      },
      onPointerMove: recordWinner,
      onPointerUp: recordWinner,
      onTapDown: recordWinner,
      onTapUp: recordWinner,
      onTap: recordWinner,
      onDragStart: recordWinner,
      onDragUpdate: recordWinner,
      onDragEnd: recordWinner,
    );

    host.dispatch(_down(pointer: 4));
    host.dispatch(_move(pointer: 4, x: 4, deltaX: 4, millis: 16));
    host.dispatch(_move(pointer: 4, x: 8, deltaX: 4, millis: 32));
    host.dispatch(_up(pointer: 4, x: 8, millis: 48));

    expect(winnerPhases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.tapDown,
      ElEventPhase.pointerMove,
      ElEventPhase.pointerMove,
      ElEventPhase.pointerUp,
      ElEventPhase.tapUp,
    ]);
    expect(loserPhases, isEmpty, reason: 'pointerDown 中失去 id 后，loser 后续 raw 与语义链都必须停止');
  });

  testWidgets('OWN-5: tapUp eager drops loser callbacks already queued in the same dispatch', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final winnerPhases = <ElEventPhase>[];
    final loserPhases = <ElEventPhase>[];
    host.rootDispatcher.event = ElEvent(
      onTapUp: (event) => loserPhases.add(event.phase),
      onTap: (event) => loserPhases.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(
      onTapUp: (event) {
        winnerPhases.add(event.phase);
        event.eagerGesture();
      },
      onTap: (event) => winnerPhases.add(event.phase),
    );

    host.dispatch(_down(pointer: 5));
    host.dispatch(_up(pointer: 5, x: 0, millis: 16));

    expect(winnerPhases, <ElEventPhase>[ElEventPhase.tapUp, ElEventPhase.tap]);
    expect(loserPhases, isEmpty, reason: '同轮已入队回调执行前也必须重查 pointer membership');
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('OWN-13: eagerGesture 返回前同步结清 loser terminal', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    var winnerSideEffectCommitted = false;
    final loserTerminals = <ElEventPhase>[];
    final loserObservedCommittedStates = <bool>[];
    host.rootDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onTapDown: (_) {},
      onPointerCancel: (event) {
        loserTerminals.add(event.phase);
        loserObservedCommittedStates.add(winnerSideEffectCommitted);
      },
      onTapCancel: (event) {
        loserTerminals.add(event.phase);
        loserObservedCommittedStates.add(winnerSideEffectCommitted);
      },
    );
    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onDragStart: (event) {
        event.eagerGesture(cancelSelfTap: true);
        winnerSideEffectCommitted = true;
      },
    );

    host.dispatch(const PointerDownEvent(pointer: 13, position: Offset.zero, buttons: kPrimaryButton));
    host.dispatch(
      const PointerMoveEvent(
        pointer: 13,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 16),
      ),
    );

    expect(loserTerminals, <ElEventPhase>[ElEventPhase.pointerCancel, ElEventPhase.tapCancel]);
    expect(loserObservedCommittedStates, <bool>[false, false], reason: 'eager 事务的全部 loser terminal 必须在调用返回前完成。');
  });

  testWidgets('OWN-14: raw-started loser receives PointerCancel without an orphan TapCancel', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    Object? originalEvent;
    ElEventCancelReason? cancelReason;
    var pointerCount = -1;
    var orphanTapCancels = 0;
    host.rootDispatcher.event = ElEvent(
      onPointerDown: (event) => phases.add(event.phase),
      onPointerCancel: (event) {
        phases.add(event.phase);
        originalEvent = event.originalEvent;
        cancelReason = event.cancelReason;
        pointerCount = event.pointerCount;
      },
      onTapCancel: (_) => orphanTapCancels++,
    );
    host.leafDispatcher.event = ElEvent(onTapDown: (event) => event.eagerGesture());

    host.dispatch(_down(pointer: 14));
    await tester.pump();

    expect(phases, <ElEventPhase>[ElEventPhase.pointerDown, ElEventPhase.pointerCancel]);
    expect(originalEvent, isA<PointerCancelEvent>());
    expect(cancelReason, ElEventCancelReason.otherGestureAccepted);
    expect(pointerCount, 0);
    expect(orphanTapCancels, 0, reason: '尚未收到 TapDown 的 raw loser 不得产生孤立 TapCancel');
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('OWN-17: eager clears an active side-button tracker after PointerCancel', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final parentPhases = <ElEventPhase>[];
    host.rootDispatcher.event = ElEvent(
      onPointerCancel: (event) => parentPhases.add(event.phase),
      onSecondaryTapDown: (event) => parentPhases.add(event.phase),
      onSecondaryTapUp: (event) => parentPhases.add(event.phase),
      onSecondaryTap: (event) => parentPhases.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(onPointerMove: (event) => event.eagerGesture());

    host.dispatch(
      const PointerDownEvent(
        pointer: 17,
        kind: PointerDeviceKind.mouse,
        position: Offset.zero,
        buttons: kSecondaryButton,
      ),
    );
    host.dispatch(
      const PointerMoveEvent(
        pointer: 17,
        kind: PointerDeviceKind.mouse,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        buttons: kSecondaryButton,
      ),
    );
    host.dispatch(const PointerUpEvent(pointer: 17, kind: PointerDeviceKind.mouse, position: Offset(4, 0)));

    expect(parentPhases, <ElEventPhase>[ElEventPhase.secondaryTapDown, ElEventPhase.pointerCancel]);
  });

  testWidgets('OWN-18: eager clears an active PanZoom route after PointerCancel', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final parentPhases = <ElEventPhase>[];
    host.rootDispatcher.event = ElEvent(
      onPointerCancel: (event) {
        parentPhases.add(event.phase);
        expect(event.originalEvent, isA<PointerCancelEvent>());
      },
      onPointerPanZoomStart: (event) => parentPhases.add(event.phase),
      onPointerPanZoomUpdate: (event) => parentPhases.add(event.phase),
      onPointerPanZoomEnd: (event) => parentPhases.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(onPointerPanZoomUpdate: (event) => event.eagerGesture());

    host.dispatch(const PointerPanZoomStartEvent(pointer: 18, position: Offset(20, 20)));
    host.dispatch(
      const PointerPanZoomUpdateEvent(pointer: 18, position: Offset(20, 20), pan: Offset(4, 0), panDelta: Offset(4, 0)),
    );
    host.dispatch(const PointerPanZoomEndEvent(pointer: 18, position: Offset(20, 20)));

    expect(parentPhases, <ElEventPhase>[ElEventPhase.pointerPanZoomStart, ElEventPhase.pointerCancel]);
  });

  testWidgets('OWN-11: cancelAllPending keeps the winner tombstone until pointer terminal', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    var parentPointerMoves = 0;
    host.rootDispatcher.event = ElEvent(onPointerMove: (_) => parentPointerMoves++);
    host.leafDispatcher.event = ElEvent(onPointerDown: (event) => event.eagerGesture());

    const down = PointerDownEvent(pointer: 11, position: Offset.zero, timeStamp: Duration.zero);
    const move = PointerMoveEvent(
      pointer: 11,
      position: Offset(20, 0),
      delta: Offset(20, 0),
      timeStamp: Duration(milliseconds: 16),
    );
    const up = PointerUpEvent(pointer: 11, position: Offset(20, 0), timeStamp: Duration(milliseconds: 32));

    host.dispatch(down);
    host.leafDispatcher.cancelAllPending(move);
    host.dispatch(move);
    host.dispatch(up);

    expect(parentPointerMoves, 0, reason: 'winner 自身清理机器状态不能让同一 pointer 的 loser 复活');
  });
}

const _dragConfig = ElEventConfig(dragStartDistance: 3);

ElEvent _tapEvent(String owner, List<String> trace) {
  void record(ElEventDetails event) => trace.add('$owner:${event.phase.name}');
  return ElEvent(onTapDown: record, onTapUp: record, onTap: record, onTapCancel: record);
}

ElEvent _dragEvent(String owner, List<String> trace, {bool eager = false}) {
  void record(ElEventDetails event) => trace.add('$owner:${event.phase.name}');
  return ElEvent(
    config: _dragConfig,
    onDragStart: (event) {
      record(event);
      if (eager) event.eagerGesture();
    },
    onDragEnd: record,
  );
}

PointerDownEvent _down({required int pointer, int millis = 0}) => PointerDownEvent(
  pointer: pointer,
  position: Offset.zero,
  kind: PointerDeviceKind.touch,
  timeStamp: Duration(milliseconds: millis),
);

PointerMoveEvent _move({required int pointer, required double x, required double deltaX, required int millis}) =>
    PointerMoveEvent(
      pointer: pointer,
      position: Offset(x, 0),
      delta: Offset(deltaX, 0),
      kind: PointerDeviceKind.touch,
      timeStamp: Duration(milliseconds: millis),
    );

PointerUpEvent _up({required int pointer, required double x, required int millis}) => PointerUpEvent(
  pointer: pointer,
  position: Offset(x, 0),
  kind: PointerDeviceKind.touch,
  timeStamp: Duration(milliseconds: millis),
);
