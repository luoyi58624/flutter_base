import 'package:flutter_base/src/flutter/views/view/event/shape.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  setUp(EventDispatcher.debugReset);

  group('ElEvent flags', () {
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

  group('声明位图', () {
    test('每个阶段与轴向拖拽组各占一位', () {
      final slots = <(ElEventPhase, Axis?)>[
        for (final phase in ElEventPhase.values) (phase, null),
        for (final axis in Axis.values)
          for (final phase in ElEventPhase.dragPhases) (phase, axis),
      ];
      final seen = <EventShape>{};
      for (final (phase, axis) in slots) {
        final shape = EventShape.compile((p, [a]) => p == phase && a == axis ? true : null);
        expect(shape.isNotEmpty, isTrue);
        expect(seen.add(shape), isTrue, reason: '$phase / $axis 与其他回调共用了位');
        for (final (otherPhase, otherAxis) in slots) {
          expect(shape.has(otherPhase, otherAxis), otherPhase == phase && otherAxis == axis);
        }
      }
      expect(seen, hasLength(55));
      expect(EventShape.compile((_, [_]) => null), EventShape.none);
    });

    test('ElEvent 的相等性只看声明了哪些回调，不看闭包', () {
      expect(ElEvent(onTap: (_) {}), ElEvent(onTap: (_) {}));
      expect(ElEvent(onTap: (_) {}).hashCode, ElEvent(onTap: (_) {}).hashCode);
      expect(ElEvent(onTap: (_) {}), isNot(ElEvent(onTapDown: (_) {})));
      expect(ElEvent(onDragStart: (_) {}), isNot(ElEvent(onHorizontalDragStart: (_) {})));
      expect(ElEvent(onHorizontalDragStart: (_) {}), isNot(ElEvent(onVerticalDragStart: (_) {})));
      expect(ElEvent(onTap: (_) {}), isNot(ElEvent(disabled: true, onTap: (_) {})));
    });

    test('点击候选按按键分组，长按与连击从位图派生', () {
      final empty = ElEvent().shape;
      expect(empty.isNotEmpty, isFalse);
      expect(empty.gesture, isFalse);
      expect(empty.maxTaps, 1);
      expect(empty.wantsTap(kPrimaryButton), isFalse);

      final tap = ElEvent(onTap: (_) {}).shape;
      expect(tap.wantsTap(kPrimaryButton), isTrue);
      expect(tap.wantsTap(kSecondaryButton), isFalse);
      expect(tap.gesture, isTrue);
      expect(tap.longPressOnly, isFalse);
      expect(ElEvent(onTapCancel: (_) {}).shape.wantsTap(kPrimaryButton), isTrue);

      final longPress = ElEvent(onLongPress: (_) {}).shape;
      expect(longPress.wantsTap(kPrimaryButton), isTrue);
      expect(longPress.longPressOnly, isTrue);
      expect(ElEvent(onLongPress: (_) {}, onTapCancel: (_) {}).shape.longPressOnly, isFalse);

      final secondary = ElEvent(onSecondaryTapDown: (_) {}).shape;
      expect(secondary.wantsTap(kSecondaryButton), isTrue);
      expect(secondary.wantsTap(kPrimaryButton), isFalse);
      expect(secondary.gesture, isTrue);
      expect(ElEvent(onTertiaryTap: (_) {}).shape.wantsTap(kTertiaryButton), isTrue);
      expect(ElEvent(onForwardTapUp: (_) {}).shape.wantsTap(kForwardMouseButton), isTrue);
      expect(ElEvent(onBackTap: (_) {}).shape.wantsTap(kBackMouseButton), isTrue);
      expect(tap.wantsTap(kPrimaryButton | kSecondaryButton), isFalse);

      expect(ElEvent(onDoubleTapDown: (_) {}).shape.maxTaps, 2);
      expect(ElEvent(onDoubleTap: (_) {}, onTripleTap: (_) {}).shape.maxTaps, 3);

      // 原始指针、键盘与焦点回调不参加手势竞技场。
      for (final event in [ElEvent(onPointerDown: (_) {}), ElEvent(onKeyDown: (_) {}), ElEvent(onFocus: (_) {})]) {
        expect(event.shape.isNotEmpty, isTrue);
        expect(event.shape.gesture, isFalse);
      }
    });

    test('拖拽按组承接轴向，缩放与换形比较从位图派生', () {
      final down = ElEvent(onDragDown: (_) {}).shape;
      expect(down.has(ElEventPhase.dragDown), isTrue);
      expect(down.drag, isFalse);
      expect(down.gesture, isTrue);

      final pan = ElEvent(onDragUpdate: (_) {}).shape;
      expect(pan.pan, isTrue);
      expect(pan.drag, isTrue);
      expect(pan.acceptsDrag(Axis.horizontal), isTrue);
      expect(pan.acceptsDrag(Axis.vertical), isTrue);

      final horizontal = ElEvent(onHorizontalDragEnd: (_) {}).shape;
      expect(horizontal.pan, isFalse);
      expect(horizontal.drag, isTrue);
      expect(horizontal.gesture, isTrue);
      expect(horizontal.acceptsDrag(Axis.horizontal), isTrue);
      expect(horizontal.acceptsDrag(Axis.vertical), isFalse);
      expect(horizontal.has(ElEventPhase.dragEnd), isFalse);
      expect(horizontal.has(ElEventPhase.dragEnd, Axis.horizontal), isTrue);
      expect(ElEvent(onHorizontalDragEnd: (_) {}).hasDragCallback, isTrue);
      expect(ElEvent(onDragDown: (_) {}).hasDragCallback, isFalse);

      final scale = ElEvent(onRotationUpdate: (_) {}).shape;
      expect(scale.scale, isTrue);
      expect(scale.gesture, isTrue);
      expect(pan.scale, isFalse);

      // 增减拖拽不算点击识别条件变化，增减连击才算。
      final tap = ElEvent(onTap: (_) {}).shape;
      expect(tap.sameDiscrete(ElEvent(onTap: (_) {}, onDragStart: (_) {}).shape), isTrue);
      expect(tap.sameDiscrete(ElEvent(onTap: (_) {}, onVerticalDragStart: (_) {}).shape), isTrue);
      expect(tap.sameDiscrete(ElEvent(onTap: (_) {}, onDoubleTap: (_) {}).shape), isFalse);
      expect(tap.sameDiscrete(ElEvent(onTap: (_) {}, onKeyDown: (_) {}).shape), isFalse);
      expect(scale.sameScale(ElEvent(onRotationUpdate: (_) {}, onTap: (_) {}).shape), isTrue);
      expect(scale.sameScale(tap), isFalse);
    });
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
          longPressDelay: Duration(milliseconds: 20),
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
                  ElView(style: eventTestDefaultStyle, focusNode: first),
                  ElView(style: eventTestDefaultStyle, focusNode: skipped),
                  ElView(style: eventTestDefaultStyle, focusNode: second),
                  ElView(style: eventTestDefaultStyle, focusNode: third),
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
