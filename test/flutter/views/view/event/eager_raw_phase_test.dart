// 覆盖 eager claim 对 loser 整条事件链的淘汰、chainCutoff 对 raw 的严格拦截、
// 长按 timeout 对 eager 独占的检查、以及 ElEventDetails.hasAncestorDragConsumer
// 的快照语义。
//
// 宿主基准：官方 RenderBox + EventDispatcher 手工 dispatch（见
// [[event-scroll-test-hosting]]）。

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

class _DummyBox extends RenderBox {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(10, 10));
  }
}

class _DummyParent extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  @override
  void performLayout() {
    final c = child;
    if (c != null) {
      c.layout(constraints, parentUsesSize: true);
      size = c.size;
    } else {
      size = constraints.biggest;
    }
  }
}

({_DummyParent parent, _DummyBox child}) _attachedPair() {
  final pipelineOwner = PipelineOwner();
  final parent = _DummyParent();
  final child = _DummyBox();
  parent.child = child;
  pipelineOwner.rootNode = parent;
  parent.layout(BoxConstraints.tight(const Size(1000, 1000)));
  return (parent: parent, child: child);
}

({_DummyParent grandparent, _DummyParent parent, _DummyBox child}) _attachedTriple() {
  final pipelineOwner = PipelineOwner();
  final grandparent = _DummyParent();
  final parent = _DummyParent();
  final child = _DummyBox();
  parent.child = child;
  grandparent.child = parent;
  pipelineOwner.rootNode = grandparent;
  grandparent.layout(BoxConstraints.tight(const Size(1000, 1000)));
  return (grandparent: grandparent, parent: parent, child: child);
}

