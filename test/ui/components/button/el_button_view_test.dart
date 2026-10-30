import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show DragPointerLock, ViewState, ViewStateRenderAccess;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  setUp(() {
    EventDispatcher.debugResetEagerGestureOwners();
    DragPointerLock.debugReset();
  });

  tearDown(DragPointerLock.debugReset);

  Widget shell(Widget child) => MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 400, maxHeight: 400), child: child),
    ),
  );

  group('semantics', () {
    testWidgets('exposes merged button node with enabled state and tap action', (tester) async {
      const hostKey = ValueKey<String>('btn');
      var presses = 0;

      await tester.pumpWidget(shell(ElButtonView(key: hostKey, onPressed: () => presses++, child: 'Save')));

      final semantics = tester.ensureSemantics();
      try {
        final node = tester.getSemantics(find.byKey(hostKey));
        expect(
          node,
          matchesSemantics(
            label: 'Save',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            isFocusable: true,
          ),
        );
        node.owner!.performAction(node.id, SemanticsAction.tap);
        expect(presses, 1);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('assistive tap runs the same composed activation as pointer/keyboard', (tester) async {
      const hostKey = ValueKey<String>('btn-a11y-composed');
      var presses = 0;
      var eventTaps = 0;

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () => presses++,
            event: ElEvent(onTap: (_) => eventTaps++),
            child: 'Save',
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      try {
        final node = tester.getSemantics(find.byKey(hostKey));
        node.owner!.performAction(node.id, SemanticsAction.tap);
        // 读屏激活与指针/键盘同路径：onPressed 与调用方 event.onTap 都触发。
        expect(presses, 1);
        expect(eventTaps, 1);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('assistive caller can prevent the default onPressed action', (tester) async {
      const hostKey = ValueKey<String>('btn-a11y-prevent-default');
      var presses = 0;
      var eventTaps = 0;
      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () => presses++,
            event: ElEvent(
              onTap: (event) {
                eventTaps++;
                event.preventDefault();
              },
            ),
            child: 'Save',
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      try {
        final node = tester.getSemantics(find.byKey(hostKey));
        node.owner!.performAction(node.id, SemanticsAction.tap);
        expect(eventTaps, 1);
        expect(presses, 0);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('event.onTap alone still exposes a semantic tap action', (tester) async {
      const hostKey = ValueKey<String>('btn-a11y-event-only');
      var eventTaps = 0;

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            event: ElEvent(onTap: (_) => eventTaps++),
            child: 'Go',
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      try {
        // onPressed 为 null 但指针可点 → 读屏也必须可激活，不许指针/读屏能力不对等。
        final node = tester.getSemantics(find.byKey(hostKey));
        expect(
          node,
          matchesSemantics(
            label: 'Go',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            isFocusable: true,
          ),
        );
        node.owner!.performAction(node.id, SemanticsAction.tap);
        expect(eventTaps, 1);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('semanticLabel overrides child text; disabled reports not enabled', (tester) async {
      const hostKey = ValueKey<String>('btn-disabled');

      await tester.pumpWidget(
        shell(ElButtonView(key: hostKey, disabled: true, semanticLabel: 'Spoken', child: 'painted')),
      );

      final semantics = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(find.byKey(hostKey)),
          matchesSemantics(label: 'Spoken', isButton: true, hasEnabledState: true, isEnabled: false),
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('onPressed null keeps button enabled and focusable (not disabled)', (tester) async {
      const hostKey = ValueKey<String>('btn-null-press');

      await tester.pumpWidget(shell(ElButtonView(key: hostKey, onPressed: null, child: 'Idle')));

      final view = tester.widget<ElButtonView>(find.byKey(hostKey));
      expect(view.event!.disabled, isFalse);
      // 不传 focusNode：ElView 按键盘事件自动建焦点节点，语义层断言 isFocusable。
      expect(view.event!.hasKeyboardCallback, isTrue);

      final semantics = tester.ensureSemantics();
      try {
        // onPressed==null 只表示按下无动作；按钮仍是 enabled 的 button。
        expect(
          tester.getSemantics(find.byKey(hostKey)),
          matchesSemantics(label: 'Idle', isButton: true, hasEnabledState: true, isEnabled: true, isFocusable: true),
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('icon and text children merge into a single node', (tester) async {
      const hostKey = ValueKey<String>('btn-merge');

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () {},
            // 多叶子用 Flutter Column 并列；Iterable 会走富文本路径。
            style: ElStyle(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElView(child: '＋'),
                ElView(child: 'Add item'),
              ],
            ),
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      try {
        // mergeDescendants：两个子节点 label 由 pipeline 合并进按钮节点，
        // 子内容不产生独立语义节点。
        final node = tester.getSemantics(find.byKey(hostKey));
        expect(
          node,
          matchesSemantics(
            label: '＋\nAdd item',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            isFocusable: true,
          ),
        );
      } finally {
        semantics.dispose();
      }
    });
  });

  group('interaction', () {
    test('buildEvent 不得给普通按钮凭空注入任何 Drag 回调', () {
      final event = ElButtonView.buildEvent(() {}, false, null)!;

      expect(event.onDragStart, isNull);
      expect(event.onDragUpdate, isNull);
      expect(event.onDragEnd, isNull);
      expect(event.onDragCancel, isNull);
      expect(event.onVerticalDragStart, isNull);
      expect(event.onVerticalDragUpdate, isNull);
      expect(event.onVerticalDragEnd, isNull);
      expect(event.onVerticalDragCancel, isNull);
      expect(event.onHorizontalDragStart, isNull);
      expect(event.onHorizontalDragUpdate, isNull);
      expect(event.onHorizontalDragEnd, isNull);
      expect(event.onHorizontalDragCancel, isNull);
    });

    test('buildEvent 原样保留调用方显式声明的完整 Drag 回调', () {
      void onStart(ElEventDetails _) {}
      void onUpdate(ElEventDetails _) {}
      void onEnd(ElEventDetails _) {}
      void onCancel(ElEventDetails _) {}

      final event = ElButtonView.buildEvent(
        () {},
        false,
        ElEvent(onDragStart: onStart, onDragUpdate: onUpdate, onDragEnd: onEnd, onDragCancel: onCancel),
      )!;

      expect(event.onDragStart, same(onStart));
      expect(event.onDragUpdate, same(onUpdate));
      expect(event.onDragEnd, same(onEnd));
      expect(event.onDragCancel, same(onCancel));
    });

    testWidgets('tap fires onPressed', (tester) async {
      const hostKey = ValueKey<String>('btn-tap');
      var presses = 0;

      await tester.pumpWidget(shell(ElButtonView(key: hostKey, onPressed: () => presses++, child: 'Tap')));

      await tester.tap(find.byKey(hostKey));
      await tester.pump();
      expect(presses, 1);
    });

    testWidgets('普通按钮 mouse 在盒内大幅多帧移动仍保持按压事件与样式并点击', (tester) async {
      const hostKey = ValueKey<String>('btn-mouse-move-inside');
      var presses = 0;
      var rawMoves = 0;
      final tapPhases = <ElEventPhase>[];
      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () => presses++,
            event: ElEvent(
              onPointerMove: (_) => rawMoves++,
              onTapDown: (event) => tapPhases.add(event.phase),
              onTapUp: (event) => tapPhases.add(event.phase),
              onTap: (event) => tapPhases.add(event.phase),
              onTapCancel: (event) => tapPhases.add(event.phase),
            ),
            style: const ElStyle(
              width: 300,
              height: 120,
              bgColor: Color(0xff111111),
              onHover: ElStyle(bgColor: Color(0xff222222)),
              onTap: ElStyle(bgColor: Color(0xff333333)),
            ),
            child: 'Move inside',
          ),
        ),
      );

      final render = tester.renderObject<ElRenderView>(find.byKey(hostKey));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(150, 60));
      addTearDown(mouse.removePointer);
      await tester.pump();

      await mouse.down(const Offset(150, 60));
      await tester.pump();
      expect(render.internalStateHas(ViewState.tap), isTrue);
      expect(render.committedResolvedStyle.box.bgColor, const Color(0xff333333));

      for (final position in const <Offset>[Offset(30, 30), Offset(270, 30), Offset(270, 90), Offset(30, 90)]) {
        await mouse.moveTo(position);
        await tester.pump();
        expect(render.internalStateHas(ViewState.tap), isTrue);
        expect(render.committedResolvedStyle.box.bgColor, const Color(0xff333333));
        expect(DragPointerLock.isActive, isFalse, reason: '普通按钮没有 Drag，不得因移动取得全局指针锁。');
      }

      await mouse.up();
      await tester.pump();

      expect(rawMoves, 4);
      expect(tapPhases, <ElEventPhase>[ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
      expect(presses, 1);
      expect(render.internalStateHas(ViewState.tap), isFalse);
      expect(render.internalStateHas(ViewState.hover), isTrue);
      expect(render.committedResolvedStyle.box.bgColor, const Color(0xff222222));
    });

    testWidgets('普通按钮 mouse 移出再回来会完整恢复 Tap、Hover、样式与点击事件链', (tester) async {
      const hostKey = ValueKey<String>('btn-mouse-exit-reenter');
      const outside = Offset(300, 50);
      const inside = Offset(50, 50);
      var presses = 0;
      final tapPhases = <ElEventPhase>[];
      final hoverPhases = <ElEventPhase>[];
      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () => presses++,
            event: ElEvent(
              onPointerEnter: (event) => hoverPhases.add(event.phase),
              onPointerExit: (event) => hoverPhases.add(event.phase),
              onTapDown: (event) => tapPhases.add(event.phase),
              onTapUp: (event) => tapPhases.add(event.phase),
              onTap: (event) => tapPhases.add(event.phase),
              onTapCancel: (event) => tapPhases.add(event.phase),
            ),
            style: const ElStyle(
              width: 100,
              height: 100,
              bgColor: Color(0xff111111),
              onHover: ElStyle(bgColor: Color(0xff222222)),
              onTap: ElStyle(bgColor: Color(0xff333333)),
            ),
            child: 'Exit and re-enter',
          ),
        ),
      );

      final render = tester.renderObject<ElRenderView>(find.byKey(hostKey));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(350, 350));
      addTearDown(mouse.removePointer);

      await mouse.moveTo(inside);
      await tester.pump();
      expect(render.internalStateHas(ViewState.hover), isTrue);
      expect(render.committedResolvedStyle.box.bgColor, const Color(0xff222222));

      await mouse.down(inside);
      await tester.pump();
      expect(render.internalStateHas(ViewState.tap), isTrue);
      expect(render.committedResolvedStyle.box.bgColor, const Color(0xff333333));

      await mouse.moveTo(outside);
      await tester.pump();
      expect(render.internalStateHas(ViewState.tap), isFalse);
      expect(render.internalStateHas(ViewState.hover), isFalse);
      expect(render.committedResolvedStyle.box.bgColor, const Color(0xff111111));

      await mouse.moveTo(inside);
      await tester.pump();
      expect(DragPointerLock.isActive, isFalse, reason: '普通按钮移出再进入期间不应建立 Drag 指针锁。');
      expect(render.internalStateHas(ViewState.tap), isTrue);
      expect(render.internalStateHas(ViewState.hover), isTrue);
      expect(render.committedResolvedStyle.box.bgColor, const Color(0xff333333));

      await mouse.up();
      await tester.pump();

      expect(tapPhases, <ElEventPhase>[
        ElEventPhase.tapDown,
        ElEventPhase.tapCancel,
        ElEventPhase.tapDown,
        ElEventPhase.tapUp,
        ElEventPhase.tap,
      ]);
      expect(hoverPhases, <ElEventPhase>[
        ElEventPhase.pointerEnter,
        ElEventPhase.pointerExit,
        ElEventPhase.pointerEnter,
      ]);
      expect(presses, 1);
      expect(render.internalStateHas(ViewState.tap), isFalse);
      expect(render.internalStateHas(ViewState.hover), isTrue);
      expect(render.committedResolvedStyle.box.bgColor, const Color(0xff222222));
    });

    testWidgets('caller tap runs before the default onPressed action', (tester) async {
      const hostKey = ValueKey<String>('btn-default-order');
      final trace = <String>[];
      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () => trace.add('default'),
            event: ElEvent(onTap: (_) => trace.add('caller')),
            child: 'Order',
          ),
        ),
      );

      await tester.tap(find.byKey(hostKey));
      await tester.pump();
      expect(trace, <String>['caller', 'default']);
    });

    testWidgets('caller tap preventDefault blocks onPressed', (tester) async {
      const hostKey = ValueKey<String>('btn-prevent-default');
      var presses = 0;
      var eventTaps = 0;
      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () => presses++,
            event: ElEvent(
              onTap: (event) {
                eventTaps++;
                event.preventDefault();
              },
            ),
            child: 'Prevent',
          ),
        ),
      );

      await tester.tap(find.byKey(hostKey));
      await tester.pump();
      expect(eventTaps, 1);
      expect(presses, 0);
    });

    testWidgets('Enter activates on keydown and repeats; Space activates on keyup', (tester) async {
      const hostKey = ValueKey<String>('btn-key');
      var presses = 0;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () => presses++,
            focusNode: node,
            child: 'Go',
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);

      // Enter：keydown 即触发。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      expect(presses, 1);
      // 按住 repeat 连续触发。
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      expect(presses, 2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(presses, 2);

      // Space：keydown 不触发，keyup 触发。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      expect(presses, 2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(presses, 3);
    });

    testWidgets('pressController 跨 rebuild 保留 Space 按压并在 keyup 释放', (tester) async {
      const hostKey = ValueKey<String>('btn-key-press-controller');
      var presses = 0;
      final node = FocusNode();
      final controller = ElButtonViewPressController();
      addTearDown(node.dispose);
      addTearDown(controller.dispose);

      Widget build(String label) => shell(
        ElButtonView(
          key: hostKey,
          onPressed: () => presses++,
          focusNode: node,
          pressController: controller,
          child: label,
        ),
      );

      await tester.pumpWidget(build('before'));
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      expect(controller.pressed, isTrue);
      expect(presses, 0);

      await tester.pumpWidget(build('after'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(controller.pressed, isFalse);
      expect(presses, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      expect(controller.pressed, isFalse);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(presses, 1);
    });

    testWidgets('disabled button swallows taps', (tester) async {
      const hostKey = ValueKey<String>('btn-swallow');
      var presses = 0;

      await tester.pumpWidget(
        shell(ElButtonView(key: hostKey, onPressed: () => presses++, disabled: true, child: 'Nope')),
      );

      await tester.tap(find.byKey(hostKey), warnIfMissed: false);
      await tester.pump();
      expect(presses, 0);
    });

    testWidgets('explicit focus node stays attached but cannot request focus while disabled', (tester) async {
      const hostKey = ValueKey<String>('btn-disabled-explicit-focus');
      final node = FocusNode(debugLabel: 'disabled explicit button');

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () {},
            focusNode: node,
            child: 'Enabled',
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () {},
            focusNode: node,
            disabled: true,
            child: 'Disabled',
          ),
        ),
      );
      expect(node.context, isNotNull);
      expect(node.canRequestFocus, isFalse);
      expect(node.hasFocus, isFalse);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);

      await tester.pumpWidget(const SizedBox());
      node.dispose();
    });

    testWidgets('disabled keeps onPressed while blocking activation', (tester) async {
      const hostKey = ValueKey<String>('btn-explicit-disabled');
      var presses = 0;

      await tester.pumpWidget(
        shell(ElButtonView(key: hostKey, onPressed: () => presses++, disabled: true, child: 'Wait')),
      );

      final view = tester.widget<ElButtonView>(find.byKey(hostKey));
      expect(view.event!.disabled, isTrue);
      expect(view.focusNode, isNull);

      await tester.tap(find.byKey(hostKey), warnIfMissed: false);
      await tester.pump();
      expect(presses, 0);

      final semantics = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(find.byKey(hostKey)),
          matchesSemantics(label: 'Wait', isButton: true, hasEnabledState: true, isEnabled: false),
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('caller event augments activation and can override builtin keys', (tester) async {
      const hostKey = ValueKey<String>('btn-event');
      var presses = 0;
      var longPresses = 0;
      var customKeys = 0;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () => presses++,
            focusNode: node,
            event: ElEvent(
              onLongPress: (event) {
                longPresses++;
                event.eagerGesture(cancelSelfTap: true);
              },
              // 覆盖内建 Enter keydown 激活。
              onKeyDown: (_) => customKeys++,
            ),
            child: 'Rich',
          ),
        ),
      );

      // 未覆盖的内建 onTap 仍生效。
      await tester.tap(find.byKey(hostKey));
      await tester.pump();
      expect(presses, 1);

      // 叠加的 onLongPress 生效。
      await tester.longPress(find.byKey(hostKey));
      await tester.pump();
      expect(longPresses, 1);

      // 覆盖的 onKeyDown：Enter 不再走内建激活，走调用方回调。
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      expect(customKeys, 1);
      expect(presses, 1); // longPress 不触发 onTap；Enter 已被覆盖不激活。
      // 按住 Enter 的 keyRepeat 经 dispatcher 回退也走调用方 onKeyDown，
      // 不得经内建激活（半吊子覆盖回归防护）。
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      expect(customKeys, 2);
      expect(presses, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);

      // 键盘激活按组让位：覆盖了 onKeyDown，内建 Space keyup 激活同样退出。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(presses, 1);
      expect(customKeys, 3); // space keydown 也进调用方回调。
    });

    testWidgets('space keyup only activates when armed by keydown on this button', (tester) async {
      const firstKey = ValueKey<String>('btn-sticky-a');
      const secondKey = ValueKey<String>('btn-sticky-b');
      var firstPresses = 0;
      var secondPresses = 0;
      final firstNode = FocusNode();
      final secondNode = FocusNode();
      addTearDown(firstNode.dispose);
      addTearDown(secondNode.dispose);

      await tester.pumpWidget(
        shell(
          Column(
            children: [
              ElButtonView(
                key: firstKey,
                onPressed: () => firstPresses++,
                focusNode: firstNode,
                child: 'A',
              ),
              ElButtonView(
                key: secondKey,
                onPressed: () => secondPresses++,
                focusNode: secondNode,
                child: 'B',
              ),
            ],
          ),
        ),
      );

      // 粘滞空格（web 口径）：keydown 落在 A，按住期间焦点移到 B，
      // keyup 落在 B——两个按钮都不得激活。
      firstNode.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      secondNode.requestFocus();
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(firstPresses, 0);
      expect(secondPresses, 0);

      // 正常按压仍激活。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(secondPresses, 1);
    });

    testWidgets('Escape while space is held cancels the pending activation', (tester) async {
      const hostKey = ValueKey<String>('btn-space-esc');
      var presses = 0;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () => presses++,
            focusNode: node,
            child: 'Go',
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(presses, 0);

      // 取消只作用于本次按压，下一次按压恢复正常。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(presses, 1);
    });

    testWidgets('space keydown is consumed by the focused button (no page scroll)', (tester) async {
      const hostKey = ValueKey<String>('btn-space-consume');
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () {},
            focusNode: node,
            child: 'Go',
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();

      // handled=true → 空格不会漏给祖先滚动容器当翻页键。
      expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.space), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    });
  });

  group('focus', () {
    testWidgets('enabled button is tab-focusable; disabled is not', (tester) async {
      const enabledKey = ValueKey<String>('btn-focusable');
      const disabledKey = ValueKey<String>('btn-unfocusable');
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        shell(
          Column(
            children: [
              ElButtonView(
                key: enabledKey,
                onPressed: () {},
                focusNode: node,
                child: 'A',
              ),
              ElButtonView(key: disabledKey, disabled: true, child: 'B'),
            ],
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);

      // 禁用按钮没有 focus 配置 → 不进焦点树（web 语义：disabled 不可聚焦）。
      final enabledView = tester.widget<ElButtonView>(find.byKey(enabledKey));
      final disabledView = tester.widget<ElButtonView>(find.byKey(disabledKey));
      expect(enabledView.focusNode, isNotNull);
      expect(disabledView.focusNode, isNull);
      expect(disabledView.event!.disabled, isTrue);
    });
  });

  group('style', () {
    // ElButtonView 无默认**外观**，样式透传给 ElView——外观由上层组件库
    // （element_plus ElButton 等）负责。唯一注入的是行为性字段 userSelect: none
    // （web 口径：按钮文字不参与文本选区），调用方声明同名字段可覆盖。
    testWidgets('caller style passes through; only userSelect injected', (tester) async {
      const hostKey = ValueKey<String>('btn-style');

      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () {},
            style: ElStyle(bgColor: Color(0xff112233)),
            child: 'S',
          ),
        ),
      );

      final view = tester.widget<ElButtonView>(find.byKey(hostKey));
      expect(view.style!.bgColor, Color(0xff112233));
      // 行为性默认：按钮文字不可选中。
      expect(view.style!.userSelect, isNotNull);
      // 其余未声明字段不被注入外观默认值。
      expect(view.style!.cursor, isNull);
      expect(view.style!.padding, isNull);
      expect(view.style!.onFocusVisible, isNull);
    });

    testWidgets('style keeps its appearance when userSelect is merged', (tester) async {
      const hostKey = ValueKey<String>('btn-style-builder');

      // element_plus ElButton 传的就是 builder 形态；userSelect 注入若直接对 builder
      // 做 merge，未求值形态字段全空会把整套外观合丢（回归防护）。
      await tester.pumpWidget(
        shell(
          ElButtonView(
            key: hostKey,
            onPressed: () {},
            style: ElStyle(bgColor: Color(0xff112233)),
            child: 'S',
          ),
        ),
      );

      final render = tester.renderObject<ElRenderView>(find.byKey(hostKey));
      expect(render.committedResolvedStyle.box.bgColor, Color(0xff112233));
    });
  });
}
