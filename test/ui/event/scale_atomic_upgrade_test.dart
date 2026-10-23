import 'package:flutter_base/src/ui/event/index.dart';
import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  testWidgets('SCALE-A1: 可让渡 Drag 在第二指加入时由祖先 Scale 原子接管', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    host.rootDispatcher.event = _scaleEvent(trace);
    host.leafDispatcher.event = _dragEvent(
      trace,
      onStart: (event) => event.eagerGesture(allowScaleUpgrade: true),
    );

    await host.dispatch(
      _down(pointer: 1, position: const Offset(50, 50), millis: 0),
    );
    await host.dispatch(
      _move(
        pointer: 1,
        position: const Offset(50, 60),
        delta: const Offset(0, 10),
        millis: 16,
      ),
    );
    expect(trace, <String>['dragStart']);

    await host.dispatch(
      _down(pointer: 2, position: const Offset(150, 50), millis: 32),
    );
    expect(trace, <String>[
      'dragStart',
      'dragCancel',
      'scaleStart:2',
    ], reason: '两根序列必须先整体改归 Scale，再终止 Drag，最后才公开 scaleStart');

    await host.dispatch(
      _move(
        pointer: 2,
        position: const Offset(170, 50),
        delta: const Offset(20, 0),
        millis: 48,
      ),
    );
    await host.dispatch(
      _up(pointer: 2, position: const Offset(170, 50), millis: 64),
    );
    await host.dispatch(
      _move(
        pointer: 1,
        position: const Offset(60, 70),
        delta: const Offset(10, 10),
        millis: 80,
      ),
    );
    await host.dispatch(
      _up(pointer: 1, position: const Offset(60, 70), millis: 96),
    );

    expect(trace, <String>[
      'dragStart',
      'dragCancel',
      'scaleStart:2',
      'scaleUpdate:2',
      'scaleEnd',
    ], reason: '1→2→1 只允许一套 Scale 生命周期，减回单指后继续 update 而不是重启');
  });

  testWidgets('SCALE-A2: 默认 eagerGesture 不向祖先 Scale 让渡', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    host.rootDispatcher.event = _scaleEvent(trace);
    host.leafDispatcher.event = _dragEvent(
      trace,
      onStart: (event) => event.eagerGesture(),
    );

    await host.dispatch(
      _down(pointer: 1, position: const Offset(50, 50), millis: 0),
    );
    await host.dispatch(
      _move(
        pointer: 1,
        position: const Offset(50, 60),
        delta: const Offset(0, 10),
        millis: 16,
      ),
    );
    await host.dispatch(
      _down(pointer: 2, position: const Offset(150, 50), millis: 32),
    );
    expect(trace, <String>[
      'dragStart',
    ], reason: '第二指加入不能越过默认 eager owner 接管第一指');

    await host.dispatch(
      _up(pointer: 2, position: const Offset(150, 50), millis: 48),
    );
    await host.dispatch(
      _move(
        pointer: 1,
        position: const Offset(50, 75),
        delta: const Offset(0, 15),
        millis: 64,
      ),
    );
    await host.dispatch(
      _up(pointer: 1, position: const Offset(50, 75), millis: 80),
    );

    expect(trace, <String>['dragStart', 'dragUpdate', 'dragEnd']);
  });

  testWidgets('SCALE-A3: 任一参与指针不可让渡时不得部分取消既有 Drag', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    host.rootDispatcher.event = _scaleEvent(trace);
    host.leafDispatcher.event = _dragEvent(
      trace,
      onPointerDown: (event) {
        final original = event.originalEvent;
        if (original is PointerDownEvent && original.pointer == 2) {
          event.eagerGesture();
          trace.add('pointer2Exclusive');
        }
      },
      onStart: (event) => event.eagerGesture(allowScaleUpgrade: true),
    );

    await host.dispatch(
      _down(pointer: 1, position: const Offset(50, 50), millis: 0),
    );
    await host.dispatch(
      _move(
        pointer: 1,
        position: const Offset(50, 60),
        delta: const Offset(0, 10),
        millis: 16,
      ),
    );
    await host.dispatch(
      _down(pointer: 2, position: const Offset(150, 50), millis: 32),
    );
    expect(trace, <String>[
      'dragStart',
      'pointer2Exclusive',
    ], reason: '第二指已不可让渡时，祖先必须零提交，不能先改归第一指并发出 dragCancel');

    await host.dispatch(
      _up(pointer: 2, position: const Offset(150, 50), millis: 48),
    );
    await host.dispatch(
      _move(
        pointer: 1,
        position: const Offset(50, 75),
        delta: const Offset(0, 15),
        millis: 64,
      ),
    );
    await host.dispatch(
      _up(pointer: 1, position: const Offset(50, 75), millis: 80),
    );

    expect(trace, <String>[
      'dragStart',
      'pointer2Exclusive',
      'dragUpdate',
      'dragEnd',
    ], reason: '失败的 Scale 接管不得留下半提交状态，原 Drag 必须能继续并正常结束');
  });

  testWidgets('SCALE-A4: 可让渡 winner 被移除后不得残留第二指立即升级权限', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    var scaleStarts = 0;
    host.rootDispatcher.event = ElEvent(onScaleStart: (_) => scaleStarts++);
    host.leafDispatcher.event = _dragEvent(
      <String>[],
      onStart: (event) => event.eagerGesture(allowScaleUpgrade: true),
    );

    await host.dispatch(
      _down(pointer: 1, position: const Offset(50, 50), millis: 0),
    );
    await host.dispatch(
      _move(
        pointer: 1,
        position: const Offset(50, 60),
        delta: const Offset(0, 10),
        millis: 16,
      ),
    );
    host.leafDispatcher.dispose();

    final rootEntry = BoxHitTestEntry(host.nodes.first, Offset.zero);
    host.rootDispatcher.handleEvent(
      _down(pointer: 2, position: const Offset(150, 50), millis: 32),
      rootEntry,
    );
    expect(
      scaleStarts,
      0,
      reason: '原 winner 已消失，遗留 tracker 只能退回普通双指阈值，不能沿用旧让渡权',
    );

    host.rootDispatcher.handleEvent(
      _move(
        pointer: 2,
        position: const Offset(210, 50),
        delta: const Offset(60, 0),
        millis: 48,
      ),
      rootEntry,
    );
    expect(
      scaleStarts,
      0,
      reason: 'winner 离场会终止旧 pointer 序列，旧 loser 不能借第二指重新复活',
    );
  });

  testWidgets('SCALE-A6: pipeline shadow 不得覆盖第二指自己的默认 eager', (_) async {
    final host = DispatcherTestHost.chain(depth: 3);
    addTearDown(host.dispose);
    final trace = <String>[];
    final root = host.dispatchers[0];
    final middle = host.dispatchers[1];
    final leaf = host.dispatchers[2];
    root.event = ElEvent(
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragOverflow: (_) {}),
    );
    middle.event = ElEvent(
      onPointerDown: (event) {
        final original = event.originalEvent;
        if (original is PointerDownEvent && original.pointer == 2) {
          event.eagerGesture();
          trace.add('pointer2Exclusive');
        }
      },
    );
    leaf.event = ElEvent(
      config: const ElEventConfig(
        dragStartDistance: 3,
        dragResampling: <TargetPlatform>{},
      ),
      onScaleStart: (_) => trace.add('scaleStart'),
      onVerticalDragStart: (_) => trace.add('dragStart'),
      onVerticalDragUpdate: (_) => trace.add('dragUpdate'),
      onVerticalDragEnd: (_) => trace.add('dragEnd'),
      onVerticalDragCancel: (_) => trace.add('dragCancel'),
    );

    await host.dispatch(
      _down(pointer: 1, position: const Offset(50, 50), millis: 0),
    );
    await host.dispatch(
      _move(
        pointer: 1,
        position: const Offset(50, 60),
        delta: const Offset(0, 10),
        millis: 16,
      ),
    );
    expect(trace, ['dragStart']);

    final down2 = _down(
      pointer: 2,
      position: const Offset(150, 50),
      millis: 32,
    );
    middle.handleEvent(down2, BoxHitTestEntry(host.nodes[1], down2.position));
    root.handleEvent(down2, BoxHitTestEntry(host.nodes[0], down2.position));
    expect(trace, [
      'dragStart',
      'pointer2Exclusive',
    ], reason: '不在 target 链上的第二指已默认 eager，shadow 不得后写可让渡权限');

    final up2 = _up(pointer: 2, position: const Offset(150, 50), millis: 48);
    middle.handleEvent(up2, BoxHitTestEntry(host.nodes[1], up2.position));
    root.handleEvent(up2, BoxHitTestEntry(host.nodes[0], up2.position));
    await host.dispatch(
      _move(
        pointer: 1,
        position: const Offset(50, 75),
        delta: const Offset(0, 15),
        millis: 64,
      ),
    );
    await host.dispatch(
      _up(pointer: 1, position: const Offset(50, 75), millis: 80),
    );
    expect(trace, [
      'dragStart',
      'pointer2Exclusive',
      'dragUpdate',
      'dragEnd',
    ], reason: '失败的 shadow 不得取消或污染首指 pipeline');
  });

  testWidgets('SCALE-A8: 跨后代 Scale 接管时祖先 dragCancel 报告目标侧双指计数', (_) async {
    final pipelineOwner = PipelineOwner();
    final rootBox = RenderFlex(
      direction: Axis.horizontal,
      textDirection: TextDirection.ltr,
    );
    final leftBox = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 100,
        height: 100,
      ),
    );
    final rightBox = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 100,
        height: 100,
      ),
    );
    rootBox.addAll(<RenderBox>[leftBox, rightBox]);
    pipelineOwner.rootNode = rootBox;
    rootBox.layout(const BoxConstraints.tightFor(width: 200, height: 100));

    final root = ElEventDispatcher(rootBox);
    final left = ElEventDispatcher(leftBox);
    final right = ElEventDispatcher(rightBox);
    addTearDown(() {
      right.dispose();
      left.dispose();
      root.dispose();
      pipelineOwner.rootNode = null;
    });

    int? ancestorCancelPointerCount;
    root.event = ElEvent(
      config: const ElEventConfig(
        dragStartDistance: 3,
        dragResampling: <TargetPlatform>{},
      ),
      onScaleStart: (_) {},
      onDragCancel: (event) => ancestorCancelPointerCount = event.pointerCount,
    );
    left.event = ElEvent(
      config: const ElEventConfig(
        dragStartDistance: 3,
        dragResampling: <TargetPlatform>{},
      ),
      onDragStart: (_) {},
      onDragUpdate: (_) {},
      onDragCancel: (_) {},
    );
    right.event = ElEvent(onPointerDown: (_) {});

    Future<void> dispatchThrough(
      ElEventDispatcher leaf,
      RenderBox box,
      PointerEvent event,
    ) async {
      leaf.handleEvent(event, BoxHitTestEntry(box, event.position));
      root.handleEvent(event, BoxHitTestEntry(rootBox, event.position));
      routeTestPointer(event);
    }

    await dispatchThrough(
      left,
      leftBox,
      _down(pointer: 31, position: const Offset(50, 50), millis: 0),
    );
    await dispatchThrough(
      left,
      leftBox,
      _move(
        pointer: 31,
        position: const Offset(50, 60),
        delta: const Offset(0, 10),
        millis: 16,
      ),
    );
    await dispatchThrough(
      right,
      rightBox,
      _down(pointer: 32, position: const Offset(150, 50), millis: 32),
    );

    // 第二指通过共同祖先加入真实识别路线，不再强制调用内部 Scale 阶段。

    expect(
      ancestorCancelPointerCount,
      2,
      reason: '内层 Drag 仅跟踪左侧指针，但冒泡到共同祖先时必须按祖先的两条活跃序列重写计数',
    );
  });
}

