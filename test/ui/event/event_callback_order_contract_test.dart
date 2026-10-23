import 'package:flutter_base/src/ui/event/index.dart';
import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  testWidgets('ORDER-1: raw、tap 终止与 drag 生命周期保持固定顺序', (tester) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    void record(ElEventCallback event) => phases.add(event.phase);

    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(
        dragStartDistance: 3,
        dragResampling: <TargetPlatform>{},
      ),
      onPointerDown: record,
      onDragDown: record,
      onTapDown: record,
      onPointerMove: record,
      onTapCancel: record,
      onDragStart: record,
      onDragUpdate: record,
      onPointerCancel: record,
      onDragCancel: record,
    );

    await host.dispatch(
      const PointerDownEvent(
        pointer: 1,
        position: Offset.zero,
        kind: PointerDeviceKind.touch,
        timeStamp: Duration.zero,
      ),
    );
    expect(phases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.dragDown,
      ElEventPhase.tapDown,
    ]);

    await host.dispatch(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        kind: PointerDeviceKind.touch,
        timeStamp: Duration(milliseconds: 16),
      ),
    );
    expect(phases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.dragDown,
      ElEventPhase.tapDown,
      ElEventPhase.pointerMove,
      ElEventPhase.dragStart,
    ]);

    await host.dispatch(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(8, 0),
        delta: Offset(4, 0),
        kind: PointerDeviceKind.touch,
        timeStamp: Duration(milliseconds: 32),
      ),
    );
    expect(phases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.dragDown,
      ElEventPhase.tapDown,
      ElEventPhase.pointerMove,
      ElEventPhase.dragStart,
      ElEventPhase.pointerMove,
      ElEventPhase.dragUpdate,
    ]);

    await host.dispatch(
      const PointerCancelEvent(
        pointer: 1,
        position: Offset(8, 0),
        kind: PointerDeviceKind.touch,
        timeStamp: Duration(milliseconds: 48),
      ),
    );
    expect(phases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.dragDown,
      ElEventPhase.tapDown,
      ElEventPhase.pointerMove,
      ElEventPhase.dragStart,
      ElEventPhase.pointerMove,
      ElEventPhase.dragUpdate,
      ElEventPhase.pointerCancel,
      ElEventPhase.dragCancel,
      ElEventPhase.tapCancel,
    ]);
  });

  testWidgets('ORDER-2: 未接受 drag 时 pointer cancel 先发 raw 再终止 tap', (
    tester,
  ) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    void record(ElEventCallback event) => phases.add(event.phase);

    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 100),
      onPointerDown: record,
      onTapDown: record,
      onPointerCancel: record,
      onTapCancel: record,
    );

    await host.dispatch(
      const PointerDownEvent(
        pointer: 2,
        position: Offset.zero,
        kind: PointerDeviceKind.touch,
        timeStamp: Duration.zero,
      ),
    );
    await host.dispatch(
      const PointerCancelEvent(
        pointer: 2,
        position: Offset.zero,
        kind: PointerDeviceKind.touch,
        timeStamp: Duration(milliseconds: 16),
      ),
    );

    expect(phases, <ElEventPhase>[
      ElEventPhase.pointerDown,
      ElEventPhase.tapDown,
      ElEventPhase.pointerCancel,
      ElEventPhase.tapCancel,
    ]);
  });
}
