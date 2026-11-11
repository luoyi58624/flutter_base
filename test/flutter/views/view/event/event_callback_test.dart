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

  test('consumeDelta re-resolves remaining local delta after clamped consumption', () {
    final event = ElEventDetails(
      phase: ElEventPhase.pointerMove,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      delta: const Offset(10, 0),
      localDelta: const Offset(5, 0),
    )..resolveLocalDelta((globalDelta) => globalDelta / 2.0);

    event.consumeDelta(const Offset(20, 0));

    expect(event.remainingDelta, Offset.zero);
    expect(event.remainingLocalDelta, Offset.zero);
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
      );
      expect(event.originalEvent, same(source));
      expect(event.primaryVelocity, isNull);
      expect(event.logicalKey, source is KeyEvent ? source.logicalKey : null);
      expect(event.physicalKey, source is KeyEvent ? source.physicalKey : null);
      expect(event.character, source is KeyEvent ? source.character : null);
    }
    final explicit = ElEventDetails(
      phase: ElEventPhase.dragEnd,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      primaryVelocity: 37,
    );
    expect(explicit.primaryVelocity, 37);
  });

  test('余量只在消费发生时换算局部坐标', () {
    var resolutions = 0;
    final event = ElEventDetails(
      phase: ElEventPhase.dragUpdate,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      delta: Offset(10, -12),
      localDelta: Offset(5, -6),
    );
    event.resolveLocalDelta((value) {
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
    event.consumePrimaryDelta(Axis.horizontal, -1);
    expect(resolutions, 1);
    expect(event.remainingLocalDelta, Offset(3, -6));
    event.consumePrimaryDelta(Axis.vertical, -100);
    expect(event.remainingDelta, Offset(6, 0));
    event.consumeAllDelta();
    expect(event.remainingDelta, Offset.zero);
    expect(event.remainingLocalDelta, Offset.zero);
  });
}
