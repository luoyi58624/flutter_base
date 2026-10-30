import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/event_widget_test_host.dart';

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  group('preventDefault scope', () {
    testWidgets('PointerDown shares the flag with ancestors in the same phase', (tester) async {
      final observations = <String>[];
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(onPointerDown: (event) => observations.add('ancestor:${event.defaultPrevented}')),
          child: ElView(
            style: eventTestDefaultStyle,
            focusNode: focusNode,
            event: ElEvent(
              onPointerDown: (event) {
                observations.add('child:${event.defaultPrevented}');
                event.preventDefault();
              },
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(pointer: 61, kind: PointerDeviceKind.mouse);
      await gesture.down(const Offset(40, 40));
      await tester.pump();

      expect(focusNode.hasPrimaryFocus, isTrue, reason: 'PointerDown 的 preventDefault 不阻止指针聚焦');

      await gesture.up();
      await tester.pump();

      expect(observations, <String>['child:false', 'ancestor:true']);
    });

    testWidgets('PointerDown prevention does not cross into Tap phases', (tester) async {
      final phases = <ElEventPhase, bool>{};
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(
            onPointerDown: (event) {
              event.preventDefault();
              phases[event.phase] = event.defaultPrevented;
            },
            onTapDown: (event) => phases[event.phase] = event.defaultPrevented,
            onTap: (event) => phases[event.phase] = event.defaultPrevented,
          ),
        ),
      );

      await tester.tapAt(const Offset(40, 40));
      await tester.pump();

      expect(phases, <ElEventPhase, bool>{
        ElEventPhase.pointerDown: true,
        ElEventPhase.tapDown: false,
        ElEventPhase.tap: false,
      });
    });

    testWidgets('plain ElView Tap prevention does not stop propagation', (tester) async {
      final observations = <String>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(onTap: (event) => observations.add('ancestor:${event.defaultPrevented}')),
          child: ElView(
            style: eventTestDefaultStyle,
            event: ElEvent(
              onTap: (event) {
                observations.add('child:${event.defaultPrevented}');
                event.preventDefault();
              },
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(40, 40));
      await tester.pump();

      expect(observations, <String>['child:false', 'ancestor:true']);
    });
  });

  test('preventDefault does not consume delta or stop propagation', () {
    final event = ElEventDetails(
      phase: ElEventPhase.dragUpdate,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      delta: const Offset(8, -12),
    );

    event.preventDefault();

    expect(event.defaultPrevented, isTrue);
    expect(event.propagationStopped, isFalse);
    expect(event.remainingDelta, const Offset(8, -12));
    expect(event.remainingPrimaryDelta(.horizontal), 8);
    expect(event.remainingPrimaryDelta(.vertical), -12);
  });

  testWidgets('PointerSignal prevention controls the platform default response', (tester) async {
    bool? platformDefaultAllowed;
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: ElEvent(onPointerSignal: (event) => event.preventDefault()),
      ),
    );

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: const Offset(40, 40),
        scrollDelta: const Offset(0, 20),
        onRespond: ({required bool allowPlatformDefault}) => platformDefaultAllowed = allowPlatformDefault,
      ),
    );
    await tester.pump();
    expect(platformDefaultAllowed, isFalse);

    platformDefaultAllowed = null;
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: ElEvent(onPointerSignal: (_) {}),
      ),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: const Offset(40, 40),
        scrollDelta: const Offset(0, 20),
        onRespond: ({required bool allowPlatformDefault}) => platformDefaultAllowed = allowPlatformDefault,
      ),
    );
    await tester.pump();
    expect(platformDefaultAllowed, isTrue);
  });

  testWidgets('ancestor LongPress prevention rejects automatic ownership', (tester) async {
    var childLongPresses = 0;
    var ancestorLongPresses = 0;
    var childTaps = 0;
    var ancestorPointerUps = 0;
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: ElEvent(
          onLongPress: (event) {
            ancestorLongPresses++;
            event.preventDefault();
          },
          onPointerUp: (_) => ancestorPointerUps++,
        ),
        child: ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(
            config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
            onLongPress: (_) => childLongPresses++,
            onTap: (_) => childTaps++,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(40, 40), pointer: 71);
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.up();
    await tester.pump();

    expect(childLongPresses, 1);
    expect(ancestorLongPresses, 1);
    expect(childTaps, 1, reason: '祖先拒绝长按默认认领后，发起节点仍保留 Tap 资格');
    expect(ancestorPointerUps, 1, reason: 'preventDefault 不收缩原始 pointer 事件链');
  });
}
