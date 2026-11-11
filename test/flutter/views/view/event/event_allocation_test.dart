import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  setUp(() {
    EventDispatcher.debugReset();
    BenchmarkProbe.reset();
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('仅 onTap 挂载与点击不分配无关状态：$kind', (tester) async {
      final counts = <int>[];
      ElView view() => ElView(
        style: eventTestDefaultStyle,
        event: ElEvent(onTap: (event) => counts.add(event.tapCount)),
      );

      await pumpEventView(tester, view());
      final render = tester.renderObject<RenderBox>(find.byType(ElView));
      final dispatcher = EventDispatcher.of(render)!;
      expect(BenchmarkProbe.eventDispatcherInstantiateCount, 1);
      expect(BenchmarkProbe.eventPressStateInstantiateCount, 0);
      _expectNoOptionalAllocations();
      expect(dispatcher.debugRetainedStates, isEmpty);

      final gesture = await tester.createGesture(kind: kind);
      addTearDown(gesture.removePointer);
      await gesture.down(Offset(30, 30));
      expect(dispatcher.isTapPressed, isTrue);
      expect(BenchmarkProbe.eventPressStateInstantiateCount, 1);
      await gesture.moveBy(Offset(3, 0));
      await gesture.up();
      await tester.pump(Duration(milliseconds: 200));

      expect(counts, [1]);
      expect(dispatcher.isTapPressed, isFalse);
      expect(dispatcher.debugRetainedStates, isEmpty);
      _expectNoOptionalAllocations();

      await pumpEventView(tester, view());
      expect(EventDispatcher.of(tester.renderObject<RenderBox>(find.byType(ElView))), same(dispatcher));
      expect(BenchmarkProbe.eventDispatcherInstantiateCount, 1);
      expect(BenchmarkProbe.eventPressStateInstantiateCount, 1);
      _expectNoOptionalAllocations();
    });
  }

  testWidgets('按钮键盘激活按需分配状态，切回普通点击后释放', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var taps = 0;
    await pumpEventView(
      tester,
      ElView(
        focusNode: node,
        style: eventTestDefaultStyle,
        // 复用按钮的实际激活逻辑，普通 ElView 不把键盘释放合成为点击。
        event: ElButtonView.buildEvent(() => taps++, false, null),
      ),
    );
    final dispatcher = EventDispatcher.of(tester.renderObject<RenderBox>(find.byType(ElView)))!;
    node.requestFocus();
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    expect(BenchmarkProbe.eventKeyboardStateInstantiateCount, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(dispatcher.isTapPressed, isTrue);
    expect(BenchmarkProbe.eventKeyboardStateInstantiateCount, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(Duration(milliseconds: 200));
    expect(taps, 1);
    expect(dispatcher.isTapPressed, isFalse);

    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: ElEvent(onTap: (_) => taps++),
      ),
    );
    expect(EventDispatcher.of(tester.renderObject<RenderBox>(find.byType(ElView))), same(dispatcher));
    expect(dispatcher.debugRetainedStates, isNot(contains('keyboard')));
    expect(BenchmarkProbe.eventTapSequenceInstantiateCount, 0);
    expect(BenchmarkProbe.eventScaleStateInstantiateCount, 0);
    expect(BenchmarkProbe.eventVelocityBufferInstantiateCount, 0);
    await tester.tapAt(Offset(30, 30));
    await tester.pump(Duration(milliseconds: 200));
    expect(taps, 2);
  });

  testWidgets('双击按需创建连击窗口，移除连击声明后恢复独立单击', (tester) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    var doubles = 0;
    final counts = <int>[];
    final dispatcher = host.leafDispatcher..event = ElEvent(onDoubleTap: (_) => doubles++);
    expect(BenchmarkProbe.eventTapSequenceInstantiateCount, 0);

    for (var index = 0; index < 2; index++) {
      host.tap(
        pointer: index + 1,
        position: Offset(30, 30),
        downTime: Duration(milliseconds: index * 60),
        upTime: Duration(milliseconds: index * 60 + 16),
      );
    }
    expect(doubles, 1);
    expect(BenchmarkProbe.eventTapSequenceInstantiateCount, greaterThan(0));

    host.tap(
      pointer: 3,
      position: Offset(30, 30),
      downTime: Duration(milliseconds: 160),
      upTime: Duration(milliseconds: 176),
    );
    expect(dispatcher.debugRetainedStates, contains('tapSequence'));
    dispatcher.event = ElEvent(onTap: (event) => counts.add(event.tapCount));
    expect(dispatcher.debugRetainedStates, isNot(contains('tapSequence')));
    host.tap(
      pointer: 4,
      position: Offset(30, 30),
      downTime: Duration(milliseconds: 220),
      upTime: Duration(milliseconds: 236),
    );
    await tester.pump(Duration(milliseconds: 400));
    expect(counts, [1]);
    expect(doubles, 1);
    expect(BenchmarkProbe.eventKeyboardStateInstantiateCount, 0);
    expect(BenchmarkProbe.eventScaleStateInstantiateCount, 0);
    expect(BenchmarkProbe.eventVelocityBufferInstantiateCount, 0);
  });

  testWidgets('双指缩放按需创建状态，移除能力后不影响普通点击', (tester) async {
    final host = DispatcherTestHost.chain(size: Size(400, 200));
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    final scales = <double>[];
    var taps = 0;
    final dispatcher = host.leafDispatcher
      ..event = ElEvent(
        onScaleStart: (event) => phases.add(event.phase),
        onScaleUpdate: (event) {
          phases.add(event.phase);
          scales.add(event.scale);
        },
        onScaleEnd: (event) => phases.add(event.phase),
      );
    expect(BenchmarkProbe.eventScaleStateInstantiateCount, 0);
    host.dispatch(PointerDownEvent(pointer: 1, position: Offset(100, 100)));
    host.dispatch(PointerDownEvent(pointer: 2, position: Offset(200, 100)));
    expect(phases, isEmpty);
    host.dispatch(PointerMoveEvent(pointer: 2, position: Offset(260, 100), delta: Offset(60, 0)));
    host.dispatch(PointerMoveEvent(pointer: 2, position: Offset(300, 100), delta: Offset(40, 0)));
    host.dispatch(PointerUpEvent(pointer: 1, position: Offset(100, 100)));
    host.dispatch(PointerUpEvent(pointer: 2, position: Offset(300, 100)));

    expect(phases, [ElEventPhase.scaleStart, ElEventPhase.scaleUpdate, ElEventPhase.scaleEnd]);
    expect(scales.single, closeTo(1.25, 1e-9));
    expect(BenchmarkProbe.eventScaleStateInstantiateCount, greaterThan(0));
    dispatcher.event = ElEvent(onTap: (_) => taps++);
    expect(dispatcher.debugRetainedStates, isNot(contains('scale')));
    host.tap(pointer: 3, downTime: Duration.zero, upTime: Duration(milliseconds: 16), position: Offset(30, 30));
    await tester.pump(Duration(milliseconds: 200));
    expect(taps, 1);
    expect(BenchmarkProbe.eventKeyboardStateInstantiateCount, 0);
    expect(BenchmarkProbe.eventTapSequenceInstantiateCount, 0);
  });

  testWidgets('实际拖动创建速度采样并保留非零结束速度', (tester) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    Velocity? released;
    var starts = 0;
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onHorizontalDragStart: (_) => starts++,
      onHorizontalDragEnd: (event) => released = event.velocity,
    );
    expect(BenchmarkProbe.eventVelocityBufferInstantiateCount, 0);
    host.dispatch(PointerDownEvent(pointer: 1, position: Offset(20, 20)));
    for (var index = 1; index <= 3; index++) {
      host.dispatch(
        PointerMoveEvent(
          pointer: 1,
          position: Offset(20.0 + index * 20, 20),
          delta: Offset(20, 0),
          timeStamp: Duration(milliseconds: index * 16),
        ),
      );
    }
    host.dispatch(PointerUpEvent(pointer: 1, position: Offset(80, 20), timeStamp: Duration(milliseconds: 50)));
    expect(starts, 1);
    expect(released, isNotNull);
    expect(released!.pixelsPerSecond.dx, greaterThan(0));
    expect(BenchmarkProbe.eventVelocityBufferInstantiateCount, 1);
    expect(BenchmarkProbe.eventKeyboardStateInstantiateCount, 0);
    expect(BenchmarkProbe.eventTapSequenceInstantiateCount, 0);
    expect(BenchmarkProbe.eventScaleStateInstantiateCount, 0);
    await tester.pump(Duration(milliseconds: 200));
  });
}

void _expectNoOptionalAllocations() {
  expect(BenchmarkProbe.eventTapSequenceInstantiateCount, 0);
  expect(BenchmarkProbe.eventKeyboardStateInstantiateCount, 0);
  expect(BenchmarkProbe.eventScaleStateInstantiateCount, 0);
  expect(BenchmarkProbe.eventVelocityBufferInstantiateCount, 0);
}
