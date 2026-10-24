import 'support/event_test_host.dart';

import 'package:flutter_base/src/ui/cores/event/render.dart';
import 'package:flutter_base/src/ui/cores/event/index.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapUp replacing event does not fire tap into replacement', (
    tester,
  ) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final ElRenderEvent element;
    final phases = <String>[];
    element = box
      ..event = ElEvent(
        onTapUp: (event) {
          phases.add('old:${event.phase.name}');
          element.event = ElEvent(
            onTap: (event) => phases.add('new:${event.phase.name}'),
          );
        },
        onTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(element.dispose);
    try {
      await element.dispatchInput(
        const PointerDownEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );
      await element.dispatchInput(
        const PointerUpEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );

      expect(phases, <String>['old:tapUp']);
    } finally {
      element.dispose();
    }
  });

  testWidgets('pointerUp replacing event does not fire tap into replacement', (
    tester,
  ) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);

    late final ElRenderEvent element;
    final phases = <String>[];
    element = box
      ..event = ElEvent(
        onPointerUp: (event) {
          phases.add('old:${event.phase.name}');
          element.event = ElEvent(
            onTapUp: (event) => phases.add('new:${event.phase.name}'),
            onTap: (event) => phases.add('new:${event.phase.name}'),
          );
        },
        onTapUp: (event) => phases.add('old:${event.phase.name}'),
        onTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(element.dispose);
    try {
      await element.dispatchInput(
        const PointerDownEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );
      await element.dispatchInput(
        const PointerUpEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );

      expect(phases, <String>['old:pointerUp']);
      expect(element.activePointerCount, 0);
    } finally {
      element.dispose();
    }
  });

  testWidgets(
    'pointerMove replacing event does not start drag or leave tap alive for replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          config: const ElEventConfig(dragStartDistance: 3),
          onPointerMove: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              config: const ElEventConfig(dragStartDistance: 3),
              onDragStart: (event) => phases.add('new:${event.phase.name}'),
              onTap: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onDragStart: (event) => phases.add('old:${event.phase.name}'),
          onTap: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await element.dispatchInput(
          const PointerDownEvent(pointer: 1, position: Offset.zero),
          entry,
        );
        await element.dispatchInput(
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(4, 0),
            delta: Offset(4, 0),
            timeStamp: Duration(milliseconds: 16),
          ),
          entry,
        );
        await element.dispatchInput(
          const PointerUpEvent(pointer: 1, position: Offset(4, 0)),
          entry,
        );

        expect(phases, <String>['old:pointerMove']);
        expect(element.activePointerCount, 0);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'pointerCancel replacing event does not fire cancel into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onPointerCancel: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onTapCancel: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onTapCancel: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await element.dispatchInput(
          const PointerDownEvent(pointer: 1, position: Offset(20, 20)),
          entry,
        );
        await element.dispatchInput(
          const PointerCancelEvent(pointer: 1, position: Offset(20, 20)),
          entry,
        );

        expect(phases, <String>['old:pointerCancel']);
        expect(element.activePointerCount, 0);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'event removal cancel replacement does not emit panZoomEnd into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onTapCancel: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onPointerPanZoomEnd: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
          onPointerPanZoomStart: (event) =>
              phases.add('old:${event.phase.name}'),
          onPointerPanZoomEnd: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await element.dispatchInput(
          const PointerDownEvent(pointer: 1, position: Offset.zero),
          entry,
        );
        await element.dispatchInput(
          const PointerPanZoomStartEvent(pointer: 2, position: Offset(20, 20)),
          entry,
        );

        element.event = null;

        expect(phases, <String>['old:pointerPanZoomStart', 'old:tapCancel']);
        expect(element.event, isNotNull);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'cancelAllPending cancel replacement does not emit panZoomEnd into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onTapCancel: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onPointerPanZoomEnd: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
          onPointerPanZoomStart: (event) =>
              phases.add('old:${event.phase.name}'),
          onPointerPanZoomEnd: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await element.dispatchInput(
          const PointerDownEvent(pointer: 1, position: Offset.zero),
          entry,
        );
        await element.dispatchInput(
          const PointerPanZoomStartEvent(pointer: 2, position: Offset(20, 20)),
          entry,
        );

        element.cancelAllPending(
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(4, 0),
            delta: Offset(4, 0),
          ),
        );

        expect(phases, <String>['old:pointerPanZoomStart', 'old:tapCancel']);
        expect(element.event, isNotNull);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'passive drag acceptance does not invoke tap cancel replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          config: const ElEventConfig(dragStartDistance: 3),
          onTapCancel: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              config: const ElEventConfig(dragStartDistance: 3),
              onDragStart: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onDragStart: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await element.dispatchInput(
          const PointerDownEvent(pointer: 1, position: Offset.zero),
          entry,
        );
        await element.dispatchInput(
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(4, 0),
            delta: Offset(4, 0),
            timeStamp: Duration(milliseconds: 16),
          ),
          entry,
        );

        expect(phases, <String>['old:dragStart']);
        await element.dispatchInput(
          PointerUpEvent(pointer: 1, position: Offset(4, 0)),
          entry,
        );
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'pointerDown replacing event rejects the pending longPress callback',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          config: const ElEventConfig(
            longPressDelay: Duration(milliseconds: 20),
          ),
          onPointerDown: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              config: const ElEventConfig(
                longPressDelay: Duration(milliseconds: 20),
              ),
              onLongPress: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onLongPress: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await _dispatch(
          element,
          entry,
          const PointerDownEvent(pointer: 1, position: Offset.zero),
        );
        await tester.pump(const Duration(milliseconds: 40));

        expect(phases, <String>['old:pointerDown']);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'drag cancel replacing event during scale takeover does not emit scaleStart',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          config: const ElEventConfig(dragStartDistance: 3),
          onDragStart: (event) => phases.add('old:${event.phase.name}'),
          onDragCancel: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onScaleStart: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onScaleStart: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await element.dispatchInput(
          const PointerDownEvent(pointer: 1, position: Offset.zero),
          entry,
        );
        await element.dispatchInput(
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(4, 0),
            delta: Offset(4, 0),
            timeStamp: Duration(milliseconds: 16),
          ),
          entry,
        );

        await element.dispatchInput(
          const PointerDownEvent(pointer: 2, position: Offset(40, 0)),
          entry,
        );

        expect(phases, <String>['old:dragStart', 'old:dragCancel']);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'forward tapUp replacing event does not fire forwardTap into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onForwardTapDown: (event) => phases.add('old:${event.phase.name}'),
          onForwardTapUp: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onForwardTap: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onForwardTap: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await element.dispatchInput(
          const PointerDownEvent(
            pointer: 1,
            position: Offset(10, 10),
            kind: PointerDeviceKind.mouse,
            buttons: kForwardMouseButton,
          ),
          entry,
        );
        await element.dispatchInput(
          const PointerUpEvent(
            pointer: 1,
            position: Offset(10, 10),
            kind: PointerDeviceKind.mouse,
          ),
          entry,
        );

        expect(phases, <String>['old:forwardTapDown', 'old:forwardTapUp']);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'secondary tapUp replacing event does not fire secondaryTap into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onSecondaryTapDown: (event) => phases.add('old:${event.phase.name}'),
          onSecondaryTapUp: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onSecondaryTap: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onSecondaryTap: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await _dispatch(
          element,
          entry,
          const PointerDownEvent(
            pointer: 1,
            position: Offset(10, 10),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryButton,
          ),
        );
        await _dispatch(
          element,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(10, 10),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(phases, <String>['old:secondaryTapDown', 'old:secondaryTapUp']);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'tertiary tapUp replacing event does not fire tertiaryTap into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onTertiaryTapDown: (event) => phases.add('old:${event.phase.name}'),
          onTertiaryTapUp: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onTertiaryTap: (event) => phases.add('new:${event.phase.name}'),
            );
          },
          onTertiaryTap: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await _dispatch(
          element,
          entry,
          const PointerDownEvent(
            pointer: 1,
            position: Offset(10, 10),
            kind: PointerDeviceKind.mouse,
            buttons: kTertiaryButton,
          ),
        );
        await _dispatch(
          element,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(10, 10),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(phases, <String>['old:tertiaryTapDown', 'old:tertiaryTapUp']);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'scale update replacing event does not fire rotationUpdate into replacement',
    (tester) async {
      final box = _attachedBox();

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onScaleStart: (event) => phases.add('old:${event.phase.name}'),
          onScaleUpdate: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onRotationUpdate: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
          onRotationUpdate: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);

      final entry = BoxHitTestEntry(box, Offset.zero);
      await element.dispatchInput(
        const PointerPanZoomStartEvent(pointer: 1, position: Offset(4, 0)),
        entry,
      );
      await element.dispatchInput(
        const PointerPanZoomUpdateEvent(
          pointer: 1,
          position: Offset(4, 0),
          scale: 1.1,
        ),
        entry,
      );
      await element.dispatchInput(
        const PointerPanZoomUpdateEvent(
          pointer: 1,
          position: Offset(4, 0),
          scale: 1.2,
          rotation: 0.2,
        ),
        entry,
      );
      expect(phases, <String>['old:scaleStart', 'old:scaleUpdate']);
    },
  );

  testWidgets('pointerMove no longer bubbles from child to parent', (
    tester,
  ) async {
    final pair = _attachedPair();

    var parentMoves = 0;
    var childMoves = 0;
    final childElement = pair.child
      ..event = ElEvent(
        onPointerMove: (event) {
          childMoves++;
          event.consumeDelta(const Offset(4, 0));
        },
      );
    final parentElement = pair.parent
      ..event = ElEvent(
        onPointerMove: (event) {
          parentMoves++;
        },
      );
    addTearDown(childElement.dispose);
    addTearDown(parentElement.dispose);
    try {
      const down = PointerDownEvent(pointer: 42, position: Offset(10, 20));
      childElement.handleEvent(down, BoxHitTestEntry(pair.child, Offset.zero));
      parentElement.handleEvent(
        down,
        BoxHitTestEntry(pair.parent, Offset.zero),
      );
      childElement.handleEvent(
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
    } finally {
      parentElement.dispose();
      childElement.dispose();
    }
  });

  testWidgets(
    'pointerPanZoomStart replacing event does not retarget the same start',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onPointerPanZoomStart: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onPointerPanZoomStart: (event) =>
                  phases.add('new:${event.phase.name}'),
              onPointerPanZoomUpdate: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
        );
      addTearDown(element.dispose);

      await element.dispatchInput(
        const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );
      await element.dispatchInput(
        const PointerPanZoomUpdateEvent(
          pointer: 1,
          position: Offset(20, 20),
          pan: Offset(0, 8),
          panDelta: Offset(0, 8),
        ),
        entry,
      );
      await element.dispatchInput(
        const PointerPanZoomEndEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );

      expect(phases, <String>[
        'old:pointerPanZoomStart',
        'new:pointerPanZoomUpdate',
      ]);
    },
  );

  testWidgets(
    'pointerPanZoomUpdate replacing event does not retarget the same update',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onPointerPanZoomUpdate: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onPointerPanZoomUpdate: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
        );
      addTearDown(element.dispose);

      await element.dispatchInput(
        const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );
      await element.dispatchInput(
        const PointerPanZoomUpdateEvent(
          pointer: 1,
          position: Offset(20, 20),
          pan: Offset(0, 8),
          panDelta: Offset(0, 8),
        ),
        entry,
      );
      await element.dispatchInput(
        const PointerPanZoomEndEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );

      expect(phases, <String>['old:pointerPanZoomUpdate']);
    },
  );

  testWidgets(
    'pointerPanZoomEnd replacing event does not retarget the same end',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);

      late final ElRenderEvent element;
      final phases = <String>[];
      element = box
        ..event = ElEvent(
          onPointerPanZoomEnd: (event) {
            phases.add('old:${event.phase.name}');
            element.event = ElEvent(
              onPointerPanZoomEnd: (event) =>
                  phases.add('new:${event.phase.name}'),
            );
          },
        );
      addTearDown(element.dispose);

      await element.dispatchInput(
        const PointerPanZoomStartEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );
      await element.dispatchInput(
        const PointerPanZoomEndEvent(pointer: 1, position: Offset(20, 20)),
        entry,
      );

      expect(phases, <String>['old:pointerPanZoomEnd']);
    },
  );
}

Future<void> _dispatch(
  ElRenderEvent element,
  BoxHitTestEntry entry,
  PointerEvent event,
) async {
  await element.dispatchInput(event, entry);
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

final class _EventTestBox extends ElRenderEvent {
  @override
  void performLayout() {
    final child = this.child;
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
    }
    size = constraints.constrain(const Size(100, 100));
  }
}
