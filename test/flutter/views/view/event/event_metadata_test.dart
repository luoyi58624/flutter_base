import 'dart:async';

import 'package:flutter_base/src/flutter/views/view/event/event.dart';
import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

void main() {
  testWidgets('tapDown tapUp and immediate tap preserve original pointer events and buttons', (tester) async {
    final box = _attachedBox();

    final originalEvents = <ElEventPhase, Object?>{};
    final buttons = <ElEventPhase, int>{};
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onTapDown: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
        onTapUp: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
        onTap: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
      );
    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset(20, 20), buttons: kPrimaryButton),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 1, position: Offset(20, 20), buttons: kPrimaryButton),
      entry,
    );
    dispatcher.dispose();

    expect(originalEvents[ElEventPhase.tapDown], isA<PointerDownEvent>());
    expect(originalEvents[ElEventPhase.tapUp], isA<PointerUpEvent>());
    expect(originalEvents[ElEventPhase.tap], isA<PointerUpEvent>());
    expect(buttons[ElEventPhase.tapDown], kPrimaryButton);
    expect(buttons[ElEventPhase.tapUp], kPrimaryButton);
    expect(buttons[ElEventPhase.tap], kPrimaryButton);
  });

  testWidgets('primary tap candidate cancels when mouse buttons change before up', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    Object? cancelOriginalEvent;
    int? cancelButtons;
    ElEventCancelReason? cancelReason;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onTapDown: (event) => phases.add(event.phase),
        onTapUp: (event) => phases.add(event.phase),
        onTap: (event) => phases.add(event.phase),
        onTapCancel: (event) {
          phases.add(event.phase);
          cancelOriginalEvent = event.originalEvent;
          cancelButtons = event.buttons;
          cancelReason = event.cancelReason;
        },
      );
    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(
        pointer: 11,
        kind: PointerDeviceKind.mouse,
        position: Offset(20, 20),
        buttons: kPrimaryButton,
      ),
      entry,
    );
    await tester.pump(kPressTimeout);
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 11,
        kind: PointerDeviceKind.mouse,
        position: Offset(20, 20),
        delta: Offset.zero,
        buttons: 0,
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 11, kind: PointerDeviceKind.mouse, position: Offset(20, 20), buttons: 0),
      entry,
    );
    dispatcher.dispose();

    expect(phases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapCancel]);
    expect(cancelOriginalEvent, isA<PointerMoveEvent>());
    expect(cancelButtons, 0);
    expect(cancelReason, ElEventCancelReason.tapRejected);
  });

  testWidgets('removing event during active tap dispatches cancel to old event', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    ElEventCancelReason? cancelReason;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onTapDown: (event) => phases.add(event.phase),
        onTapCancel: (event) {
          phases.add(event.phase);
          cancelReason = event.cancelReason;
        },
      );
    final entry = BoxHitTestEntry(box, Offset.zero);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(20, 20)), entry);
    await tester.pump(kPressTimeout);
    dispatcher.event = null;

    expect(phases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapCancel]);
    expect(cancelReason, ElEventCancelReason.external);
    expect(dispatcher.isTapPressed, isFalse);
    expect(dispatcher.activePointerCount, 0);

    dispatcher.dispose();
  });

  testWidgets('disposing dispatcher during active tap dispatches cancel', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    ElEventCancelReason? cancelReason;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onTapDown: (event) => phases.add(event.phase),
        onTapCancel: (event) {
          phases.add(event.phase);
          cancelReason = event.cancelReason;
        },
      );
    final entry = BoxHitTestEntry(box, Offset.zero);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(20, 20)), entry);
    await tester.pump(kPressTimeout);
    dispatcher.dispose();

    expect(phases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapCancel]);
    expect(cancelReason, ElEventCancelReason.external);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('preserved detach 保留活动序列与按压状态，重挂后同一条手势继续走完', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    final event = ElEvent(
      onTapDown: (event) => phases.add(event.phase),
      onTapUp: (event) => phases.add(event.phase),
      onTap: (event) => phases.add(event.phase),
      onTapCancel: (event) => phases.add(event.phase),
    );
    final dispatcher = EventDispatcher(box)..event = event;
    dispatcher.onTapChanged = (_) {};
    final entry = BoxHitTestEntry(box, Offset.zero);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(20, 20)), entry);
    expect(dispatcher.activePointerCount, 1);
    expect(dispatcher.isTapPressed, isTrue);

    dispatcher.detach(preserveEvent: true);
    expect(dispatcher.event, same(event));
    expect(dispatcher.activePointerCount, 1, reason: '临时重挂沿用按下时的输入路线');
    expect(dispatcher.isTapPressed, isTrue, reason: '重挂不得熄灭按压状态——用户手指还按着');

    // 重挂不是手势结束：同一条 pointer 的抬手仍要照常走完 tapUp / tap。
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(20, 20)), entry);
    expect(phases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
    expect(dispatcher.isTapPressed, isFalse);

    dispatcher.attach();
    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 2, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 2, position: Offset(20, 20)), entry);
    dispatcher.dispose();

    expect(phases, <ElEventPhase>[
      ElEventPhase.tapDown,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
      ElEventPhase.tapDown,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
    ]);
  });

  testWidgets('removing event during active pointerPanZoom dispatches terminal end', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onPointerPanZoomStart: (event) => phases.add(event.phase),
        onPointerPanZoomEnd: (event) => phases.add(event.phase),
      );
    final entry = BoxHitTestEntry(box, Offset.zero);

    dispatcher.dispatchTestPointer(const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.event = null;
    dispatcher.dispose();

    expect(phases, <ElEventPhase>[ElEventPhase.pointerPanZoomStart, ElEventPhase.pointerPanZoomEnd]);
  });

  testWidgets('raw pointerCount 按祖先目标报告 1→2→1→0 且排除并存 panZoom', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    void record(ElEventDetails event) => trace.add('${event.phase.name}:${event.pointerCount}');

    host.rootDispatcher.event = ElEvent(
      onPointerDown: record,
      onPointerMove: record,
      onPointerUp: record,
      onPointerPanZoomStart: (_) {},
      onPointerPanZoomEnd: (_) {},
    );
    host.leafDispatcher.event = ElEvent(onPointerDown: (_) {});

    host.dispatch(const PointerDownEvent(pointer: 41, kind: PointerDeviceKind.touch, position: Offset(20, 20)));
    host.dispatch(const PointerPanZoomStartEvent(pointer: 90, position: Offset(20, 20)));
    host.dispatch(const PointerDownEvent(pointer: 42, kind: PointerDeviceKind.touch, position: Offset(30, 20)));
    host.dispatch(
      const PointerMoveEvent(pointer: 41, kind: PointerDeviceKind.touch, position: Offset(24, 20), delta: Offset(4, 0)),
    );
    host.dispatch(const PointerUpEvent(pointer: 41, kind: PointerDeviceKind.touch, position: Offset(24, 20)));
    host.dispatch(const PointerUpEvent(pointer: 42, kind: PointerDeviceKind.touch, position: Offset(30, 20)));
    host.dispatch(const PointerPanZoomEndEvent(pointer: 90, position: Offset(20, 20)));

    expect(trace, <String>['pointerDown:1', 'pointerDown:2', 'pointerMove:2', 'pointerUp:1', 'pointerUp:0']);
  });

  testWidgets('拖拽详情在抬手后保留更新时的 pointerCount 快照', (tester) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final deferredCounts = <int>[];

    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onHorizontalDragUpdate: (event) => scheduleMicrotask(() => deferredCounts.add(event.pointerCount)),
    );

    host.dispatch(const PointerDownEvent(pointer: 43, kind: PointerDeviceKind.mouse, position: Offset(10, 20)));
    host.dispatch(
      const PointerMoveEvent(
        pointer: 43,
        kind: PointerDeviceKind.mouse,
        position: Offset(20, 20),
        delta: Offset(10, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
    );
    host.dispatch(
      const PointerMoveEvent(
        pointer: 43,
        kind: PointerDeviceKind.mouse,
        position: Offset(30, 20),
        delta: Offset(10, 0),
        timeStamp: Duration(milliseconds: 32),
      ),
    );
    host.dispatch(
      const PointerUpEvent(
        pointer: 43,
        kind: PointerDeviceKind.mouse,
        position: Offset(30, 20),
        timeStamp: Duration(milliseconds: 48),
      ),
    );
    await tester.pump();
    expect(deferredCounts, <int>[1]);
  });

  testWidgets('owner 在 raw pointerUp 内移除后祖先同次终态 pointerCount 为零', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final ancestorCounts = <int>[];

    host.rootDispatcher.event = ElEvent(
      onPointerDown: (_) {},
      onPointerUp: (event) => ancestorCounts.add(event.pointerCount),
    );
    host.leafDispatcher.event = ElEvent(onPointerDown: (_) {}, onPointerUp: (_) => host.leafDispatcher.event = null);

    host.dispatch(const PointerDownEvent(pointer: 44, position: Offset(20, 20)));
    host.dispatch(const PointerUpEvent(pointer: 44, position: Offset(20, 20)));

    expect(ancestorCounts, <int>[0]);
  });

  testWidgets('pointerPanZoom ignores update and end from a different pointer', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onPointerPanZoomStart: (event) => phases.add(event.phase),
        onPointerPanZoomUpdate: (event) => phases.add(event.phase),
        onPointerPanZoomEnd: (event) => phases.add(event.phase),
      );
    addTearDown(dispatcher.dispose);
    final entry = BoxHitTestEntry(box, Offset.zero);

    dispatcher.dispatchTestPointer(const PointerPanZoomStartEvent(pointer: 4, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(
      const PointerPanZoomUpdateEvent(pointer: 5, position: Offset(20, 20), pan: Offset(0, 8), panDelta: Offset(0, 8)),
      entry,
    );
    dispatcher.dispatchTestPointer(const PointerPanZoomEndEvent(pointer: 5, position: Offset(20, 20)), entry);

    expect(phases, <ElEventPhase>[ElEventPhase.pointerPanZoomStart]);

    dispatcher.dispatchTestPointer(
      const PointerPanZoomUpdateEvent(pointer: 4, position: Offset(20, 20), pan: Offset(0, 8), panDelta: Offset(0, 8)),
      entry,
    );
    dispatcher.dispatchTestPointer(const PointerPanZoomEndEvent(pointer: 4, position: Offset(20, 20)), entry);

    expect(phases, <ElEventPhase>[
      ElEventPhase.pointerPanZoomStart,
      ElEventPhase.pointerPanZoomUpdate,
      ElEventPhase.pointerPanZoomEnd,
    ]);
  });

  testWidgets('state-only pointer removed clears active route and feedback', (tester) async {
    final box = _attachedBox();

    final activeChanges = <bool>[];
    final dispatcher = EventDispatcher(box)..onTapChanged = activeChanges.add;
    addTearDown(dispatcher.dispose);
    final entry = BoxHitTestEntry(box, Offset.zero);

    const down = PointerDownEvent(pointer: 7, kind: PointerDeviceKind.touch, position: Offset(20, 20));
    dispatcher.dispatchTestPointer(down, entry);

    expect(dispatcher.activePointerCount, 1);

    GestureBinding.instance.pointerRouter.route(
      const PointerRemovedEvent(pointer: 7, kind: PointerDeviceKind.touch, position: Offset(20, 20)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(activeChanges, <bool>[true, false]);
    expect(dispatcher.activePointerCount, 0);
  });

  testWidgets('active scale pointer removed emits one cancellation and clears the route', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onScaleStart: (event) => phases.add(event.phase),
        onScaleCancel: (event) => phases.add(event.phase),
      );
    addTearDown(dispatcher.dispose);
    final entry = BoxHitTestEntry(box, Offset.zero);

    const down = PointerDownEvent(pointer: 8, kind: PointerDeviceKind.touch, position: Offset(20, 20));
    dispatcher.dispatchTestPointer(down, entry);
    DispatcherScaleGesture.start(dispatcher, entry, existingDown: down);

    expect(dispatcher.activePointerCount, 1);

    GestureBinding.instance.pointerRouter.route(
      const PointerRemovedEvent(pointer: 8, kind: PointerDeviceKind.touch, position: Offset(20, 20)),
    );

    expect(dispatcher.activePointerCount, 0);
    expect(phases, <ElEventPhase>[ElEventPhase.scaleStart, ElEventPhase.scaleCancel]);
  });

  testWidgets('accepted drag pointer removed emits the matching dragCancel terminal', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => phases.add(event.phase),
        onDragUpdate: (event) => phases.add(event.phase),
        onDragCancel: (event) => phases.add(event.phase),
        onDragEnd: (event) => phases.add(event.phase),
      );
    addTearDown(dispatcher.dispose);
    final entry = BoxHitTestEntry(box, Offset.zero);

    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 10, kind: PointerDeviceKind.touch, position: Offset(20, 20)),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 10, kind: PointerDeviceKind.touch, position: Offset(20, 28), delta: Offset(0, 8)),
      entry,
    );

    expect(phases, <ElEventPhase>[ElEventPhase.dragStart]);
    expect(dispatcher.activePointerCount, 1);

    GestureBinding.instance.pointerRouter.route(
      const PointerRemovedEvent(pointer: 10, kind: PointerDeviceKind.touch, position: Offset(20, 28)),
    );

    expect(dispatcher.activePointerCount, 0);
    expect(phases, <ElEventPhase>[ElEventPhase.dragStart, ElEventPhase.dragCancel]);
  });

  testWidgets('unrelated routed pointer removed does not clear active scale', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragDevices: {PointerDeviceKind.touch}),
        onScaleStart: (event) => phases.add(event.phase),
        onScaleEnd: (event) => phases.add(event.phase),
        onPointerPanZoomStart: (_) {},
      );
    addTearDown(dispatcher.dispose);
    final entry = BoxHitTestEntry(box, Offset.zero);

    const scaleDown = PointerDownEvent(pointer: 8, device: 8, kind: PointerDeviceKind.touch, position: Offset(20, 20));
    dispatcher.dispatchTestPointer(scaleDown, entry);
    final scale = DispatcherScaleGesture.start(dispatcher, entry, existingDown: scaleDown);
    dispatcher.dispatchTestPointer(
      const PointerPanZoomStartEvent(pointer: 9, device: 9, position: Offset(40, 40)),
      entry,
    );

    expect(dispatcher.activePointerCount, 1);

    GestureBinding.instance.pointerRouter.route(
      const PointerRemovedEvent(pointer: 9, device: 9, kind: PointerDeviceKind.trackpad, position: Offset(40, 40)),
    );

    expect(dispatcher.activePointerCount, 1);

    scale.end();

    expect(phases, <ElEventPhase>[ElEventPhase.scaleStart, ElEventPhase.scaleEnd]);
    expect(dispatcher.activePointerCount, 0);
  });

  testWidgets('non-primary pointer up does not cancel active primary tap', (tester) async {
    final box = _attachedBox();

    final activeChanges = <bool>[];
    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..onTapChanged = activeChanges.add
      ..event = ElEvent(
        onTapDown: (event) => phases.add(event.phase),
        onTapUp: (event) => phases.add(event.phase),
        onTap: (event) => phases.add(event.phase),
      );
    addTearDown(dispatcher.dispose);
    final entry = BoxHitTestEntry(box, Offset.zero);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 2, position: Offset(20, 20)), entry);
    expect(activeChanges, <bool>[true]);
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(20, 20)), entry);

    expect(activeChanges, <bool>[true, false]);
    expect(phases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
  });

  testWidgets('non-primary pointer cancel does not cancel active primary tap', (tester) async {
    final box = _attachedBox();

    final activeChanges = <bool>[];
    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..onTapChanged = activeChanges.add
      ..event = ElEvent(
        onTapDown: (event) => phases.add(event.phase),
        onTapUp: (event) => phases.add(event.phase),
        onTap: (event) => phases.add(event.phase),
        onTapCancel: (event) => phases.add(event.phase),
      );
    addTearDown(dispatcher.dispose);
    final entry = BoxHitTestEntry(box, Offset.zero);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(const PointerCancelEvent(pointer: 2, position: Offset(20, 20)), entry);
    expect(activeChanges, <bool>[true]);
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(20, 20)), entry);

    expect(activeChanges, <bool>[true, false]);
    expect(phases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
  });

  testWidgets('setting equal event object preserves active primary tap', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    void record(ElEventDetails event) => phases.add(event.phase);
    final dispatcher = EventDispatcher(box)..event = ElEvent(onTapDown: record, onTapUp: record, onTap: record);
    addTearDown(dispatcher.dispose);
    final entry = BoxHitTestEntry(box, Offset.zero);
    final replacement = ElEvent(onTapDown: record, onTapUp: record, onTap: record);

    expect(identical(dispatcher.event, replacement), isFalse);
    expect(dispatcher.event, replacement);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.event = replacement;
    expect(dispatcher.event, same(replacement));
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(20, 20)), entry);

    expect(phases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
  });

  testWidgets('move cancel and pointer cancel preserve original event and buttons', (tester) async {
    final box = _attachedBox();

    final originalEvents = <Object?>[];
    final buttons = <int>[];
    final reasons = <ElEventCancelReason?>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(tapCancelByDistance: true, tapCancelDistance: 4),
        onTap: (_) {},
        onTapCancel: (event) {
          originalEvents.add(event.originalEvent);
          buttons.add(event.buttons);
          reasons.add(event.cancelReason);
        },
      );
    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 3, position: Offset(20, 20), buttons: kPrimaryButton),
      entry,
    );
    await tester.pump(kPressTimeout);
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 3, position: Offset(30, 20), delta: Offset(10, 0), buttons: kPrimaryButton),
      entry,
    );
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 3, position: Offset(30, 20)), entry);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 4, position: Offset(20, 20), buttons: kPrimaryButton),
      entry,
    );
    await tester.pump(kPressTimeout);
    dispatcher.dispatchTestPointer(
      const PointerCancelEvent(pointer: 4, position: Offset(20, 20), buttons: kPrimaryButton),
      entry,
    );
    dispatcher.dispose();

    expect(originalEvents, hasLength(2));
    expect(originalEvents[0], isA<PointerMoveEvent>());
    expect(originalEvents[1], isA<PointerCancelEvent>());
    expect(buttons, <int>[kPrimaryButton, kPrimaryButton]);
    expect(reasons, <ElEventCancelReason>[ElEventCancelReason.tapRejected, ElEventCancelReason.pointerCanceled]);
  });

  testWidgets('forward and back tap callbacks preserve side button metadata', (tester) async {
    final box = _attachedBox();

    final originalEvents = <ElEventPhase, Object?>{};
    final buttons = <ElEventPhase, int>{};
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onForwardTapDown: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
        onForwardTapUp: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
        onForwardTap: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
        onBackTapDown: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
        onBackTapUp: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
        onBackTap: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
      );
    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 5, position: Offset(20, 20), buttons: kForwardMouseButton),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 5, position: Offset(20, 20), buttons: kForwardMouseButton),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 6, position: Offset(30, 20), buttons: kBackMouseButton),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 6, position: Offset(30, 20), buttons: kBackMouseButton),
      entry,
    );
    dispatcher.dispose();

    expect(originalEvents[ElEventPhase.forwardTapDown], isA<PointerDownEvent>());
    expect(originalEvents[ElEventPhase.forwardTapUp], isA<PointerUpEvent>());
    expect(originalEvents[ElEventPhase.forwardTap], isA<PointerUpEvent>());
    expect(originalEvents[ElEventPhase.backTapDown], isA<PointerDownEvent>());
    expect(originalEvents[ElEventPhase.backTapUp], isA<PointerUpEvent>());
    expect(originalEvents[ElEventPhase.backTap], isA<PointerUpEvent>());
    expect(buttons[ElEventPhase.forwardTapDown], kForwardMouseButton);
    expect(buttons[ElEventPhase.forwardTapUp], kForwardMouseButton);
    expect(buttons[ElEventPhase.forwardTap], kForwardMouseButton);
    expect(buttons[ElEventPhase.backTapDown], kBackMouseButton);
    expect(buttons[ElEventPhase.backTapUp], kBackMouseButton);
    expect(buttons[ElEventPhase.backTap], kBackMouseButton);
  });

  testWidgets('secondary and tertiary tap callbacks preserve button metadata', (tester) async {
    final buttons = <ElEventPhase, int>{};
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElView(
          style: const ElStyle(width: 100, height: 100),
          event: ElEvent(
            onSecondaryTapDown: (event) => buttons[event.phase] = event.buttons,
            onSecondaryTapUp: (event) => buttons[event.phase] = event.buttons,
            onSecondaryTap: (event) => buttons[event.phase] = event.buttons,
            onTertiaryTapDown: (event) => buttons[event.phase] = event.buttons,
            onTertiaryTapUp: (event) => buttons[event.phase] = event.buttons,
            onTertiaryTap: (event) => buttons[event.phase] = event.buttons,
          ),
        ),
      ),
    );

    final secondary = TestPointer(40, PointerDeviceKind.mouse, 0, kSecondaryButton);
    await tester.sendEventToBinding(secondary.down(const Offset(20, 20)));
    await tester.sendEventToBinding(secondary.up());
    await tester.pump();

    final tertiary = TestPointer(41, PointerDeviceKind.mouse, 0, kTertiaryButton);
    await tester.sendEventToBinding(tertiary.down(const Offset(30, 20)));
    await tester.sendEventToBinding(tertiary.up());
    await tester.pump();

    expect(buttons[ElEventPhase.secondaryTapDown], kSecondaryButton);
    expect(buttons[ElEventPhase.secondaryTapUp], kSecondaryButton);
    expect(buttons[ElEventPhase.secondaryTap], kSecondaryButton);
    expect(buttons[ElEventPhase.tertiaryTapDown], kTertiaryButton);
    expect(buttons[ElEventPhase.tertiaryTapUp], kTertiaryButton);
    expect(buttons[ElEventPhase.tertiaryTap], kTertiaryButton);
  });

  testWidgets('side button taps only complete for matching pointer lifecycle', (tester) async {
    final box = _attachedBox();

    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onForwardTapDown: (event) => phases.add(event.phase),
        onForwardTapUp: (event) => phases.add(event.phase),
        onForwardTap: (event) => phases.add(event.phase),
        onBackTapDown: (event) => phases.add(event.phase),
        onBackTapUp: (event) => phases.add(event.phase),
        onBackTap: (event) => phases.add(event.phase),
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 7, position: Offset(20, 20), buttons: kForwardMouseButton),
      entry,
    );
    await tester.pump(kPressTimeout);
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 8, position: Offset(20, 20), buttons: kPrimaryButton),
      entry,
    );

    expect(phases, <ElEventPhase>[ElEventPhase.forwardTapDown]);

    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 7, position: Offset(20, 20), buttons: kForwardMouseButton),
      entry,
    );

    expect(phases, <ElEventPhase>[ElEventPhase.forwardTapDown, ElEventPhase.forwardTapUp, ElEventPhase.forwardTap]);

    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 9, position: Offset(30, 20), buttons: kBackMouseButton),
      entry,
    );
    await tester.pump(kPressTimeout);
    dispatcher.dispatchTestPointer(const PointerCancelEvent(pointer: 9, position: Offset(30, 20)), entry);
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 9, position: Offset(30, 20), buttons: kBackMouseButton),
      entry,
    );

    expect(phases, <ElEventPhase>[
      ElEventPhase.forwardTapDown,
      ElEventPhase.forwardTapUp,
      ElEventPhase.forwardTap,
      ElEventPhase.backTapDown,
    ]);
  });

  testWidgets('drag callbacks preserve original pointer events and buttons', (tester) async {
    final box = _attachedBox();

    final originalEvents = <ElEventPhase, Object?>{};
    final buttons = <ElEventPhase, int>{};
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
        onDragUpdate: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
        onDragEnd: (event) {
          originalEvents[event.phase] = event.originalEvent;
          buttons[event.phase] = event.buttons;
        },
      );
    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 7, kind: PointerDeviceKind.mouse, position: Offset.zero, buttons: kPrimaryButton),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 7,
        kind: PointerDeviceKind.mouse,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        buttons: kPrimaryButton,
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 7,
        kind: PointerDeviceKind.mouse,
        position: Offset(8, 0),
        delta: Offset(4, 0),
        buttons: kPrimaryButton,
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 7, kind: PointerDeviceKind.mouse, position: Offset(8, 0), buttons: kPrimaryButton),
      entry,
    );
    dispatcher.dispose();

    expect(originalEvents[ElEventPhase.dragStart], isA<PointerMoveEvent>());
    expect(originalEvents[ElEventPhase.dragUpdate], isA<PointerMoveEvent>());
    expect(originalEvents[ElEventPhase.dragEnd], isA<PointerUpEvent>());
    expect(buttons[ElEventPhase.dragStart], kPrimaryButton);
    expect(buttons[ElEventPhase.dragUpdate], kPrimaryButton);
    expect(buttons[ElEventPhase.dragEnd], kPrimaryButton);
  });

  testWidgets('pointer localDelta follows the target local coordinate transform', (tester) async {
    final box = _attachedBox();

    ElEventDetails? captured;
    final dispatcher = EventDispatcher(box);
    dispatcher.localPositionResolver = (target, globalPosition, callback) => globalPosition / 2.0;
    dispatcher.event = ElEvent(onPointerMove: (event) => captured = event);
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 41, position: Offset(10, 16)),
      BoxHitTestEntry(box, Offset.zero),
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 41, position: Offset(20, 20), delta: Offset(10, 4)),
      BoxHitTestEntry(box, Offset.zero),
    );

    expect(captured, isNotNull);
    expect(captured!.delta, const Offset(10, 4));
    expect(captured!.localPosition, const Offset(10, 10));
    expect(captured!.localDelta, const Offset(5, 2));
    expect(captured!.remainingLocalDelta, const Offset(5, 2));
    dispatcher.dispose();
  });

  testWidgets('direct pointerMove localDelta resolves per hit-test target', (tester) async {
    final pair = _attachedPair();

    Offset? childLocalDelta;
    Offset? childRemainingLocalDelta;
    Offset? parentLocalDelta;
    Offset? parentRemainingLocalDelta;
    final childDispatcher = EventDispatcher(pair.child)
      ..localPositionResolver = (target, globalPosition, callback) {
        if (identical(target, pair.child)) return globalPosition / 2.0;
        if (identical(target, pair.parent)) return globalPosition;
        return target.globalToLocal(globalPosition);
      }
      ..event = ElEvent(
        onPointerMove: (event) {
          childLocalDelta = event.localDelta;
          event.consumeDelta(const Offset(4, 0));
          childRemainingLocalDelta = event.remainingLocalDelta;
        },
      );
    final parentDispatcher = EventDispatcher(pair.parent)
      ..event = ElEvent(
        onPointerMove: (event) {
          parentLocalDelta = event.localDelta;
          parentRemainingLocalDelta = event.remainingLocalDelta;
        },
      );
    addTearDown(childDispatcher.dispose);
    addTearDown(parentDispatcher.dispose);

    const down = PointerDownEvent(pointer: 42, position: Offset(10, 20));
    childDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.parent, Offset.zero));
    childDispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 42, position: Offset(20, 20), delta: Offset(10, 0)),
      BoxHitTestEntry(pair.child, Offset.zero),
    );
    parentDispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 42, position: Offset(20, 20), delta: Offset(10, 0)),
      BoxHitTestEntry(pair.parent, Offset.zero),
    );

    expect(childLocalDelta, const Offset(5, 0));
    expect(childRemainingLocalDelta, const Offset(3, 0));
    expect(parentLocalDelta, const Offset(10, 0));
    expect(parentRemainingLocalDelta, const Offset(10, 0), reason: 'pointerMove is no longer a bubbling phase');
  });

  testWidgets('state-only child dispatcher does not suppress parent pointer and tap events', (tester) async {
    final pair = _attachedPair();
    final parentEntry = BoxHitTestEntry(pair.parent, Offset.zero);
    final childEntry = BoxHitTestEntry(pair.child, Offset.zero);

    var childActive = false;
    final childDispatcher = EventDispatcher(pair.child)..onTapChanged = (active) => childActive = active;
    final parentPhases = <ElEventPhase>[];
    final parentDispatcher = EventDispatcher(pair.parent)
      ..event = ElEvent(
        onPointerDown: (event) => parentPhases.add(event.phase),
        onPointerUp: (event) => parentPhases.add(event.phase),
        onTap: (event) => parentPhases.add(event.phase),
      );
    addTearDown(childDispatcher.dispose);
    addTearDown(parentDispatcher.dispose);

    const down = PointerDownEvent(pointer: 31, position: Offset(20, 20), buttons: kPrimaryButton);
    const up = PointerUpEvent(pointer: 31, position: Offset(20, 20), buttons: kPrimaryButton);
    childDispatcher.dispatchTestPointer(down, childEntry);
    parentDispatcher.dispatchTestPointer(down, parentEntry);

    expect(childActive, isTrue);
    expect(parentPhases, <ElEventPhase>[ElEventPhase.pointerDown]);

    childDispatcher.dispatchTestPointer(up, childEntry);
    parentDispatcher.dispatchTestPointer(up, parentEntry);

    expect(childActive, isFalse);
    expect(parentPhases, <ElEventPhase>[ElEventPhase.pointerDown, ElEventPhase.pointerUp, ElEventPhase.tap]);
  });
}

_EventTestBox _attachedBox() {
  final owner = PipelineOwner();
  final box = _EventTestBox();
  owner.rootNode = box;
  box.layout(BoxConstraints.tight(const Size(1000, 1000)));
  return box;
}

({_EventTestBox parent, _EventTestBox child}) _attachedPair() {
  final owner = PipelineOwner();
  final parent = _EventTestBox();
  final child = _EventTestBox();
  parent.child = child;
  owner.rootNode = parent;
  parent.layout(BoxConstraints.tight(const Size(1000, 1000)));
  return (parent: parent, child: child);
}

final class _EventTestBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  @override
  void performLayout() {
    final child = this.child;
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
    }
    size = constraints.constrain(const Size(100, 100));
  }
}
