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

  testWidgets('官方手势先认领时，待提交的eager不截断已收到Down的祖先rawUp', (tester) async {
    for (final claimOnRawDown in [false, true]) {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final official = EagerGestureRecognizer();
      addTearDown(official.dispose);
      final parentRaw = <ElEventPhase>[];
      var childTapDowns = 0;
      var childTapCancels = 0;
      var parentTapCancels = 0;
      var taps = 0;
      host.rootDispatcher.event = ElEvent(
        onPointerDown: (event) => parentRaw.add(event.phase),
        onPointerUp: (event) => parentRaw.add(event.phase),
        onPointerCancel: (event) => parentRaw.add(event.phase),
        onTapDown: (_) {},
        onTapCancel: (_) => parentTapCancels++,
        onTap: (_) => taps++,
      );
      host.leafDispatcher.event = ElEvent(
        onPointerDown: (event) {
          if (claimOnRawDown) event.eagerGesture();
        },
        onTapDown: (event) {
          childTapDowns++;
          if (!claimOnRawDown) event.eagerGesture();
        },
        onTapCancel: (_) => childTapCancels++,
        onTap: (_) => taps++,
      );
      final pointer = claimOnRawDown ? 110 : 101;
      final down = _down(pointer, Offset(20, 20));
      official.addPointer(down);
      host.directLeaf(down);
      host.directRoot(down);
      expect(parentRaw, claimOnRawDown ? <ElEventPhase>[] : [ElEventPhase.pointerDown]);
      dispatchTestPointerInput(down);
      expect(childTapDowns, 1);
      expect(childTapCancels, 1);
      expect(parentRaw, [ElEventPhase.pointerDown]);
      host.dispatch(_up(pointer, Offset(20, 20)));
      expect(parentRaw, [ElEventPhase.pointerDown, ElEventPhase.pointerUp]);
      expect(childTapCancels, 1);
      expect(parentTapCancels, lessThanOrEqualTo(1));
      expect(taps, 0);
      await tester.pump(Duration(milliseconds: 100));
      host.dispose();
    }
  });

  testWidgets('待提交的eager认领者清空事件或销毁后，祖先已有Down仍以rawUp收尾', (tester) async {
    for (final disposeOwner in [false, true]) {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final parentRaw = <ElEventPhase>[];
      var childTapDowns = 0;
      var childTapCancels = 0;
      var parentTapCancels = 0;
      host.rootDispatcher.event = ElEvent(
        onPointerDown: (event) => parentRaw.add(event.phase),
        onPointerUp: (event) => parentRaw.add(event.phase),
        onPointerCancel: (event) => parentRaw.add(event.phase),
        onTapDown: (_) {},
        onTapCancel: (_) => parentTapCancels++,
      );
      host.leafDispatcher.event = ElEvent(
        onTapDown: (event) {
          childTapDowns++;
          event.eagerGesture();
          if (disposeOwner) {
            host.leafDispatcher.dispose();
          } else {
            host.leafDispatcher.event = null;
          }
        },
        onTapCancel: (_) => childTapCancels++,
      );
      final pointer = disposeOwner ? 103 : 102;
      host.dispatch(_down(pointer, Offset(20, 20)));
      expect(childTapDowns, 1);
      expect(parentRaw, [ElEventPhase.pointerDown]);
      host.dispatch(_up(pointer, Offset(20, 20)));
      expect(parentRaw, [ElEventPhase.pointerDown, ElEventPhase.pointerUp], reason: 'disposeOwner=$disposeOwner');
      expect(childTapCancels, 1);
      expect(parentTapCancels, lessThanOrEqualTo(1));
      await tester.pump(Duration(milliseconds: 100));
      host.dispose();
    }
  });

  testWidgets('eager取消回调重入cancelAll时，祖先rawCancel和TapCancel各一次', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final parentRaw = <ElEventPhase>[];
    var parentTapCancels = 0;
    var parentDragStarts = 0;
    var parentDragCancels = 0;
    var childDragEnds = 0;
    host.rootDispatcher.event = ElEvent(
      onPointerDown: (event) => parentRaw.add(event.phase),
      onPointerUp: (event) => parentRaw.add(event.phase),
      onPointerCancel: (event) {
        parentRaw.add(event.phase);
        host.rootDispatcher.cancelAllPendingAtLastPosition();
      },
      onTapDown: (_) {},
      onTapCancel: (_) => parentTapCancels++,
      onDragStart: (_) => parentDragStarts++,
      onDragCancel: (_) => parentDragCancels++,
    );
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onDragStart: (event) => event.eagerGesture(),
      onDragEnd: (_) => childDragEnds++,
    );
    host.dispatch(_down(104, Offset(20, 20)));
    host.dispatch(_move(104, Offset(24, 20), Offset(4, 0)));
    expect(parentRaw, [ElEventPhase.pointerDown, ElEventPhase.pointerCancel]);
    expect(parentTapCancels, 1);
    host.dispatch(_move(104, Offset(28, 20), Offset(4, 0)));
    host.dispatch(_up(104, Offset(28, 20)));
    expect(parentRaw, [ElEventPhase.pointerDown, ElEventPhase.pointerCancel]);
    expect(parentTapCancels, 1);
    expect(parentDragStarts, 0);
    expect(parentDragCancels, 0);
    expect(childDragEnds, 1);
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('三层eager取消首个祖先时清理另一个祖先，两者终态都只通知一次', (tester) async {
    final host = DispatcherTestHost.chain(depth: 3);
    addTearDown(host.dispose);
    final rawCancels = [0, 0];
    final rawUps = [0, 0];
    final tapCancels = [0, 0];
    final dragCancels = [0, 0];
    for (var index = 0; index < 2; index++) {
      host.dispatchers[index].event = ElEvent(
        onPointerDown: (_) {},
        onPointerUp: (_) => rawUps[index]++,
        onPointerCancel: (_) {
          rawCancels[index]++;
          if (index == 1) host.rootDispatcher.cancelAllPendingAtLastPosition();
        },
        onTapDown: (_) {},
        onTapCancel: (_) => tapCancels[index]++,
        onDragCancel: (_) => dragCancels[index]++,
      );
    }
    var childDragEnds = 0;
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onDragStart: (event) => event.eagerGesture(),
      onDragEnd: (_) => childDragEnds++,
    );
    host.dispatch(_down(105, Offset(20, 20)));
    host.dispatch(_move(105, Offset(24, 20), Offset(4, 0)));
    expect(rawCancels, [1, 1]);
    expect(tapCancels, [1, 1]);
    host.dispatch(_up(105, Offset(24, 20)));
    expect(rawCancels, [1, 1]);
    expect(rawUps, [0, 0]);
    expect(tapCancels, [1, 1]);
    expect(dragCancels, [0, 0]);
    expect(childDragEnds, 1);
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('已起拖祖先在rawCancel内销毁自己，raw和派生取消都不重复', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final parentRaw = <ElEventPhase>[];
    var parentDragStarts = 0;
    var parentDragCancels = 0;
    var parentTapCancels = 0;
    var claim = false;
    host.rootDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onPointerDown: (event) => parentRaw.add(event.phase),
      onPointerUp: (event) => parentRaw.add(event.phase),
      onPointerCancel: (event) {
        parentRaw.add(event.phase);
        host.rootDispatcher.dispose();
      },
      onTapDown: (_) {},
      onTapCancel: (_) => parentTapCancels++,
      onDragStart: (_) => parentDragStarts++,
      onDragCancel: (_) => parentDragCancels++,
    );
    host.leafDispatcher.event = ElEvent(
      onPointerMove: (event) {
        if (claim) event.eagerGesture();
      },
    );
    host.dispatch(_down(106, Offset(20, 20)));
    host.dispatch(_move(106, Offset(24, 20), Offset(4, 0)));
    expect(parentDragStarts, 1);
    claim = true;
    host.dispatch(_move(106, Offset(28, 20), Offset(4, 0)));
    expect(parentRaw, [ElEventPhase.pointerDown, ElEventPhase.pointerCancel]);
    expect(parentTapCancels, 1);
    expect(parentDragCancels, 1);
    host.dispatch(_up(106, Offset(28, 20)));
    expect(parentRaw, [ElEventPhase.pointerDown, ElEventPhase.pointerCancel]);
    expect(parentTapCancels, 1);
    expect(parentDragCancels, 1);
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('祖先未收到被eager截断的rawDown，退出路线时不伪造任何取消', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final parentEvents = <ElEventPhase>[];
    host.rootDispatcher.event = ElEvent(
      onPointerDown: (event) => parentEvents.add(event.phase),
      onPointerUp: (event) => parentEvents.add(event.phase),
      onPointerCancel: (event) => parentEvents.add(event.phase),
      onTapDown: (event) => parentEvents.add(event.phase),
      onTapCancel: (event) => parentEvents.add(event.phase),
      onDragCancel: (event) => parentEvents.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(onPointerDown: (event) => event.eagerGesture());
    host.dispatch(_down(107, Offset(20, 20)));
    expect(parentEvents, isEmpty);
    host.rootDispatcher.cancelAllPendingAtLastPosition();
    expect(parentEvents, isEmpty);
    host.dispatch(_up(107, Offset(20, 20)));
    expect(parentEvents, isEmpty);
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('允许Scale让渡的赢家退出路线后，第二指不能让已失权祖先复活', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final parentScale = <ElEventPhase>[];
    var childDragStarts = 0;
    var childDragCancels = 0;
    host.rootDispatcher.event = ElEvent(
      onScaleStart: (event) => parentScale.add(event.phase),
      onScaleUpdate: (event) => parentScale.add(event.phase),
      onScaleEnd: (event) => parentScale.add(event.phase),
      onScaleCancel: (event) => parentScale.add(event.phase),
    );
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onDragStart: (event) {
        childDragStarts++;
        event.eagerGesture(allowScaleUpgrade: true);
      },
      onDragCancel: (_) => childDragCancels++,
    );
    host.dispatch(_down(108, Offset(50, 50)));
    host.dispatch(_move(108, Offset(50, 60), Offset(0, 10)));
    expect(childDragStarts, 1);
    host.leafDispatcher.cancelAllPendingAtLastPosition();
    expect(host.leafDispatcher.event, isNotNull);
    expect(childDragCancels, 1);
    host.dispatch(_down(109, Offset(150, 50)));
    await tester.pump();
    expect(parentScale, isEmpty);
    host.dispatch(_move(109, Offset(180, 50), Offset(30, 0)));
    expect(parentScale, isEmpty);
    host.dispatch(_up(109, Offset(180, 50)));
    host.dispatch(_up(108, Offset(50, 60)));
    expect(parentScale, isEmpty);
    expect(childDragCancels, 1);
    await tester.pump(Duration(milliseconds: 100));
  });

  testWidgets('暂缓Down回放时中层再次认领，外层不会收到孤立取消且失败后仍能完整收尾', (tester) async {
    for (final officialWins in [false, true]) {
      final host = DispatcherTestHost.chain(depth: 3);
      addTearDown(host.dispose);
      final official = EagerGestureRecognizer();
      addTearDown(official.dispose);
      final outerRaw = <ElEventPhase>[];
      final middleRaw = <ElEventPhase>[];
      host.rootDispatcher.event = ElEvent(
        onPointerDown: (event) => outerRaw.add(event.phase),
        onPointerUp: (event) => outerRaw.add(event.phase),
        onPointerCancel: (event) => outerRaw.add(event.phase),
      );
      host.dispatchers[1].event = ElEvent(
        onPointerDown: (event) {
          middleRaw.add(event.phase);
          event.eagerGesture();
        },
        onPointerUp: (event) => middleRaw.add(event.phase),
        onPointerCancel: (event) => middleRaw.add(event.phase),
      );
      host.leafDispatcher.event = ElEvent(
        onPointerDown: (event) => event.eagerGesture(),
        onTapDown: (_) => host.leafDispatcher.cancelAllPendingAtLastPosition(),
      );
      final pointer = officialWins ? 112 : 111;
      final down = _down(pointer, Offset(20, 20));
      if (officialWins) official.addPointer(down);
      host.directLeaf(down);
      host.direct(1, down);
      host.directRoot(down);
      expect(middleRaw, isEmpty);
      expect(outerRaw, isEmpty);
      dispatchTestPointerInput(down);
      expect(middleRaw, [ElEventPhase.pointerDown]);
      expect(outerRaw, officialWins ? [ElEventPhase.pointerDown] : <ElEventPhase>[]);
      host.dispatch(_up(pointer, Offset(20, 20)));
      expect(middleRaw, [ElEventPhase.pointerDown, ElEventPhase.pointerUp]);
      expect(outerRaw, officialWins ? [ElEventPhase.pointerDown, ElEventPhase.pointerUp] : <ElEventPhase>[]);
      host.dispose();
      await tester.pump(Duration(milliseconds: 100));
    }
  });
}
