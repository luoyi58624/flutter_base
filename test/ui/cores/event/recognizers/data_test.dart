import 'dart:math' as math;

import 'package:flutter_base/src/ui/cores/view/event/event.dart' show ElEventDetails;
import 'package:flutter_base/src/ui/cores/view/event/press.dart' hide ElEventDetails;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show Axis, Matrix4;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('按压保留窄指针类型与元数据，不持有变换台账', () {
    final down = PointerDownEvent(pointer: 71, position: Offset(8, 9), buttons: kPrimaryButton);
    final up = PointerUpEvent(pointer: 71, position: Offset(10, 11), timeStamp: Duration(milliseconds: 26));
    final press = PressGestureDetails(
      phase: ElEventPhase.tapUp,
      originalEvent: up,
      globalPosition: up.position,
      buttons: down.buttons,
      downEvent: down,
      tapCount: 2,
    );
    final PointerEvent original = press.originalEvent;
    expect(original, same(up));
    expect(press.downEvent, same(down));
    expect(press.pointer, 71);
    expect(press.timeStamp, Duration(milliseconds: 26));
    expect(press.buttons, kPrimaryButton);
    expect(press.localPosition, Offset(10, 11));
    expect(press.tapCount, 2);
    expect(press, isA<GestureDetails>());
    final dynamic data = press;
    expect(() => data.delta, throwsNoSuchMethodError);
    expect(() => data.velocity, throwsNoSuchMethodError);
    expect(() => data.remainingDelta, throwsNoSuchMethodError);
    expect(() => data.scale, throwsNoSuchMethodError);
    expect(press.isActive, isTrue);
    expect(press.isPrimaryTarget, isTrue);
    expect(press.dispatchIdentity, same(press));
    expect(press.sequenceIdentity, same(press));
    expect(PressCancelReason.ineligible, isNot(PressCancelReason.rejected));
  });

  test('合成采样时间与原始指针时间分别保留，普通事件保持空采样时间', () {
    final raw = PointerMoveEvent(pointer: 72, timeStamp: Duration(milliseconds: 10));
    final transform = TransformGestureDetails(
      phase: ElEventPhase.dragUpdate,
      originalEvent: raw,
      globalPosition: Offset.zero,
      sampleTimeStamp: Duration(milliseconds: 16),
    );
    final callback = ElEventDetails(
      phase: ElEventPhase.dragUpdate,
      originalEvent: raw,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      sampleTimeStamp: transform.sampleTimeStamp,
    );
    final press = PressGestureDetails(
      phase: ElEventPhase.tapDown,
      originalEvent: raw,
      globalPosition: Offset.zero,
      buttons: kPrimaryButton,
    );
    for (final data in [
      (timeStamp: transform.timeStamp, originalEvent: transform.originalEvent),
      (timeStamp: callback.timeStamp, originalEvent: callback.originalEvent),
      (timeStamp: press.timeStamp, originalEvent: press.originalEvent),
    ]) {
      expect(data.timeStamp, Duration(milliseconds: 10));
      expect(data.originalEvent, same(raw));
    }
    expect(transform.sampleTimeStamp, Duration(milliseconds: 16));
    expect(callback.sampleTimeStamp, Duration(milliseconds: 16));
    expect(press.sampleTimeStamp, isNull);
    expect(callback, isNot(isA<GestureDetails>()));
    expect(transform, isA<GestureDetails>());
  });

  testWidgets('逐目标坐标与消费余量使用同一实际变换，派发身份和控制沿链共享', (tester) async {
    final childUpdates = <TransformGestureDetails>[];
    final parentUpdates = <TransformGestureDetails>[];
    Offset? childPosition;
    Offset? childDelta;
    Offset? childRemaining;
    final parent = TransformRecognizer()
      ..axis = Axis.horizontal
      ..startDistance = 2
      ..callbacks[.dragStart] = (_) {}
      ..callbacks[.dragUpdate] = parentUpdates.add;
    final child = TransformRecognizer()
      ..parent = parent
      ..axis = Axis.horizontal
      ..startDistance = 2
      ..callbacks[.dragStart] = (_) {}
      ..callbacks[.dragUpdate] = (details) {
        childUpdates.add(details);
        childPosition = details.localPosition;
        childDelta = details.localDelta;
        details.consumeDelta(Offset(4, 0));
        childRemaining = details.remainingLocalDelta;
        details.preventDefault();
      };
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    final pointer = TestPointer(73);
    final down = pointer.down(Offset(10, 10));
    child.addPointer(down.transformed(Matrix4.diagonal3Values(0.5, 0.5, 1)));
    parent.addPointer(down.transformed(Matrix4.diagonal3Values(0.25, 0.25, 1)));
    GestureBinding.instance.gestureArena.close(pointer.pointer);
    _route(down);
    _route(pointer.move(Offset(30, 10)));
    _route(pointer.move(Offset(38, 12)));
    final childData = childUpdates.single;
    final parentData = parentUpdates.single;
    expect(childData.globalPosition, Offset(38, 12));
    expect(childPosition, Offset(19, 6));
    expect(parentData.localPosition, Offset(9.5, 3));
    expect(childDelta, Offset(4, 0));
    expect(parentData.localDelta, Offset(2, 0));
    expect(childData.dispatchIdentity, same(parentData.dispatchIdentity));
    expect(childData.sequenceIdentity, same(parentData.sequenceIdentity));
    expect(parentData.defaultPrevented, isTrue);
    expect(childRemaining, Offset(2, 0));
    expect(parentData.remainingDelta, Offset(4, 0));
    expect(parentData.remainingLocalDelta, Offset(1, 0));
    _route(pointer.up());
    expect(childData.isActive, isFalse);
  });

  testWidgets('旋转宿主主轴速度由本地向量计算，二维速度继续保留全局方向', (tester) async {
    TransformGestureDetails? end;
    final transform = TransformRecognizer()
      ..axis = Axis.horizontal
      ..startDistance = 2
      ..minFlingDistance = 4
      ..minFlingVelocity = 10
      ..maxFlingVelocity = 300
      ..callbacks[.dragStart] = (_) {}
      ..callbacks[.dragEnd] = (details) => end = details;
    addTearDown(transform.dispose);
    final pointer = TestPointer(74);
    final down = pointer.down(Offset.zero);
    transform.addPointer(down.transformed(Matrix4.rotationZ(-math.pi / 2)));
    GestureBinding.instance.gestureArena.close(pointer.pointer);
    _route(down);
    for (var index = 1; index <= 8; index++) {
      _route(pointer.move(Offset(0, index * 10), timeStamp: Duration(milliseconds: index * 10)));
    }
    _route(pointer.up(timeStamp: Duration(milliseconds: 80)));
    expect(end!.primaryVelocity, closeTo(300, 0.01));
    expect(end!.velocity.pixelsPerSecond.dx, closeTo(0, 0.01));
    expect(end!.velocity.pixelsPerSecond.dy, closeTo(300, 0.01));
    final copied = ElEventDetails(
      phase: end!.phase,
      originalEvent: end!.originalEvent,
      globalPosition: end!.globalPosition,
      localPosition: end!.localPosition,
      dragAxis: end!.dragAxis,
      velocity: end!.velocity,
      primaryVelocity: end!.primaryVelocity,
    );
    expect(copied.primaryVelocity, closeTo(300, 0.01));
  });
}

void _route(PointerEvent event) {
  GestureBinding.instance.pointerRouter.route(event);
  if (event is PointerUpEvent) GestureBinding.instance.gestureArena.sweep(event.pointer);
}
