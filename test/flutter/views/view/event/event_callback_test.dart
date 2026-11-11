import 'package:flutter_base/src/flutter/views/view/event/event.dart';
import 'package:flutter_base/src/flutter/views/view/event/details.dart' show EventDetailsAccess;
import 'package:flutter/gestures.dart' show Velocity;
import 'package:flutter/rendering.dart' show Axis;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consumeDelta clamps over-consumption without reversing remaining delta', () {
    final event = ElEventDetails(
      phase: ElEventPhase.pointerMove,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      delta: const Offset(10, -5),
    );

    event.consumeDelta(const Offset(20, -2));

    expect(event.remainingDelta, const Offset(0, -3));

    event.consumeDelta(const Offset(0, -10));

    expect(event.remainingDelta, Offset.zero);
  });

  test('consumeDelta ignores opposite-direction consumption', () {
    final event = ElEventDetails(
      phase: ElEventPhase.pointerMove,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      delta: const Offset(10, 0),
    );

    event.consumeDelta(const Offset(-4, 0));

    expect(event.remainingDelta, const Offset(10, 0));
  });

  test('业务可写属性独立保留，不因共享基类而重置其他余量', () {
    final event = ElEventDetails(
      phase: ElEventPhase.dragUpdate,
      globalPosition: Offset(30, 40),
      localPosition: Offset(3, 4),
      delta: Offset(10, 20),
      localDelta: Offset(5, 10),
      remainingDelta: Offset(8, 16),
      remainingLocalDelta: Offset(4, 8),
      pointerCount: 2,
    );
    event.localPosition = Offset(6, 7);
    event.localDelta = Offset(2, 3);
    event.remainingDelta = Offset(4, 6);
    event.remainingLocalDelta = Offset(1, 2);
    event.pointerCount = 1;
    expect([event.globalX, event.globalY, event.localX, event.localY], [30, 40, 6, 7]);
    expect(event.delta, Offset(10, 20));
    expect(event.localDelta, Offset(2, 3));
    expect(event.remainingDelta, Offset(4, 6));
    expect(event.remainingLocalDelta, Offset(1, 2));
    expect(event.pointerCount, 1);
  });

  test('业务取消原因保持旧五项及默认值，禁止把原因放到其他阶段', () {
    expect(ElEventCancelReason.values.map((value) => value.name), [
      'tapRejected',
      'selfGestureAccepted',
      'otherGestureAccepted',
      'pointerCanceled',
      'external',
    ]);
    ElEventDetails callback(ElEventPhase phase, {ElEventCancelReason? reason}) =>
        ElEventDetails(phase: phase, globalPosition: Offset.zero, localPosition: Offset.zero, cancelReason: reason);
    expect(callback(ElEventPhase.tapCancel).cancelReason, ElEventCancelReason.external);
    expect(callback(ElEventPhase.pointerCancel).cancelReason, ElEventCancelReason.pointerCanceled);
    expect(
      callback(ElEventPhase.tapCancel, reason: ElEventCancelReason.selfGestureAccepted).cancelReason,
      ElEventCancelReason.selfGestureAccepted,
    );
    expect(() => callback(ElEventPhase.tap, reason: ElEventCancelReason.external), throwsAssertionError);
  });

}
