import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'replacing pending tap keeps pointer state and uses current event on release',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];

      final dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent(
          'old',
          phases,
          onTap: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -4),
            delta: Offset(0, -4),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );

        dispatcher.event = _dragEvent(
          'new',
          phases,
          onTap: (event) => phases.add('new:${event.phase.name}'),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -4),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        expect(phases, <String>['new:tap']);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'replacing pending drag config does not fire stale longPress timer callback',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];

      final dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent('old', phases);
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));

        dispatcher.event = _dragEvent('new', phases, includeLongPress: false);
        await tester.pump(const Duration(milliseconds: 40));

        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset.zero,
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 40),
          ),
        );

        expect(phases, isEmpty);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'replacing equivalent pending drag still keeps drag tracking alive',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];

      final dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent('old', phases);
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));

        dispatcher.event = _dragEvent('new', phases);
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        expect(phases, <String>['new:dragStart', 'new:dragEnd']);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'replacing non-equivalent drag config keeps active pointer tracking alive',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];

      final dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent('old', phases, dragStartDistance: 30);
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));

        dispatcher.event = _dragEvent('new', phases, dragStartDistance: 12);
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        expect(phases, <String>['new:dragStart', 'new:dragEnd']);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'replacing non-drag event with drag event seeds active pointer tracking',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];

      final dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          onTap: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));

        dispatcher.event = _dragEvent('new', phases);
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        expect(phases, <String>['new:dragStart', 'new:dragEnd']);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'replacing equivalent event during accepted move keeps touch drag alive',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late ElEventDispatcher dispatcher;

      dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent(
          'old',
          phases,
          onPointerMove: (_) {
            dispatcher.event = _dragEvent('new', phases);
          },
        );
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -28),
            delta: Offset(0, -12),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -28),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 48),
          ),
        );

        expect(phases, <String>[
          'new:dragStart',
          'new:dragUpdate',
          'new:dragEnd',
        ]);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'deferred dragStart replacement does not fire update into replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late ElEventDispatcher dispatcher;

      dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent(
          'old',
          phases,
          onPointerMove: (_) {
            dispatcher.event = _dragEvent(
              'new',
              phases,
              onDragStart: (_) {
                phases.add('new:dragStart');
                dispatcher.event = _dragEvent('replacement', phases);
              },
            );
          },
        );
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -28),
            delta: Offset(0, -12),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -40),
            delta: Offset(0, -12),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 48),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -40),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 64),
          ),
        );

        // 'new' -> 'replacement' 是 shape 相等的热替换：已入队的 dragUpdate 改为
        // 实时解析 handler（新闭包即刻生效），不再像旧闭包身份等值时代那样整体
        // 丢弃——move2 的 update 不丢失，fire 到 replacement 闭包。
        expect(phases, <String>[
          'new:dragStart',
          'replacement:dragUpdate',
          'replacement:dragUpdate',
          'replacement:dragEnd',
        ]);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'deferred dragStart replacement followed by pointerUp does not retarget replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late ElEventDispatcher dispatcher;

      dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent(
          'old',
          phases,
          onPointerMove: (_) {
            dispatcher.event = _dragEvent('new', phases);
          },
        );
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        expect(phases, isEmpty);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'dragStart replacement cancels old drag and preserves the pending tap candidate',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late ElEventDispatcher dispatcher;

      dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent(
          'old',
          phases,
          onDragStart: (_) {
            phases.add('old:dragStart');
            dispatcher.event = ElEvent(
              onTap: (event) => phases.add('replacement:${event.phase.name}'),
            );
          },
        );
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -28),
            delta: Offset(0, -12),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -28),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 48),
          ),
        );

        expect(phases, <String>[
          'old:dragStart',
          'old:dragCancel',
          'replacement:tap',
        ]);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'dragStart replacement with null event cancels old tracking without leaking callbacks',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late ElEventDispatcher dispatcher;

      dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent(
          'old',
          phases,
          onDragStart: (_) {
            phases.add('old:dragStart');
            dispatcher.event = null;
          },
        );
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -28),
            delta: Offset(0, -12),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -28),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 48),
          ),
        );

        expect(phases, <String>['old:dragStart', 'old:dragCancel']);
        expect(dispatcher.event, isNull);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets(
    'pointerUp replacement cancels the old drag before the next drag starts',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late final ElEventDispatcher dispatcher;

      dispatcher = ElEventDispatcher(box)
        ..event = _dragEvent(
          'old',
          phases,
          onPointerUp: (_) {
            phases.add('old:pointerUp');
            dispatcher.event = _dragEvent('replacement', phases);
          },
        );
      addTearDown(dispatcher.dispose);
      try {
        _dispatch(dispatcher, entry, _touchDown(pointer: 1));
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        _dispatch(
          dispatcher,
          entry,
          const PointerDownEvent(
            pointer: 2,
            position: Offset.zero,
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 48),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerMoveEvent(
            pointer: 2,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 64),
          ),
        );
        _dispatch(
          dispatcher,
          entry,
          const PointerUpEvent(
            pointer: 2,
            position: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 80),
          ),
        );

        expect(phases, <String>[
          'old:dragStart',
          'old:pointerUp',
          'old:dragCancel',
          'replacement:dragStart',
          'replacement:dragEnd',
        ]);
        expect(dispatcher.activePointerCount, 0);
      } finally {
        dispatcher.dispose();
      }
    },
  );

  testWidgets('pointerCancel replacement terminates only the old drag', (
    tester,
  ) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];
    late final ElEventDispatcher dispatcher;

    dispatcher = ElEventDispatcher(box)
      ..event = _dragEvent(
        'old',
        phases,
        onPointerCancel: (_) {
          phases.add('old:pointerCancel');
          dispatcher.event = _dragEvent('replacement', phases);
        },
      );
    addTearDown(dispatcher.dispose);
    try {
      _dispatch(dispatcher, entry, _touchDown(pointer: 1));
      _dispatch(
        dispatcher,
        entry,
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, -16),
          delta: Offset(0, -16),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 16),
        ),
      );
      _dispatch(
        dispatcher,
        entry,
        const PointerCancelEvent(
          pointer: 1,
          position: Offset(0, -16),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 32),
        ),
      );

      expect(phases, <String>[
        'old:dragStart',
        'old:pointerCancel',
        'old:dragCancel',
      ]);
      expect(dispatcher.activePointerCount, 0);
    } finally {
      dispatcher.dispose();
    }
  });
}

