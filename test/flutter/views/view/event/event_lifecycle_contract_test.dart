import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  group('ElView wires event to render dispatcher', () {
    testWidgets('without event the dispatcher is not allocated', (tester) async {
      await pumpEventView(tester, ElView(style: eventTestDefaultStyle));
      final box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), isNull);
    });

    testWidgets('with event the dispatcher holds the reference', (tester) async {
      final event = ElEvent(onTap: (_) {});
      await pumpEventView(tester, ElView(style: eventTestDefaultStyle, event: event));
      final box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box)!.event, same(event));
    });

    testWidgets('event=null in rebuild releases dispatcher', (tester) async {
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) {}),
        ),
      );
      var box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), isNotNull);
      await pumpEventView(tester, ElView(style: eventTestDefaultStyle));
      box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), isNull);
    });

    testWidgets('copyWith null removes a handler during rebuild', (tester) async {
      var taps = 0;
      final event = ElEvent(onTap: (_) => taps++);

      await pumpEventView(tester, ElView(style: eventTestDefaultStyle, event: event));
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(taps, 1);

      await pumpEventView(tester, ElView(style: eventTestDefaultStyle, event: event.copyWith(onTap: null)));
      await tester.tap(find.byType(ElView));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('removing state variants releases idle dispatcher', (tester) async {
      await pumpEventView(
        tester,
        const ElView(
          style: ElStyle(width: 100, height: 100, onTap: ElStyle(backgroundColor: Color(0xFFFF0000))),
        ),
      );
      var box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), isNotNull);

      await pumpEventView(tester, ElView(style: eventTestDefaultStyle));

      box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), isNull);
    });

    testWidgets('removing focus-only entry releases idle dispatcher', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpEventView(tester, ElView(style: const ElStyle(width: 100, height: 100), focusNode: node));
      var box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), isNull);

      await tester.tap(find.byType(ElView));
      await tester.pump();

      box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), isNotNull);

      await pumpEventView(tester, const ElView(style: ElStyle(width: 100, height: 100)));

      box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), isNull);
    });

    testWidgets('unmounting widget disposes dispatcher', (tester) async {
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) {}),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(ElView));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(EventDispatcher.of(box), isNull);
    });
  });

  group('Style and event independence', () {
    testWidgets('updating style preserves dispatcher and event', (tester) async {
      final event = ElEvent(onTap: (_) {});
      await pumpEventView(tester, ElView(style: eventTestDefaultStyle, event: event));
      var box = tester.renderObject<RenderBox>(find.byType(ElView));
      final dispatcher = EventDispatcher.of(box);
      await pumpEventView(
        tester,
        ElView(
          style: const ElStyle(width: 200, height: 100, backgroundColor: Color(0xFF0000FF)),
          event: event,
        ),
      );
      box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), same(dispatcher));
      expect(dispatcher!.event, same(event));
      expect(box.size, const Size(200, 100));
    });
  });

  group('Mouse hover lifecycle', () {
    testWidgets('removing onHover clears the stored hover state', (tester) async {
      const idleColor = Color(0x00000000);
      const hoverColor = Color(0xFFFFFFFF);
      const plainColor = Color(0xFFD6D6D6);
      const hoverStyle = ElStyle(
        width: 100,
        height: 100,
        backgroundColor: idleColor,
        onHover: ElStyle(backgroundColor: hoverColor),
      );
      const plainStyle = ElStyle(width: 100, height: 100, backgroundColor: plainColor);

      var useHoverStyle = true;
      late StateSetter setViewState;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: StatefulBuilder(
              builder: (context, setState) {
                setViewState = setState;
                return ElView(style: useHoverStyle ? hoverStyle : plainStyle);
              },
            ),
          ),
        ),
      );

      final box = tester.renderObject<ElRenderView>(find.byType(ElView));
      Color? bgColor() => box.committedResolvedStyle.box.backgroundColor;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(-10, -10));
      await tester.pump();
      await mouse.moveTo(const Offset(50, 50));
      await tester.pump();
      expect(bgColor(), hoverColor);

      setViewState(() => useHoverStyle = false);
      await tester.pump();
      expect(bgColor(), plainColor);
      await mouse.moveTo(const Offset(500, 500));
      await tester.pump();
      setViewState(() => useHoverStyle = true);
      await tester.pump();
      expect(bgColor(), idleColor, reason: '移除 hover 变体时必须同步清掉旧状态');
    });

    testWidgets('hover shrink stays stable until the mouse moves again', (tester) async {
      const key = ValueKey<String>('hover-shrink-box');
      var enters = 0;
      var exits = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ElView(
              key: key,
              style: const ElStyle(
                width: 100,
                height: 100,
                backgroundColor: Color(0xFF808080),
                transition: <ElTransition>[ElTransition.all()],
                onHover: ElStyle(width: 120, height: 80, backgroundColor: Color(0xFF0000FF)),
              ),
              event: .new(onPointerEnter: (_) => enters++, onPointerExit: (_) => exits++),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(-10, -10));
      await tester.pump();
      await mouse.moveTo(const Offset(50, 90));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final box = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(box.size.height, 80);
      expect(enters, 1);
      expect(exits, 0);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(enters, 1);
      expect(exits, 0);

      await mouse.moveTo(const Offset(51, 90));
      await tester.pump();
      expect(exits, 1, reason: '鼠标重新移动后才按新几何退出 hover');
    });
  });

  testWidgets('cancelAllPending clears an active side-button sequence', (_) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    host.leafDispatcher.event = ElEvent(
      onForwardTapDown: (event) => phases.add(event.phase),
      onForwardTapUp: (event) => phases.add(event.phase),
      onForwardTap: (event) => phases.add(event.phase),
    );
    const down = PointerDownEvent(
      pointer: 1,
      position: Offset(20, 20),
      buttons: kForwardMouseButton,
      kind: PointerDeviceKind.mouse,
    );

    host.dispatch(down);
    expect(host.leafDispatcher.hasActivePointerSequence, isTrue);
    host.leafDispatcher.cancelAllPending(down);
    expect(host.leafDispatcher.hasActivePointerSequence, isFalse);
    host.dispatch(
      const PointerUpEvent(
        pointer: 1,
        position: Offset(20, 20),
        buttons: kForwardMouseButton,
        kind: PointerDeviceKind.mouse,
      ),
    );

    expect(phases, <ElEventPhase>[ElEventPhase.forwardTapDown]);
  });

  group('EventDispatcher lifecycle', () {
    testWidgets('registers itself in Expando on creation', (_) async {
      final host = DispatcherTestHost.chain();
      expect(EventDispatcher.of(host.nodes.single), same(host.leafDispatcher));
      host.dispose();
    });

    testWidgets('dispose deregisters from Expando and clears event', (_) async {
      final host = DispatcherTestHost.chain();
      final node = host.nodes.single;
      final dispatcher = host.leafDispatcher..event = .new(onTap: (_) {});
      host.dispose();
      expect(EventDispatcher.of(node), isNull);
      expect(dispatcher.event, isNull);
    });

    testWidgets('detach during active press notifies active false', (_) async {
      final host = DispatcherTestHost.chain();
      final states = <bool>[];
      final dispatcher = host.leafDispatcher
        ..onTapChanged = states.add
        ..event = .new(onTapDown: (_) {});
      host.dispatch(const PointerDownEvent(pointer: 1, position: Offset.zero, buttons: kPrimaryButton));

      dispatcher.detach();

      expect(dispatcher.isTapPressed, isFalse);
      expect(states, <bool>[true, false]);
      expect(EventDispatcher.of(host.nodes.single), isNull);
      host.dispose();
    });

    testWidgets('setting event keeps reference; null clears it', (_) async {
      final host = DispatcherTestHost.chain();
      final dispatcher = host.leafDispatcher;
      final event = ElEvent(onTap: (_) {});
      dispatcher.event = event;
      expect(dispatcher.event, same(event));
      dispatcher.event = null;
      expect(dispatcher.event, isNull);
      host.dispose();
    });
  });

  group('Lazy lifecycle', () {
    testWidgets('updating event keeps the same dispatcher instance', (tester) async {
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) {}),
        ),
      );
      var box = tester.renderObject<RenderBox>(find.byType(ElView));
      final first = EventDispatcher.of(box);
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onPointerDown: (_) {}),
        ),
      );
      box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box), same(first));
    });

    testWidgets('removing tap handler stops tap firing', (tester) async {
      var taps = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) => taps++),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(taps, 1);

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onPointerDown: (_) {}),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('removing drag handlers stops drag firing', (tester) async {
      var starts = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onDragStart: (_) => starts++, onDragUpdate: (_) {}, onDragEnd: (_) {}),
        ),
      );
      await tester.drag(find.byType(ElView), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(starts, 1);

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) {}),
        ),
      );
      await tester.drag(find.byType(ElView), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(starts, 1);
    });

    testWidgets('updating event cancels pending deferred tap', (tester) async {
      var oldTaps = 0;
      var newTaps = 0;

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(config: const ElEventConfig(deferTap: true), onTap: (_) => oldTaps++, onDoubleTap: (_) {}),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(oldTaps, 0);

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) => newTaps++),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(oldTaps, 0);
      expect(newTaps, 0, reason: '旧 event 排队的 deferred tap 不能在 rebuild 后打到新 event。');
    });

    testWidgets('rebuilding equivalent event keeps deferred tap pending', (tester) async {
      var taps = 0;
      void tap(ElEventDetails event) => taps++;
      void doubleTap(ElEventDetails event) {}

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(config: const ElEventConfig(deferTap: true), onTap: tap, onDoubleTap: doubleTap),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(taps, 0);

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(config: const ElEventConfig(deferTap: true), onTap: tap, onDoubleTap: doubleTap),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(taps, 1);
    });

    testWidgets('shape-equal event replacement keeps consecutive tap window', (tester) async {
      var doubleTaps = 0;
      void oldTap(ElEventDetails event) {}
      void newTap(ElEventDetails event) {}

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(onTap: oldTap, onDoubleTap: (_) => doubleTaps++),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump(const Duration(milliseconds: 40));

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(onTap: newTap, onDoubleTap: (_) => doubleTaps++),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();

      // shape 相等的替换（典型：rebuild 传新内联闭包）是热替换：连击窗口
      // 完整保留，第二击构成双击——修复旧实现 rebuild 杀双击窗口的缺陷。
      expect(doubleTaps, 1);
    });

    testWidgets('structural event replacement resets consecutive tap window', (tester) async {
      var doubleTaps = 0;

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(onTap: (_) {}, onDoubleTap: (_) => doubleTaps++),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump(const Duration(milliseconds: 40));

      // onTapDown 从无到有 → shape 变化 → 结构替换丢弃离散 pending（连击窗口）。
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(onTapDown: (_) {}, onTap: (_) {}, onDoubleTap: (_) => doubleTaps++),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();

      expect(doubleTaps, 0);
    });

    testWidgets('drag-only event replacement keeps consecutive tap window', (tester) async {
      var doubleTaps = 0;

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(onTap: (_) {}, onDoubleTap: (_) => doubleTaps++),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump(const Duration(milliseconds: 40));

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(onTap: (_) {}, onDoubleTap: (_) => doubleTaps++, onDragStart: (_) {}),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();

      expect(doubleTaps, 1, reason: '仅挂载 Drag 不应破坏与它无关的连击状态');
    });

    testWidgets('drag-only event replacement keeps deferred tap', (tester) async {
      final phases = <String>[];
      const config = ElEventConfig(deferTap: true, doubleTapInterval: Duration(milliseconds: 20));

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(config: config, onTap: (_) => phases.add('old'), onDoubleTap: (_) {}),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(phases, isEmpty);

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(config: config, onTap: (_) => phases.add('new'), onDoubleTap: (_) {}, onDragDown: (_) {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 21));

      expect(phases, <String>['new'], reason: '仅挂载 Drag 不应清理已排队的延迟 Tap');
    });

    testWidgets('drag-only event replacement keeps active longPress timer', (tester) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      var longPresses = 0;
      const config = ElEventConfig(longPressDelay: Duration(milliseconds: 20));
      final dispatcher = host.leafDispatcher..event = ElEvent(config: config, onLongPress: (_) => longPresses++);

      host.dispatch(
        const PointerDownEvent(
          pointer: 1,
          kind: PointerDeviceKind.touch,
          position: Offset.zero,
          timeStamp: Duration.zero,
        ),
      );
      dispatcher.event = ElEvent(config: config, onLongPress: (_) => longPresses++, onDragStart: (_) {});
      await tester.pump(const Duration(milliseconds: 21));

      expect(longPresses, 1, reason: '挂载 Drag 不应取消已开始的长按计时');
      host.dispatch(
        const PointerUpEvent(
          pointer: 1,
          kind: PointerDeviceKind.touch,
          position: Offset.zero,
          timeStamp: Duration(milliseconds: 30),
        ),
      );
    });

    testWidgets('event replacement after accepted long press does not turn release into tap', (tester) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final phases = <String>[];
      final dispatcher = host.leafDispatcher
        ..event = ElEvent(
          config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
          onLongPress: (event) {
            phases.add('old:${event.phase.name}');
          },
          onTap: (event) => phases.add('old:${event.phase.name}'),
        );

      const down = PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero);
      host.dispatch(down);
      await tester.pump(const Duration(milliseconds: 40));

      dispatcher.event = ElEvent(onTap: (event) => phases.add('new:${event.phase.name}'));
      host.dispatch(const PointerUpEvent(pointer: 1, position: Offset.zero, timeStamp: Duration(milliseconds: 50)));

      expect(phases, <String>['old:longPress']);
    });

    testWidgets('长按后挂载的拖拽从下一次 PointerDown 开始识别', (tester) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final phases = <ElEventPhase>[];
      final dispatcher = host.leafDispatcher;
      dispatcher.event = ElEvent(
        config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
        onLongPress: (event) {
          phases.add(event.phase);
          dispatcher.event = ElEvent(
            config: const ElEventConfig(dragStartDistance: 4),
            onDragStart: (event) => phases.add(event.phase),
            onDragUpdate: (event) => phases.add(event.phase),
            onDragEnd: (event) => phases.add(event.phase),
            onDragCancel: (event) => phases.add(event.phase),
          );
        },
      );

      host.dispatch(
        const PointerDownEvent(
          pointer: 1,
          kind: PointerDeviceKind.touch,
          position: Offset.zero,
          timeStamp: Duration.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 21));

      expect(phases, <ElEventPhase>[ElEventPhase.longPress]);
      expect(dispatcher.event?.onDragStart, isNotNull, reason: '长按成立后才挂载 Drag 回调');

      host.dispatch(
        const PointerMoveEvent(
          pointer: 1,
          kind: PointerDeviceKind.touch,
          position: Offset(0, 12),
          delta: Offset(0, 12),
          timeStamp: Duration(milliseconds: 30),
        ),
      );
      host.dispatch(
        const PointerMoveEvent(
          pointer: 1,
          kind: PointerDeviceKind.touch,
          position: Offset(0, 24),
          delta: Offset(0, 12),
          timeStamp: Duration(milliseconds: 40),
        ),
      );
      host.dispatch(
        const PointerUpEvent(
          pointer: 1,
          kind: PointerDeviceKind.touch,
          position: Offset(0, 24),
          timeStamp: Duration(milliseconds: 50),
        ),
      );

      expect(phases, <ElEventPhase>[ElEventPhase.longPress]);

      final next = TestPointer(2);
      host.dispatch(next.down(Offset.zero));
      host.dispatch(next.move(Offset(0, 20)));
      host.dispatch(next.up());
      expect(phases, <ElEventPhase>[ElEventPhase.longPress, ElEventPhase.dragStart, ElEventPhase.dragEnd]);
    });

    testWidgets('removing event cancels pending deferred tap', (tester) async {
      var taps = 0;

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(config: const ElEventConfig(deferTap: true), onTap: (_) => taps++, onDoubleTap: (_) {}),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(taps, 0);

      await pumpEventView(tester, ElView(style: eventTestDefaultStyle));
      await tester.pump(const Duration(milliseconds: 350));

      expect(taps, 0);
    });

    testWidgets('replacing event cancels active scale before rewiring callbacks', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final dispatcher = host.leafDispatcher;
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        onScaleStart: (event) => phases.add(event.phase),
        onScaleUpdate: (_) {},
        onScaleEnd: (event) => phases.add(event.phase),
        onScaleCancel: (event) => phases.add(event.phase),
        onRotationUpdate: (_) {},
      );
      DispatcherScaleGesture.start(
        dispatcher,
        BoxHitTestEntry(host.nodes.last, Offset.zero),
        focalPoint: const Offset(8, 12),
      );
      dispatcher.event = null;

      expect(phases, <ElEventPhase>[ElEventPhase.scaleStart, ElEventPhase.scaleCancel]);
    });

    testWidgets('removing event during scaleStart preserves scaleCancel reentrant replacement', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final dispatcher = host.leafDispatcher;
      final replacement = ElEvent(onTap: (_) {});
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        onScaleStart: (event) => phases.add(event.phase),
        onScaleCancel: (_) {
          phases.add(ElEventPhase.scaleCancel);
          dispatcher.event = replacement;
        },
      );
      DispatcherScaleGesture.start(
        dispatcher,
        BoxHitTestEntry(host.nodes.last, Offset.zero),
        focalPoint: const Offset(8, 12),
      );

      dispatcher.event = null;

      expect(phases, <ElEventPhase>[ElEventPhase.scaleStart, ElEventPhase.scaleCancel]);
      expect(dispatcher.event, same(replacement));
    });

    testWidgets('removing event during scaleCancel preserves replacement gesture state', (tester) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final dispatcher = host.leafDispatcher;
      var longPresses = 0;
      dispatcher.event = ElEvent(
        config: const ElEventConfig(),
        onScaleStart: (_) {},
        onScaleCancel: (_) {
          dispatcher.event = ElEvent(
            config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
            onLongPress: (_) => longPresses++,
          );
        },
      );
      DispatcherScaleGesture.start(
        dispatcher,
        BoxHitTestEntry(host.nodes.last, Offset.zero),
        focalPoint: const Offset(8, 12),
      );

      dispatcher.event = null;

      host.dispatch(const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero));
      await tester.pump(const Duration(milliseconds: 40));

      expect(longPresses, 1);
    });

    testWidgets('replacing active scale with non scale event clears scale sequence', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final dispatcher = host.leafDispatcher;
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        onScaleStart: (event) => phases.add(event.phase),
        onScaleUpdate: (event) => phases.add(event.phase),
        onScaleEnd: (event) => phases.add(event.phase),
        onScaleCancel: (event) => phases.add(event.phase),
      );
      final scale = DispatcherScaleGesture.start(
        dispatcher,
        BoxHitTestEntry(host.nodes.last, Offset.zero),
        focalPoint: const Offset(8, 12),
      );

      dispatcher.event = .new(onTap: (_) {});
      scale.moveTo(const Offset(12, 16));
      scale.end();

      expect(phases, <ElEventPhase>[ElEventPhase.scaleStart, ElEventPhase.scaleUpdate, ElEventPhase.scaleCancel]);
    });

    testWidgets('replacing active scale with non scale event preserves scaleCancel reentrant replacement', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final dispatcher = host.leafDispatcher;
      final replacement = ElEvent(onTap: (_) {});
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        onScaleStart: (event) => phases.add(event.phase),
        onScaleCancel: (event) {
          phases.add(event.phase);
          dispatcher.event = replacement;
        },
      );
      DispatcherScaleGesture.start(
        dispatcher,
        BoxHitTestEntry(host.nodes.last, Offset.zero),
        focalPoint: const Offset(8, 12),
      );

      dispatcher.event = .new(onTap: (_) {});

      expect(phases, <ElEventPhase>[ElEventPhase.scaleStart, ElEventPhase.scaleCancel]);
      expect(dispatcher.event, same(replacement));
    });

    testWidgets('replacing active drag with non drag event dispatches dragCancel', (tester) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final dispatcher = host.leafDispatcher;
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 3),
        onDragStart: (event) => phases.add(event.phase),
        onDragCancel: (event) => phases.add(event.phase),
      );

      const down = PointerDownEvent(pointer: 1, position: Offset.zero, buttons: kPrimaryButton);
      host.dispatch(down);
      expect(dispatcher.hasActivePointerSequence, isTrue);
      const move = PointerMoveEvent(pointer: 1, position: Offset(0, 4), delta: Offset(0, 4), buttons: kPrimaryButton);
      host.dispatch(move);
      expect(dispatcher.isTapPressed, isFalse);
      expect(dispatcher.hasActivePointerSequence, isTrue);

      dispatcher.event = .new(onTap: (_) {});

      expect(phases, <ElEventPhase>[ElEventPhase.dragStart, ElEventPhase.dragCancel]);
      // 惰性实例化契约：旧配置只有 drag shape → down 时不创建 tap 机；结构
      // 替换取消 drag 机后没有任何状态机继续跟踪该指针，宿主协调视角下序列
      // 即刻结束（对齐官方"mid-press 新增 recognizer 不追溯当前按压"语义）。
      // 后续 up 作为孤立终态照常安全处理。
      expect(dispatcher.hasActivePointerSequence, isFalse);
      host.dispatch(const PointerUpEvent(pointer: 1, position: Offset(0, 4), buttons: kPrimaryButton));
      expect(dispatcher.hasActivePointerSequence, isFalse);
    });

    testWidgets('replacing active pointerPanZoom with non panZoom event dispatches end', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final dispatcher = host.leafDispatcher;
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        onPointerPanZoomStart: (event) => phases.add(event.phase),
        onPointerPanZoomEnd: (event) => phases.add(event.phase),
      );

      const start = PointerPanZoomStartEvent(pointer: 4, position: Offset(5, 6));
      host.dispatch(start);
      expect(dispatcher.hasActivePointerSequence, isTrue);

      dispatcher.event = .new(onTap: (_) {});

      expect(phases, <ElEventPhase>[ElEventPhase.pointerPanZoomStart, ElEventPhase.pointerPanZoomEnd]);
      expect(dispatcher.hasActivePointerSequence, isFalse);
    });

    testWidgets('replacing active pointerPanZoom preserves end reentrant replacement', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final dispatcher = host.leafDispatcher;
      final replacement = ElEvent(onTap: (_) {});
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        onPointerPanZoomStart: (event) => phases.add(event.phase),
        onPointerPanZoomEnd: (event) {
          phases.add(event.phase);
          dispatcher.event = replacement;
        },
      );

      const start = PointerPanZoomStartEvent(pointer: 4, position: Offset(5, 6));
      host.dispatch(start);
      dispatcher.event = .new(onTap: (_) {});

      expect(phases, <ElEventPhase>[ElEventPhase.pointerPanZoomStart, ElEventPhase.pointerPanZoomEnd]);
      expect(dispatcher.event, same(replacement));
    });

    testWidgets('disposing dispatcher cancels active scale', (_) async {
      final host = DispatcherTestHost.chain();
      final dispatcher = host.leafDispatcher;
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        onScaleStart: (event) => phases.add(event.phase),
        onScaleCancel: (event) => phases.add(event.phase),
      );
      DispatcherScaleGesture.start(
        dispatcher,
        BoxHitTestEntry(host.nodes.last, Offset.zero),
        focalPoint: const Offset(8, 12),
      );
      host.dispose();

      expect(phases, <ElEventPhase>[ElEventPhase.scaleStart, ElEventPhase.scaleCancel]);
    });

    testWidgets('scale end handler replacing event does not emit scale cancel', (_) async {
      final host = DispatcherTestHost.chain();
      final dispatcher = host.leafDispatcher;
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        onScaleStart: (event) => phases.add(event.phase),
        onScaleEnd: (event) {
          phases.add(event.phase);
          dispatcher.event = null;
        },
        onScaleCancel: (event) => phases.add(event.phase),
      );
      final scale = DispatcherScaleGesture.start(
        dispatcher,
        BoxHitTestEntry(host.nodes.last, Offset.zero),
        focalPoint: const Offset(8, 12),
      );
      scale.end();
      host.dispose();

      expect(phases, <ElEventPhase>[ElEventPhase.scaleStart, ElEventPhase.scaleEnd]);
    });

    testWidgets('event removal does not overwrite event set by terminal callback', (tester) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final dispatcher = host.leafDispatcher;
      final replacement = ElEvent(onTap: (_) {});
      final phases = <ElEventPhase>[];
      dispatcher.event = .new(
        config: const ElEventConfig(dragStartDistance: 0),
        onDragStart: (event) => phases.add(event.phase),
        onDragCancel: (_) {
          phases.add(ElEventPhase.dragCancel);
          dispatcher.event = replacement;
        },
      );
      host.dispatch(const PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero));
      host.dispatch(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(0, 20),
          delta: Offset(0, 20),
          timeStamp: Duration(milliseconds: 16),
        ),
      );

      dispatcher.event = null;

      expect(phases, <ElEventPhase>[ElEventPhase.dragStart, ElEventPhase.dragCancel]);
      expect(dispatcher.event, same(replacement));
    });
  });

  group('ElView interaction-state wiring', () {
    testWidgets('onTap style alone participates in hit testing', (tester) async {
      await pumpEventView(
        tester,
        const ElView(
          style: ElStyle(
            width: 100,
            height: 100,
            backgroundColor: Color(0xFFFF0000),
            onTap: ElStyle(backgroundColor: Color(0xFF0000FF)),
          ),
        ),
      );
      final box = tester.renderObject<ElRenderView>(find.byType(ElView));
      expect(box.committedResolvedStyle.box.backgroundColor, const Color(0xFFFF0000));

      final gesture = await tester.startGesture(const Offset(20, 20));
      await tester.pump();
      expect(box.committedResolvedStyle.box.backgroundColor, const Color(0xFF0000FF));
      await gesture.up();
      await tester.pump();
      expect(box.committedResolvedStyle.box.backgroundColor, Color(0xFF0000FF));
      await tester.pump(Duration(milliseconds: 100));
      expect(box.committedResolvedStyle.box.backgroundColor, const Color(0xFFFF0000));
      // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
      await tester.pump(Duration(milliseconds: 100));
    });

    testWidgets('selecting another tab clears the previous tab hover state', (tester) async {
      const idleColor = Color(0x00000000);
      const hoverColor = Color(0xFFFFFFFF);
      const selectedColor = Color(0xFFD6D6D6);
      const selectedStyle = ElStyle(width: 80, height: 32, backgroundColor: selectedColor);
      const idleStyle = ElStyle(
        width: 80,
        height: 32,
        backgroundColor: idleColor,
        onHover: ElStyle(backgroundColor: hoverColor),
      );
      const tabKeys = <ValueKey<String>>[
        ValueKey<String>('tab-0'),
        ValueKey<String>('tab-1'),
        ValueKey<String>('tab-2'),
      ];

      var selected = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (var index = 0; index < tabKeys.length; index++)
                      ElView(
                        key: tabKeys[index],
                        style: selected == index ? selectedStyle : idleStyle,
                        event: .new(onTap: (_) => setState(() => selected = index)),
                        child: 'Tab $index',
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      Color? tabBg(int index) =>
          tester.renderObject<ElRenderView>(find.byKey(tabKeys[index])).committedResolvedStyle.box.backgroundColor;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(-10, -10));
      await tester.pump();

      final tab1Center = tester.getCenter(find.byKey(tabKeys[1]));
      await mouse.moveTo(tab1Center);
      await tester.pump();
      expect(tabBg(1), hoverColor);
      await mouse.down(tab1Center);
      await mouse.up();
      await tester.pump();
      expect(tabBg(1), selectedColor);

      final tab2Center = tester.getCenter(find.byKey(tabKeys[2]));
      await mouse.moveTo(tab2Center);
      await tester.pump();
      await mouse.down(tab2Center);
      await mouse.up();
      await tester.pump();
      expect(selected, 2);
      expect(tabBg(1), idleColor, reason: '旧 tab 回到 idle 后不能复用残留 hover');
    });

    testWidgets('disabled focus target cannot request focus from a pointer', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var focusCount = 0;

      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,

          focusNode: node,
          event: .new(disabled: true, onFocus: (_) => focusCount++),
        ),
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.pump();

      expect(node.hasPrimaryFocus, isFalse);
      expect(focusCount, 0);
    });
  });

  group('Recognizers on demand', () {
    setUp(BenchmarkProbe.reset);

    Widget column(List<Widget> children) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );

    testWidgets('纯悬停节点不创建分发器，命中与悬停不变', (tester) async {
      final hoverColor = Color(0xFF0000FF);
      await tester.pumpWidget(
        column([
          for (var index = 0; index < 100; index++)
            ElView(
              key: ValueKey(index),
              style: ElStyle(width: 100, height: 4, onHover: ElStyle(backgroundColor: hoverColor)),
            ),
        ]),
      );

      expect(BenchmarkProbe.eventDispatcherInstantiateCount, 0);
      expect(BenchmarkProbe.transformRecognizerInstantiateCount, 0);
      final box = tester.renderObject<ElRenderView>(find.byKey(ValueKey(0)));
      expect(EventDispatcher.of(box), isNull);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset(-10, -10));
      await tester.pump();
      await mouse.moveTo(Offset(50, 2));
      await tester.pump();
      expect(box.committedResolvedStyle.box.backgroundColor, hoverColor, reason: '无背景的悬停节点仍须参与命中');
      expect(tester.hitTestOnBinding(Offset(50, 2)).path.any((entry) => identical(entry.target, box)), isTrue);
    });

    testWidgets('点击节点不创建变换识别器，按下和重建也不补建', (tester) async {
      var taps = 0;
      Widget build() => column([
        for (var index = 0; index < 100; index++)
          ElView(
            key: ValueKey(index),
            style: ElStyle(width: 100, height: 4),
            event: ElEvent(onTap: (_) => taps++),
          ),
      ]);

      await tester.pumpWidget(build());
      expect(BenchmarkProbe.eventDispatcherInstantiateCount, 100);
      expect(BenchmarkProbe.transformRecognizerInstantiateCount, 0);

      await tester.tapAt(Offset(50, 2));
      await tester.pump();
      await tester.pumpWidget(build());
      expect(taps, 1);
      expect(BenchmarkProbe.eventDispatcherInstantiateCount, 100);
      expect(BenchmarkProbe.transformRecognizerInstantiateCount, 0);
      // 正常抬手可能保留视觉反馈，推进到反馈结束再退出用例。
      await tester.pump(Duration(milliseconds: 200));
    });

    testWidgets('拖拽识别器只为参与输入的宿主按需创建', (tester) async {
      final phases = <String>[];
      await pumpEventView(
        tester,
        ElView(
          key: ValueKey('outer'),
          style: ElStyle(width: 200, height: 200),
          event: ElEvent(onTap: (_) => phases.add('outer.tap')),
          child: ElView(
            style: eventTestDefaultStyle,
            event: ElEvent(onDragStart: (_) => phases.add('inner.dragStart')),
          ),
        ),
      );
      expect(BenchmarkProbe.transformRecognizerInstantiateCount, 0);

      final gesture = await tester.startGesture(Offset(50, 50));
      expect(BenchmarkProbe.transformRecognizerInstantiateCount, 1);
      await gesture.moveBy(Offset(0, 40));
      await gesture.up();
      expect(phases, ['inner.dragStart']);
      await tester.pump(Duration(milliseconds: 200));
    });
  });
}