_DummyBox _attachedBox() {
  final pipelineOwner = PipelineOwner();
  final box = _DummyBox();
  pipelineOwner.rootNode = box;
  box.layout(BoxConstraints.tight(const Size(1000, 1000)));
  return box;
}

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  group('eager claim removes loser event chains', () {
    testWidgets('non-eager chain members stop receiving raw and semantic phases after descendant eagerGesture', (
      tester,
    ) async {
      final pair = _attachedPair();
      final parentDispatcher = EventDispatcher(pair.parent);
      final childDispatcher = EventDispatcher(pair.child);
      var parentPointerMoves = 0;
      var parentPointerUps = 0;
      var parentDragStarts = 0;
      var parentTapUps = 0;
      var childDragStarts = 0;

      parentDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onPointerMove: (_) => parentPointerMoves++,
        onPointerUp: (_) => parentPointerUps++,
        onDragStart: (_) => parentDragStarts++,
        onTapUp: (_) => parentTapUps++,
      );
      childDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) {
          childDragStarts++;
          event.eagerGesture();
        },
      );

      const down = PointerDownEvent(
        pointer: 1,
        position: Offset.zero,
        buttons: kPrimaryButton,
        timeStamp: Duration.zero,
      );
      const firstMove = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 16),
      );
      const secondMove = PointerMoveEvent(
        pointer: 1,
        position: Offset(28, 0),
        delta: Offset(8, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 32),
      );
      const up = PointerUpEvent(pointer: 1, position: Offset(28, 0), timeStamp: Duration(milliseconds: 40));

      childDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.child, Offset.zero));
      parentDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.parent, Offset.zero));
      childDispatcher.dispatchTestPointer(firstMove, BoxHitTestEntry(pair.child, const Offset(20, 0)));
      parentDispatcher.dispatchTestPointer(firstMove, BoxHitTestEntry(pair.parent, const Offset(20, 0)));

      expect(childDragStarts, 1);
      expect(parentPointerMoves, 0, reason: 'loser 在 eager 后必须立刻失去当前 pointerMove 与全部后续 raw phase');
      expect(parentDragStarts, 0, reason: 'the semantic drag layer is suppressed by eager');

      childDispatcher.dispatchTestPointer(secondMove, BoxHitTestEntry(pair.child, const Offset(28, 0)));
      parentDispatcher.dispatchTestPointer(secondMove, BoxHitTestEntry(pair.parent, const Offset(28, 0)));

      expect(parentPointerMoves, 0, reason: 'subsequent raw pointerMove must stay suppressed');

      childDispatcher.dispatchTestPointer(up, BoxHitTestEntry(pair.child, const Offset(28, 0)));
      parentDispatcher.dispatchTestPointer(up, BoxHitTestEntry(pair.parent, const Offset(28, 0)));

      expect(parentPointerUps, 0, reason: 'loser 不再收到 pointerUp');
      expect(parentTapUps, 0, reason: 'semantic tapUp is blocked because child owns the sequence');

      parentDispatcher.dispose();
      childDispatcher.dispose();
    });

    testWidgets('evicting an eager winner terminates the sequence without resurrecting a loser', (_) async {
      final pair = _attachedPair();
      final parentDispatcher = EventDispatcher(pair.parent);
      final childDispatcher = EventDispatcher(pair.child);
      addTearDown(() {
        parentDispatcher.dispose();
        childDispatcher.dispose();
      });
      var childScaleStarts = 0;
      var childPointerMoves = 0;

      parentDispatcher.event = .new(onPointerMove: (event) => event.eagerGesture(allowScaleUpgrade: true));
      childDispatcher.event = .new(onPointerMove: (_) => childPointerMoves++, onScaleStart: (_) => childScaleStarts++);

      const down = PointerDownEvent(pointer: 2, position: Offset.zero, timeStamp: Duration.zero);
      const claimMove = PointerMoveEvent(
        pointer: 2,
        position: Offset(1, 0),
        delta: Offset(1, 0),
        timeStamp: Duration(milliseconds: 8),
      );
      const move = PointerMoveEvent(
        pointer: 2,
        position: Offset(40, 0),
        delta: Offset(39, 0),
        timeStamp: Duration(milliseconds: 16),
      );
      const up = PointerUpEvent(pointer: 2, position: Offset(40, 0), timeStamp: Duration(milliseconds: 32));

      childDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.child, Offset.zero));
      parentDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.parent, Offset.zero));
      childDispatcher.dispatchTestPointer(claimMove, BoxHitTestEntry(pair.child, const Offset(1, 0)));
      parentDispatcher.dispatchTestPointer(claimMove, BoxHitTestEntry(pair.parent, const Offset(1, 0)));
      expect(childPointerMoves, 1, reason: 'winner 认领前已开始执行的 child move 不追溯撤回');

      parentDispatcher.event = null;

      childDispatcher.dispatchTestPointer(move, BoxHitTestEntry(pair.child, const Offset(40, 0)));

      expect(childPointerMoves, 1, reason: 'winner 消失只会终止本序列，不会把 pointer id 还给旧 loser');
      expect(childScaleStarts, 0, reason: '旧 loser 的语义机同样不得复活');

      childDispatcher.dispatchTestPointer(up, BoxHitTestEntry(pair.child, const Offset(40, 0)));
      parentDispatcher.dispatchTestPointer(up, BoxHitTestEntry(pair.parent, const Offset(40, 0)));
      expect(childDispatcher.debugRoutedPointerCount, 0);
    });
  });

  group('long press timeout defers when another member owns eager', () {
    testWidgets('longPress does not fire, set state, or claim when eager is owned by a sibling', (tester) async {
      final pair = _attachedPair();
      final parentDispatcher = EventDispatcher(pair.parent);
      final childDispatcher = EventDispatcher(pair.child);
      var parentLongPresses = 0;
      var childDragStarts = 0;

      parentDispatcher.event = .new(
        config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
        onLongPress: (_) => parentLongPresses++,
      );
      childDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) {
          childDragStarts++;
          event.eagerGesture();
        },
      );

      const down = PointerDownEvent(
        pointer: 1,
        position: Offset.zero,
        buttons: kPrimaryButton,
        timeStamp: Duration.zero,
      );
      const move = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: 8),
      );

      childDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.child, Offset.zero));
      parentDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.parent, Offset.zero));
      childDispatcher.dispatchTestPointer(move, BoxHitTestEntry(pair.child, const Offset(20, 0)));
      parentDispatcher.dispatchTestPointer(move, BoxHitTestEntry(pair.parent, const Offset(20, 0)));

      expect(childDragStarts, 1, reason: 'child accepts drag and claims eager');

      await tester.pump(const Duration(milliseconds: 40));

      expect(parentLongPresses, 0, reason: 'timeout must silently defer when eager is owned by a sibling');

      parentDispatcher.dispose();
      childDispatcher.dispose();
    });

    testWidgets('longPress still fires when eager is not owned by anyone else', (tester) async {
      final box = _attachedBox();
      var longPresses = 0;
      final dispatcher = EventDispatcher(box)
        ..event = .new(
          config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
          onLongPress: (_) => longPresses++,
        );

      const down = PointerDownEvent(
        pointer: 1,
        position: Offset.zero,
        buttons: kPrimaryButton,
        timeStamp: Duration.zero,
      );
      dispatcher.dispatchTestPointer(down, BoxHitTestEntry(box, Offset.zero));
      await tester.pump(const Duration(milliseconds: 40));

      expect(longPresses, 1);

      dispatcher.dispose();
    });
  });

  group('ElEventDetails.hasAncestorDragConsumer snapshot', () {
    testWidgets('true when firer has a drag-capable ancestor within primaryGestureCutoff', (tester) async {
      final pair = _attachedPair();
      final parentDispatcher = EventDispatcher(pair.parent);
      final childDispatcher = EventDispatcher(pair.child);
      final childDragStartFlags = <bool>[];
      final childDragUpdateFlags = <bool>[];

      parentDispatcher.event = .new(config: const ElEventConfig(dragStartDistance: 3), onDragStart: (_) {});
      childDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => childDragStartFlags.add(event.hasAncestorDragConsumer),
        onDragUpdate: (event) => childDragUpdateFlags.add(event.hasAncestorDragConsumer),
      );

      const down = PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero);
      const firstMove = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        timeStamp: Duration(milliseconds: 16),
      );
      const secondMove = PointerMoveEvent(
        pointer: 1,
        position: Offset(28, 0),
        delta: Offset(8, 0),
        timeStamp: Duration(milliseconds: 32),
      );

      childDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.child, Offset.zero));
      parentDispatcher.dispatchTestPointer(down, BoxHitTestEntry(pair.parent, Offset.zero));
      childDispatcher.dispatchTestPointer(firstMove, BoxHitTestEntry(pair.child, const Offset(20, 0)));
      childDispatcher.dispatchTestPointer(secondMove, BoxHitTestEntry(pair.child, const Offset(28, 0)));

      expect(childDragStartFlags, [true]);
      expect(childDragUpdateFlags, [true]);

      parentDispatcher.dispose();
      childDispatcher.dispose();
    });

    testWidgets('false for a single-member chain (no ancestor exists)', (tester) async {
      final box = _attachedBox();
      final flags = <bool>[];
      final dispatcher = EventDispatcher(box)
        ..event = .new(
          config: const ElEventConfig(dragStartDistance: 3),
          onDragStart: (event) => flags.add(event.hasAncestorDragConsumer),
        );

      const down = PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero);
      const move = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        timeStamp: Duration(milliseconds: 16),
      );
      dispatcher.dispatchTestPointer(down, BoxHitTestEntry(box, Offset.zero));
      dispatcher.dispatchTestPointer(move, BoxHitTestEntry(box, const Offset(20, 0)));

      expect(flags, [false]);

      dispatcher.dispose();
    });

    testWidgets('false when the ancestor is outside the DragStart route', (tester) async {
      final triple = _attachedTriple();
      final grandDispatcher = EventDispatcher(triple.grandparent);
      final parentDispatcher = EventDispatcher(triple.parent);
      final childDispatcher = EventDispatcher(triple.child);
      final childDragUpdateFlags = <bool>[];

      grandDispatcher.event = .new(config: const ElEventConfig(dragStartDistance: 3), onDragStart: (_) {});
      parentDispatcher.event = .new(config: const ElEventConfig(dragStartDistance: 3), onDragStart: (_) {});
      childDispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => event.stopPropagation(),
        onDragUpdate: (event) => childDragUpdateFlags.add(event.hasAncestorDragConsumer),
      );

      const down = PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero);
      const firstMove = PointerMoveEvent(
        pointer: 1,
        position: Offset(20, 0),
        delta: Offset(20, 0),
        timeStamp: Duration(milliseconds: 16),
      );
      const secondMove = PointerMoveEvent(
        pointer: 1,
        position: Offset(28, 0),
        delta: Offset(8, 0),
        timeStamp: Duration(milliseconds: 32),
      );

      // 单一 owner 认领：只从最内层（child）发起 handleEvent。
      childDispatcher.dispatchTestPointer(down, BoxHitTestEntry(triple.child, Offset.zero));
      childDispatcher.dispatchTestPointer(firstMove, BoxHitTestEntry(triple.child, const Offset(20, 0)));
      // 此刻 child.onDragStart 内 stopPropagation → Drag route 截断在 child。
      childDispatcher.dispatchTestPointer(secondMove, BoxHitTestEntry(triple.child, const Offset(28, 0)));

      expect(childDragUpdateFlags, [false], reason: 'Drag route 外的祖先不再算可接手的拖拽消费者');

      grandDispatcher.dispose();
      parentDispatcher.dispose();
      childDispatcher.dispose();
    });
  });
}
