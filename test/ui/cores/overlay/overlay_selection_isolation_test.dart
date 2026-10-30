import '../../support/portal.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart' show selectionParticipantOf;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// overlay 与底层的指针 / 选区隔离（2026-08-03 裁决，封堵"弹窗展示时底层
/// 内容还能选中"事故）：
///
/// 1. 面板命中不透明：落点在面板上不得启动底层选区、不得触发底层点击/hover；
///    面板外照常穿透。
/// 3. 选区上下文隔离：面板默认不启用选择；显式根独立选择。
void main() {
  const pageTextKey = ValueKey('page-text');
  const pageText2Key = ValueKey('page-text-2');
  const panelKey = ValueKey('panel');

  Widget app({required ElSelectionController pageController, ValueChanged<Offset>? onPageTap}) {
    return MaterialApp(
      home: ElTestPortal(
        child: ElSelectionView(
          controller: pageController,
          child: ElView(
            style: const ElStyle(width: 400, height: 300),
            event: onPageTap == null ? null : ElEvent(onTap: (e) => onPageTap(e.globalPosition)),
            // 两行文本隔开 180px：面板（topLeft 300×120）只盖第一行，
            // 第二行在面板下方可自由交互。
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElView(
                  key: pageTextKey,
                  semantics: ElSemantics(label: 'page-selection-content'),
                  child: 'alpha bravo charlie',
                ),
                const ElView(style: ElStyle(height: 180)),
                const ElView(key: pageText2Key, child: 'delta echo foxtrot'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 覆盖底层文本的免锚面板（topLeft 全盖两行文本区域）。
  ElPortalController showPanel(WidgetTester tester, {Widget? content, bool captureFocus = true}) {
    final ctx = tester.element(find.byKey(pageTextKey));
    return ElTestPortal.of(ctx).show(
      align: Alignment.topLeft,
      captureFocus: captureFocus,
      builder: (c) => ElView(
        key: panelKey,
        style: const ElStyle(width: 300, height: 120, bgColor: Color(0xFFEEEEEE)),
        child: content,
      ),
    );
  }

  Future<void> mouseDrag(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(from);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.removePointer();
    await tester.pumpAndSettle();
  }

  Future<void> pressCtrlA(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets('面板命中不透明：面板上拖拽不启动底层选区，面板上点击不触底层 onTap', (tester) async {
    final pageController = ElSelectionController();
    addTearDown(pageController.dispose);
    final taps = <Offset>[];

    await tester.pumpWidget(app(pageController: pageController, onPageTap: taps.add));
    showPanel(tester);
    await tester.pump();
    await tester.pump();

    final panelRect = tester.getRect(find.byKey(panelKey));
    // 面板压住底层文本；在面板内横向拖拽（对应底层文本行位置）
    await mouseDrag(tester, panelRect.topLeft + const Offset(4, 8), panelRect.topLeft + const Offset(200, 8));
    expect(pageController.text, isNull, reason: '落点在面板上不得启动底层选区');

    await tester.tapAt(panelRect.center);
    await tester.pumpAndSettle();
    expect(taps, isEmpty, reason: '面板矩形内点击不穿透到底层 onTap');

    // 面板外照常穿透：点击面板下方的底层区域，onTap 正常触发
    await tester.tapAt(Offset(panelRect.left + 10, panelRect.bottom + 40));
    await tester.pumpAndSettle();
    expect(taps, hasLength(1), reason: '面板外区域照常穿透到底层');
  });

  testWidgets('选区上下文隔离：面板显式根不进底层并独立 Ctrl+A', (tester) async {
    const overlayTextKey = ValueKey('overlay-text');
    final pageController = ElSelectionController();
    final overlayController = ElSelectionController();
    addTearDown(pageController.dispose);
    addTearDown(overlayController.dispose);

    await tester.pumpWidget(app(pageController: pageController));
    showPanel(
      tester,
      // 此用例单独验证两个选区根，允许在它们之间主动换焦。
      captureFocus: false,
      content: ElSelectionView(
        controller: overlayController,
        child: const ElView(key: overlayTextKey, child: 'overlay content'),
      ),
    );
    await tester.pump();

    // 底层 Ctrl+A：先点底层文本（面板外）授焦再全选——不含弹层文本
    final line2 = tester.getRect(find.byKey(pageText2Key));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(line2.center);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.removePointer();
    await tester.pumpAndSettle();
    await pressCtrlA(tester);
    expect(pageController.text, 'alpha bravo charlie\ndelta echo foxtrot', reason: '弹层内容不注册进底层根');

    // 弹层内 Ctrl+A：点弹层文本授焦 → 只选弹层内容，底层选区不被替换为弹层内容
    final overlayGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await overlayGesture.down(tester.getCenter(find.byKey(overlayTextKey)));
    await tester.pump(const Duration(milliseconds: 16));
    await overlayGesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await overlayGesture.removePointer();
    await tester.pumpAndSettle();
    await pressCtrlA(tester);
    expect(overlayController.text, 'overlay content', reason: '弹层内选区上下文独立工作');
    expect(pageController.text, isNot(contains('overlay')), reason: '弹层选区不溢出到底层上下文');
  });

  testWidgets('opaque/inert modal 屏蔽底层 selection semantics 与交互，关闭后保留 range 恢复', (tester) async {
    const modalTextKey = ValueKey('modal-selection-text');
    final semantics = tester.ensureSemantics();
    final pageController = ElSelectionController();
    addTearDown(pageController.dispose);
    await tester.pumpWidget(app(pageController: pageController));

    final firstParticipant = selectionParticipantOf(tester.renderObject(find.byKey(pageTextKey)))!;
    final secondParticipant = selectionParticipantOf(tester.renderObject(find.byKey(pageText2Key)))!;
    pageController.selectAll();
    await tester.pump();
    const retainedFirstRange = TextRange(start: 0, end: 19);
    const retainedSecondRange = TextRange(start: 0, end: 18);
    expect(firstParticipant.currentSelectionRange, retainedFirstRange);
    expect(secondParticipant.currentSelectionRange, retainedSecondRange);
    expect(find.semantics.byLabel('page-selection-content'), findsOne);

    final source = tester.element(find.byKey(pageTextKey));
    final entry = Navigator.of(source);
    entry.push(
      RawDialogRoute<void>(
        barrierDismissible: false,
        barrierColor: Color(0xFFEEEEEE),
        transitionDuration: Duration.zero,
        requestFocus: false,
        pageBuilder: (_, _, _) => ElSelectionView(
          child: ElView(
            style: const ElStyle(width: '100%', height: '100%', bgColor: Color(0xFFEEEEEE)),
            child: ElView(
              key: modalTextKey,
              semantics: ElSemantics(label: 'modal-selection-content'),
              child: 'modal selection',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.semantics.byLabel('page-selection-content'), findsNothing);
    expect(find.semantics.byLabel('modal-selection-content'), findsOne);
    expect(firstParticipant.currentSelectionRange, retainedFirstRange);
    expect(secondParticipant.currentSelectionRange, retainedSecondRange);

    final coveredPageRect = tester.getRect(find.byKey(pageTextKey));
    await mouseDrag(
      tester,
      coveredPageRect.centerLeft + const Offset(2, 0),
      coveredPageRect.centerRight - const Offset(2, 0),
    );

    expect(firstParticipant.currentSelectionRange, retainedFirstRange);
    expect(secondParticipant.currentSelectionRange, retainedSecondRange);
    expect(pageController.text, 'alpha bravo charlie\ndelta echo foxtrot');

    entry.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(modalTextKey), findsNothing);
    expect(find.semantics.byLabel('modal-selection-content'), findsNothing);
    expect(find.semantics.byLabel('page-selection-content'), findsOne);

    expect(firstParticipant.currentSelectionRange, retainedFirstRange);
    expect(secondParticipant.currentSelectionRange, retainedSecondRange);
    expect(pageController.text, 'alpha bravo charlie\ndelta echo foxtrot');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
