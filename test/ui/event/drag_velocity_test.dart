import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final resampling in [false, true]) {
    for (final releaseMs in [45, 50]) {
      testWidgets('合成 move 不改变真实甩出速度：${releaseMs}ms resampling=$resampling', (
        tester,
      ) async {
        final oldEnabled = ElEventDispatcher.enableDragResampling;
        final oldPlatform =
            ElEventDispatcher.debugDragResamplingPlatformOverride;
        final oldRate =
            ElEventDispatcher.debugDragResamplingRefreshRateOverride;
        ElEventDispatcher.enableDragResampling = resampling;
        ElEventDispatcher.debugDragResamplingPlatformOverride =
            TargetPlatform.android;
        ElEventDispatcher.debugDragResamplingRefreshRateOverride = 120;
        addTearDown(() {
          ElEventDispatcher.enableDragResampling = oldEnabled;
          ElEventDispatcher.debugDragResamplingPlatformOverride = oldPlatform;
          ElEventDispatcher.debugDragResamplingRefreshRateOverride = oldRate;
        });
        final box = _attachedBox();
        final tracker = _RecordingVelocityTracker(PointerDeviceKind.touch);
        Velocity? released;
        var deliveredDelta = Offset.zero;
        final dispatcher = ElEventDispatcher(box)
          ..velocityTrackerBuilder = ((_) => tracker)
          ..event = ElEvent(
            config: ElEventConfig(
              dragStartDistance: 3,
              dragResampling: {if (resampling) TargetPlatform.android},
            ),
            onHorizontalDragStart: (_) {},
            onHorizontalDragUpdate: (event) => deliveredDelta += event.delta,
            onHorizontalDragEnd: (event) => released = event.velocity,
          );
        addTearDown(dispatcher.dispose);
        final entry = BoxHitTestEntry(box, Offset.zero);
        dispatcher.handleEvent(
          PointerDownEvent(pointer: 1, position: Offset.zero),
          entry,
        );
        for (var sample = 1; sample <= 3; sample++) {
          dispatcher.handleEvent(
            PointerMoveEvent(
              pointer: 1,
              position: Offset(sample * 20, 0),
              delta: Offset(20, 0),
              timeStamp: Duration(milliseconds: sample * 10),
            ),
            entry,
          );
        }
        final expectedVelocity = tracker.getVelocity().pixelsPerSecond.dx;
        expect(dispatcher.debugDragResamplingActive, resampling);
        // Web converter 在 up 坐标变化时补发 synthetic move；0.01px 是终点修正，不是真实减速。
        dispatcher.handleEvent(
          PointerMoveEvent(
            pointer: 1,
            synthesized: true,
            position: Offset(60.01, 0),
            delta: Offset(0.01, 0),
            timeStamp: Duration(milliseconds: releaseMs),
          ),
          entry,
        );
        dispatcher.handleEvent(
          PointerUpEvent(
            pointer: 1,
            position: Offset(60.01, 0),
            timeStamp: Duration(milliseconds: releaseMs),
          ),
          entry,
        );
        expect(released!.pixelsPerSecond.dx, closeTo(expectedVelocity, 0.001));
        expect(tracker.positions.length, 4, reason: '只采集 down 与三条真实 move');
        expect(
          deliveredDelta.dx,
          closeTo(40.01, 0.001),
          reason: '合成事件仍然更新激活后的完整位移',
        );
      });
    }
  }

  for (final sparse in [false, true]) {
    testWidgets('合成 move 不掩盖真实停顿或污染稀疏速度终点：sparse=$sparse', (tester) async {
      final box = _attachedBox();
      Velocity? released;
      final dispatcher = ElEventDispatcher(box)
        ..event = ElEvent(
          config: ElEventConfig(
            dragStartDistance: 3,
            dragMinFlingDistance: 3,
            dragResampling: {},
          ),
          onHorizontalDragStart: (_) {},
          onHorizontalDragEnd: (event) => released = event.velocity,
        );
      addTearDown(dispatcher.dispose);
      final entry = BoxHitTestEntry(box, Offset.zero);
      dispatcher.handleEvent(
        PointerDownEvent(pointer: 1, position: Offset.zero),
        entry,
      );
      dispatcher.handleEvent(
        PointerMoveEvent(
          pointer: 1,
          position: Offset(10, 0),
          delta: Offset(10, 0),
          timeStamp: Duration(milliseconds: 16),
        ),
        entry,
      );
      final time = Duration(milliseconds: sparse ? 32 : 500);
      final end = Offset(sparse ? 1000 : 10.01, 0);
      dispatcher.handleEvent(
        PointerMoveEvent(
          pointer: 1,
          synthesized: true,
          position: end,
          delta: end - Offset(10, 0),
          timeStamp: time,
        ),
        entry,
      );
      dispatcher.handleEvent(
        PointerUpEvent(pointer: 1, position: end, timeStamp: time),
        entry,
      );
      expect(released!.pixelsPerSecond.dx, closeTo(sparse ? 625 : 0, 0.001));
    });
  }

  for (final accepted in [false, true]) {
    for (final timing in ['continuous', 'paused', 'deliveryDelay']) {
      testWidgets('accepted=$accepted $timing 释放速度按真实事件停顿判断，处理延迟不冒充停顿', (
        tester,
      ) async {
        final box = _attachedBox();
        final tracker = _RecordingVelocityTracker(PointerDeviceKind.touch);
        Velocity? released;
        var starts = 0;
        final dispatcher = ElEventDispatcher(box);
        dispatcher.velocityTrackerBuilder = (_) => tracker;
        dispatcher.event = ElEvent(
          config: ElEventConfig(dragStartDistance: accepted ? 3 : 1000),
          onHorizontalDragStart: (_) => starts++,
          onHorizontalDragEnd: (event) => released = event.velocity,
        );
        addTearDown(dispatcher.dispose);
        final entry = BoxHitTestEntry(box, Offset.zero);
        dispatcher.handleEvent(
          const PointerDownEvent(
            pointer: 1,
            position: Offset.zero,
            timeStamp: Duration.zero,
          ),
          entry,
        );
        for (var sample = 1; sample <= 3; sample++) {
          dispatcher.handleEvent(
            PointerMoveEvent(
              pointer: 1,
              position: Offset(sample * 20, 0),
              delta: const Offset(20, 0),
              timeStamp: Duration(milliseconds: sample * 10),
            ),
            entry,
          );
        }
        expect(tracker.getVelocity().pixelsPerSecond.dx, greaterThan(0));
        if (timing == 'deliveryDelay') {
          await tester.pump(const Duration(milliseconds: 100));
        }
        dispatcher.handleEvent(
          PointerUpEvent(
            pointer: 1,
            position: const Offset(60, 0),
            timeStamp: Duration(milliseconds: timing == 'paused' ? 500 : 32),
          ),
          entry,
        );
        if (timing == 'paused') {
          expect(released?.pixelsPerSecond ?? Offset.zero, Offset.zero);
          expect(starts, accepted ? 1 : 0);
        } else {
          expect(released!.pixelsPerSecond.dx, greaterThan(0));
          expect(starts, 1);
        }
        expect(tracker.positions.length, 4, reason: 'up 位置不能污染 tracker 的拟合样本');
      });
    }
  }
  testWidgets('dragEnd velocity ignores pointerUp-only position jump', (
    tester,
  ) async {
    final box = _attachedBox();
    final tracker = _RecordingVelocityTracker(PointerDeviceKind.touch);

    Offset? dragOffset;
    Velocity? velocity;
    final dispatcher = ElEventDispatcher(box);
    dispatcher.velocityTrackerBuilder = (_) => tracker;
    dispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onDragStart: (_) {},
      onDragEnd: (event) {
        dragOffset = event.dragOffset;
        velocity = event.velocity;
      },
    );
    addTearDown(dispatcher.dispose);

    final entry = BoxHitTestEntry(box, Offset.zero);
    dispatcher.handleEvent(
      const PointerDownEvent(
        pointer: 1,
        kind: PointerDeviceKind.touch,
        position: Offset.zero,
        timeStamp: Duration.zero,
      ),
      entry,
    );
    dispatcher.handleEvent(
      const PointerMoveEvent(
        pointer: 1,
        kind: PointerDeviceKind.touch,
        position: Offset(10, 0),
        delta: Offset(10, 0),
        timeStamp: Duration(milliseconds: 16),
      ),
      entry,
    );
    dispatcher.handleEvent(
      const PointerUpEvent(
        pointer: 1,
        kind: PointerDeviceKind.touch,
        position: Offset(1000, 0),
        timeStamp: Duration(milliseconds: 32),
      ),
      entry,
    );

    expect(tracker.positions, <Offset>[Offset.zero, const Offset(10, 0)]);
    // 零基台账：accept 前段 10px 不进账，dragEnd 只带激活后位移（10 → 1000）。
    expect(dragOffset, const Offset(990, 0));
    expect(velocity, isNotNull);
    expect(velocity!.pixelsPerSecond.dx, lessThan(2000));
  });

  testWidgets(
    'average boundary drag strategy coalesces same-frame pointer moves with different event timestamps',
    (tester) async {
      final box = _attachedBox();

      final deltas = <Offset>[];
      final offsets = <Offset>[];
      final dispatcher = ElEventDispatcher(box)
        ..multitouchDragStrategy =
            MultitouchDragStrategy.averageBoundaryPointers
        ..event = ElEvent(
          config: const ElEventConfig(dragStartDistance: 3),
          onHorizontalDragStart: (_) {},
          onHorizontalDragUpdate: (event) {
            deltas.add(event.delta);
            offsets.add(event.dragOffset);
          },
        );
      addTearDown(dispatcher.dispose);

      final entry = BoxHitTestEntry(box, Offset.zero);
      dispatcher.handleEvent(
        const PointerDownEvent(
          pointer: 1,
          position: Offset.zero,
          timeStamp: Duration.zero,
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(100, 0),
          delta: Offset(100, 0),
          timeStamp: Duration(milliseconds: 16),
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerDownEvent(
          pointer: 2,
          position: Offset(200, 0),
          timeStamp: Duration(milliseconds: 20),
        ),
        entry,
      );
      await tester.pump(const Duration(milliseconds: 16));

      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(110, 0),
          delta: Offset(10, 0),
          timeStamp: Duration(milliseconds: 32),
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 2,
          position: Offset(210, 0),
          delta: Offset(10, 0),
          timeStamp: Duration(milliseconds: 33),
        ),
        entry,
      );

      expect(deltas, <Offset>[const Offset(10, 0)]);
      expect(offsets, <Offset>[const Offset(10, 0)]);
    },
  );

  testWidgets(
    'average boundary fallback frame bucket follows display refresh rate',
    (tester) async {
      final previousRefreshRate =
          ElEventDispatcher.debugDragResamplingRefreshRateOverride;
      ElEventDispatcher.debugDragResamplingRefreshRateOverride = 120;
      addTearDown(() {
        ElEventDispatcher.debugDragResamplingRefreshRateOverride =
            previousRefreshRate;
      });

      final box = _attachedBox();

      final deltas = <Offset>[];
      final offsets = <Offset>[];
      final dispatcher = ElEventDispatcher(box)
        ..multitouchDragStrategy =
            MultitouchDragStrategy.averageBoundaryPointers
        ..event = ElEvent(
          config: const ElEventConfig(dragStartDistance: 3),
          onHorizontalDragStart: (_) {},
          onHorizontalDragUpdate: (event) {
            deltas.add(event.delta);
            offsets.add(event.dragOffset);
          },
        );
      addTearDown(dispatcher.dispose);

      final entry = BoxHitTestEntry(box, Offset.zero);
      dispatcher.handleEvent(
        const PointerDownEvent(
          pointer: 1,
          position: Offset.zero,
          timeStamp: Duration.zero,
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(100, 0),
          delta: Offset(100, 0),
          timeStamp: Duration(milliseconds: 16),
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerDownEvent(
          pointer: 2,
          position: Offset(200, 0),
          timeStamp: Duration(milliseconds: 20),
        ),
        entry,
      );

      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(110, 0),
          delta: Offset(10, 0),
          timeStamp: Duration(milliseconds: 32),
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 2,
          position: Offset(210, 0),
          delta: Offset(10, 0),
          timeStamp: Duration(milliseconds: 42),
        ),
        entry,
      );

      expect(deltas, <Offset>[const Offset(10, 0), const Offset(10, 0)]);
      expect(offsets, <Offset>[const Offset(10, 0), const Offset(20, 0)]);
    },
  );

  testWidgets(
    'average boundary drag strategy does not jump after boundary pointer lifts',
    (tester) async {
      final box = _attachedBox();

      final deltas = <Offset>[];
      final offsets = <Offset>[];
      final dispatcher = ElEventDispatcher(box)
        ..multitouchDragStrategy =
            MultitouchDragStrategy.averageBoundaryPointers
        ..event = ElEvent(
          config: const ElEventConfig(dragStartDistance: 3),
          onHorizontalDragStart: (_) {},
          onHorizontalDragUpdate: (event) {
            deltas.add(event.delta);
            offsets.add(event.dragOffset);
          },
        );
      addTearDown(dispatcher.dispose);

      final entry = BoxHitTestEntry(box, Offset.zero);
      dispatcher.handleEvent(
        const PointerDownEvent(
          pointer: 1,
          position: Offset.zero,
          timeStamp: Duration.zero,
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(100, 0),
          delta: Offset(100, 0),
          timeStamp: Duration(milliseconds: 16),
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerDownEvent(
          pointer: 2,
          position: Offset(200, 0),
          timeStamp: Duration(milliseconds: 20),
        ),
        entry,
      );
      await tester.pump(const Duration(milliseconds: 16));

      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 2,
          position: Offset(210, 0),
          delta: Offset(10, 0),
          timeStamp: Duration(milliseconds: 32),
        ),
        entry,
      );
      dispatcher.handleEvent(
        const PointerUpEvent(
          pointer: 1,
          position: Offset(100, 0),
          timeStamp: Duration(milliseconds: 40),
        ),
        entry,
      );
      await tester.pump(const Duration(milliseconds: 16));

      dispatcher.handleEvent(
        const PointerMoveEvent(
          pointer: 2,
          position: Offset(220, 0),
          delta: Offset(10, 0),
          timeStamp: Duration(milliseconds: 48),
        ),
        entry,
      );

      expect(deltas, <Offset>[const Offset(10, 0), const Offset(10, 0)]);
      expect(offsets, <Offset>[const Offset(10, 0), const Offset(20, 0)]);
    },
  );
}

_EventTestBox _attachedBox() {
  final owner = PipelineOwner();
  final box = _EventTestBox();
  owner.rootNode = box;
  return box;
}

final class _EventTestBox extends RenderBox {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(100, 100));
  }
}

final class _RecordingVelocityTracker extends VelocityTracker {
  _RecordingVelocityTracker(super.kind) : super.withKind();

  final List<Offset> positions = <Offset>[];

  @override
  void addPosition(Duration time, Offset position) {
    positions.add(position);
    super.addPosition(time, position);
  }
}
