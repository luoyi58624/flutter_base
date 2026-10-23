import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'consumeDelta clamps over-consumption without reversing remaining delta',
    () {
      final event = ElEventCallback(
        phase: ElEventPhase.pointerMove,
        globalPosition: Offset.zero,
        localPosition: Offset.zero,
        delta: const Offset(10, -5),
      );

      event.consumeDelta(const Offset(20, -2));

      expect(event.remainingDelta, const Offset(0, -3));

      event.consumeDelta(const Offset(0, -10));

      expect(event.remainingDelta, Offset.zero);
    },
  );

  test('consumeDelta ignores opposite-direction consumption', () {
    final event = ElEventCallback(
      phase: ElEventPhase.pointerMove,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      delta: const Offset(10, 0),
    );

    event.consumeDelta(const Offset(-4, 0));

    expect(event.remainingDelta, const Offset(10, 0));
  });

  test(
    'consumeDelta re-resolves remaining local delta after clamped consumption',
    () {
      final event = ElEventCallback(
        phase: ElEventPhase.pointerMove,
        globalPosition: Offset.zero,
        localPosition: Offset.zero,
        delta: const Offset(10, 0),
        localDelta: const Offset(5, 0),
      )..updateLocalDeltaResolver((globalDelta) => globalDelta / 2.0);

      event.consumeDelta(const Offset(20, 0));

      expect(event.remainingDelta, Offset.zero);
      expect(event.remainingLocalDelta, Offset.zero);
    },
  );
}
