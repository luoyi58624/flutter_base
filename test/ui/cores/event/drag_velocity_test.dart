import 'package:flutter/gestures.dart';
import 'package:flutter_base/src/ui/cores/event/dispatcher.dart';
import 'package:flutter_base/src/ui/cores/event/index.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  testWidgets('真实输入估速，合成移动只影响输出', (tester) async {
    final baseline = await _runDrag(tester);
    final synthetic = await _runDrag(tester, synthetic: true);
    expect(baseline.velocity.pixelsPerSecond.dx, greaterThan(0));
    expect(
      synthetic.velocity.pixelsPerSecond.dx,
      closeTo(baseline.velocity.pixelsPerSecond.dx, 0.001),
    );
    expect(synthetic.delta.dx, closeTo(40.01, 0.001));
    expect(baseline.delta.dx, closeTo(40, 0.001));
  });
  testWidgets('输入派发延迟不算手指停顿，真实事件停顿仍清零释放速度', (tester) async {
    final baseline = await _runDrag(tester);
    final delayed = await _runDrag(tester, processingDelay: true);
    final paused = await _runDrag(tester, paused: true, synthetic: true);
    expect(
      delayed.velocity.pixelsPerSecond.dx,
      closeTo(baseline.velocity.pixelsPerSecond.dx, 0.001),
    );
    expect(paused.velocity, Velocity.zero);
  });

  testWidgets('Up 坐标跳变不计入移动台账或速度样本', (tester) async {
    final baseline = await _runDrag(tester);
    final jumped = await _runDrag(tester, upPosition: const Offset(1000, 0));
    expect(jumped.velocity, baseline.velocity);
    expect(jumped.offset, const Offset(40, 0));
    expect(jumped.delta, const Offset(40, 0));
  });

  testWidgets('未越过启动阈值不能在 Up 通过高速救援伪造已开始的拖拽', (tester) async {
    final host = DispatcherTestHost.chain();
    final phases = <ElEventPhase>[];
    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 1000),
      onDragStart: (event) => phases.add(event.phase),
      onDragEnd: (event) => phases.add(event.phase),
    );
    try {
      await host.dispatch(const PointerDownEvent(pointer: 40));
      await host.dispatch(
        const PointerMoveEvent(
          pointer: 40,
          position: Offset(60, 0),
          delta: Offset(60, 0),
          timeStamp: Duration(milliseconds: 10),
        ),
      );
      await host.dispatch(
        const PointerUpEvent(
          pointer: 40,
          position: Offset(60, 0),
          timeStamp: Duration(milliseconds: 11),
        ),
      );
      expect(phases, isEmpty);
      expect(host.leafDispatcher.activePointerCount, 0);
    } finally {
      host.dispose();
    }
  });

  testWidgets('多指使用最新已接受触点，释放交还旧触点时不跳位移且只有一次 End', (tester) async {
    final host = DispatcherTestHost.chain();
    final deltas = <Offset>[];
    var starts = 0;
    var ends = 0;
    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onDragStart: (_) => starts++,
      onDragUpdate: (event) => deltas.add(event.delta),
      onDragEnd: (_) => ends++,
    );
    try {
      await host.dispatch(const PointerDownEvent(pointer: 50));
      await host.dispatch(
        const PointerMoveEvent(
          pointer: 50,
          position: Offset(10, 0),
          delta: Offset(10, 0),
        ),
      );
      await host.dispatch(
        const PointerDownEvent(pointer: 51, position: Offset(100, 0)),
      );
      await host.dispatch(
        const PointerMoveEvent(
          pointer: 51,
          position: Offset(105, 0),
          delta: Offset(5, 0),
        ),
      );
      await host.dispatch(
        const PointerMoveEvent(
          pointer: 50,
          position: Offset(20, 0),
          delta: Offset(10, 0),
        ),
      );
      await host.dispatch(
        const PointerUpEvent(pointer: 51, position: Offset(105, 0)),
      );
      expect(ends, 0);
      await host.dispatch(
        const PointerMoveEvent(
          pointer: 50,
          position: Offset(25, 0),
          delta: Offset(5, 0),
        ),
      );
      await host.dispatch(
        const PointerUpEvent(pointer: 50, position: Offset(25, 0)),
      );
      expect([starts, ends], [1, 1]);
      expect(deltas, [const Offset(5, 0), const Offset(5, 0)]);
    } finally {
      host.dispose();
    }
  });
}

Future<({Velocity velocity, Offset delta, Offset offset})> _runDrag(
  WidgetTester tester, {
  bool synthetic = false,
  bool paused = false,
  bool processingDelay = false,
  Offset upPosition = const Offset(60, 0),
}) async {
  final host = DispatcherTestHost.chain();
  Velocity? velocity;
  var delta = Offset.zero;
  var offset = Offset.zero;
  host.leafDispatcher.event = ElEvent(
    config: ElEventConfig(
      dragStartDistance: 3,
      dragMinFlingDistance: 3,

    ),
    onHorizontalDragStart: (_) {},
    onHorizontalDragUpdate: (event) => delta += event.delta,
    onHorizontalDragEnd: (event) {
      velocity = event.velocity;
      offset = event.dragOffset;
      expect(event.primaryVelocity, event.velocity.pixelsPerSecond.dx);
    },
  );
  try {
    await host.dispatch(const PointerDownEvent(pointer: 1));
    for (var sample = 1; sample <= 3; sample++) {
      await host.dispatch(
        PointerMoveEvent(
          pointer: 1,
          position: Offset(sample * 20, 0),
          delta: const Offset(20, 0),
          timeStamp: Duration(milliseconds: sample * 10),
        ),
      );
    }

    if (processingDelay) await tester.pump(const Duration(milliseconds: 100));
    final release = paused ? 500 : 32;
    if (synthetic) {
      await host.dispatch(
        PointerMoveEvent(
          pointer: 1,
          synthesized: true,
          position: const Offset(60.01, 0),
          delta: const Offset(0.01, 0),
          timeStamp: Duration(milliseconds: release),
        ),
      );
    }
    await host.dispatch(
      PointerUpEvent(
        pointer: 1,
        position: synthetic ? const Offset(60.01, 0) : upPosition,
        timeStamp: Duration(milliseconds: release),
      ),
    );

    return (velocity: velocity!, delta: delta, offset: offset);
  } finally {
    host.dispose();
  }
}
