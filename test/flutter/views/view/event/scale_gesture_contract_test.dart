import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  group('Pointer pan zoom', () {
    testWidgets('start / update / end each fire', (tester) async {
      final phases = <ElEventPhase>[];
      ElEventDetails? updateEvent;
      ElEventDetails? endEvent;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onPointerPanZoomStart: (e) => phases.add(e.phase),
            onPointerPanZoomUpdate: (e) {
              phases.add(e.phase);
              updateEvent = e;
            },
            onPointerPanZoomEnd: (e) {
              phases.add(e.phase);
              endEvent = e;
            },
          ),
        ),
      );
      final pointer = TestPointer(11, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(const Offset(50, 50)));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(const Offset(50, 50), pan: const Offset(10, 5), scale: 1.5, rotation: 0.1),
      );
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      expect(phases, [
        ElEventPhase.pointerPanZoomStart,
        ElEventPhase.pointerPanZoomUpdate,
        ElEventPhase.pointerPanZoomEnd,
      ]);
      expect(updateEvent!.scale, 1.5);
      expect(updateEvent!.rotation, closeTo(0.1, 1e-9));
      expect(updateEvent!.delta, const Offset(10, 5));
      expect(updateEvent!.globalPosition, const Offset(60, 55));
      expect(endEvent!.globalPosition, const Offset(60, 55));
    });

    testWidgets('update delta is per-event panDelta instead of cumulative pan', (tester) async {
      final deltas = <Offset>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onPointerPanZoomUpdate: (e) => deltas.add(e.delta)),
        ),
      );
      final pointer = TestPointer(12, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(const Offset(50, 50)));
      await tester.sendEventToBinding(pointer.panZoomUpdate(const Offset(50, 50), pan: const Offset(10, 5)));
      await tester.sendEventToBinding(pointer.panZoomUpdate(const Offset(50, 50), pan: const Offset(14, 2)));
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      expect(deltas, [const Offset(10, 5), const Offset(4, -3)]);
    });

    testWidgets('ROUTE-5A: PanZoomStart stop keeps update and end on the same route', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childPhases = <ElEventPhase>[];
      final parentPhases = <ElEventPhase>[];
      void recordParent(ElEventDetails event) => parentPhases.add(event.phase);

      host.rootDispatcher.event = ElEvent(
        onPointerPanZoomStart: recordParent,
        onPointerPanZoomUpdate: recordParent,
        onPointerPanZoomEnd: recordParent,
      );
      host.leafDispatcher.event = ElEvent(
        onPointerPanZoomStart: (event) {
          childPhases.add(event.phase);
          event.stopPropagation();
        },
        onPointerPanZoomUpdate: (event) => childPhases.add(event.phase),
        onPointerPanZoomEnd: (event) => childPhases.add(event.phase),
      );

      host.dispatch(const PointerPanZoomStartEvent(pointer: 31, position: Offset(50, 50)));
      host.dispatch(
        const PointerPanZoomUpdateEvent(
          pointer: 31,
          position: Offset(50, 50),
          pan: Offset(10, 5),
          panDelta: Offset(10, 5),
        ),
      );
      host.dispatch(const PointerPanZoomEndEvent(pointer: 31, position: Offset(50, 50)));

      expect(childPhases, <ElEventPhase>[
        ElEventPhase.pointerPanZoomStart,
        ElEventPhase.pointerPanZoomUpdate,
        ElEventPhase.pointerPanZoomEnd,
      ]);
      expect(parentPhases, isEmpty, reason: '祖先不能收到没有配对 Start 的 PanZoom update/terminal');
    });
  });

  testWidgets('ROUTE-5B: Scale 的开始、更新和结束只投递到竞技场赢家', (_) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final childPhases = <ElEventPhase>[];
    final parentPhases = <ElEventPhase>[];
    void recordParent(ElEventDetails event) => parentPhases.add(event.phase);

    host.rootDispatcher.event = ElEvent(
      onScaleStart: recordParent,
      onScaleUpdate: recordParent,
      onScaleEnd: recordParent,
    );
    host.leafDispatcher.event = ElEvent(
      onScaleStart: (event) => childPhases.add(event.phase),
      onScaleUpdate: (event) => childPhases.add(event.phase),
      onScaleEnd: (event) => childPhases.add(event.phase),
    );

    host.dispatch(const PointerDownEvent(pointer: 32, position: Offset(100, 100), kind: PointerDeviceKind.touch));
    host.dispatch(
      const PointerMoveEvent(
        pointer: 32,
        position: Offset(150, 100),
        delta: Offset(50, 0),
        kind: PointerDeviceKind.touch,
      ),
    );
    host.dispatch(
      const PointerMoveEvent(
        pointer: 32,
        position: Offset(180, 100),
        delta: Offset(30, 0),
        kind: PointerDeviceKind.touch,
      ),
    );
    host.dispatch(const PointerUpEvent(pointer: 32, position: Offset(180, 100), kind: PointerDeviceKind.touch));

    expect(childPhases, <ElEventPhase>[
      ElEventPhase.scaleStart,
      ElEventPhase.scaleUpdate,
      ElEventPhase.scaleUpdate,
      ElEventPhase.scaleEnd,
    ]);
    expect(parentPhases, isEmpty, reason: '祖先不能收到没有配对 Start 的 Scale update/terminal');
  });

  testWidgets('SCALE-META-1: Scale 回调保留真实触点输入实例', (_) async {
    final host = DispatcherTestHost.chain(size: const Size(400, 400));
    addTearDown(host.dispose);
    final originalEvents = <ElEventPhase, Object?>{};
    void record(ElEventDetails event) => originalEvents[event.phase] = event.originalEvent;
    host.leafDispatcher.event = ElEvent(
      onScaleStart: record,
      onScaleUpdate: record,
      onRotationUpdate: record,
      onScaleEnd: record,
    );
    host.dispatch(const PointerDownEvent(pointer: 7001, position: Offset(60, 100)));
    host.dispatch(
      const PointerDownEvent(pointer: 7002, position: Offset(140, 100), timeStamp: Duration(milliseconds: 4)),
    );
    const start = PointerMoveEvent(
      pointer: 7002,
      position: Offset(200, 100),
      delta: Offset(60, 0),
      timeStamp: Duration(milliseconds: 20),
    );
    const update = PointerMoveEvent(
      pointer: 7002,
      position: Offset(220, 140),
      delta: Offset(20, 40),
      timeStamp: Duration(milliseconds: 36),
    );
    const end = PointerUpEvent(pointer: 7001, position: Offset(60, 100), timeStamp: Duration(milliseconds: 52));
    host.dispatch(start);
    host.dispatch(update);
    host.dispatch(end);
    host.dispatch(
      const PointerUpEvent(pointer: 7002, position: Offset(220, 140), timeStamp: Duration(milliseconds: 68)),
    );

    expect(originalEvents[ElEventPhase.scaleStart], same(start));
    expect(originalEvents[ElEventPhase.scaleUpdate], same(update));
    expect(originalEvents[ElEventPhase.rotationUpdate], same(update));
    expect(originalEvents[ElEventPhase.scaleEnd], same(end));
  });

  testWidgets('SCALE-7: high phase ScaleStart does not collide with pointerMove in one cycle', (_) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    var pointerMoves = 0;
    var scaleStarts = 0;
    host.leafDispatcher.event = ElEvent(
      onPointerMove: (_) => pointerMoves++,
      onScaleStart: (_) => scaleStarts++,
      onScaleUpdate: (_) {},
    );
    expect(ElEventPhase.scaleStart.index >> 5, isNot(ElEventPhase.pointerMove.index >> 5));

    host.dispatch(const PointerDownEvent(pointer: 41, position: Offset(100, 100), kind: PointerDeviceKind.touch));
    host.dispatch(
      const PointerMoveEvent(
        pointer: 41,
        position: Offset(150, 100),
        delta: Offset(50, 0),
        kind: PointerDeviceKind.touch,
      ),
    );

    expect(scaleStarts, 1);
    expect(pointerMoves, 1, reason: 'Web 32-bit bitwise 下高低 phase 必须使用独立去重字');
  });
}
