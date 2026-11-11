import 'package:flutter_base/src/flutter/views/view/event/event.dart' show ElEventDetails;
import 'package:flutter_base/src/flutter/views/view/event/press.dart' hide ElEventDetails;
import 'package:flutter/gestures.dart';
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
    final callback = ElEventDetails(
      phase: ElEventPhase.dragUpdate,
      originalEvent: raw,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      sampleTimeStamp: Duration(milliseconds: 16),
    );
    final press = PressGestureDetails(
      phase: ElEventPhase.tapDown,
      originalEvent: raw,
      globalPosition: Offset.zero,
      buttons: kPrimaryButton,
    );
    for (final data in [
      (timeStamp: callback.timeStamp, originalEvent: callback.originalEvent),
      (timeStamp: press.timeStamp, originalEvent: press.originalEvent),
    ]) {
      expect(data.timeStamp, Duration(milliseconds: 10));
      expect(data.originalEvent, same(raw));
    }
    expect(callback.sampleTimeStamp, Duration(milliseconds: 16));
    expect(press.sampleTimeStamp, isNull);
    expect(callback, isNot(isA<GestureDetails>()));
  });
}