ElEvent _scaleEvent(List<String> trace) {
  return ElEvent(
    onScaleStart: (event) => trace.add('scaleStart:${event.pointerCount}'),
    onScaleUpdate: (event) => trace.add('scaleUpdate:${event.pointerCount}'),
    onScaleEnd: (_) => trace.add('scaleEnd'),
    onScaleCancel: (_) => trace.add('scaleCancel'),
  );
}

ElEvent _dragEvent(
  List<String> trace, {
  ElEventHandler? onPointerDown,
  required ElEventHandler onStart,
}) {
  return ElEvent(
    config: const ElEventConfig(
      dragStartDistance: 3,
      dragResampling: <TargetPlatform>{},
    ),
    onPointerDown: onPointerDown,
    onDragStart: (event) {
      trace.add('dragStart');
      onStart(event);
    },
    onDragUpdate: (_) => trace.add('dragUpdate'),
    onDragEnd: (_) => trace.add('dragEnd'),
    onDragCancel: (_) => trace.add('dragCancel'),
  );
}

PointerDownEvent _down({
  required int pointer,
  required Offset position,
  required int millis,
}) {
  return PointerDownEvent(
    pointer: pointer,
    position: position,
    kind: PointerDeviceKind.touch,
    timeStamp: Duration(milliseconds: millis),
  );
}

PointerMoveEvent _move({
  required int pointer,
  required Offset position,
  required Offset delta,
  required int millis,
}) {
  return PointerMoveEvent(
    pointer: pointer,
    position: position,
    delta: delta,
    kind: PointerDeviceKind.touch,
    timeStamp: Duration(milliseconds: millis),
  );
}

PointerUpEvent _up({
  required int pointer,
  required Offset position,
  required int millis,
}) {
  return PointerUpEvent(
    pointer: pointer,
    position: position,
    kind: PointerDeviceKind.touch,
    timeStamp: Duration(milliseconds: millis),
  );
}
