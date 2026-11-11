import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

void main() {
  testWidgets('accepted drag cancels tap and long-press candidates even below tap cancel distance', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    var taps = 0;
    var longPresses = 0;
    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(tapCancelDistance: 30, dragStartDistance: 3),
        onTap: (_) => taps++,
        onLongPress: (_) => longPresses++,
        onDragStart: (event) {
          phases.add(event.phase);
          event.eagerGesture(cancelSelfTap: true);
        },
        onDragUpdate: (event) => phases.add(event.phase),
        onDragEnd: (event) => phases.add(event.phase),
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(const PointerDownEvent(position: Offset.zero, timeStamp: Duration.zero), entry);
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(position: Offset(4, 0), delta: Offset(4, 0), timeStamp: Duration(milliseconds: 16)),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(position: Offset(8, 0), delta: Offset(4, 0), timeStamp: Duration(milliseconds: 32)),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(position: Offset(8, 0), timeStamp: Duration(milliseconds: 48)),
      entry,
    );

    expect(phases, <ElEventPhase>[ElEventPhase.dragStart, ElEventPhase.dragUpdate, ElEventPhase.dragEnd]);
    expect(taps, 0);
    expect(longPresses, 0);
  });

  testWidgets('dragStart is a pure lifecycle signal — delta / remaining / dragOffset all zero', (tester) async {
    // 契约：dragStart 帧只承载"拖拽已越阈"这一信号，delta / remainingDelta /
    // dragOffset 一律归零；下一个 dragUpdate 帧才带来 frame delta 与
    // 累计 dragOffset（零基台账，dragOffset ≡ 已派发 delta 累计）。对齐
    // Flutter DragStartBehavior.start 的"down→accept 位移丢弃、首帧从 0
    // 跟手"契约，避免真机首帧合并事件把 30+px 一次性挤到消费者——delta 流
    // 与 dragOffset 流两个通道都不得漏出激活前段。
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    Offset? startDelta;
    Offset? startRemainingDelta;
    Offset? startRemainingLocalDelta;
    Offset? startOffset;
    Offset? updateDelta;
    Offset? updateOffset;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 10),
        onVerticalDragStart: (event) {
          startDelta = event.delta;
          startRemainingDelta = event.remainingDelta;
          startRemainingLocalDelta = event.remainingLocalDelta;
          startOffset = event.dragOffset;
        },
        onVerticalDragUpdate: (event) {
          updateDelta ??= event.delta;
          updateOffset ??= event.dragOffset;
        },
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 12),
        delta: Offset(4, 12),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );

    expect(startDelta, Offset.zero);
    expect(startRemainingDelta, Offset.zero);
    expect(startRemainingLocalDelta, Offset.zero);
    expect(startOffset, Offset.zero);

    // 首个 dragUpdate 帧：正常携带 frame delta 与累计 dragOffset（首帧
    // accept 的 12px 按零基契约不进账）。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 20),
        delta: Offset(0, 8),
        timeStamp: Duration(milliseconds: 32),
      ),
      entry,
    );
    expect(updateDelta, const Offset(0, 8));
    expect(updateOffset, const Offset(0, 8));
  });

  testWidgets('default free drag uses pan slop while axis drag keeps hit slop', (tester) async {
    final freePipelineOwner = PipelineOwner();
    final freeBox = _EventTestBox();
    freePipelineOwner.rootNode = freeBox;

    var freeStarts = 0;
    Offset? freeStartDelta;
    Offset? freeStartOffset;
    final freeDispatcher = EventDispatcher(freeBox)
      ..event = ElEvent(
        onDragStart: (event) {
          freeStarts++;
          freeStartDelta = event.delta;
          freeStartOffset = event.dragOffset;
        },
      );
    addTearDown(freeDispatcher.dispose);

    final freeEntry = BoxHitTestEntry(freeBox, Offset.zero);
    freeDispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      freeEntry,
    );
    freeDispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(30, 0),
        delta: Offset(30, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      freeEntry,
    );

    expect(freeStarts, 0);

    freeDispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(40, 0),
        delta: Offset(10, 0),
        timeStamp: Duration(milliseconds: 32),
      ),
      freeEntry,
    );

    expect(freeStarts, 1);
    // dragStart 纯生命周期信号：delta / dragOffset 一律归零，无论触发 slop 之
    // 前累积了多少位移（判定 slop 已越过靠 freeStarts 从 0→1 的跳变即可证）。
    expect(freeStartDelta, Offset.zero);
    expect(freeStartOffset, Offset.zero);

    final axisPipelineOwner = PipelineOwner();
    final axisBox = _EventTestBox();
    axisPipelineOwner.rootNode = axisBox;

    var axisStarts = 0;
    Offset? axisStartDelta;
    final axisDispatcher = EventDispatcher(axisBox)
      ..event = ElEvent(
        onVerticalDragStart: (event) {
          axisStarts++;
          axisStartDelta = event.delta;
        },
      );
    addTearDown(axisDispatcher.dispose);

    final axisEntry = BoxHitTestEntry(axisBox, Offset.zero);
    axisDispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 2, position: Offset.zero, timeStamp: Duration.zero),
      axisEntry,
    );
    axisDispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(0, 20),
        delta: Offset(0, 20),
        timeStamp: Duration(milliseconds: 16),
      ),
      axisEntry,
    );

    expect(axisStarts, 1);
    // dragStart 种子归零：axis 拖拽同样只是"越阈信号"，无 overslop delta。
    expect(axisStartDelta, Offset.zero);
  });

  testWidgets('replacing equivalent drag event during active drag keeps the gesture alive', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    final oldPhases = <ElEventPhase>[];
    final newPhases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => oldPhases.add(event.phase),
        onDragUpdate: (event) => oldPhases.add(event.phase),
        onDragEnd: (event) => oldPhases.add(event.phase),
        onDragCancel: (event) => oldPhases.add(event.phase),
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(const PointerDownEvent(position: Offset.zero, timeStamp: Duration.zero), entry);
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(position: Offset(4, 0), delta: Offset(4, 0), timeStamp: Duration(milliseconds: 16)),
      entry,
    );

    dispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onDragStart: (event) => newPhases.add(event.phase),
      onDragUpdate: (event) => newPhases.add(event.phase),
      onDragEnd: (event) => newPhases.add(event.phase),
      onDragCancel: (event) => newPhases.add(event.phase),
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(position: Offset(8, 0), delta: Offset(4, 0), timeStamp: Duration(milliseconds: 32)),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(position: Offset(8, 0), timeStamp: Duration(milliseconds: 48)),
      entry,
    );

    expect(oldPhases, <ElEventPhase>[ElEventPhase.dragStart]);
    expect(newPhases, <ElEventPhase>[ElEventPhase.dragUpdate, ElEventPhase.dragEnd]);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('replacing equivalent drag event during pending touch drag keeps the gesture alive', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    final phases = <String>[];
    ElEvent replacementEvent(String prefix) {
      return ElEvent(
        config: const ElEventConfig(dragStartDistance: 12),
        onDragStart: (event) => phases.add('$prefix:${event.phase.name}:${event.dragOffset.dy}'),
        onDragUpdate: (event) => phases.add('$prefix:${event.phase.name}:${event.dragOffset.dy}'),
        onDragEnd: (event) => phases.add('$prefix:${event.phase.name}'),
        onDragCancel: (event) => phases.add('$prefix:${event.phase.name}'),
      );
    }

    final dispatcher = EventDispatcher(box)..event = replacementEvent('old');
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(
        pointer: 1,
        position: Offset.zero,
        kind: PointerDeviceKind.touch,
        timeStamp: Duration.zero,
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(0, -8),
        delta: Offset(0, -8),
        kind: PointerDeviceKind.touch,
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );

    dispatcher.event = replacementEvent('new');
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(0, -24),
        delta: Offset(0, -16),
        kind: PointerDeviceKind.touch,
        timeStamp: Duration(milliseconds: 32),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(
        pointer: 1,
        position: Offset(0, -24),
        kind: PointerDeviceKind.touch,
        timeStamp: Duration(milliseconds: 48),
      ),
      entry,
    );

    // dragStart 纯生命周期信号 → dragOffset 归零；deferred 补发路径同样归零。
    expect(phases, <String>['new:dragStart:0.0', 'new:dragEnd']);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('replacing equivalent drag event during dragEnd keeps future touch drags alive', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    ElEvent replacementEvent() {
      return ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => phases.add('new:${event.phase.name}'),
        onDragUpdate: (event) => phases.add('new:${event.phase.name}'),
        onDragEnd: (event) => phases.add('new:${event.phase.name}'),
        onDragCancel: (event) => phases.add('new:${event.phase.name}'),
      );
    }

    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => phases.add('old:${event.phase.name}'),
        onDragUpdate: (event) => phases.add('old:${event.phase.name}'),
        onDragEnd: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = replacementEvent();
        },
        onDragCancel: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 1, position: Offset(4, 0), timeStamp: Duration(milliseconds: 32)),
      entry,
    );

    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 2, position: Offset.zero, timeStamp: Duration(milliseconds: 48)),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(5, 0),
        delta: Offset(5, 0),
        timeStamp: Duration(milliseconds: 64),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 2, position: Offset(5, 0), timeStamp: Duration(milliseconds: 80)),
      entry,
    );

    expect(phases, <String>['old:dragStart', 'old:dragEnd', 'new:dragStart', 'new:dragEnd']);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('dragEnd handler removing event does not emit dragCancel', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    late final EventDispatcher dispatcher;
    final phases = <ElEventPhase>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => phases.add(event.phase),
        onDragEnd: (event) {
          phases.add(event.phase);
          dispatcher.event = null;
        },
        onDragCancel: (event) => phases.add(event.phase),
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 1, position: Offset(4, 0), timeStamp: Duration(milliseconds: 32)),
      entry,
    );

    expect(phases, <ElEventPhase>[ElEventPhase.dragStart, ElEventPhase.dragEnd]);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('dragCancel handler replacing event is not reentrant', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => phases.add('old:${event.phase.name}'),
        onDragCancel: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onDragCancel: (event) => phases.add('new:${event.phase.name}'));
        },
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerCancelEvent(pointer: 1, position: Offset(4, 0), timeStamp: Duration(milliseconds: 32)),
      entry,
    );

    expect(phases, <String>['old:dragStart', 'old:dragCancel']);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('replacing event during pointerDown does not retarget the same tap to new event', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    ElEvent replacementEvent() {
      return ElEvent(
        onTapDown: (event) => phases.add('new:${event.phase.name}'),
        onTapUp: (event) => phases.add('new:${event.phase.name}'),
        onTap: (event) => phases.add('new:${event.phase.name}'),
      );
    }

    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onPointerDown: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = replacementEvent();
        },
        onTapDown: (event) => phases.add('old:${event.phase.name}'),
        onTapUp: (event) => phases.add('old:${event.phase.name}'),
        onTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 1, position: Offset.zero, timeStamp: Duration(milliseconds: 16)),
      entry,
    );

    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 2, position: Offset(10, 0), timeStamp: Duration(milliseconds: 32)),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 2, position: Offset(10, 0), timeStamp: Duration(milliseconds: 48)),
      entry,
    );

    expect(phases, <String>['old:pointerDown', 'new:tapDown', 'new:tapUp', 'new:tap']);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('removing event during pointerDown does not leave active state set', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    final activeChanges = <bool>[];
    dispatcher = EventDispatcher(box)
      ..onTapChanged = activeChanges.add
      ..event = ElEvent(
        onPointerDown: (event) {
          phases.add(event.phase.name);
          dispatcher.event = null;
        },
        onTapDown: (event) => phases.add(event.phase.name),
        onTapUp: (event) => phases.add(event.phase.name),
        onTap: (event) => phases.add(event.phase.name),
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      entry,
    );

    expect(dispatcher.event, isNull);
    expect(dispatcher.isTapPressed, isFalse);
    expect(phases, <String>['pointerDown']);
    expect(activeChanges, isEmpty);
  });

  testWidgets('removing event reports current multitouch drag offset when cancelling', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    Offset? cancelOffset;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (_) {},
        onDragUpdate: (_) {},
        onDragCancel: (event) => cancelOffset = event.dragOffset,
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 2, position: Offset(100, 0), timeStamp: Duration(milliseconds: 20)),
      entry,
    );
    await tester.pump();
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(110, 0),
        delta: Offset(10, 0),
        timeStamp: Duration(milliseconds: 32),
      ),
      entry,
    );

    dispatcher.event = null;

    expect(cancelOffset, const Offset(10, 0));
  });

  testWidgets('dispose during active drag dispatches dragCancel before deregistering', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => phases.add(event.phase),
        onDragCancel: (event) => phases.add(event.phase),
      );

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(const PointerDownEvent(position: Offset.zero, timeStamp: Duration.zero), entry);
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(position: Offset(4, 0), delta: Offset(4, 0), timeStamp: Duration(milliseconds: 16)),
      entry,
    );

    dispatcher.dispose();

    expect(phases, <ElEventPhase>[ElEventPhase.dragStart, ElEventPhase.dragCancel]);
    expect(EventDispatcher.of(box), isNull);
  });

  testWidgets('pointer cancel reports current multitouch drag offset', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    Offset? cancelOffset;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (_) {},
        onDragUpdate: (_) {},
        onDragCancel: (event) => cancelOffset = event.dragOffset,
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 2, position: Offset(100, 0), timeStamp: Duration(milliseconds: 20)),
      entry,
    );
    await tester.pump();
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(110, 0),
        delta: Offset(10, 0),
        timeStamp: Duration(milliseconds: 32),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerCancelEvent(pointer: 1, position: Offset(4, 0), timeStamp: Duration(milliseconds: 40)),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerCancelEvent(pointer: 2, position: Offset(110, 0), timeStamp: Duration(milliseconds: 48)),
      entry,
    );

    expect(cancelOffset, const Offset(10, 0));
  });

  testWidgets('latest pointer drag strategy switches updates to newest finger', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    final deltas = <Offset>[];
    final offsets = <Offset>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (_) {},
        onDragUpdate: (event) {
          deltas.add(event.delta);
          offsets.add(event.dragOffset);
        },
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 2, position: Offset(100, 0), timeStamp: Duration(milliseconds: 20)),
      entry,
    );
    await tester.pump();
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(40, 0),
        delta: Offset(36, 0),
        timeStamp: Duration(milliseconds: 32),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(110, 0),
        delta: Offset(10, 0),
        timeStamp: Duration(milliseconds: 48),
      ),
      entry,
    );

    expect(deltas, <Offset>[const Offset(10, 0)]);
    expect(offsets, <Offset>[const Offset(10, 0)]);
  });

  testWidgets('mouse drag cancels when buttons change mid-drag', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    final phases = <ElEventPhase>[];
    final buttons = <int>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) {
          phases.add(event.phase);
          buttons.add(event.buttons);
        },
        onDragUpdate: (event) {
          phases.add(event.phase);
          buttons.add(event.buttons);
        },
        onDragCancel: (event) {
          phases.add(event.phase);
          buttons.add(event.buttons);
        },
        onDragEnd: (event) {
          phases.add(event.phase);
          buttons.add(event.buttons);
        },
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(
        pointer: 1,
        kind: PointerDeviceKind.mouse,
        position: Offset.zero,
        buttons: kPrimaryButton,
        timeStamp: Duration.zero,
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        kind: PointerDeviceKind.mouse,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        kind: PointerDeviceKind.mouse,
        position: Offset(8, 0),
        delta: Offset(4, 0),
        buttons: 0,
        timeStamp: Duration(milliseconds: 32),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        kind: PointerDeviceKind.mouse,
        position: Offset(12, 0),
        delta: Offset(4, 0),
        buttons: 0,
        timeStamp: Duration(milliseconds: 48),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(
        pointer: 1,
        kind: PointerDeviceKind.mouse,
        position: Offset(12, 0),
        buttons: 0,
        timeStamp: Duration(milliseconds: 64),
      ),
      entry,
    );

    expect(phases, <ElEventPhase>[ElEventPhase.dragStart, ElEventPhase.dragCancel]);
    expect(buttons, <int>[kPrimaryButton, 0]);
  });

  testWidgets('shape-equal replacement keeps pending long press and fires the new handler', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    var oldLongPresses = 0;
    var newLongPresses = 0;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
        onLongPress: (_) => oldLongPresses++,
      );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.dispatchTestPointer(const PointerDownEvent(position: Offset.zero, timeStamp: Duration.zero), entry);
    dispatcher.event = ElEvent(
      config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
      onLongPress: (_) => newLongPresses++,
    );

    await tester.pump(const Duration(milliseconds: 40));

    // shape 相等（同 delay、同回调空性）的替换是热替换：长按计时**保留**、
    // fire 新闭包。这正是"onTapDown 里 setState 触发 rebuild 后长按永远不
    // 触发"问题的修复。结构替换仍会丢弃 pending 长按（见
    // event_dispatch_reentrancy_test 的 rejects pending longPress 用例）。
    expect(oldLongPresses, 0);
    expect(newLongPresses, 1);
  });

  testWidgets('updating longPressDelay applies to the next pointer sequence', (tester) async {
    final pipelineOwner = PipelineOwner();
    final box = _EventTestBox();
    pipelineOwner.rootNode = box;

    var longPresses = 0;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(longPressDelay: Duration(milliseconds: 200)),
        onLongPress: (_) => longPresses++,
      );
    addTearDown(dispatcher.dispose);
    final entry = BoxHitTestEntry(box, Offset.zero);

    dispatcher.event = ElEvent(
      config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
      onLongPress: (_) => longPresses++,
    );
    const down = PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero, buttons: kPrimaryButton);
    dispatcher.dispatchTestPointer(down, entry);
    GestureBinding.instance.pointerRouter.route(down);

    await tester.pump(const Duration(milliseconds: 40));

    expect(longPresses, 1);
  });
}

final class _EventTestBox extends RenderBox {
  _EventTestBox() {
    layout(BoxConstraints.tight(Size(100, 100)));
  }

  @override
  void performLayout() {
    size = constraints.constrain(const Size(100, 100));
  }
}
