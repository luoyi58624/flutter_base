import 'package:flutter_base/src/ui/cores/view/event/event.dart';
import 'package:flutter_base/src/ui/cores/view/event/press.dart' show GestureControl, GestureControlAccess, EventDetailsAccess;
import 'package:flutter/gestures.dart' show Velocity;
import 'package:flutter/rendering.dart' show Axis;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('业务回调与通用识别结果共享同阶段控制，代理复位不清除默认动作标记', () {
    final control = GestureControl();
    ElEventDetails callback() =>
        ElEventDetails(phase: ElEventPhase.pointerMove, globalPosition: Offset.zero, localPosition: Offset.zero)
          ..shareControl(control);
    final child = callback();
    final parent = callback();
    child.preventDefault();
    parent.stopPropagation();
    expect(control.defaultPrevented, isTrue);
    expect(parent.defaultPrevented, isTrue);
    expect(child.propagationStopped, isTrue);
    child.resetPropagation();
    expect(parent.propagationStopped, isFalse);
    expect(parent.defaultPrevented, isTrue);
    expect(callback().defaultPrevented, isTrue);
  });

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

  test('consumeDelta re-resolves remaining local delta after clamped consumption', () {
    final event = ElEventDetails(
      phase: ElEventPhase.pointerMove,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      delta: const Offset(10, 0),
      localDelta: const Offset(5, 0),
    )..updateLocalDeltaResolver((globalDelta) => globalDelta / 2.0);

    event.consumeDelta(const Offset(20, 0));

    expect(event.remainingDelta, Offset.zero);
    expect(event.remainingLocalDelta, Offset.zero);
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

  test('业务原始事件可为键盘、其他对象或空，主轴速度保持显式可空', () {
    final key = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration(milliseconds: 12),
      character: 'a',
    );
    final marker = Object();
    for (final source in <Object?>[key, marker, null]) {
      final event = ElEventDetails(
        phase: ElEventPhase.keyDown,
        globalPosition: Offset.zero,
        localPosition: Offset.zero,
        originalEvent: source,
        dragAxis: Axis.horizontal,
        velocity: Velocity(pixelsPerSecond: Offset(100, 200)),
        logicalKey: key.logicalKey,
        physicalKey: key.physicalKey,
        character: key.character,
      );
      expect(event.originalEvent, same(source));
      expect(event.primaryVelocity, isNull);
      expect(event.logicalKey, LogicalKeyboardKey.keyA);
      expect(event.physicalKey, PhysicalKeyboardKey.keyA);
      expect(event.character, 'a');
    }
    final explicit = ElEventDetails(
      phase: ElEventPhase.dragEnd,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      primaryVelocity: 37,
    );
    expect(explicit.primaryVelocity, 37);
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

  test('余量换算保留未消费快路，消费后才换算，移除换算器恢复全局余量', () {
    var resolutions = 0;
    final event = ElEventDetails(
      phase: ElEventPhase.dragUpdate,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      delta: Offset(10, -12),
      localDelta: Offset(5, -6),
    );
    event.updateLocalDeltaResolver((value) {
      resolutions++;
      return value / 2;
    });
    expect(resolutions, 0);
    expect(event.remainingLocalDelta, Offset(5, -6));
    event.consumePrimaryDelta(Axis.horizontal, 4);
    expect(resolutions, 1);
    expect(event.remainingDelta, Offset(6, -12));
    expect(event.remainingLocalDelta, Offset(3, -6));
    expect(event.remainingPrimaryDelta(Axis.vertical), -12);
    event.updateLocalDeltaResolver(null);
    expect(event.remainingLocalDelta, Offset(6, -12));
    event.consumePrimaryDelta(Axis.vertical, -100);
    expect(event.remainingDelta, Offset(6, 0));
    event.consumeAllDelta();
    expect(event.remainingDelta, Offset.zero);
    expect(event.remainingLocalDelta, Offset.zero);
  });

  test('业务焦点、独占和管线状态由原处理器执行并保留回调对象', () {
    final event = ElEventDetails(
      phase: ElEventPhase.pointerDown,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      focusReason: ElFocusReason.pointer,
    );
    ElEventDetails? eagerSource;
    (bool, bool)? options;
    var preserved = 0;
    event.updateEagerGestureHandler((source, cancelTap, allowScale) {
      eagerSource = source;
      options = (cancelTap, allowScale);
    });
    event.updatePreserveFocusHandler(() => preserved++);
    event.eagerGesture(cancelSelfTap: true, allowScaleUpgrade: true);
    event.preserveFocus();
    event.markCallbackInvoked();
    event.dragPipelineActive = true;
    event.dragBoundaryHandoff = true;
    event.hasAncestorDragConsumer = true;
    expect(eagerSource, same(event));
    expect(options, (true, true));
    expect(preserved, 1);
    expect(event.callbackInvoked, isTrue);
    expect(event.focusReason, ElFocusReason.pointer);
    expect([event.dragPipelineActive, event.dragBoundaryHandoff, event.hasAncestorDragConsumer], everyElement(isTrue));
    event.updateEagerGestureHandler(null);
    event.updatePreserveFocusHandler(null);
    event.eagerGesture();
    event.preserveFocus();
    expect(options, (true, true));
    expect(preserved, 1);
  });
}
