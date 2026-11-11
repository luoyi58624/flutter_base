// 验证主动认领后原始事件链与长按计时的清理。

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
      expect(parentPointerMoves, 1, reason: '起拖的原始移动先于 Flutter 的获胜回调');
      expect(parentDragStarts, 0, reason: 'the semantic drag layer is suppressed by eager');

      childDispatcher.dispatchTestPointer(secondMove, BoxHitTestEntry(pair.child, const Offset(28, 0)));
      parentDispatcher.dispatchTestPointer(secondMove, BoxHitTestEntry(pair.parent, const Offset(28, 0)));

      expect(parentPointerMoves, 1, reason: '认领后的移动不再投递给祖先');

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
}
