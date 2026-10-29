import 'package:flutter_base/src/ui/cores/view/event/dispatcher.dart';
import 'package:flutter_base/src/ui/cores/view/event/event.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

void main() {
  testWidgets('tapUp replacing event does not fire tap into replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onTapUp: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onTap: (event) => phases.add('new:${event.phase.name}'));
        },
        onTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(20, 20)), entry);

    expect(phases, <String>['old:tapUp']);
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('pointerUp replacing event does not fire tap into replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onPointerUp: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(
            onTapUp: (event) => phases.add('new:${event.phase.name}'),
            onTap: (event) => phases.add('new:${event.phase.name}'),
          );
        },
        onTapUp: (event) => phases.add('old:${event.phase.name}'),
        onTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(20, 20)), entry);

    expect(phases, <String>['old:pointerUp']);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('pointerMove replacing event does not start drag or leave tap alive for replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onPointerMove: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(
            config: const ElEventConfig(dragStartDistance: 3),
            onDragStart: (event) => phases.add('new:${event.phase.name}'),
            onTap: (event) => phases.add('new:${event.phase.name}'),
          );
        },
        onDragStart: (event) => phases.add('old:${event.phase.name}'),
        onTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset.zero), entry);
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(4, 0)), entry);

    expect(phases, <String>['old:pointerMove']);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('pointerCancel replacing event does not fire cancel into replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onPointerCancel: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onTapCancel: (event) => phases.add('new:${event.phase.name}'));
        },
        onTapCancel: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(const PointerCancelEvent(pointer: 1, position: Offset(20, 20)), entry);

    expect(phases, <String>['old:pointerCancel']);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('event removal cancel replacement does not emit panZoomEnd into replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onTapCancel: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onPointerPanZoomEnd: (event) => phases.add('new:${event.phase.name}'));
        },
        onPointerPanZoomStart: (event) => phases.add('old:${event.phase.name}'),
        onPointerPanZoomEnd: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset.zero), entry);
    dispatcher.dispatchTestPointer(const PointerPanZoomStartEvent(pointer: 2, position: Offset(20, 20)), entry);

    dispatcher.event = null;

    expect(phases, <String>['old:pointerPanZoomStart', 'old:tapCancel']);
    expect(dispatcher.event, isNotNull);
  });

  testWidgets('cancelAllPending cancel replacement does not emit panZoomEnd into replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onTapCancel: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onPointerPanZoomEnd: (event) => phases.add('new:${event.phase.name}'));
        },
        onPointerPanZoomStart: (event) => phases.add('old:${event.phase.name}'),
        onPointerPanZoomEnd: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset.zero), entry);
    dispatcher.dispatchTestPointer(const PointerPanZoomStartEvent(pointer: 2, position: Offset(20, 20)), entry);

    dispatcher.cancelAllPending(const PointerMoveEvent(pointer: 1, position: Offset(4, 0), delta: Offset(4, 0)));

    expect(phases, <String>['old:pointerPanZoomStart', 'old:tapCancel']);
    expect(dispatcher.event, isNotNull);
  });

  testWidgets('passive drag acceptance does not invoke tap cancel replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onTapCancel: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(
            config: const ElEventConfig(dragStartDistance: 3),
            onDragStart: (event) => phases.add('new:${event.phase.name}'),
          );
        },
        onDragStart: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset.zero), entry);
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );

    expect(phases, <String>['old:dragStart']);
    dispatcher.dispatchTestPointer(PointerUpEvent(pointer: 1, position: Offset(4, 0)), entry);
    // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('pointerDown replacing event rejects the pending longPress callback', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
        onPointerDown: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(
            config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
            onLongPress: (event) => phases.add('new:${event.phase.name}'),
          );
        },
        onLongPress: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    _dispatch(dispatcher, entry, const PointerDownEvent(pointer: 1, position: Offset.zero));
    await tester.pump(const Duration(milliseconds: 40));

    expect(phases, <String>['old:pointerDown']);
  });

  testWidgets('drag cancel replacing event during scale takeover does not emit scaleStart', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => phases.add('old:${event.phase.name}'),
        onDragCancel: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onScaleStart: (event) => phases.add('new:${event.phase.name}'));
        },
        onScaleStart: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset.zero), entry);
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 1,
        position: Offset(4, 0),
        delta: Offset(4, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 2, position: Offset(100, 0)), entry);
    await tester.pump();
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(160, 0), delta: Offset(60, 0)),
      entry,
    );

    expect(phases, <String>['old:dragStart', 'old:dragCancel']);
  });

  testWidgets('forward tapUp replacing event does not fire forwardTap into replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onForwardTapDown: (event) => phases.add('old:${event.phase.name}'),
        onForwardTapUp: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onForwardTap: (event) => phases.add('new:${event.phase.name}'));
        },
        onForwardTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(
      const PointerDownEvent(
        pointer: 1,
        position: Offset(10, 10),
        kind: PointerDeviceKind.mouse,
        buttons: kForwardMouseButton,
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 1, position: Offset(10, 10), kind: PointerDeviceKind.mouse),
      entry,
    );

    expect(phases, <String>['old:forwardTapDown', 'old:forwardTapUp']);
  });

  testWidgets('secondary tapUp replacing event does not fire secondaryTap into replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onSecondaryTapDown: (event) => phases.add('old:${event.phase.name}'),
        onSecondaryTapUp: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onSecondaryTap: (event) => phases.add('new:${event.phase.name}'));
        },
        onSecondaryTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    _dispatch(
      dispatcher,
      entry,
      const PointerDownEvent(
        pointer: 1,
        position: Offset(10, 10),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      ),
    );
    _dispatch(
      dispatcher,
      entry,
      const PointerUpEvent(pointer: 1, position: Offset(10, 10), kind: PointerDeviceKind.mouse),
    );

    expect(phases, <String>['old:secondaryTapDown', 'old:secondaryTapUp']);
  });

  testWidgets('tertiary tapUp replacing event does not fire tertiaryTap into replacement', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onTertiaryTapDown: (event) => phases.add('old:${event.phase.name}'),
        onTertiaryTapUp: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onTertiaryTap: (event) => phases.add('new:${event.phase.name}'));
        },
        onTertiaryTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    _dispatch(
      dispatcher,
      entry,
      const PointerDownEvent(
        pointer: 1,
        position: Offset(10, 10),
        kind: PointerDeviceKind.mouse,
        buttons: kTertiaryButton,
      ),
    );
    _dispatch(
      dispatcher,
      entry,
      const PointerUpEvent(pointer: 1, position: Offset(10, 10), kind: PointerDeviceKind.mouse),
    );

    expect(phases, <String>['old:tertiaryTapDown', 'old:tertiaryTapUp']);
  });

  testWidgets('scale update replacing event does not fire rotationUpdate into replacement', (_) async {
    final box = _attachedBox();

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onScaleStart: (event) => phases.add('old:${event.phase.name}'),
        onScaleUpdate: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onRotationUpdate: (event) => phases.add('new:${event.phase.name}'));
        },
        onRotationUpdate: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    final scale = DispatcherScaleGesture.start(
      dispatcher,
      BoxHitTestEntry(box, Offset.zero),
      focalPoint: const Offset(4, 0),
    );
    scale.moveTo(const Offset(4, 20));

    expect(phases, <String>['old:scaleStart', 'old:scaleUpdate']);
  });

  testWidgets('pointerMove no longer bubbles from child to parent', (tester) async {
    final pair = _attachedPair();

    var parentMoves = 0;
    var childMoves = 0;
    final childDispatcher = EventDispatcher(pair.child)
      ..localPositionResolver = (target, globalPosition, callback) {
        if (identical(target, pair.child)) return globalPosition / 2.0;
        if (identical(target, pair.parent)) return globalPosition;
        return target.globalToLocal(globalPosition);
      }
      ..event = ElEvent(
        onPointerMove: (event) {
          childMoves++;
          event.consumeDelta(const Offset(4, 0));
        },
      );
    final parentDispatcher = EventDispatcher(pair.parent)
      ..event = ElEvent(
        onPointerMove: (event) {
          parentMoves++;
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
      includeAncestors: false,
    );

    expect(childMoves, 1);
    expect(parentMoves, 0, reason: 'high-frequency pointerMove must not bubble back into the scroll hot path');
    childDispatcher.dispose();
    parentDispatcher.dispose();
  });

  testWidgets('pointerPanZoomStart replacing event does not retarget the same start', (_) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onPointerPanZoomStart: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(
            onPointerPanZoomStart: (event) => phases.add('new:${event.phase.name}'),
            onPointerPanZoomUpdate: (event) => phases.add('new:${event.phase.name}'),
          );
        },
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(
      const PointerPanZoomUpdateEvent(pointer: 1, position: Offset(20, 20), pan: Offset(0, 8), panDelta: Offset(0, 8)),
      entry,
    );
    dispatcher.dispatchTestPointer(const PointerPanZoomEndEvent(pointer: 1, position: Offset(20, 20)), entry);

    expect(phases, <String>['old:pointerPanZoomStart', 'new:pointerPanZoomUpdate']);
  });

  testWidgets('pointerPanZoomUpdate replacing event does not retarget the same update', (_) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onPointerPanZoomUpdate: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onPointerPanZoomUpdate: (event) => phases.add('new:${event.phase.name}'));
        },
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(
      const PointerPanZoomUpdateEvent(pointer: 1, position: Offset(20, 20), pan: Offset(0, 8), panDelta: Offset(0, 8)),
      entry,
    );
    dispatcher.dispatchTestPointer(const PointerPanZoomEndEvent(pointer: 1, position: Offset(20, 20)), entry);

    expect(phases, <String>['old:pointerPanZoomUpdate']);
  });

  testWidgets('pointerPanZoomEnd replacing event does not retarget the same end', (_) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final EventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onPointerPanZoomEnd: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(onPointerPanZoomEnd: (event) => phases.add('new:${event.phase.name}'));
        },
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)), entry);
    dispatcher.dispatchTestPointer(const PointerPanZoomEndEvent(pointer: 1, position: Offset(20, 20)), entry);

    expect(phases, <String>['old:pointerPanZoomEnd']);
  });
}

void _dispatch(EventDispatcher dispatcher, BoxHitTestEntry entry, PointerEvent event) {
  dispatcher.dispatchTestPointer(event, entry);
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
