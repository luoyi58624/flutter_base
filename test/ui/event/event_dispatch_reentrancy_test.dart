import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapUp replacing event does not fire tap into replacement', (
    tester,
  ) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final ElEventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = ElEventDispatcher(box)
      ..event = ElEvent(
        onTapUp: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(
            onTap: (event) => phases.add('new:${event.phase.name}'),
          );
        },
        onTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.handleEvent(
      const PointerDownEvent(pointer: 1, position: Offset(20, 20)),
      entry,
    );
    dispatcher.handleEvent(
      const PointerUpEvent(pointer: 1, position: Offset(20, 20)),
      entry,
    );

    expect(phases, <String>['old:tapUp']);
  });

  testWidgets('pointerUp replacing event does not fire tap into replacement', (
    tester,
  ) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final ElEventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = ElEventDispatcher(box)
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

    dispatcher.handleEvent(
      const PointerDownEvent(pointer: 1, position: Offset(20, 20)),
      entry,
    );
    dispatcher.handleEvent(
      const PointerUpEvent(pointer: 1, position: Offset(20, 20)),
      entry,
    );

    expect(phases, <String>['old:pointerUp']);
    expect(dispatcher.activePointerCount, 0);
  });

  testWidgets(
    'pointerMove replacing event does not start drag or leave tap alive for replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
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

      dispatcher.handleEvent(
        const PointerDownEvent(pointer: 1, position: Offset.zero),
        entry,
      );
      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(4, 0),
          delta: Offset(4, 0),
          timeStamp: Duration(milliseconds: 16),
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerUpEvent(pointer: 1, position: Offset(4, 0)),
        entry,
      );

      expect(phases, <String>['old:pointerMove']);
      expect(dispatcher.activePointerCount, 0);
    },
  );

  testWidgets(
    'pointerCancel replacing event does not fire cancel into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          onPointerCancel: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              onTapCancel: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onTapCancel: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(dispatcher.dispose);

      dispatcher.handleEvent(
        const PointerDownEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );
      dispatcher.handleEvent(
        const PointerCancelEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );

      expect(phases, <String>['old:pointerCancel']);
      expect(dispatcher.activePointerCount, 0);
    },
  );

  testWidgets(
    'event removal cancel replacement does not emit panZoomEnd into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          onTapCancel: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              onPointerPanZoomEnd: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
          onPointerPanZoomStart: (event) =>
              phases.add('old:${event.phase.name}'),
          onPointerPanZoomEnd: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(dispatcher.dispose);

      dispatcher.handleEvent(
        const PointerDownEvent(pointer: 1, position: Offset.zero),
        entry,
      );
      dispatcher.handleEvent(
        const PointerPanZoomStartEvent(pointer: 2, position: Offset(20, 20)),
        entry,
      );

      dispatcher.event = null;

      expect(phases, <String>['old:pointerPanZoomStart', 'old:tapCancel']);
      expect(dispatcher.event, isNotNull);
    },
  );

  testWidgets(
    'cancelAllPending cancel replacement does not emit panZoomEnd into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          onTapCancel: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              onPointerPanZoomEnd: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
          onPointerPanZoomStart: (event) =>
              phases.add('old:${event.phase.name}'),
          onPointerPanZoomEnd: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(dispatcher.dispose);

      dispatcher.handleEvent(
        const PointerDownEvent(pointer: 1, position: Offset.zero),
        entry,
      );
      dispatcher.handleEvent(
        const PointerPanZoomStartEvent(pointer: 2, position: Offset(20, 20)),
        entry,
      );

      dispatcher.cancelAllPending(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(4, 0),
          delta: Offset(4, 0),
        ),
      );

      expect(phases, <String>['old:pointerPanZoomStart', 'old:tapCancel']);
      expect(dispatcher.event, isNotNull);
    },
  );

  testWidgets(
    'passive drag acceptance does not invoke tap cancel replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
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

      dispatcher.handleEvent(
        const PointerDownEvent(pointer: 1, position: Offset.zero),
        entry,
      );
      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(4, 0),
          delta: Offset(4, 0),
          timeStamp: Duration(milliseconds: 16),
        ),
        entry,
      );

      expect(phases, <String>['old:dragStart']);
      dispatcher.handleEvent(
        PointerUpEvent(pointer: 1, position: Offset(4, 0)),
        entry,
      );
    },
  );

  testWidgets(
    'pointerDown replacing event rejects the pending longPress callback',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          config: const ElEventConfig(
            longPressDelay: Duration(milliseconds: 20),
          ),
          onPointerDown: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              config: const ElEventConfig(
                longPressDelay: Duration(milliseconds: 20),
              ),
              onLongPress: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onLongPress: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(dispatcher.dispose);

      _dispatch(
        dispatcher,
        entry,
        const PointerDownEvent(pointer: 1, position: Offset.zero),
      );
      await tester.pump(const Duration(milliseconds: 40));

      expect(phases, <String>['old:pointerDown']);
    },
  );

  testWidgets(
    'drag cancel replacing event during scale takeover does not emit scaleStart',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          config: const ElEventConfig(dragStartDistance: 3),
          onDragStart: (event) => phases.add('old:${event.phase.name}'),
          onDragCancel: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              onScaleStart: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onScaleStart: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(dispatcher.dispose);

      dispatcher.handleEvent(
        const PointerDownEvent(pointer: 1, position: Offset.zero),
        entry,
      );
      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(4, 0),
          delta: Offset(4, 0),
          timeStamp: Duration(milliseconds: 16),
        ),
        entry,
      );

      dispatcher.debugHandleScaleStartForTest(const Offset(4, 0));

      expect(phases, <String>['old:dragStart', 'old:dragCancel']);
    },
  );

  testWidgets(
    'forward tapUp replacing event does not fire forwardTap into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          onForwardTapDown: (event) => phases.add('old:${event.phase.name}'),
          onForwardTapUp: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              onForwardTap: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onForwardTap: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(dispatcher.dispose);

      dispatcher.handleEvent(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(10, 10),
          kind: PointerDeviceKind.mouse,
          buttons: kForwardMouseButton,
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerUpEvent(
          pointer: 1,
          position: Offset(10, 10),
          kind: PointerDeviceKind.mouse,
        ),
        entry,
      );

      expect(phases, <String>['old:forwardTapDown', 'old:forwardTapUp']);
    },
  );

  testWidgets(
    'secondary tapUp replacing event does not fire secondaryTap into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          onSecondaryTapDown: (event) => phases.add('old:${event.phase.name}'),
          onSecondaryTapUp: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              onSecondaryTap: (event) => phases.add('new:${event.phase.name}'),
            );
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
        const PointerUpEvent(
          pointer: 1,
          position: Offset(10, 10),
          kind: PointerDeviceKind.mouse,
        ),
      );

      expect(phases, <String>['old:secondaryTapDown', 'old:secondaryTapUp']);
    },
  );

  testWidgets(
    'tertiary tapUp replacing event does not fire tertiaryTap into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          onTertiaryTapDown: (event) => phases.add('old:${event.phase.name}'),
          onTertiaryTapUp: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              onTertiaryTap: (event) => phases.add('new:${event.phase.name}'),
            );
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
        const PointerUpEvent(
          pointer: 1,
          position: Offset(10, 10),
          kind: PointerDeviceKind.mouse,
        ),
      );

      expect(phases, <String>['old:tertiaryTapDown', 'old:tertiaryTapUp']);
    },
  );

  test('scale update replacing event does not fire rotationUpdate into replacement', () {
    final box = _attachedBox();

    late final ElEventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = ElEventDispatcher(box)
      ..event = ElEvent(
        onScaleStart: (event) => phases.add('old:${event.phase.name}'),
        onScaleUpdate: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(
            onRotationUpdate: (event) => phases.add('new:${event.phase.name}'),
          );
        },
        onRotationUpdate: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.debugHandleScaleStartForTest(const Offset(4, 0));
    dispatcher.debugFireScaleUpdateForTest(
      ScaleUpdateDetails(
        focalPoint: const Offset(4, 0),
        scale: 1.1,
        rotation: 0.2,
      ),
    );

    expect(phases, <String>['old:scaleStart', 'old:scaleUpdate']);
  });

  testWidgets('pointerMove no longer bubbles from child to parent', (
    tester,
  ) async {
    final pair = _attachedPair();

    var parentMoves = 0;
    var childMoves = 0;
    final childDispatcher = ElEventDispatcher(pair.child)
      ..event = ElEvent(
        onPointerMove: (event) {
          childMoves++;
          event.consumeDelta(const Offset(4, 0));
        },
      );
    final parentDispatcher = ElEventDispatcher(pair.parent)
      ..event = ElEvent(
        onPointerMove: (event) {
          parentMoves++;
        },
      );
    addTearDown(childDispatcher.dispose);
    addTearDown(parentDispatcher.dispose);

    const down = PointerDownEvent(pointer: 42, position: Offset(10, 20));
    childDispatcher.handleEvent(down, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.handleEvent(
      down,
      BoxHitTestEntry(pair.parent, Offset.zero),
    );
    childDispatcher.handleEvent(
      const PointerMoveEvent(
        pointer: 42,
        position: Offset(20, 20),
        delta: Offset(10, 0),
      ),
      BoxHitTestEntry(pair.child, Offset.zero),
    );

    expect(childMoves, 1);
    expect(
      parentMoves,
      0,
      reason: 'high-frequency pointerMove must not bubble back into the scroll hot path',
    );
  });

  test(
    'pointerPanZoomStart replacing event does not retarget the same start',
    () {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          onPointerPanZoomStart: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              onPointerPanZoomStart: (event) =>
                  phases.add('new:${event.phase.name}'),
              onPointerPanZoomUpdate: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
        );
      addTearDown(dispatcher.dispose);

      dispatcher.handleEvent(
        const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );
      dispatcher.handleEvent(
        const PointerPanZoomUpdateEvent(
          pointer: 1,
          position: Offset(20, 20),
          pan: Offset(0, 8),
          panDelta: Offset(0, 8),
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerPanZoomEndEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );

      expect(phases, <String>[
        'old:pointerPanZoomStart',
        'new:pointerPanZoomUpdate',
      ]);
    },
  );

  test(
    'pointerPanZoomUpdate replacing event does not retarget the same update',
    () {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElEventDispatcher dispatcher;
      final phases = <String>[];
      dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          onPointerPanZoomUpdate: (event) {
            phases.add('old:${event.phase.name}');
            dispatcher.event = ElEvent(
              onPointerPanZoomUpdate: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
        );
      addTearDown(dispatcher.dispose);

      dispatcher.handleEvent(
        const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );
      dispatcher.handleEvent(
        const PointerPanZoomUpdateEvent(
          pointer: 1,
          position: Offset(20, 20),
          pan: Offset(0, 8),
          panDelta: Offset(0, 8),
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerPanZoomEndEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );

      expect(phases, <String>['old:pointerPanZoomUpdate']);
    },
  );

  test('pointerPanZoomEnd replacing event does not retarget the same end', () {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final ElEventDispatcher dispatcher;
    final phases = <String>[];
    dispatcher = ElEventDispatcher(box)
      ..event = ElEvent(
        onPointerPanZoomEnd: (event) {
          phases.add('old:${event.phase.name}');
          dispatcher.event = ElEvent(
            onPointerPanZoomEnd: (event) =>
                phases.add('new:${event.phase.name}'),
          );
        },
      );
    addTearDown(dispatcher.dispose);

    dispatcher.handleEvent(
      const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)),
      entry,
    );
    dispatcher.handleEvent(
      const PointerPanZoomEndEvent(pointer: 1, position: Offset(20, 20)),
      entry,
    );

    expect(phases, <String>['old:pointerPanZoomEnd']);
  });
}

void _dispatch(
  ElEventDispatcher dispatcher,
  BoxHitTestEntry entry,
  PointerEvent event,
) {
  dispatcher.handleEvent(event, entry);
  GestureBinding.instance.pointerRouter.route(event);
  if (event is PointerDownEvent) {
    GestureBinding.instance.gestureArena.close(event.pointer);
  } else if (event is PointerUpEvent || event is PointerPanZoomEndEvent) {
    GestureBinding.instance.gestureArena.sweep(event.pointer);
  }
}

_EventTestBox _attachedBox() {
  final owner = PipelineOwner();
  final box = _EventTestBox();
  owner.rootNode = box;
  return box;
}

({_EventTestBox parent, _EventTestBox child}) _attachedPair() {
  final owner = PipelineOwner();
  final parent = _EventTestBox();
  final child = _EventTestBox();
  parent.child = child;
  owner.rootNode = parent;
  return (parent: parent, child: child);
}

final class _EventTestBox extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  @override
  void performLayout() {
    final child = this.child;
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
    }
    size = constraints.constrain(const Size(100, 100));
  }
}