ElEvent _dragEvent(
  String prefix,
  List<String> phases, {
  ElEventHandler? onTap,
  ElEventHandler? onPointerMove,
  ElEventHandler? onPointerUp,
  ElEventHandler? onPointerCancel,
  ElEventHandler? onDragStart,
  double dragStartDistance = 12,
  bool includeLongPress = true,
}) {
  return ElEvent(
    config: ElEventConfig(
      longPressDelay: const Duration(milliseconds: 30),
      dragStartDistance: dragStartDistance,
    ),
    onPointerMove: onPointerMove,
    onPointerUp: onPointerUp,
    onPointerCancel: onPointerCancel,
    onTap: onTap,
    onLongPress: includeLongPress
        ? (event) => phases.add('$prefix:${event.phase.name}')
        : null,
    onDragStart:
        onDragStart ?? (event) => phases.add('$prefix:${event.phase.name}'),
    onDragUpdate: (event) => phases.add('$prefix:${event.phase.name}'),
    onDragEnd: (event) => phases.add('$prefix:${event.phase.name}'),
    onDragCancel: (event) => phases.add('$prefix:${event.phase.name}'),
  );
}

_EventTestBox _attachedBox() {
  final owner = PipelineOwner();
  final box = _EventTestBox();
  owner.rootNode = box;
  return box;
}

PointerDownEvent _touchDown({required int pointer}) {
  return PointerDownEvent(
    pointer: pointer,
    position: Offset.zero,
    kind: PointerDeviceKind.touch,
    timeStamp: Duration.zero,
  );
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

final class _EventTestBox extends RenderBox {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(100, 100));
  }
}
