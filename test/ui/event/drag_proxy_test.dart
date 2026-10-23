import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  testWidgets('代理按 pre、main、overflow 顺序消费同一份 delta', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    final consumed = <double>[];
    host.rootDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragPreUpdate: (event) {
          trace.add('pre:${event.remainingPrimaryDelta(Axis.vertical)}');
          event.consumePrimaryDelta(Axis.vertical, 3);
          consumed.add(3);
        },
        onDragOverflow: (event) {
          trace.add('overflow:${event.remainingPrimaryDelta(Axis.vertical)}');
          consumed.add(event.remainingPrimaryDelta(Axis.vertical));
          event.consumeAllDelta();
        },
      ),
    );
    host.leafDispatcher.event = ElEvent(
      config: _config,
      onVerticalDragStart: (event) {
        expect(event.delta, Offset.zero);
        expect(event.dragOffset, Offset.zero);
      },
      onVerticalDragUpdate: (event) {
        trace.add('main:${event.remainingPrimaryDelta(Axis.vertical)}');
        event.consumePrimaryDelta(Axis.vertical, 2);
        consumed.add(2);
      },
    );

    _start(host);
    expect(trace, isEmpty, reason: 'DragStart 仅公开生命周期，代理不得消费激活阈值之前的位移');
    _move(host, 20, 32);

    expect(trace, ['pre:10.0', 'main:7.0', 'overflow:5.0']);
    expect(consumed.reduce((a, b) => a + b), 10);
    _end(host, 20);
  });

  testWidgets('pre 消费全部 delta 仍向 main 投递一次零余量，overflow 不再执行', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    host.rootDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragPreUpdate: (event) {
          trace.add('pre');
          event.consumeAllDelta();
          event.stopPropagation();
        },
        onDragOverflow: (_) => trace.add('overflow'),
      ),
    );
    host.leafDispatcher.event = ElEvent(
      config: _config,
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (event) =>
          trace.add('main:${event.remainingDelta.dy}'),
    );

    _start(host);
    _move(host, 20, 32);
    expect(trace, ['pre', 'main:0.0']);
    _end(host, 20);
  });

  for (final axis in <Axis?>[Axis.horizontal, Axis.vertical, null]) {
    testWidgets('纵向 Drag 仅收集兼容轴的代理：axis=$axis', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      var preUpdates = 0;
      var driverUpdates = 0;
      host.rootDispatcher.event = ElEvent(
        dragProxy: ElDragProxy(
          axis: axis,
          onDragPreUpdate: (_) => preUpdates++,
        ),
      );
      host.leafDispatcher.event = ElEvent(
        config: _config,
        onVerticalDragStart: (_) {},
        onVerticalDragUpdate: (_) => driverUpdates++,
      );

      _start(host);
      _move(host, 20, 32);
      expect(driverUpdates, 1);
      expect(preUpdates, axis == Axis.horizontal ? 0 : 1);
      _end(host, 20);
    });
  }

  testWidgets('等形代理替换保留当前 pipeline 并使用新回调', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final trace = <String>[];
    host.rootDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(onDragPreUpdate: (_) => trace.add('old')),
    );
    host.leafDispatcher.event = ElEvent(
      config: _config,
      onDragStart: (_) {},
      onDragUpdate: (_) {},
    );
    _start(host);
    _move(host, 20, 32);
    host.rootDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(onDragPreUpdate: (_) => trace.add('new')),
    );
    _move(host, 30, 48);
    expect(trace, ['old', 'new']);
    _end(host, 30);
  });

  testWidgets('取消 pipeline 后代理成员可以在下一条序列重新参加', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    var starts = 0;
    var cancels = 0;
    var preUpdates = 0;
    host.rootDispatcher.event = ElEvent(
      config: _config,
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragPreUpdate: (_) => preUpdates++,
      ),
      onVerticalDragStart: (_) => starts++,
      onVerticalDragCancel: (_) => cancels++,
    );
    host.leafDispatcher.event = ElEvent(
      config: _config,
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );
    _start(host);
    _move(host, 20, 32);
    host.dispatch(
      const PointerCancelEvent(
        pointer: 1,
        position: Offset(0, 20),
        timeStamp: Duration(milliseconds: 40),
      ),
    );
    expect(starts, 1);
    expect(cancels, 1);
    expect(
      host.dispatchers.map((dispatcher) => dispatcher.activePointerCount),
      everyElement(0),
    );

    _start(host, pointer: 2, baseMillis: 100);
    _move(host, 20, 132, pointer: 2);
    _end(host, 20, pointer: 2, millis: 148);
    expect(starts, 2);
    expect(cancels, 1);
    expect(preUpdates, 2);
  });

  test('代理形状仅比较轴与回调是否存在，独立代理不伪造事件回调', () {
    final first = ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) {});
    final equivalent = ElDragProxy(
      axis: Axis.vertical,
      onDragPreUpdate: (_) {},
    );
    final otherAxis = ElDragProxy(
      axis: Axis.horizontal,
      onDragPreUpdate: (_) {},
    );
    expect(first, equivalent);
    expect(first, isNot(otherAxis));
    final event = ElEvent(dragProxy: first);
    expect(event.hasAnyCallback, isFalse);
    expect(
      event.copyWith(clear: {ElEventClearField.dragProxy}).dragProxy,
      isNull,
    );
  });
}

const _config = ElEventConfig(
  dragStartDistance: 3,
  dragResampling: <TargetPlatform>{},
);

void _start(DispatcherTestHost host, {int pointer = 1, int baseMillis = 0}) {
  host.dispatch(
    PointerDownEvent(
      pointer: pointer,
      timeStamp: Duration(milliseconds: baseMillis),
    ),
  );
  _move(host, 10, baseMillis + 16, pointer: pointer);
}

void _move(DispatcherTestHost host, double y, int millis, {int pointer = 1}) {
  host.dispatch(
    PointerMoveEvent(
      pointer: pointer,
      position: Offset(0, y),
      delta: const Offset(0, 10),
      timeStamp: Duration(milliseconds: millis),
    ),
  );
}

void _end(
  DispatcherTestHost host,
  double y, {
  int pointer = 1,
  int millis = 64,
}) {
  host.dispatch(
    PointerUpEvent(
      pointer: pointer,
      position: Offset(0, y),
      timeStamp: Duration(milliseconds: millis),
    ),
  );
}
