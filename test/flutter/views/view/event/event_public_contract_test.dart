import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  group('ElEvent flags', () {
    test('生成配置保留未声明值，显式 null 恢复默认或设备自适应', () {
      final empty = ElEventConfig();
      expect(empty.copyWith(), empty);
      final configured = empty.copyWith(
        delayTouchUp: Duration(milliseconds: 250),
        tapCancelByDistance: true,
        dragStartDistance: 12,
      );
      expect(configured.delayTouchUp, Duration(milliseconds: 250));
      expect(configured.dragStartDistance, 12);
      expect(configured.copyWith(delayTouchUp: null, tapCancelByDistance: null, dragStartDistance: null), empty);
      expect(configured.merge(empty), configured);
      expect(configured.merge(ElEventConfig(delayTouchUp: Duration.zero)).delayTouchUp, Duration.zero);
    });

    test('生成事件合并保留不同回调并合并嵌套声明', () {
      void tap(ElEventDetails event) {}
      void down(ElEventDetails event) {}
      final base = ElEvent(
        config: ElEventConfig(dragStartDistance: 12),
        dragProxy: ElDragProxy(onDragPreUpdate: tap),
        onTap: tap,
      );
      final merged = base.merge(
        ElEvent(
          config: ElEventConfig(delayTouchUp: Duration.zero),
          dragProxy: ElDragProxy(onDragOverflow: down),
          onPointerDown: down,
        ),
      );
      expect(merged.onTap, same(tap));
      expect(merged.onPointerDown, same(down));
      expect(merged.config?.dragStartDistance, 12);
      expect(merged.config?.delayTouchUp, Duration.zero);
      expect(merged.dragProxy?.onDragPreUpdate, same(tap));
      expect(merged.dragProxy?.onDragOverflow, same(down));
      expect(merged.dragProxy!.copyWith(onDragPreUpdate: null).onDragPreUpdate, isNull);
      final cleared = merged.copyWith(config: null, dragProxy: null, onTap: null);
      expect(cleared.config, isNull);
      expect(cleared.dragProxy, isNull);
      expect(cleared.onTap, isNull);
      expect(cleared.onPointerDown, same(down));
    });

    test('cursor 与 disabled 参与复制、清除与等值，识别结构保持不变', () {
      final event = ElEvent(cursor: SystemMouseCursors.click, disabled: true, onTap: (_) {});
      expect(event.copyWith().cursor, SystemMouseCursors.click);
      expect(event.copyWith().disabled, isTrue);
      expect(event.copyWith(cursor: null).cursor, isNull);
      final changed = event.copyWith(cursor: SystemMouseCursors.text, disabled: false);
      expect(changed.cursor, SystemMouseCursors.text);
      expect(changed.disabled, isFalse);
      expect(changed, isNot(event));
      expect(changed.hasSameGestureShape(event), isTrue);
      final cleared = event.copyWith(cursor: null);
      expect(cleared.cursor, isNull);
      expect(cleared.disabled, isTrue);
      expect(cleared.onTap, same(event.onTap));
    });

    test('命中行为参与复制与等值，但不打断既有 Tap 配置', () {
      void tap(ElEventDetails e) {}
      final event = ElEvent(onTap: tap);
      expect(event.behavior, HitTestBehavior.opaque);
      final changed = event.copyWith(behavior: HitTestBehavior.translucent);
      expect(changed.behavior, HitTestBehavior.translucent);
      expect(changed.onTap, same(tap));
      expect(changed, isNot(event));
      expect(changed, event.copyWith(behavior: HitTestBehavior.translucent));
      expect(changed.hashCode, event.copyWith(behavior: HitTestBehavior.translucent).hashCode);
      expect(changed.hasSameNonDragShape(event), isTrue);
    });

    test('hasAnyCallback is false on empty event, true with any handler', () {
      expect(const ElEvent().hasAnyCallback, isFalse);
      expect(ElEvent(onTap: (_) {}).hasAnyCallback, isTrue);
      expect(ElEvent(onPointerEnter: (_) {}).hasAnyCallback, isTrue);
      expect(ElEvent(onKeyDown: (_) {}).hasAnyCallback, isTrue);
      expect(ElEvent(onFocus: (_) {}).hasAnyCallback, isTrue);
    });

    test('hasTapLikeCallback covers tap/down/up/double/triple/longPress only', () {
      expect(ElEvent(onTap: (_) {}).hasTapLikeCallback, isTrue);
      expect(ElEvent(onTapDown: (_) {}).hasTapLikeCallback, isTrue);
      expect(ElEvent(onTapUp: (_) {}).hasTapLikeCallback, isTrue);
      expect(ElEvent(onDoubleTap: (_) {}).hasTapLikeCallback, isTrue);
      expect(ElEvent(onDoubleTapDown: (_) {}).hasTapLikeCallback, isTrue);
      expect(ElEvent(onTripleTap: (_) {}).hasTapLikeCallback, isTrue);
      expect(ElEvent(onTripleTapDown: (_) {}).hasTapLikeCallback, isTrue);
      expect(ElEvent(onLongPress: (_) {}).hasTapLikeCallback, isTrue);
      expect(ElEvent(onPointerDown: (_) {}).hasTapLikeCallback, isFalse);
      expect(ElEvent(onDragStart: (_) {}).hasTapLikeCallback, isFalse);
      expect(ElEvent(onFocus: (_) {}).hasTapLikeCallback, isFalse);
    });

    test('copyWith/merge/equality include drag tuning fields', () {
      const event = ElEvent(config: ElEventConfig(dragMinFlingDistance: 12));

      expect(event.copyWith(config: const ElEventConfig(dragMinFlingDistance: 24)).config?.dragMinFlingDistance, 24);
      expect(
        event.merge(const ElEvent(config: ElEventConfig(dragMinFlingDistance: 36))).config?.dragMinFlingDistance,
        36,
      );
      expect(event, const ElEvent(config: ElEventConfig(dragMinFlingDistance: 12)));
      expect(event, isNot(const ElEvent(config: ElEventConfig(dragMinFlingDistance: 13))));
      expect(
        ElEvent(config: ElEventConfig(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse})),
        ElEvent(config: ElEventConfig(dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch})),
      );
    });

    test('copyWith null removes nullable handlers', () {
      void tap(ElEventDetails event) {}
      void dragStart(ElEventDetails event) {}
      void pointerSignal(ElEventDetails event) {}
      final event = ElEvent(onTap: tap, onVerticalDragStart: dragStart, onPointerSignal: pointerSignal);

      final kept = event.copyWith();
      expect(kept.onTap, same(tap));
      expect(kept.onVerticalDragStart, same(dragStart));
      expect(kept.onPointerSignal, same(pointerSignal));

      final cleared = event.copyWith(onTap: null, onVerticalDragStart: null, onPointerSignal: null);
      expect(cleared.onTap, isNull);
      expect(cleared.onVerticalDragStart, isNull);
      expect(cleared.onPointerSignal, isNull);
      expect(cleared.config, event.config);
    });

    test('merge preserves nullable fields when other config has nulls', () {
      void tap(ElEventDetails event) {}
      void pointerDown(ElEventDetails event) {}
      final base = ElEvent(onHorizontalDragStart: (_) {}, onTap: tap, onPointerDown: pointerDown);
      final merged = base.merge(
        ElEvent(config: const ElEventConfig(dragStartDistance: 24), onPointerDown: pointerDown),
      );

      expect(merged.onTap, same(tap));
      expect(merged.onHorizontalDragStart, same(base.onHorizontalDragStart));
      expect(merged.onPointerDown, same(pointerDown));
      expect(merged.config?.dragStartDistance, 24);
    });
  });

  testWidgets('只更新 cursor 不打断已按下的鼠标侧键', (tester) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    void record(ElEventDetails e) => phases.add(e.phase);
    host.leafDispatcher.event = ElEvent(
      cursor: SystemMouseCursors.click,
      onSecondaryTapDown: record,
      onSecondaryTapUp: record,
      onSecondaryTap: record,
    );
    host.dispatch(PointerDownEvent(pointer: 61, kind: .mouse, buttons: kSecondaryButton, position: Offset(20, 20)));
    host.leafDispatcher.event = host.leafDispatcher.event!.copyWith(cursor: SystemMouseCursors.text);
    host.dispatch(PointerUpEvent(pointer: 61, kind: .mouse, position: Offset(20, 20)));
    expect(phases, [ElEventPhase.secondaryTapDown, ElEventPhase.secondaryTapUp, ElEventPhase.secondaryTap]);
  });

  group('preventDefault', () {
    testWidgets('preventDefault toggles defaultPrevented for caller to read', (tester) async {
      bool? sawPrevented;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onTap: (e) {
              expect(e.defaultPrevented, isFalse);
              e.preventDefault();
              sawPrevented = e.defaultPrevented;
            },
          ),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(sawPrevented, isTrue);
    });
  });

  testWidgets('PUBLIC-META-1: LongPress preserves pointer-down metadata', (tester) async {
    Object? originalEvent;
    int? buttons;
    int? tapCount;
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: .new(
          config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
          onLongPress: (event) {
            originalEvent = event.originalEvent;
            buttons = event.buttons;
            tapCount = event.tapCount;
          },
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(40, 40), pointer: 42, buttons: kPrimaryButton);
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.up();
    await tester.pump();

    expect(originalEvent, isA<PointerDownEvent>());
    expect((originalEvent! as PointerDownEvent).pointer, 42);
    expect(buttons, kPrimaryButton);
    expect(tapCount, 0);
  });

  testWidgets('PUBLIC-META-2: side taps preserve their raw pointer events', (_) async {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final originalEvents = <ElEventPhase, Object?>{};
    void record(ElEventDetails event) => originalEvents[event.phase] = event.originalEvent;
    host.leafDispatcher.event = ElEvent(
      onSecondaryTapDown: record,
      onSecondaryTapUp: record,
      onSecondaryTap: record,
      onTertiaryTapDown: record,
      onTertiaryTapUp: record,
      onTertiaryTap: record,
    );

    const secondaryDown = PointerDownEvent(
      pointer: 21,
      position: Offset(20, 20),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    const secondaryUp = PointerUpEvent(pointer: 21, position: Offset(20, 20), kind: PointerDeviceKind.mouse);
    const tertiaryDown = PointerDownEvent(
      pointer: 22,
      position: Offset(30, 20),
      kind: PointerDeviceKind.mouse,
      buttons: kTertiaryButton,
    );
    const tertiaryUp = PointerUpEvent(pointer: 22, position: Offset(30, 20), kind: PointerDeviceKind.mouse);
    host.dispatch(secondaryDown);
    host.dispatch(secondaryUp);
    host.dispatch(tertiaryDown);
    host.dispatch(tertiaryUp);

    expect(originalEvents[ElEventPhase.secondaryTapDown], same(secondaryDown));
    expect(originalEvents[ElEventPhase.secondaryTapUp], same(secondaryUp));
    expect(originalEvents[ElEventPhase.secondaryTap], same(secondaryUp));
    expect(originalEvents[ElEventPhase.tertiaryTapDown], same(tertiaryDown));
    expect(originalEvents[ElEventPhase.tertiaryTapUp], same(tertiaryUp));
    expect(originalEvents[ElEventPhase.tertiaryTap], same(tertiaryUp));
  });

  group('ElEventDetails.tapCount', () {
    testWidgets('single onTap reports tapCount 1', (tester) async {
      int? captured;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (event) => captured = event.tapCount),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(captured, 1);
    });

    testWidgets('onDoubleTap reports tapCount 2', (tester) async {
      int? captured;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onDoubleTap: (event) => captured = event.tapCount),
        ),
      );
      await tester.tapAt(const Offset(30, 30));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(30, 30));
      await tester.pumpAndSettle();
      expect(captured, 2);
    });

    testWidgets('onDoubleTap preserves second-down metadata', (tester) async {
      Object? originalEvent;
      int? buttons;
      int? tapCount;
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onDoubleTap: (event) {
              originalEvent = event.originalEvent;
              buttons = event.buttons;
              tapCount = event.tapCount;
            },
          ),
        ),
      );

      await tester.tapAt(const Offset(30, 30), pointer: 31, buttons: kPrimaryButton);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(30, 30), pointer: 32, buttons: kPrimaryButton);
      await tester.pumpAndSettle();

      expect(originalEvent, isA<PointerDownEvent>());
      expect((originalEvent! as PointerDownEvent).pointer, 32);
      expect(buttons, kPrimaryButton);
      expect(tapCount, 2);
    });

    test('onTripleTap reports tapCount 3', () {
      int? captured;
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      host.leafDispatcher.event = ElEvent(onTripleTap: (event) => captured = event.tapCount);

      void sendTap(Duration at) {
        host.dispatch(PointerDownEvent(position: const Offset(3, 4), timeStamp: at));
        host.dispatch(PointerUpEvent(position: const Offset(3, 4), timeStamp: at));
      }

      sendTap(Duration.zero);
      sendTap(const Duration(milliseconds: 50));
      sendTap(const Duration(milliseconds: 100));
      expect(captured, 3);
    });

    testWidgets('TapDown and TapUp always report tapCount 0', (tester) async {
      final downCounts = <int>[];
      final upCounts = <int>[];
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(
            onTapDown: (event) => downCounts.add(event.tapCount),
            onTapUp: (event) => upCounts.add(event.tapCount),
          ),
        ),
      );
      await tester.tap(find.byType(ElView));
      await tester.pump();
      expect(downCounts, <int>[0]);
      expect(upCounts, <int>[0]);
    });
  });

  group('MouseTracker public surface', () {
    testWidgets('onEnter/onExit are null without matching callbacks', (tester) async {
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onTap: (_) {}),
        ),
      );
      final box = tester.renderObject(find.byType(ElView)) as MouseTrackerAnnotation;
      expect(box.onEnter, isNull);
      expect(box.onExit, isNull);
      expect(box.validForMouseTracker, isFalse);
      expect(box.cursor, MouseCursor.defer);
    });

    testWidgets('validForMouseTracker is false without event', (tester) async {
      await pumpEventView(tester, ElView(style: eventTestDefaultStyle));
      final box = tester.renderObject(find.byType(ElView)) as MouseTrackerAnnotation;
      expect(box.validForMouseTracker, isFalse);
    });

    testWidgets('onPointerEnter makes MouseTracker annotation valid', (tester) async {
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onPointerEnter: (_) {}),
        ),
      );
      final box = tester.renderObject(find.byType(ElView)) as MouseTrackerAnnotation;
      expect(box.validForMouseTracker, isTrue);
    });

    testWidgets('onPointerExit makes MouseTracker annotation valid', (tester) async {
      await pumpEventView(
        tester,
        ElView(
          style: eventTestDefaultStyle,
          event: .new(onPointerExit: (_) {}),
        ),
      );
      final box = tester.renderObject(find.byType(ElView)) as MouseTrackerAnnotation;
      expect(box.validForMouseTracker, isTrue);
    });
  });

  test('PUBLIC-SHAPE-1: hitTestSelf follows the current event callback shape', () {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    expect(host.leafDispatcher.hitTestSelf(Offset.zero), isFalse);
    host.leafDispatcher.event = const ElEvent();
    expect(host.leafDispatcher.hitTestSelf(Offset.zero), isFalse);
    host.leafDispatcher.event = ElEvent(onTap: (_) {});
    expect(host.leafDispatcher.hitTestSelf(Offset.zero), isTrue);
  });

  test('PUBLIC-FOCUS-1: notifyFocusChanged exposes focus and blur reasons', () {
    final host = DispatcherTestHost.chain();
    addTearDown(host.dispose);
    final phases = <ElEventPhase>[];
    final reasons = <ElFocusReason?>[];
    host.leafDispatcher.event = ElEvent(
      onFocus: (event) {
        phases.add(event.phase);
        reasons.add(event.focusReason);
      },
      onBlur: (event) {
        phases.add(event.phase);
        reasons.add(event.focusReason);
      },
    );

    host.leafDispatcher.notifyFocusChanged(true, reason: ElFocusReason.keyboard);
    host.leafDispatcher.notifyFocusChanged(false, reason: ElFocusReason.lifecycle);

    expect(phases, <ElEventPhase>[ElEventPhase.focus, ElEventPhase.blur]);
    expect(reasons, <ElFocusReason?>[ElFocusReason.keyboard, ElFocusReason.lifecycle]);
  });

  testWidgets('PUBLIC-FOCUS-2: Tab traversal skips only traversal-disabled targets', (tester) async {
    final first = FocusNode(debugLabel: 'first');
    final skipped = FocusNode(debugLabel: 'skipped', skipTraversal: true);
    final second = FocusNode(debugLabel: 'second');
    final third = FocusNode(debugLabel: 'third');
    addTearDown(first.dispose);
    addTearDown(skipped.dispose);
    addTearDown(second.dispose);
    addTearDown(third.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusTraversalGroup(
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                children: <Widget>[
                  ElView(
                    style: eventTestDefaultStyle,
                    focusNode: first,
                  ),
                  ElView(
                    style: eventTestDefaultStyle,
                    focusNode: skipped,
                  ),
                  ElView(
                    style: eventTestDefaultStyle,
                    focusNode: second,
                  ),
                  ElView(
                    style: eventTestDefaultStyle,
                    focusNode: third,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(second.hasPrimaryFocus, isTrue);
    expect(skipped.hasPrimaryFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(third.hasPrimaryFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(second.hasPrimaryFocus, isTrue);

    skipped.requestFocus();
    await tester.pump();
    expect(skipped.hasPrimaryFocus, isTrue, reason: 'skipTraversal 仅影响遍历，不禁止程序聚焦');
  });
}
