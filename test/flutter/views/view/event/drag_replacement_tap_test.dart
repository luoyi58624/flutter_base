import 'package:flutter_base/src/flutter/views/view/event/event.dart';
import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

void main() {
  testWidgets('replacing pending tap keeps pointer state and uses current event on release', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];

    final dispatcher = EventDispatcher(box)
      ..event = _dragEvent('old', phases, onTap: (event) => phases.add('old:${event.phase.name}'));
    addTearDown(dispatcher.dispose);

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

    dispatcher.event = _dragEvent('new', phases, onTap: (event) => phases.add('new:${event.phase.name}'));
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
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('replacing equivalent event during accepted move keeps touch drag alive', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];
    late EventDispatcher dispatcher;

    dispatcher = EventDispatcher(box)
      ..event = _dragEvent(
        'old',
        phases,
        onPointerMove: (_) {
          dispatcher.event = _dragEvent('new', phases, onPointerMove: (_) {});
        },
      );
    addTearDown(dispatcher.dispose);

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

    expect(phases, <String>['new:dragStart', 'new:dragUpdate', 'new:dragEnd']);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('同构声明在 DragStart 内更新时，后续移动交给新回调', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];
    late EventDispatcher dispatcher;

    dispatcher = EventDispatcher(box)
      ..event = _dragEvent(
        'old',
        phases,
        onDragStart: (_) {
          phases.add('old:dragStart');
          dispatcher.event = _dragEvent('replacement', phases);
        },
      );
    addTearDown(dispatcher.dispose);

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

    expect(phases, <String>[
      'old:dragStart',
      'replacement:dragUpdate',
      'replacement:dragUpdate',
      'replacement:dragEnd',
    ]);
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('dragStart replacement with null event cancels old tracking without leaking callbacks', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];
    late EventDispatcher dispatcher;

    dispatcher = EventDispatcher(box)
      ..event = _dragEvent(
        'old',
        phases,
        onDragStart: (_) {
          phases.add('old:dragStart');
          dispatcher.event = null;
        },
      );
    addTearDown(dispatcher.dispose);

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
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('pointerUp replacement cancels the old drag before the next drag starts', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];
    late final EventDispatcher dispatcher;

    dispatcher = EventDispatcher(box)
      ..event = _dragEvent(
        'old',
        phases,
        onPointerUp: (_) {
          phases.add('old:pointerUp');
          dispatcher.event = _dragEvent('replacement', phases);
        },
      );
    addTearDown(dispatcher.dispose);

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
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('pointerCancel replacement terminates only the old drag', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <String>[];
    late final EventDispatcher dispatcher;

    dispatcher = EventDispatcher(box)
      ..event = _dragEvent(
        'old',
        phases,
        onPointerCancel: (_) {
          phases.add('old:pointerCancel');
          dispatcher.event = _dragEvent('replacement', phases);
        },
      );
    addTearDown(dispatcher.dispose);

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

    expect(phases, <String>['old:dragStart', 'old:pointerCancel', 'old:dragCancel']);
    expect(dispatcher.isTapPressed, isFalse);
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
    config: ElEventConfig(longPressDelay: const Duration(milliseconds: 30), dragStartDistance: dragStartDistance),
    onPointerMove: onPointerMove,
    onPointerUp: onPointerUp,
    onPointerCancel: onPointerCancel,
    onTap: onTap,
    onLongPress: includeLongPress ? (event) => phases.add('$prefix:${event.phase.name}') : null,
    onDragStart: onDragStart ?? (event) => phases.add('$prefix:${event.phase.name}'),
    onDragUpdate: (event) => phases.add('$prefix:${event.phase.name}'),
    onDragEnd: (event) => phases.add('$prefix:${event.phase.name}'),
    onDragCancel: (event) => phases.add('$prefix:${event.phase.name}'),
  );
}

_EventTestBox _attachedBox() {
  final owner = PipelineOwner();
  final box = _EventTestBox();
  // 替换合同使用正负方向输入，真实表面覆盖原点两侧，避免越界取消抢先触发。
  final surface = RenderTransform(transform: Matrix4.translationValues(-500, -500, 0), child: box);
  // getTransformTo(null) 排除根节点自身变换，因此用中性根保留表面的负向平移。
  final root = RenderProxyBox(surface);
  owner.rootNode = root;
  root.layout(BoxConstraints.tight(const Size(1000, 1000)));
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

void _dispatch(EventDispatcher dispatcher, BoxHitTestEntry entry, PointerEvent event) {
  dispatcher.dispatchTestPointer(event, entry);
}

final class _EventTestBox extends RenderBox {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(100, 100));
  }
}
