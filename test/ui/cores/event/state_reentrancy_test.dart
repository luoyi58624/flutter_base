import 'package:flutter/gestures.dart';
import 'package:flutter_base/src/ui/cores/event/index.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/event_test_host.dart';

void main() {
  testWidgets('释放回调重入同一指针的新按下，旧释放通知不清除新反馈', (tester) async {
    final host = EventTestHost.chain();
    addTearDown(host.dispose);
    var restarted = false;
    host.leaf
      ..onTapChanged = (_) {}
      ..event = ElEvent(
        onTap: (_) {
          if (restarted) return;
          restarted = true;
          host.direct(
            0,
            const PointerDownEvent(
              pointer: 1800,
              kind: PointerDeviceKind.mouse,
              timeStamp: Duration(milliseconds: 30),
            ),
          );
        },
      );
    await host.dispatch(
      const PointerDownEvent(pointer: 1800, kind: PointerDeviceKind.mouse),
    );
    await host.dispatch(
      const PointerUpEvent(
        pointer: 1800,
        kind: PointerDeviceKind.mouse,
        timeStamp: Duration(milliseconds: 20),
      ),
    );
    expect(host.leaf.isTapPressed, isTrue);
    await host.dispatch(
      const PointerUpEvent(
        pointer: 1800,
        kind: PointerDeviceKind.mouse,
        timeStamp: Duration(milliseconds: 40),
      ),
    );
    expect(host.leaf.isTapPressed, isFalse);
    expect(host.leaf.activePointerCount, 0);
  });

  testWidgets('按压释放通知中替换配置仍兑现旧 TapUp 与 Tap', (_) async {
    final host = EventTestHost.chain();
    addTearDown(host.dispose);
    final element = host.leaf;
    final phases = <String>[];
    element
      ..onTapChanged = (pressed) {
        phases.add('pressed:$pressed');
        if (!pressed) {
          element.event = ElEvent(onTap: (_) => phases.add('new:tap'));
        }
      }
      ..event = ElEvent(
        onTapUp: (_) => phases.add('old:tapUp'),
        onTap: (_) => phases.add('old:tap'),
      );

    await host.dispatch(
      const PointerDownEvent(
        pointer: 1,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      ),
    );
    await host.dispatch(
      const PointerUpEvent(pointer: 1, kind: PointerDeviceKind.mouse),
    );

    expect(phases, <String>[
      'pressed:true',
      'old:tapUp',
      'old:tap',
      'pressed:false',
    ]);
    expect(element.isTapPressed, isFalse);
    expect(element.activePointerCount, 0);
  });

  testWidgets('拖拽取消回调内替换配置只兑现一次旧 DragCancel', (_) async {
    final host = EventTestHost.chain();
    addTearDown(host.dispose);
    final element = host.leaf;
    final phases = <String>[];
    element.event = ElEvent(
      config: const ElEventConfig(
        dragStartDistance: 3,
        delayTouchUp: Duration.zero,
      ),
      onDragStart: (_) => phases.add('old:dragStart'),
      onDragCancel: (_) {
        phases.add('old:dragCancel');
        element.event = const ElEvent();
      },
    );

    await host.dispatch(const PointerDownEvent(pointer: 2));
    await host.dispatch(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(5, 0),
        delta: Offset(5, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
    );
    expect(element.isDragged, isTrue);
    await host.dispatch(
      const PointerCancelEvent(pointer: 2, position: Offset(5, 0)),
    );
    await host.dispatch(
      const PointerUpEvent(pointer: 2, position: Offset(5, 0)),
    );

    expect(phases, <String>['old:dragStart', 'old:dragCancel']);
    expect(element.isDragged, isFalse);
    expect(element.activePointerCount, 0);
  });

  testWidgets('状态通知重入新周期不会覆盖单例队列', (_) async {
    final host = EventTestHost.chain();
    addTearDown(host.dispose);
    final element = host.leaf;
    final states = <bool>[];
    element
      ..event = const ElEvent()
      ..onTapChanged = (pressed) {
        states.add(pressed);
        if (pressed) element.cancelAllPendingAtLastPosition();
      };

    for (var pointer = 3; pointer <= 4; pointer++) {
      await host.dispatch(
        PointerDownEvent(
          pointer: pointer,
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryButton,
        ),
      );
      await host.dispatch(
        PointerUpEvent(pointer: pointer, kind: PointerDeviceKind.mouse),
      );
    }

    expect(states, <bool>[true, false, true, false]);
    expect(element.isTapPressed, isFalse);
    expect(element.activePointerCount, 0);
  });

  testWidgets('不同阈值分别参赛，祖先获胜后子节点只结清候选', (_) async {
    final host = EventTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    host.rootElement.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 0),
      onDragStart: (_) {},
      onDragEnd: (_) {},
      onDragCancel: (_) {},
    );
    host.leaf.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 20),
      onDragDown: (event) => phases.add(event.phase),
      onDragStart: (event) => phases.add(event.phase),
      onDragEnd: (event) => phases.add(event.phase),
      onDragCancel: (event) => phases.add(event.phase),
    );

    await host.dispatch(const PointerDownEvent(pointer: 5));
    await host.dispatch(
      const PointerMoveEvent(
        pointer: 5,
        position: Offset(5, 0),
        delta: Offset(5, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
    );
    expect(host.leaf.isDragged, isFalse);
    await host.dispatch(
      const PointerUpEvent(pointer: 5, position: Offset(5, 0)),
    );

    expect(phases, <ElEventPhase>[
      ElEventPhase.dragDown,
      ElEventPhase.dragCancel,
    ]);
    expect(host.leaf.isDragged, isFalse);
  });
}
