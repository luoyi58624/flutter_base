import '../../../ui/support/overlay.dart';
import '../../../ui/support/portal.dart';

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pageKey = ValueKey('page');
const _pageEndKey = ValueKey('page-end');
const _firstKey = ValueKey('first');

Widget _app(ElSelectionController pageController, {SelectionControls? controls}) {
  return MaterialApp(
    home: ElTestOverlay(
      child: ElTestPortal(
        child: SelectionView(
          controller: pageController,
          controls: controls,
          child: const ElView(
            style: ElStyle(width: 500, height: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElView(key: _pageKey, child: 'page alpha bravo'),
                ElView(style: ElStyle(height: 260)),
                ElView(key: _pageEndKey, child: 'page delta echo'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

SelectionParticipant _participant(WidgetTester tester, Key key) =>
    selectionParticipantOf(tester.renderObject(find.byKey(key)))!;

RenderSelectionView _rootOf(WidgetTester tester, Key key) =>
    _participant(tester, key).selectionAppearance! as RenderSelectionView;

ElPortalController _insert(
  WidgetTester tester,
  BuildContext source, {
  required Key key,
  required String text,
  AlignmentGeometry align = Alignment.topLeft,
  Offset offset = Offset.zero,
  ElPointerEvents? pointerEvents,
  ElEvent? event,
  Duration exitDuration = Duration.zero,
}) {
  return ElTestPortal.of(source).show(
    align: align,
    offset: offset,
    exitDuration: exitDuration,
    builder: (_) => SelectionView(
      controls: const DesktopSelectionControls(longPressDelay: Duration.zero),
      child: ElView(
        style: ElStyle(width: 220, height: 100, pointerEvents: pointerEvents),
        child: ElView(key: key, event: event, child: text),
      ),
    ),
  );
}

Future<void> _mouseTap(WidgetTester tester, Offset position) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.down(position);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.removePointer();
}

Future<void> _ctrlA(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets('非模态 entry 不抢焦点，程序化焦点切换精确路由 Ctrl+A/C/Esc', (tester) async {
    Map<Object?, Object?>? clipboardData;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardData = (call.arguments as Map<Object?, Object?>?) == null
            ? null
            : Map<Object?, Object?>.of(call.arguments as Map<Object?, Object?>);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final pageFocus = FocusNode(debugLabel: 'page-selection-focus');
    final overlayFocus = FocusNode(debugLabel: 'overlay-selection-focus');
    final pageController = ElSelectionController();
    addTearDown(pageFocus.dispose);
    addTearDown(overlayFocus.dispose);
    addTearDown(pageController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ElTestOverlay(
          child: ElTestPortal(
            child: SelectionView(
              controller: pageController,
              child: ElView(key: _pageKey, focusNode: pageFocus, child: 'page keyboard content'),
            ),
          ),
        ),
      ),
    );
    pageFocus.requestFocus();
    await tester.pump();
    await _ctrlA(tester);
    expect(pageController.text, 'page keyboard content');

    final entry = ElTestPortal.of(tester.element(find.byKey(_pageKey))).show(
      // 非模态展示层：按 ElOverlayFocus 的约定显式关掉捕获，entry 出现不得抢走页面焦点。
      captureFocus: false,
      builder: (_) => SelectionView(
        controls: const DesktopSelectionControls(longPressDelay: Duration.zero),
        child: ElView(
          style: const ElStyle(width: 220, height: 100),
          child: ElView(key: _firstKey, focusNode: overlayFocus, child: 'overlay keyboard content'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final overlayRoot = _rootOf(tester, _firstKey);
    expect(pageFocus.hasPrimaryFocus, isTrue);

    overlayFocus.requestFocus();
    await tester.pump();

    await _ctrlA(tester);
    expect(overlayRoot.selectionInfo, 'overlay keyboard content');
    expect(pageController.text, 'page keyboard content', reason: '底层保留 range 但不响应上层快捷键');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(clipboardData?['text'], 'overlay keyboard content');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(overlayRoot.selectionInfo, isNull);
    expect(pageController.text, 'page keyboard content');

    pageFocus.requestFocus();
    await tester.pump();

    entry.close();
  });

  testWidgets('页面拖选一次大 move 穿过既有 Overlay 后直接松手仍延续同一会话', (tester) async {
    final pageController = ElSelectionController();
    addTearDown(pageController.dispose);
    await tester.pumpWidget(_app(pageController));
    final entry = _insert(
      tester,
      tester.element(find.byKey(_pageKey)),
      key: _firstKey,
      text: 'foreign overlay',
      offset: const Offset(0, 80),
    );
    addTearDown(entry.close);
    await tester.pump();
    await tester.pump();
    final pageStart = _participant(tester, _pageKey);
    final pageRoot = _rootOf(tester, _pageKey);
    final pageEnd = _participant(tester, _pageEndKey);
    final overlayRect = tester.getRect(find.byKey(_firstKey));
    final startRect = tester.getRect(find.byKey(_pageKey));
    final endRect = tester.getRect(find.byKey(_pageEndKey));
    final start = Offset(overlayRect.center.dx, startRect.center.dy);
    final beforeOverlay = Offset(overlayRect.center.dx, overlayRect.top - 4);
    final end = Offset(overlayRect.center.dx, endRect.center.dy);
    expect(start.dy, lessThan(overlayRect.top));
    expect(end.dy, greaterThan(overlayRect.bottom));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(start);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(beforeOverlay);
    await tester.pump(const Duration(milliseconds: 16));
    final anchorStart = pageStart.currentSelectionRange!.start;
    expect(pageRoot.isSelectionDragging, isTrue);

    await gesture.moveTo(end);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.removePointer();

    expect(pageStart.currentSelectionRange!.start, anchorStart, reason: '稀疏 move 穿过 overlay 不得重建原 anchor');
    expect(pageEnd.currentSelectionRange, isNotNull, reason: '一次 move 落在 overlay 另一侧时应继续更新原 page 会话');
    expect(_rootOf(tester, _firstKey).selectionInfo, isNull, reason: '跨越期间 foreign overlay 内容始终不得被选中');
  });

  testWidgets(
    'Overlay 内拖选成立后 self/ancestor/descendant 的 tapUp 与 tap 全部失权',
    (tester) async {
      var ancestorTapUps = 0;
      var ancestorTaps = 0;
      var selfTapUps = 0;
      var selfTaps = 0;
      var descendantTapUps = 0;
      var descendantTaps = 0;
      final pageController = ElSelectionController();
      addTearDown(pageController.dispose);
      await tester.pumpWidget(_app(pageController));
      final source = tester.element(find.byKey(_pageKey));
      final entry = ElTestPortal.of(source).show(
        align: .topLeft,
        builder: (_) => SelectionView(
          controls: const DesktopSelectionControls(longPressDelay: Duration.zero),
          child: ElView(
            style: const ElStyle(width: 220, height: 100),
            event: ElEvent(onTapUp: (_) => ancestorTapUps++, onTap: (_) => ancestorTaps++),
            child: ElView(
              event: ElEvent(onTapUp: (_) => selfTapUps++, onTap: (_) => selfTaps++),
              child: ElView(
                key: _firstKey,
                event: ElEvent(onTapUp: (_) => descendantTapUps++, onTap: (_) => descendantTaps++),
                child: 'overlay selection tap',
              ),
            ),
          ),
        ),
      );
      addTearDown(entry.close);
      await tester.pump();
      await tester.pump();
      final overlayRoot = _rootOf(tester, _firstKey);
      final overlayText = _participant(tester, _firstKey);
      final rect = tester.getRect(find.byKey(_firstKey));

      await _mouseTap(tester, rect.center);
      expect(
        [ancestorTapUps, ancestorTaps, selfTapUps, selfTaps, descendantTapUps, descendantTaps],
        everyElement(1),
        reason: '普通轻点必须仍完整触发目标与上下游的 tapUp/tap',
      );
      ancestorTapUps = ancestorTaps = selfTapUps = selfTaps = descendantTapUps = descendantTaps = 0;
      await tester.pump(const Duration(milliseconds: 400));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.down(rect.centerLeft + const Offset(2, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(rect.centerRight - const Offset(2, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(overlayRoot.isSelectionDragging, isTrue, reason: '先确认本序列已越过选区拖选阈值');
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.removePointer();

      final range = overlayText.currentSelectionRange;
      expect(range, isNotNull);
      expect(range!.isCollapsed, isFalse, reason: '先证明 pointer 已越过阈值并形成实际拖选');
      expect(
        [ancestorTapUps, ancestorTaps, selfTapUps, selfTaps, descendantTapUps, descendantTaps],
        everyElement(0),
        reason: '选区拖选已成立时，pointer up 不得再触发任何一层的 tapUp/tap',
      );
    },
  );

  testWidgets('触摸长按会话中关闭 entry 同步清 body route、magnifier 与 range', (tester) async {
    const controls = DesktopSelectionControls(longPressDelay: Duration.zero);
    final pageController = ElSelectionController();
    addTearDown(pageController.dispose);
    await tester.pumpWidget(_app(pageController, controls: controls));
    final entry = _insert(
      tester,
      tester.element(find.byKey(_pageKey)),
      key: _firstKey,
      text: 'touch overlay',
      exitDuration: const Duration(milliseconds: 100),
    );
    await tester.pump();
    await tester.pump();
    final root = _rootOf(tester, _firstKey);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    await gesture.down(tester.getTopLeft(find.byKey(_firstKey)) + Offset(6, 8));
    await tester.pump();
    expect(root.isSelectionDragging, isTrue);
    expect(root.dragInfoListenable.value, isNotNull);
    expect((root.isHandleDragInProgress || root.isSelectionDragging), isTrue);

    entry.close();
    expect(root.isSelectionDragging, isFalse);
    expect((root.isHandleDragInProgress || root.isSelectionDragging), isFalse);
    await tester.pump(const Duration(milliseconds: 16));
    expect(root.dragInfoListenable.value, isNull);
    expect(pageController.text, isNull);
    await gesture.moveBy(const Offset(80, 0));
    await gesture.up();
    await gesture.removePointer();
    await tester.pump(const Duration(milliseconds: 100));
    expect(root.attached, isFalse);
    expect(root.selectionInfo, isNull);
    expect(pageController.text, isNull, reason: '关闭后的残余 move/up 不得转交页面');
  });
}
