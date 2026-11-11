import 'package:flutter/gestures.dart';
import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

PointerDownEvent _down(int pointer, Offset position) =>
    PointerDownEvent(pointer: pointer, position: position, buttons: kPrimaryButton);

PointerMoveEvent _move(int pointer, Offset position, Offset delta) => PointerMoveEvent(
  pointer: pointer,
  position: position,
  delta: delta,
  buttons: kPrimaryButton,
  timeStamp: Duration(milliseconds: 16),
);

PointerUpEvent _up(int pointer, Offset position) =>
    PointerUpEvent(pointer: pointer, position: position, timeStamp: Duration(milliseconds: 32));

void main() {
  setUp(EventDispatcher.debugReset);

  testWidgets('显式认领同步取消祖先raw再取消Tap，首个Move与后续raw隐退，默认保留自身Tap', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    final cancelCounts = <int>[];
    var committed = false;
    host.rootDispatcher.event = ElEvent(
      onPointerDown: (_) {},
      onPointerMove: (_) => trace.add('parent.move'),
      onPointerUp: (_) => trace.add('parent.up'),
      onPointerCancel: (event) {
        expect(event.pointerEvent, isA<PointerCancelEvent>());
        expect(event.cancelReason, ElEventCancelReason.otherGestureAccepted);
        expect(committed, isFalse);
        cancelCounts.add(event.pointerCount);
        trace.add('parent.pointerCancel');
      },
      onTapDown: (_) {},
      onTapCancel: (_) {
        expect(committed, isFalse);
        trace.add('parent.tapCancel');
      },
      onDragStart: (_) => trace.add('parent.dragStart'),
    );
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onTap: (_) => trace.add('child.tap'),
      onTapUp: (_) => trace.add('child.tapUp'),
      onDragStart: (event) {
        event.eagerGesture();
        committed = true;
        trace.add('child.dragStart');
      },
      onDragEnd: (_) => trace.add('child.dragEnd'),
    );
    host.dispatch(_down(1, Offset(20, 20)));
    host.dispatch(_move(1, Offset(24, 20), Offset(4, 0)));
    expect(trace, ['parent.pointerCancel', 'parent.tapCancel', 'child.dragStart']);
    expect(cancelCounts, [0]);
    host.dispatch(_move(1, Offset(28, 20), Offset(4, 0)));
    host.dispatch(_up(1, Offset(28, 20)));
    expect(trace, [
      'parent.pointerCancel',
      'parent.tapCancel',
      'child.dragStart',
      'child.dragEnd',
      'child.tapUp',
      'child.tap',
    ]);
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('cancelSelfTap只取消最终点击，自己的rawUp、TapUp和DragEnd都保留', (tester) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final trace = <String>[];
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onPointerUp: (_) => trace.add('rawUp'),
      onTapDown: (_) => trace.add('tapDown'),
      onTapCancel: (event) {
        expect(event.cancelReason, ElEventCancelReason.selfGestureAccepted);
        trace.add('tapCancel');
      },
      onTapUp: (_) => trace.add('tapUp'),
      onTap: (_) => trace.add('tap'),
      onDragStart: (event) {
        event.eagerGesture(cancelSelfTap: true);
        event.eagerGesture(cancelSelfTap: true);
        trace.add('dragStart');
      },
      onDragEnd: (_) => trace.add('dragEnd'),
    );
    host.dispatch(_down(2, Offset(20, 20)));
    host.dispatch(_move(2, Offset(24, 20), Offset(4, 0)));
    host.dispatch(_up(2, Offset(24, 20)));
    expect(trace, ['tapDown', 'tapCancel', 'dragStart', 'rawUp', 'dragEnd', 'tapUp']);
  });

  testWidgets('只有raw Down的祖先收到PointerCancel，不伪造被stop截断的TapCancel', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    host.rootDispatcher.event = ElEvent(
      onPointerDown: (_) => trace.add('rawDown'),
      onPointerCancel: (_) => trace.add('rawCancel'),
      onTapDown: (_) => trace.add('tapDown'),
      onTapCancel: (_) => trace.add('tapCancel'),
    );
    host.leafDispatcher.event = ElEvent(
      onTapDown: (event) {
        event.stopPropagation();
        event.eagerGesture(cancelSelfTap: true);
      },
    );
    host.dispatch(_down(3, Offset(20, 20)));
    await tester.pump();
    host.dispatch(_up(3, Offset(20, 20)));
    expect(trace, ['rawDown', 'rawCancel']);
  });

  testWidgets('认领已开始的祖先拖拽先PointerCancel再DragCancel，重复请求不重复结算', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <ElEventPhase>[];
    var claim = false;
    host.rootDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onDragStart: (_) {},
      onPointerCancel: (event) => trace.add(event.phase),
      onDragCancel: (event) => trace.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(
      onPointerMove: (event) {
        if (claim) {
          event.eagerGesture();
          event.eagerGesture();
        }
      },
    );
    host.dispatch(_down(4, Offset(20, 20)));
    host.dispatch(_move(4, Offset(24, 20), Offset(4, 0)));
    claim = true;
    host.dispatch(_move(4, Offset(28, 20), Offset(4, 0)));
    host.dispatch(_up(4, Offset(28, 20)));
    expect(trace, [ElEventPhase.pointerCancel, ElEventPhase.dragCancel]);
  });

  testWidgets('赢家卸载不复活loser，旧details也不能认领复用编号的新输入', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    ElEventDetails? old;
    var parentMoves = 0;
    host.rootDispatcher.event = ElEvent(onPointerMove: (_) => parentMoves++);
    host.leafDispatcher.event = ElEvent(
      onPointerDown: (event) {
        old = event;
        event.eagerGesture();
      },
    );
    host.dispatch(_down(5, Offset(20, 20)));
    await tester.pump();
    host.leafDispatcher.dispose();
    host.dispatch(_move(5, Offset(24, 20), Offset(4, 0)));
    expect(parentMoves, 0);
    host.dispatch(_up(5, Offset(24, 20)));
    host.dispatch(_down(5, Offset(30, 20)));
    old!.eagerGesture();
    host.dispatch(_move(5, Offset(34, 20), Offset(4, 0)));
    expect(parentMoves, 1);
    host.dispatch(_up(5, Offset(34, 20)));
  });

  for (final allowUpgrade in [false, true]) {
    testWidgets('allowScaleUpgrade=$allowUpgrade控制第二指接管，并保留完整终态', (tester) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final trace = <String>[];
      host.rootDispatcher.event = ElEvent(
        onScaleStart: (event) => trace.add('scaleStart:${event.pointerCount}'),
        onScaleUpdate: (event) => trace.add('scaleUpdate:${event.pointerCount}'),
        onScaleEnd: (_) => trace.add('scaleEnd'),
      );
      host.leafDispatcher.event = ElEvent(
        dragStartDistance: 3,
        onDragStart: (event) {
          event.eagerGesture(allowScaleUpgrade: allowUpgrade);
          trace.add('dragStart');
        },
        onDragCancel: (_) => trace.add('dragCancel'),
        onDragEnd: (_) => trace.add('dragEnd'),
      );
      host.dispatch(_down(6, Offset(50, 50)));
      host.dispatch(_move(6, Offset(50, 60), Offset(0, 10)));
      host.dispatch(_down(7, Offset(150, 50)));
      await tester.pump();
      expect(trace, allowUpgrade ? ['dragStart', 'dragCancel', 'scaleStart:2'] : ['dragStart']);
      host.dispatch(_up(7, Offset(150, 50)));
      host.dispatch(_move(6, Offset(60, 70), Offset(10, 10)));
      host.dispatch(_up(6, Offset(60, 70)));
      expect(
        trace,
        allowUpgrade
            ? ['dragStart', 'dragCancel', 'scaleStart:2', 'scaleUpdate:1', 'scaleEnd']
            : ['dragStart', 'dragEnd'],
      );
    });
  }

  testWidgets('第二指拒绝让渡时Scale零提交，首指Drag不被部分取消', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    host.rootDispatcher.event = ElEvent(onScaleStart: (_) => trace.add('scaleStart'));
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onPointerDown: (event) {
        if (event.pointerEvent?.pointer == 9) event.eagerGesture();
      },
      onDragStart: (event) {
        event.eagerGesture(allowScaleUpgrade: true);
        trace.add('dragStart');
      },
      onDragCancel: (_) => trace.add('dragCancel'),
      onDragEnd: (_) => trace.add('dragEnd'),
    );
    host.dispatch(_down(8, Offset(50, 50)));
    host.dispatch(_move(8, Offset(50, 60), Offset(0, 10)));
    host.dispatch(_down(9, Offset(150, 50)));
    await tester.pump();
    expect(trace, ['dragStart']);
    host.dispatch(_up(9, Offset(150, 50)));
    host.dispatch(_move(8, Offset(60, 70), Offset(10, 10)));
    host.dispatch(_up(8, Offset(60, 70)));
    expect(trace, ['dragStart', 'dragEnd']);
  });

  testWidgets('认领不追溯撤销已执行raw，也不替没有命中投递的成员制造raw', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    var childMoves = 0;
    var parentMoves = 0;
    host.rootDispatcher.event = ElEvent(
      onPointerMove: (event) {
        parentMoves++;
        event.eagerGesture();
      },
    );
    host.leafDispatcher.event = ElEvent(onPointerMove: (_) => childMoves++);
    host.dispatch(_down(10, Offset(20, 20)));
    await tester.pump();
    final first = _move(10, Offset(24, 20), Offset(4, 0));
    host.directLeaf(first);
    dispatchTestPointerInput(first);
    expect((childMoves, parentMoves), (1, 0));
    host.dispatch(_move(10, Offset(28, 20), Offset(4, 0)));
    expect((childMoves, parentMoves), (2, 1));
    host.dispatch(_move(10, Offset(32, 20), Offset(4, 0)));
    expect((childMoves, parentMoves), (2, 2));
    host.dispatch(_up(10, Offset(32, 20)));
  });
}
