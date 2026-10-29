import 'package:flutter_base/src/ui/cores/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  group('Tap (primary)', () {
    testWidgets('fires tapDown → tapUp → tap in order', (tester) async {
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onTapDown: (e) => phases.add(e.phase),
            onTapUp: (e) => phases.add(e.phase),
            onTap: (e) => phases.add(e.phase),
          ),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(phases, [ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
    });
  });

  group('DoubleTap', () {
    void sendPrimaryTap(DispatcherTestHost host, int ordinal) {
      final at = Duration(milliseconds: ordinal * 40);
      host.dispatch(PointerDownEvent(position: const Offset(3, 4), timeStamp: at));
      host.dispatch(PointerUpEvent(position: const Offset(3, 4), timeStamp: at));
    }

    test('未声明三击时第 2、4 次 PointerDown 连续触发两次双击', () {
      final doubles = <int>[];
      var ordinal = 0;
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      host.leafDispatcher.event = .new(onDoubleTapDown: (_) => doubles.add(ordinal));

      for (ordinal = 1; ordinal <= 4; ordinal++) {
        sendPrimaryTap(host, ordinal);
      }

      expect(doubles, <int>[2, 4]);
    });

    test('声明三击时第 2 次双击、第 3 次三击，第 5 次才进入下一组双击', () {
      final phases = <String>[];
      var ordinal = 0;
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      host.leafDispatcher.event = .new(
        onDoubleTapDown: (_) => phases.add('double-down:$ordinal'),
        onTripleTapDown: (_) => phases.add('triple-down:$ordinal'),
        onTripleTap: (_) => phases.add('triple-up:$ordinal'),
      );

      for (ordinal = 1; ordinal <= 5; ordinal++) {
        sendPrimaryTap(host, ordinal);
      }

      expect(phases, <String>['double-down:2', 'triple-down:3', 'triple-up:3', 'double-down:5']);
    });

    test('两组双击之间只改变 Drag 参数时保留第 3 次点击建立的连击窗口', () {
      final doubles = <int>[];
      var ordinal = 0;
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      void onDoubleTapDown(ElEventDetails _) => doubles.add(ordinal);
      host.leafDispatcher.event = ElEvent(onDoubleTapDown: onDoubleTapDown);

      for (ordinal = 1; ordinal <= 3; ordinal++) {
        sendPrimaryTap(host, ordinal);
      }
      host.leafDispatcher.event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 8),
        onDoubleTapDown: onDoubleTapDown,
      );
      ordinal = 4;
      sendPrimaryTap(host, ordinal);

      expect(doubles, <int>[2, 4]);
    });

    test('连击识别参数变化仍会清除旧窗口', () {
      var doubles = 0;
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      void onDoubleTapDown(ElEventDetails _) => doubles++;
      host.leafDispatcher.event = ElEvent(onDoubleTapDown: onDoubleTapDown);
      sendPrimaryTap(host, 1);

      host.leafDispatcher.event = ElEvent(
        config: const ElEventConfig(doubleTapInterval: Duration(milliseconds: 500)),
        onDoubleTapDown: onDoubleTapDown,
      );
      sendPrimaryTap(host, 2);

      expect(doubles, 0);
    });

    testWidgets('fires onDoubleTapDown on second pointer down before up', (tester) async {
      final phases = <String>[];
      Object? originalEvent;
      int? tapCount;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onDoubleTapDown: (e) {
              phases.add('down');
              originalEvent = e.originalEvent;
              tapCount = e.tapCount;
            },
            onDoubleTap: (_) => phases.add('up'),
          ),
        ),
      );

      final first = await tester.createGesture(pointer: 41, kind: PointerDeviceKind.mouse);
      await first.down(const Offset(30, 30));
      await first.up();
      await tester.pump(const Duration(milliseconds: 50));

      final second = await tester.createGesture(pointer: 42, kind: PointerDeviceKind.mouse);
      await second.down(const Offset(30, 30));
      expect(phases, <String>['down']);
      expect(originalEvent, isA<PointerDownEvent>());
      expect((originalEvent! as PointerDownEvent).pointer, 42);
      expect(tapCount, 2);

      await second.up();
      await tester.pumpAndSettle();
      expect(phases, <String>['down', 'up']);
    });

    testWidgets('fires onDoubleTap on two rapid taps', (tester) async {
      var doubles = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onDoubleTap: (_) => doubles++),
        ),
      );
      await tester.tapAt(const Offset(30, 30));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(30, 30));
      await tester.pumpAndSettle();
      expect(doubles, 1);
    });

    testWidgets('two slow taps do not register as doubleTap', (tester) async {
      var doubles = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onDoubleTap: (_) => doubles++),
        ),
      );
      await tester.tapAt(const Offset(30, 30));
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(const Offset(30, 30));
      await tester.pumpAndSettle();
      expect(doubles, 0);
    });
  });

  group('TripleTap', () {
    void sendPrimaryTap(DispatcherTestHost host, Duration at) {
      host.dispatch(PointerDownEvent(position: const Offset(3, 4), timeStamp: at));
      host.dispatch(PointerUpEvent(position: const Offset(3, 4), timeStamp: at));
    }

    test('fires onTripleTap on three rapid taps', () {
      var triples = 0;
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      host.leafDispatcher.event = .new(onTripleTap: (_) => triples++);
      sendPrimaryTap(host, Duration.zero);
      sendPrimaryTap(host, const Duration(milliseconds: 50));
      sendPrimaryTap(host, const Duration(milliseconds: 100));
      expect(triples, 1);
    });

    test('fires onTripleTapDown on third pointer down before up', () {
      final phases = <String>[];
      Object? originalEvent;
      int? tapCount;
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      host.leafDispatcher.event = .new(
        onTripleTapDown: (event) {
          phases.add('down');
          originalEvent = event.originalEvent;
          tapCount = event.tapCount;
        },
        onTripleTap: (_) => phases.add('up'),
      );

      sendPrimaryTap(host, Duration.zero);
      sendPrimaryTap(host, const Duration(milliseconds: 50));
      host.dispatch(
        PointerDownEvent(position: const Offset(3, 4), timeStamp: const Duration(milliseconds: 100), pointer: 3),
      );
      expect(phases, <String>['down']);
      expect(originalEvent, isA<PointerDownEvent>());
      expect((originalEvent! as PointerDownEvent).pointer, 3);
      expect(tapCount, 3);

      host.dispatch(
        PointerUpEvent(position: const Offset(3, 4), timeStamp: const Duration(milliseconds: 100), pointer: 3),
      );
      expect(phases, <String>['down', 'up']);
    });

    test('third tap outside interval does not register as tripleTap', () {
      var triples = 0;
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      host.leafDispatcher.event = .new(onTripleTap: (_) => triples++);
      sendPrimaryTap(host, Duration.zero);
      sendPrimaryTap(host, const Duration(milliseconds: 50));
      sendPrimaryTap(host, const Duration(milliseconds: 500));
      expect(triples, 0);
    });
  });

  group('LongPress', () {
    testWidgets('fires onLongPress when held', (tester) async {
      var presses = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onLongPress: (_) => presses++),
        ),
      );
      await tester.longPressAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      expect(presses, 1);
    });

    testWidgets('quick tap does not fire onLongPress', (tester) async {
      var presses = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onLongPress: (_) => presses++),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(presses, 0);
    });

    testWidgets('honors custom longPressDelay and suppresses tap', (tester) async {
      var presses = 0;
      var taps = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
            onLongPress: (_) => presses++,
            onTap: (_) => taps++,
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(40, 40), pointer: 41);
      await tester.pump(const Duration(milliseconds: 30));
      await gesture.up();
      await tester.pump();

      expect(presses, 1);
      expect(taps, 0);
    });

    testWidgets('preventDefault rejects automatic longPress ownership', (tester) async {
      var presses = 0;
      var taps = 0;
      var ancestorUps = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(onPointerUp: (_) => ancestorUps++),
          child: ElView(
            style: eventTestDefaultStyle,
            event: ElEvent(
              config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
              onLongPress: (event) {
                presses++;
                event.preventDefault();
              },
              onTap: (_) => taps++,
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(40, 40), pointer: 42);
      await tester.pump(const Duration(milliseconds: 30));
      await gesture.up();
      await tester.pump();

      expect(presses, 1);
      expect(taps, 1, reason: '拒绝长按默认认领后，本节点 Tap 资格保持');
      expect(ancestorUps, 1, reason: '拒绝长按不得收缩 pointer 事件链');
    });
  });

  group('Secondary tap', () {
    testWidgets('right click triggers down + up + tap phases', (tester) async {
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onSecondaryTapDown: (e) => phases.add(e.phase),
            onSecondaryTapUp: (e) => phases.add(e.phase),
            onSecondaryTap: (e) => phases.add(e.phase),
          ),
        ),
      );
      await clickPointerButtonAt(tester, const Offset(20, 20), kSecondaryButton);
      await tester.pump();
      expect(phases, contains(ElEventPhase.secondaryTapDown));
      expect(phases, contains(ElEventPhase.secondaryTapUp));
      expect(phases, contains(ElEventPhase.secondaryTap));
    });

    testWidgets('right click never enters the primary longPress chain', (tester) async {
      var longPresses = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
            onSecondaryTapDown: (_) {},
            onLongPress: (_) => longPresses++,
          ),
        ),
      );

      final gesture = await tester.createGesture(pointer: 9, kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
      await gesture.down(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.up();
      await tester.pump();

      expect(longPresses, 0);
    });

    testWidgets('moving beyond cancel distance permanently suppresses secondaryTap but not secondaryTapUp', (
      tester,
    ) async {
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onSecondaryTapDown: (e) => phases.add(e.phase),
            onSecondaryTapUp: (e) => phases.add(e.phase),
            onSecondaryTap: (e) => phases.add(e.phase),
          ),
        ),
      );

      final gesture = await tester.createGesture(pointer: 7, kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
      await gesture.down(const Offset(20, 20));
      // 越界移出（> tapCancelDistance 默认 10）再移回原位：excursion 永久取消
      // *Tap，终点距离合格也不得复活（对齐 onTap 的移动取消语义）；*TapUp
      // 不受移动影响照常 fire（对齐 onTapUp / DOM mouseup）。
      await gesture.moveTo(const Offset(40, 20));
      await gesture.moveTo(const Offset(20, 20));
      await gesture.up();
      await tester.pump();

      expect(phases, <ElEventPhase>[ElEventPhase.secondaryTapDown, ElEventPhase.secondaryTapUp]);
    });
  });

  group('Tertiary tap', () {
    testWidgets('middle click triggers down + up + tap phases', (tester) async {
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onTertiaryTapDown: (e) => phases.add(e.phase),
            onTertiaryTapUp: (e) => phases.add(e.phase),
            onTertiaryTap: (e) => phases.add(e.phase),
          ),
        ),
      );
      await clickPointerButtonAt(tester, const Offset(20, 20), kTertiaryButton);
      await tester.pump();
      expect(phases, contains(ElEventPhase.tertiaryTapDown));
      expect(phases, contains(ElEventPhase.tertiaryTapUp));
      expect(phases, contains(ElEventPhase.tertiaryTap));
    });

    testWidgets('middle click never enters the primary longPress chain', (tester) async {
      var longPresses = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
            onTertiaryTapDown: (_) {},
            onLongPress: (_) => longPresses++,
          ),
        ),
      );

      final gesture = await tester.createGesture(pointer: 9, kind: PointerDeviceKind.mouse, buttons: kTertiaryButton);
      await gesture.down(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.up();
      await tester.pump();

      expect(longPresses, 0);
    });
  });

  group('Forward / Back side buttons', () {
    testWidgets('forward button triggers down + up + tap phases', (tester) async {
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onForwardTapDown: (e) => phases.add(e.phase),
            onForwardTapUp: (e) => phases.add(e.phase),
            onForwardTap: (e) => phases.add(e.phase),
          ),
        ),
      );
      await clickPointerButtonAt(tester, const Offset(20, 20), kForwardMouseButton);
      await tester.pump();
      expect(phases, [ElEventPhase.forwardTapDown, ElEventPhase.forwardTapUp, ElEventPhase.forwardTap]);
    });

    testWidgets('back button triggers down + up + tap phases', (tester) async {
      final phases = <ElEventPhase>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onBackTapDown: (e) => phases.add(e.phase),
            onBackTapUp: (e) => phases.add(e.phase),
            onBackTap: (e) => phases.add(e.phase),
          ),
        ),
      );
      await clickPointerButtonAt(tester, const Offset(20, 20), kBackMouseButton);
      await tester.pump();
      expect(phases, [ElEventPhase.backTapDown, ElEventPhase.backTapUp, ElEventPhase.backTap]);
    });

    testWidgets('side buttons never enter the primary longPress chain', (tester) async {
      Future<void> expectNoLongPress(int button, ElEventHandler downHandler) async {
        var longPresses = 0;
        await pumpEventView(
          tester,
          ElView(
            style: eventTestDefaultStyle,
            event: .new(
              config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
              onForwardTapDown: button == kForwardMouseButton ? downHandler : null,
              onBackTapDown: button == kBackMouseButton ? downHandler : null,
              onLongPress: (_) => longPresses++,
            ),
          ),
        );

        final gesture = await tester.createGesture(pointer: 9, kind: PointerDeviceKind.mouse, buttons: button);
        await gesture.down(const Offset(20, 20));
        await tester.pump(const Duration(milliseconds: 40));
        await gesture.up();
        await tester.pump();

        expect(longPresses, 0);
      }

      await expectNoLongPress(kForwardMouseButton, (_) {});
      await expectNoLongPress(kBackMouseButton, (_) {});
    });
  });

  group('Cancel', () {
    testWidgets('moving pointer far away after down fires onTapCancel', (tester) async {
      var cancels = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) {}, onTapCancel: (_) => cancels++),
        ),
      );
      final gesture = await tester.startGesture(const Offset(30, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(300, 300));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cancels, greaterThanOrEqualTo(1));
    });
  });

  group('isTapPressed 显式关闭触摸保留时立即恢复', () {
    testWidgets('initial isTapPressed is false', (tester) async {
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) {}),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(ElView));
      expect(EventDispatcher.of(box)!.isTapPressed, isFalse);
    });

    testWidgets('PointerDown flips isTapPressed true, PointerUp 立即 false', (tester) async {
      // 显式关闭轻触保留后仍支持立即进入、立即退出。
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: ElEventConfig(delayTouchUp: Duration.zero),
            onTap: (_) {},
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(ElView));
      final dispatcher = EventDispatcher.of(box)!;
      final gesture = await tester.startGesture(const Offset(20, 20));
      await tester.pump();
      expect(dispatcher.isTapPressed, isTrue);
      await gesture.up();
      await tester.pump();
      expect(dispatcher.isTapPressed, isFalse, reason: 'delayTouchUp 为零时在 PointerUp 立即 false');
    });

    testWidgets('onTap fires immediately on PointerUp regardless of active release delay', (tester) async {
      var taps = 0;
      Duration? tapTime;
      final sw = Stopwatch();
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onTap: (_) {
              taps++;
              tapTime = sw.elapsed;
            },
          ),
        ),
      );
      sw.start();
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(taps, 1);
      // onTap 在 PointerUp 后立即 fire，不等 100ms active release
      expect(tapTime!, lessThan(const Duration(milliseconds: 50)));
    });

    testWidgets('onTapUp also fires immediately, not delayed by active release', (tester) async {
      var tapUps = 0;
      Duration? upTime;
      final sw = Stopwatch();
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onTapUp: (_) {
              tapUps++;
              upTime = sw.elapsed;
            },
          ),
        ),
      );
      sw.start();
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(tapUps, 1);
      expect(upTime!, lessThan(const Duration(milliseconds: 50)));
    });

    testWidgets('rapid double tap: every press flips isTapPressed true / false', (tester) async {
      // 关闭轻触保留时，每次按下与抬起都立即翻转。
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: ElEventConfig(delayTouchUp: Duration.zero),
            onTap: (_) {},
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(ElView));
      final dispatcher = EventDispatcher.of(box)!;

      // Tap 1
      var gesture = await tester.startGesture(const Offset(20, 20));
      await tester.pump();
      expect(dispatcher.isTapPressed, isTrue);
      await gesture.up();
      await tester.pump();
      expect(dispatcher.isTapPressed, isFalse);

      // Tap 2（紧跟其后，没有 release window）
      gesture = await tester.startGesture(const Offset(20, 20));
      await tester.pump();
      expect(dispatcher.isTapPressed, isTrue, reason: 'click 2 down 必须重新触发 active true');
      await gesture.up();
      await tester.pump();
      expect(dispatcher.isTapPressed, isFalse);
    });
  });

  group('deferTap = false (default behaviour)', () {
    testWidgets('single tap fires onTap immediately on PointerUp', (tester) async {
      Duration? tapTime;
      final sw = Stopwatch();
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) => tapTime = sw.elapsed, onDoubleTap: (_) {}),
        ),
      );
      sw.start();
      await tester.tap(find.byType(ElView));
      await tester.pump();
      // 默认 deferTap=false：即使绑了 onDoubleTap，onTap 也不延迟
      expect(tapTime, isNotNull);
      expect(tapTime!, lessThan(const Duration(milliseconds: 50)));
      // 让双击窗口 timer 跑完，避免 widget tree dispose 时
      // 'Timer is still pending' assertion 失败。
      await tester.pumpAndSettle();
    });

    testWidgets('double tap fires onDoubleTap and onTap (twice)', (tester) async {
      var taps = 0;
      var doubles = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) => taps++, onDoubleTap: (_) => doubles++),
        ),
      );
      await tester.tapAt(const Offset(30, 30));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(30, 30));
      await tester.pumpAndSettle();
      // 双击不影响单击执行：两次 onTap + 一次 onDoubleTap
      expect(taps, 2);
      expect(doubles, 1);
    });
  });

  group('deferTap = true (defer single tap)', () {
    testWidgets('single tap is delayed by doubleTapInterval', (tester) async {
      var tapFired = false;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(config: const ElEventConfig(deferTap: true), onTap: (_) => tapFired = true, onDoubleTap: (_) {}),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      // PointerUp 后立刻不 fire
      expect(tapFired, isFalse);
      // 默认 doubleTapInterval = 300ms，等 350ms 后应该已 fire
      await tester.pump(const Duration(milliseconds: 350));
      expect(tapFired, isTrue);
    });

    testWidgets('double tap suppresses pending onTap', (tester) async {
      var taps = 0;
      var doubles = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(config: const ElEventConfig(deferTap: true), onTap: (_) => taps++, onDoubleTap: (_) => doubles++),
        ),
      );
      await tester.tapAt(const Offset(30, 30));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(30, 30));
      await tester.pumpAndSettle();
      // deferTap=true 双击场景：onTap 全被吞掉，只有一次 onDoubleTap
      expect(taps, 0);
      expect(doubles, 1);
    });

    testWidgets('onTapUp fires immediately even when deferTap=true', (tester) async {
      var tapUps = 0;
      Duration? upTime;
      final sw = Stopwatch();
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(deferTap: true),
            onTap: (_) {},
            onTapUp: (_) {
              tapUps++;
              upTime = sw.elapsed;
            },
            onDoubleTap: (_) {},
          ),
        ),
      );
      sw.start();
      await tester.tap(find.byType(ElView));
      await tester.pump();
      // onTapUp 不受 deferTap 影响，PointerUp 时立即 fire
      expect(tapUps, 1);
      expect(upTime!, lessThan(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    });

    testWidgets('no onDoubleTap declared → deferTap is ignored, onTap fires immediately', (tester) async {
      Duration? tapTime;
      final sw = Stopwatch();
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(config: const ElEventConfig(deferTap: true), onTap: (_) => tapTime = sw.elapsed),
        ),
      );
      sw.start();
      await tester.tap(find.byType(ElView));
      await tester.pump();
      // deferTap=true 但没有 onDoubleTap，没有要等的双击窗口 → 立即 fire
      expect(tapTime!, lessThan(const Duration(milliseconds: 50)));
    });
  });

  group('long press owns the chain and keeps winner terminal phases', () {
    testWidgets('longPress fires; onTap does NOT', (tester) async {
      var taps = 0;
      var presses = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onTap: (_) => taps++,
            onLongPress: (event) {
              presses++;
              event.eagerGesture(cancelSelfTap: true);
            },
          ),
        ),
      );
      await tester.longPressAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      expect(presses, 1);
      expect(taps, 0);
    });

    testWidgets('longPress fires; onTapUp still fires on release', (tester) async {
      var tapUps = 0;
      var presses = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onTapUp: (_) => tapUps++,
            onLongPress: (event) {
              presses++;
              event.eagerGesture(cancelSelfTap: true);
            },
          ),
        ),
      );
      await tester.longPressAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      expect(presses, 1);
      expect(tapUps, 1);
    });

    testWidgets('LONG-2: longPress owns ancestors while preserving winner tapUp and drag terminal', (tester) async {
      var childLongPresses = 0;
      var childCancels = 0;
      var childTapUps = 0;
      var childTaps = 0;
      var childDragStarts = 0;
      var childDragUpdates = 0;
      var childDragEnds = 0;
      var parentLongPresses = 0;
      var parentTapUps = 0;
      var parentTaps = 0;
      var parentDragStarts = 0;

      await pumpEventView(
        tester,
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: .new(
            config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20), dragStartDistance: 3),
            onLongPress: (_) => parentLongPresses++,
            onTapUp: (_) => parentTapUps++,
            onTap: (_) => parentTaps++,
            onDragStart: (_) => parentDragStarts++,
          ),
          child: ElView(
            style: const ElStyle(width: 40, height: 40),
            event: .new(
              config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20), dragStartDistance: 3),
              onLongPress: (event) {
                childLongPresses++;
                event.eagerGesture(cancelSelfTap: true);
              },
              onTapCancel: (_) => childCancels++,
              onTapUp: (_) => childTapUps++,
              onTap: (_) => childTaps++,
              onDragStart: (_) => childDragStarts++,
              onDragUpdate: (_) => childDragUpdates++,
              onDragEnd: (_) => childDragEnds++,
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, 4));
      await gesture.moveBy(const Offset(0, 4));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(childLongPresses, 1);
      expect(childCancels, 1);
      expect(childTapUps, 1);
      expect(childTaps, 0);
      expect(childDragStarts, 1);
      expect(childDragUpdates, 1);
      expect(childDragEnds, 1);
      expect(parentLongPresses, 0, reason: 'long press does not bubble and the child wins this primary chain');
      expect(parentTapUps, 0);
      expect(parentTaps, 0);
      expect(parentDragStarts, 0);
    });

    testWidgets('movement beyond drag threshold before longPressDelay makes drag win', (tester) async {
      var longPresses = 0;
      var dragStarts = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(longPressDelay: Duration(milliseconds: 60), dragStartDistance: 3),
            onLongPress: (_) => longPresses++,
            onDragStart: (event) {
              dragStarts++;
              event.eagerGesture(cancelSelfTap: true);
            },
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 10));
      await gesture.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(dragStarts, 1);
      expect(longPresses, 0);
    });

    testWidgets('longPress also cancels pending deferred onTap', (tester) async {
      var taps = 0;
      var presses = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            config: const ElEventConfig(deferTap: true),
            onTap: (_) => taps++,
            onDoubleTap: (_) {},
            onLongPress: (event) {
              presses++;
              event.eagerGesture(cancelSelfTap: true);
            },
          ),
        ),
      );
      await tester.longPressAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      // long press 触发后 pending 的延迟 tap 也被取消
      expect(presses, 1);
      expect(taps, 0);
    });

    testWidgets('quick tap (no long press) still fires onTap normally', (tester) async {
      var taps = 0;
      var presses = 0;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) => taps++, onLongPress: (_) => presses++),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(taps, 1);
      expect(presses, 0);
    });
  });

  testWidgets('TAP-5A: deferred child Tap bubbles once through its frozen route', (tester) async {
    var outerTaps = 0;
    var innerTaps = 0;
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: .new(onTap: (_) => outerTaps++),
        child: ElView(
          style: const ElStyle(width: 60, height: 60, bgColor: Color(0xFF0000FF)),
          event: .new(config: const ElEventConfig(deferTap: true), onTap: (_) => innerTaps++, onDoubleTap: (_) {}),
        ),
      ),
    );

    await tester.tap(find.byType(ElView).last);
    await tester.pump();
    expect(outerTaps, 0, reason: 'child 延迟 Tap 时，ancestor 不能先提交同一次点击');
    expect(innerTaps, 0);
    await tester.pump(const Duration(milliseconds: 350));
    expect(innerTaps, 1);
    expect(outerTaps, 1, reason: '到期 Tap 沿冻结 route 从 child 向 ancestor 恰好传播一次');
  });

  testWidgets('TAP-5B: deferred child Tap can stop its ancestor route', (tester) async {
    var outerTaps = 0;
    var innerTaps = 0;
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: .new(onTap: (_) => outerTaps++),
        child: ElView(
          style: const ElStyle(width: 60, height: 60, bgColor: Color(0xFF0000FF)),
          event: .new(
            config: const ElEventConfig(deferTap: true),
            onTap: (event) {
              innerTaps++;
              event.stopPropagation();
            },
            onDoubleTap: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ElView).last);
    await tester.pump(const Duration(milliseconds: 350));

    expect(innerTaps, 1);
    expect(outerTaps, 0);
  });

  testWidgets('TAP-6A: child doubleTap clears pending single Tap across the whole route', (tester) async {
    var outerTaps = 0;
    var innerTaps = 0;
    var outerDoubleTaps = 0;
    var innerDoubleTaps = 0;
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: .new(onTap: (_) => outerTaps++, onDoubleTap: (_) => outerDoubleTaps++),
        child: ElView(
          style: const ElStyle(width: 60, height: 60, bgColor: Color(0xFF0000FF)),
          event: .new(
            config: const ElEventConfig(deferTap: true),
            onTap: (_) => innerTaps++,
            onDoubleTap: (_) => innerDoubleTaps++,
          ),
        ),
      ),
    );

    final target = find.byType(ElView).last;
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 350));

    expect(innerTaps, 0);
    expect(outerTaps, 0);
    expect(innerDoubleTaps, 1);
    expect(outerDoubleTaps, 1, reason: 'doubleTap 也沿同一逻辑 route 恰好传播一次');
  });

  testWidgets('TAP-6B: child tripleTap leaves no pending single Tap on ancestors', (tester) async {
    var outerTaps = 0;
    var innerTaps = 0;
    var outerTripleTaps = 0;
    var innerTripleTaps = 0;
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: .new(onTap: (_) => outerTaps++, onTripleTap: (_) => outerTripleTaps++),
        child: ElView(
          style: const ElStyle(width: 60, height: 60, bgColor: Color(0xFF0000FF)),
          event: .new(
            config: const ElEventConfig(deferTap: true),
            onTap: (_) => innerTaps++,
            onDoubleTap: (_) {},
            onTripleTap: (_) => innerTripleTaps++,
          ),
        ),
      ),
    );

    final target = find.byType(ElView).last;
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 350));

    expect(innerTaps, 0);
    expect(outerTaps, 0);
    expect(innerTripleTaps, 1);
    expect(outerTripleTaps, 1);
  });

  testWidgets('TAP-7A: re-entered activation is canceled again when drag takes ownership', (_) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    void record(ElEventDetails event) => phases.add(event.phase);
    host.leafDispatcher.hitBoundsContainsGlobal = (position) => position.dx < 5;
    host.leafDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 20),
      onTapDown: record,
      onTapUp: record,
      onTap: record,
      onTapCancel: record,
      onDragStart: (event) {
        record(event);
        event.eagerGesture(cancelSelfTap: true);
      },
      onDragEnd: record,
    );

    host.dispatch(const PointerDownEvent(pointer: 71, position: Offset.zero));
    host.dispatch(const PointerMoveEvent(pointer: 71, position: Offset(10, 0), delta: Offset(10, 0)));
    host.dispatch(const PointerMoveEvent(pointer: 71, position: Offset(1, 0), delta: Offset(-9, 0)));
    host.dispatch(const PointerMoveEvent(pointer: 71, position: Offset(25, 0), delta: Offset(24, 0)));
    host.dispatch(const PointerUpEvent(pointer: 71, position: Offset(25, 0)));

    expect(phases, <ElEventPhase>[
      ElEventPhase.tapDown,
      ElEventPhase.tapCancel,
      ElEventPhase.tapDown,
      ElEventPhase.dragStart,
      ElEventPhase.tapCancel,
      ElEventPhase.dragEnd,
      ElEventPhase.tapUp,
    ]);
  });

  testWidgets('TAP-7B: drag cancellation resets double and triple tap windows', (tester) async {
    for (final tapsBeforeDrag in <int>[1, 2]) {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final trace = <String>[];
      host.leafDispatcher.event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 3),
        onTap: (event) => trace.add(event.phase.name),
        onDoubleTapDown: (event) => trace.add(event.phase.name),
        onDoubleTap: (event) => trace.add(event.phase.name),
        onTripleTapDown: (event) => trace.add(event.phase.name),
        onTripleTap: (event) => trace.add(event.phase.name),
        onTapCancel: (event) => trace.add(event.phase.name),
        onDragStart: (event) {
          trace.add(event.phase.name);
          event.eagerGesture(cancelSelfTap: true);
        },
        onDragEnd: (event) => trace.add(event.phase.name),
      );

      for (var index = 0; index < tapsBeforeDrag; index++) {
        final millis = index * 40;
        host.tap(
          pointer: 80 + index,
          downTime: Duration(milliseconds: millis),
          upTime: Duration(milliseconds: millis + 10),
        );
      }
      final dragMillis = tapsBeforeDrag * 40;
      host.dispatch(
        PointerDownEvent(
          pointer: 90,
          position: Offset.zero,
          timeStamp: Duration(milliseconds: dragMillis),
        ),
      );
      host.dispatch(
        PointerMoveEvent(
          pointer: 90,
          position: const Offset(4, 0),
          delta: const Offset(4, 0),
          timeStamp: Duration(milliseconds: dragMillis + 10),
        ),
      );
      host.dispatch(
        PointerUpEvent(
          pointer: 90,
          position: const Offset(4, 0),
          timeStamp: Duration(milliseconds: dragMillis + 20),
        ),
      );
      host.tap(
        pointer: 99,
        downTime: Duration(milliseconds: dragMillis + 50),
        upTime: Duration(milliseconds: dragMillis + 60),
      );

      expect(trace.where((phase) => phase == 'tap'), hasLength(tapsBeforeDrag + 1));
      expect(trace.where((phase) => phase == 'tapCancel'), hasLength(1));
      expect(trace.where((phase) => phase == 'dragStart'), hasLength(1));
      expect(trace.where((phase) => phase == 'dragEnd'), hasLength(1));
      if (tapsBeforeDrag == 1) {
        expect(trace.where((phase) => phase == 'doubleTapDown'), hasLength(1));
        expect(trace, isNot(contains('doubleTap')));
      } else {
        expect(trace.where((phase) => phase == 'doubleTap'), hasLength(1));
        expect(trace.where((phase) => phase == 'tripleTapDown'), hasLength(1));
        expect(trace, isNot(contains('tripleTap')));
      }
      await tester.pump(const Duration(milliseconds: 400));
    }
  });
}
