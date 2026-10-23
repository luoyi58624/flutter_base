import 'support/event_test_host.dart';

import 'package:flutter_base/src/ui/cores/event/render.dart';
import 'package:flutter_base/src/ui/cores/event/index.dart';
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

      final element = box
        ..event = _dragEvent(
          'old',
          phases,
          onTap: (event) => phases.add('old:${event.phase.name}'),
        );
      addTearDown(element.dispose);
      try {
        await _dispatch(element, entry, _touchDown(pointer: 1));
        await _dispatch(
          element,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -4),
            delta: Offset(0, -4),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );

        element.event = _dragEvent(
          'new',
          phases,
          onTap: (event) => phases.add('new:${event.phase.name}'),
        );
        await _dispatch(
          element,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -4),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        expect(phases, <String>['new:tap']);
        expect(element.activePointerCount, 0);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'replacing pending drag config does not fire stale longPress timer callback',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];

      final element = box..event = _dragEvent('old', phases);
      addTearDown(element.dispose);
      try {
        await _dispatch(element, entry, _touchDown(pointer: 1));

        element.event = _dragEvent('new', phases, includeLongPress: false);
        await tester.pump(const Duration(milliseconds: 40));

        await _dispatch(
          element,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset.zero,
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 40),
          ),
        );

        expect(phases, isEmpty);
        expect(element.activePointerCount, 0);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'replacing equivalent pending drag still keeps drag tracking alive',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];

      final element = box..event = _dragEvent('old', phases);
      addTearDown(element.dispose);
      try {
        await _dispatch(element, entry, _touchDown(pointer: 1));

        element.event = _dragEvent('new', phases);
        await _dispatch(
          element,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        await _dispatch(
          element,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        expect(phases, <String>['new:dragStart', 'new:dragEnd']);
        expect(element.activePointerCount, 0);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets('拖拽参数在 Down 冻结，更新的阈值从下一次 Down 生效', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];

    final element = box
      ..event = _dragEvent('old', phases, dragStartDistance: 30);
    addTearDown(element.dispose);
    try {
      await _dispatch(element, entry, _touchDown(pointer: 1));

      element.event = _dragEvent('new', phases, dragStartDistance: 12);
      await _dispatch(
        element,
        entry,
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, -16),
          delta: Offset(0, -16),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 16),
        ),
      );
      await _dispatch(
        element,
        entry,
        const PointerUpEvent(
          pointer: 1,
          position: Offset(0, -16),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 32),
        ),
      );

      expect(phases, isEmpty);
      await _nextDrag(element, entry);
      expect(phases, ['new:dragStart', 'new:dragUpdate', 'new:dragEnd']);
      expect(element.activePointerCount, 0);
    } finally {
      element.dispose();
    }
  });

  testWidgets('中途新增 Drag 不补报旧 Down，下一次输入正常识别', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];

    final element = box
      ..event = ElEvent(
        onTap: (event) => phases.add('old:${event.phase.name}'),
      );
    addTearDown(element.dispose);
    try {
      await _dispatch(element, entry, _touchDown(pointer: 1));

      element.event = _dragEvent('new', phases);
      await _dispatch(
        element,
        entry,
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, -16),
          delta: Offset(0, -16),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 16),
        ),
      );
      await _dispatch(
        element,
        entry,
        const PointerUpEvent(
          pointer: 1,
          position: Offset(0, -16),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 32),
        ),
      );

      expect(phases, isEmpty);
      await _nextDrag(element, entry);
      expect(phases, ['new:dragStart', 'new:dragUpdate', 'new:dragEnd']);
      expect(element.activePointerCount, 0);
    } finally {
      element.dispose();
    }
  });

  testWidgets(
    'replacing equivalent event during accepted move keeps touch drag alive',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late RenderElEvent element;
      var moves = 0;

      element = box
        ..event = _dragEvent(
          'old',
          phases,
          onPointerMove: (_) {
            if (++moves == 2) element.event = _dragEvent('new', phases);
          },
        );
      addTearDown(element.dispose);
      try {
        await _dispatch(element, entry, _touchDown(pointer: 1));
        await _dispatch(
          element,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        await _dispatch(
          element,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -28),
            delta: Offset(0, -12),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );
        await _dispatch(
          element,
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
          'new:dragUpdate',
          'new:dragEnd',
        ]);
        expect(element.activePointerCount, 0);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets('原始 Move 改变声明结构会取消候选，下轮 Start 内热替换可继续更新', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];
    late RenderElEvent element;

    element = box
      ..event = _dragEvent(
        'old',
        phases,
        onPointerMove: (_) {
          element.event = _dragEvent(
            'new',
            phases,
            onDragStart: (_) {
              phases.add('new:dragStart');
              element.event = _dragEvent('replacement', phases);
            },
          );
        },
      );
    addTearDown(element.dispose);
    try {
      await _dispatch(element, entry, _touchDown(pointer: 1));
      await _dispatch(
        element,
        entry,
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, -16),
          delta: Offset(0, -16),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 16),
        ),
      );
      await _dispatch(
        element,
        entry,
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, -28),
          delta: Offset(0, -12),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 32),
        ),
      );
      await _dispatch(
        element,
        entry,
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, -40),
          delta: Offset(0, -12),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 48),
        ),
      );
      await _dispatch(
        element,
        entry,
        const PointerUpEvent(
          pointer: 1,
          position: Offset(0, -40),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 64),
        ),
      );

      expect(phases, isEmpty);
      await _nextDrag(element, entry);
      expect(phases, <String>[
        'new:dragStart',
        'replacement:dragUpdate',
        'replacement:dragEnd',
      ]);
      expect(element.activePointerCount, 0);
    } finally {
      element.dispose();
    }
  });

  testWidgets(
    'deferred dragStart replacement followed by pointerUp does not retarget replacement',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late RenderElEvent element;

      element = box
        ..event = _dragEvent(
          'old',
          phases,
          onPointerMove: (_) {
            element.event = _dragEvent('new', phases);
          },
        );
      addTearDown(element.dispose);
      try {
        await _dispatch(element, entry, _touchDown(pointer: 1));
        await _dispatch(
          element,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        await _dispatch(
          element,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        expect(phases, isEmpty);
        expect(element.activePointerCount, 0);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets('DragStart 中新增 Tap 不复活旧指针，下一次点击可用', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];
    late RenderElEvent element;

    element = box
      ..event = _dragEvent(
        'old',
        phases,
        onDragStart: (_) {
          phases.add('old:dragStart');
          element.event = ElEvent(
            onTap: (event) => phases.add('replacement:${event.phase.name}'),
          );
        },
      );
    addTearDown(element.dispose);
    try {
      await _dispatch(element, entry, _touchDown(pointer: 1));
      await _dispatch(
        element,
        entry,
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, -16),
          delta: Offset(0, -16),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 16),
        ),
      );
      await _dispatch(
        element,
        entry,
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, -28),
          delta: Offset(0, -12),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 32),
        ),
      );
      await _dispatch(
        element,
        entry,
        const PointerUpEvent(
          pointer: 1,
          position: Offset(0, -28),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 48),
        ),
      );

      expect(phases, <String>['old:dragStart', 'old:dragCancel']);
      await _dispatch(element, entry, _touchDown(pointer: 2));
      await _dispatch(
        element,
        entry,
        const PointerUpEvent(
          pointer: 2,
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 16),
        ),
      );
      expect(phases, ['old:dragStart', 'old:dragCancel', 'replacement:tap']);
      expect(element.activePointerCount, 0);
    } finally {
      element.dispose();
    }
  });

  testWidgets(
    'dragStart replacement with null event cancels old tracking without leaking callbacks',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late RenderElEvent element;

      element = box
        ..event = _dragEvent(
          'old',
          phases,
          onDragStart: (_) {
            phases.add('old:dragStart');
            element.event = null;
          },
        );
      addTearDown(element.dispose);
      try {
        await _dispatch(element, entry, _touchDown(pointer: 1));
        await _dispatch(
          element,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        await _dispatch(
          element,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -28),
            delta: Offset(0, -12),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );
        await _dispatch(
          element,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -28),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 48),
          ),
        );

        expect(phases, <String>['old:dragStart', 'old:dragCancel']);
        expect(element.event, isNull);
        expect(element.activePointerCount, 0);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets(
    'pointerUp replacement cancels the old drag before the next drag starts',
    (tester) async {
      final box = _attachedBox();
      final entry = BoxHitTestEntry(box, Offset.zero);
      final phases = <String>[];
      late final RenderElEvent element;

      element = box
        ..event = _dragEvent(
          'old',
          phases,
          onPointerUp: (_) {
            phases.add('old:pointerUp');
            element.event = _dragEvent('replacement', phases);
          },
        );
      addTearDown(element.dispose);
      try {
        await _dispatch(element, entry, _touchDown(pointer: 1));
        await _dispatch(
          element,
          entry,
          const PointerMoveEvent(
            pointer: 1,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 16),
          ),
        );
        await _dispatch(
          element,
          entry,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 32),
          ),
        );

        await _dispatch(
          element,
          entry,
          const PointerDownEvent(
            pointer: 2,
            position: Offset.zero,
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 48),
          ),
        );
        await _dispatch(
          element,
          entry,
          const PointerMoveEvent(
            pointer: 2,
            position: Offset(0, -16),
            delta: Offset(0, -16),
            kind: PointerDeviceKind.touch,
            timeStamp: Duration(milliseconds: 64),
          ),
        );
        await _dispatch(
          element,
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
        expect(element.activePointerCount, 0);
      } finally {
        element.dispose();
      }
    },
  );

  testWidgets('pointerCancel replacement terminates only the old drag', (
    tester,
  ) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];
    late final RenderElEvent element;

    element = box
      ..event = _dragEvent(
        'old',
        phases,
        onPointerCancel: (_) {
          phases.add('old:pointerCancel');
          element.event = _dragEvent('replacement', phases);
        },
      );
    addTearDown(element.dispose);
    try {
      await _dispatch(element, entry, _touchDown(pointer: 1));
      await _dispatch(
        element,
        entry,
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, -16),
          delta: Offset(0, -16),
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: 16),
        ),
      );
      await _dispatch(
        element,
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
      expect(element.activePointerCount, 0);
    } finally {
      element.dispose();
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

Future<void> _nextDrag(RenderElEvent element, BoxHitTestEntry entry) async {
  await _dispatch(element, entry, _touchDown(pointer: 2));
  for (final (millis, position, delta) in [
    (16, const Offset(0, -16), const Offset(0, -16)),
    (32, const Offset(0, -28), const Offset(0, -12)),
  ]) {
    await _dispatch(
      element,
      entry,
      PointerMoveEvent(
        pointer: 2,
        kind: PointerDeviceKind.touch,
        position: position,
        delta: delta,
        timeStamp: Duration(milliseconds: millis),
      ),
    );
  }
  await _dispatch(
    element,
    entry,
    const PointerUpEvent(
      pointer: 2,
      kind: PointerDeviceKind.touch,
      position: Offset(0, -28),
      timeStamp: Duration(milliseconds: 48),
    ),
  );
}

PointerDownEvent _touchDown({required int pointer}) {
  return PointerDownEvent(
    pointer: pointer,
    position: Offset.zero,
    kind: PointerDeviceKind.touch,
    timeStamp: Duration.zero,
  );
}

Future<void> _dispatch(
  RenderElEvent element,
  BoxHitTestEntry entry,
  PointerEvent event,
) async {
  await element.dispatchInput(event, entry);
}

final class _EventTestBox extends RenderElEvent {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(100, 100));
  }
}
