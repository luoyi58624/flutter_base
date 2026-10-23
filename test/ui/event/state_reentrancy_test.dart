import 'package:flutter/gestures.dart';
import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  testWidgets('按压释放通知中替换配置仍兑现旧 TapUp 与 Tap', (_) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final dispatcher = host.leafDispatcher;
    final phases = <String>[];
    dispatcher
      ..onTapChanged = (pressed) {
        phases.add('pressed:$pressed');
        if (!pressed) {
          dispatcher.event = ElEvent(onTap: (_) => phases.add('new:tap'));
        }
      }
      ..event = ElEvent(
        onTapUp: (_) => phases.add('old:tapUp'),
        onTap: (_) => phases.add('old:tap'),
      );

    host.dispatch(
      const PointerDownEvent(
        pointer: 1,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      ),
    );
    host.dispatch(
      const PointerUpEvent(pointer: 1, kind: PointerDeviceKind.mouse),
    );

    expect(phases, <String>[
      'pressed:true',
      'old:tapUp',
      'old:tap',
      'pressed:false',
    ]);
    expect(dispatcher.isTapPressed, isFalse);
    expect(dispatcher.activePointerCount, 0);
  });

  testWidgets('拖拽释放通知中替换配置仍兑现唯一旧 DragCancel', (_) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final dispatcher = host.leafDispatcher;
    final phases = <String>[];
    dispatcher
      ..onDragChanged = (dragged) {
        phases.add('dragged:$dragged');
        if (!dragged) dispatcher.event = const ElEvent();
      }
      ..event = ElEvent(
        config: const ElEventConfig(
          dragStartDistance: 3,
          delayTouchUp: Duration.zero,
        ),
        onDragStart: (_) => phases.add('old:dragStart'),
        onDragCancel: (_) => phases.add('old:dragCancel'),
      );

    host.dispatch(const PointerDownEvent(pointer: 2));
    host.dispatch(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(5, 0),
        delta: Offset(5, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
    );
    expect(dispatcher.isDragged, isTrue);
    host.dispatch(const PointerCancelEvent(pointer: 2, position: Offset(5, 0)));
    host.dispatch(const PointerUpEvent(pointer: 2, position: Offset(5, 0)));

    expect(phases, <String>[
      'old:dragStart',
      'dragged:true',
      'old:dragCancel',
      'dragged:false',
    ]);
    expect(dispatcher.isDragged, isFalse);
    expect(dispatcher.activePointerCount, 0);
  });

  testWidgets('状态通知重入新周期不会覆盖单例队列', (_) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final dispatcher = host.leafDispatcher;
    final states = <bool>[];
    dispatcher
      ..event = const ElEvent()
      ..onTapChanged = (pressed) {
        states.add(pressed);
        if (pressed) dispatcher.cancelAllPendingAtLastPosition();
      };

    for (var pointer = 3; pointer <= 4; pointer++) {
      host.dispatch(
        PointerDownEvent(
          pointer: pointer,
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryButton,
        ),
      );
      host.dispatch(
        PointerUpEvent(pointer: pointer, kind: PointerDeviceKind.mouse),
      );
    }

    expect(states, <bool>[true, false, true, false]);
    expect(dispatcher.isTapPressed, isFalse);
    expect(dispatcher.activePointerCount, 0);
  });

  testWidgets('收到祖先 DragStart 提案的节点同步公开与结清拖拽状态', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    final states = <bool>[];
    host.rootDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 0),
      onDragStart: (_) {},
      onDragEnd: (_) {},
      onDragCancel: (_) {},
    );
    host.leafDispatcher
      ..onDragChanged = states.add
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 20),
        onDragStart: (event) => phases.add(event.phase),
        onDragEnd: (event) => phases.add(event.phase),
        onDragCancel: (event) => phases.add(event.phase),
      );

    host.dispatch(const PointerDownEvent(pointer: 5));
    host.dispatch(
      const PointerMoveEvent(
        pointer: 5,
        position: Offset(5, 0),
        delta: Offset(5, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
    );
    expect(host.leafDispatcher.isDragged, isTrue);
    expect(states, <bool>[true]);
    host.dispatch(const PointerUpEvent(pointer: 5, position: Offset(5, 0)));

    expect(phases, <ElEventPhase>[
      ElEventPhase.dragStart,
      ElEventPhase.dragEnd,
    ]);
    expect(states, <bool>[true, false]);
    expect(host.leafDispatcher.isDragged, isFalse);
  });
}
