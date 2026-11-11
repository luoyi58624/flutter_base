import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';

void main() {
  testWidgets('双指缩放按 Flutter 的起点计算比例和旋转，减指结束当前段', (_) async {
    final host = DispatcherTestHost.chain(size: Size(400, 400));
    addTearDown(host.dispose);
    final starts = <ElEventDetails>[];
    final updates = <ElEventDetails>[];
    final rotations = <ElEventDetails>[];
    final ends = <ElEventDetails>[];
    host.leafDispatcher.event = ElEvent(
      onScaleStart: starts.add,
      onScaleUpdate: updates.add,
      onRotationUpdate: rotations.add,
      onScaleEnd: ends.add,
    );
    final first = TestPointer(1);
    final second = TestPointer(2);
    host.dispatch(first.down(Offset(240, 160)));
    host.dispatch(second.down(Offset(200, 160)));
    final start = second.move(Offset(120, 160));
    host.dispatch(start);

    expect(starts.single.originalEvent, same(start));
    expect(starts.single.pointerCount, 2);
    expect(starts.single.globalPosition, Offset(180, 160));
    expect(updates.last.scale, 1);

    host.dispatch(second.move(Offset(100, 160)));
    expect(updates.last.scale, closeTo(7 / 6, 0.001));
    final rotate = second.move(Offset(240, 20));
    host.dispatch(rotate);
    expect(rotations.single.rotation, closeTo(math.pi / 2, 0.001));
    expect(rotations.single.originalEvent, same(rotate));

    final end = second.up();
    host.dispatch(end);
    expect(ends.single.originalEvent, same(end));
    expect(ends.single.pointerCount, 1);
    host.dispatch(first.up());
    expect(ends, hasLength(1));
  });

  testWidgets('触控板捏合传递官方比例、焦点位移和原始事件', (_) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final updates = <ElEventDetails>[];
    final ends = <ElEventDetails>[];
    host.leafDispatcher.event = ElEvent(onScaleUpdate: updates.add, onScaleEnd: ends.add);

    final origin = Offset(80, 80);
    host.dispatch(PointerPanZoomStartEvent(pointer: 3, position: origin));
    host.dispatch(PointerPanZoomUpdateEvent(pointer: 3, position: origin, scale: 1.2));
    final update = PointerPanZoomUpdateEvent(
      pointer: 3,
      position: origin,
      scale: 1.5,
      pan: Offset(10, 12),
      panDelta: Offset(10, 12),
    );
    host.dispatch(update);
    expect(updates.last.originalEvent, same(update));
    expect(updates.last.globalPosition, Offset(90, 92));
    expect(updates.last.delta, Offset(10, 12));
    expect(updates.last.scale, closeTo(1.25, 0.001));

    final end = PointerPanZoomEndEvent(pointer: 3, position: origin);
    host.dispatch(end);
    expect(ends.single.originalEvent, same(end));
    expect(ends.single.pointerCount, 0);
  });

  testWidgets('Flutter 拖拽已经胜出时，追加触点继续该次拖拽', (_) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    void record(ElEventDetails details) => phases.add(details.phase);
    host.leafDispatcher.event = ElEvent(
      onDragStart: record,
      onDragEnd: record,
      onDragCancel: record,
      onScaleStart: record,
    );
    final first = TestPointer(4);
    final second = TestPointer(5);
    host.dispatch(first.down(Offset(10, 10)));
    host.dispatch(first.move(Offset(60, 10)));
    host.dispatch(second.down(Offset(80, 10)));
    host.dispatch(second.move(Offset(130, 10)));
    host.dispatch(second.up());
    host.dispatch(first.up());

    expect(phases, [ElEventPhase.dragStart, ElEventPhase.dragEnd]);
  });
}
