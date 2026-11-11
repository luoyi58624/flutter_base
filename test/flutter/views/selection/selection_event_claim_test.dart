import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: .ltr,
      child: Align(alignment: .topLeft, child: child),
    ),
  );
}

RenderSelectionView _selectionRender(WidgetTester tester) {
  return tester.allRenderObjects.whereType<RenderSelectionView>().first;
}

void main() {
  testWidgets('userSelect none 内移动不武装文本选中，按钮 Tap 链保持完整', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    var tapDowns = 0;
    var tapUps = 0;
    var cancels = 0;
    var presses = 0;
    const buttonKey = ValueKey<String>('user-select-none-button');

    await tester.pumpWidget(
      _app(
        SelectionView(
          controller: controller,
          child: Column(
            crossAxisAlignment: .start,
            children: [
              const ElView(style: ElStyle(width: 280, height: 32), child: 'selectable before'),
              ElButtonView(
                key: buttonKey,
                onPressed: () => presses++,
                style: const ElStyle(width: 160, height: 40),
                event: ElEvent(onTapDown: (_) => tapDowns++, onTapUp: (_) => tapUps++, onTapCancel: (_) => cancels++),
                child: 'button chrome',
              ),
              const ElView(style: ElStyle(width: 280, height: 32), child: 'selectable after'),
            ],
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(buttonKey));
    final start = rect.center;
    final moved = start + const Offset(8, 0);
    expect(rect.contains(moved), isTrue, reason: '位移始终在按钮可交互范围内');
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.down(start);
    await gesture.moveTo(moved);
    await tester.pump();

    expect(_selectionRender(tester).isSelectionDragging, isFalse);
    expect(controller.text, isNull, reason: 'userSelect none 内起手不得用附近文本补选锚点');
    expect((tapDowns, cancels), (1, 0), reason: '选区不得通过 eagerGesture 淘汰按钮事件链');

    await gesture.up();
    await tester.pump();
    expect((tapDowns, tapUps, cancels, presses), (1, 1, 0, 1));
  });

  testWidgets('后代 DragStart.stop 只截断 Selection 拖选，后代自身 Tap 保持完整', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    var descendantDragStarts = 0;
    var descendantTaps = 0;
    const targetKey = ValueKey<String>('descendant-drag-boundary');

    await tester.pumpWidget(
      _app(
        SelectionView(
          controller: controller,
          child: ElView(
            key: targetKey,
            style: const ElStyle(width: 280, height: 64, fontSize: 18),
            event: ElEvent(
              dragStartDistance: 24,
              onDragStart: (event) {
                descendantDragStarts++;
                event.stopPropagation();
              },
              onTap: (_) => descendantTaps++,
            ),
            child: 'alpha beta gamma delta',
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(targetKey));
    final start = rect.centerLeft + const Offset(8, 0);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.down(start);
    await gesture.moveTo(start + const Offset(12, 0));
    await tester.pump();
    expect(_selectionRender(tester).isSelectionDragging, isFalse, reason: '后代 reservation 未决时，祖先 Selection 不得抢先接受');
    await gesture.moveTo(start + const Offset(80, 0));
    await tester.pump();
    expect(descendantDragStarts, 1);
    expect(_selectionRender(tester).isSelectionDragging, isFalse);
    expect(controller.text, isNull);
    await gesture.up();
    await tester.pump();
    expect(descendantTaps, 1, reason: 'DragStart.stop 只建立 Drag 家族边界，不得取消后代自身 Tap');
  });

  testWidgets('桌面字符拖选同步 eager：祖先后续 raw 终止，winner 自身拖选到 up', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    var ancestorMoves = 0;
    var ancestorUps = 0;
    const textKey = ValueKey<String>('character-claim-text');

    await tester.pumpWidget(
      _app(
        ElView(
          style: const ElStyle(width: 320, height: 80),
          event: ElEvent(onPointerMove: (_) => ancestorMoves++, onPointerUp: (_) => ancestorUps++),
          child: SelectionView(
            controller: controller,
            child: const ElView(
              key: textKey,
              style: ElStyle(width: 280, fontSize: 18),
              child: 'alpha beta gamma delta',
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(textKey));
    final start = Offset(rect.left + 4, rect.center.dy);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.down(start);
    await gesture.moveTo(Offset(rect.center.dx, rect.center.dy));
    await tester.pump();
    expect(_selectionRender(tester).isSelectionDragging, isTrue);
    expect(controller.text, isNotEmpty);
    expect(ancestorMoves, 0, reason: 'Selection 在当前 move 内认领后，祖先不得继续执行同一事件链');

    final firstText = controller.text;
    await gesture.moveTo(Offset(rect.right - 4, rect.center.dy));
    await tester.pump();
    expect(controller.text, isNot(equals(firstText)), reason: 'winner 必须继续收到自己的后续 move');
    await gesture.up();
    await tester.pump();
    expect(_selectionRender(tester).isSelectionDragging, isFalse);
    expect(ancestorUps, 0, reason: '失权祖先不得收到 pointerUp');

    // 拖选必须取消 Selection 自身的 tap 候选；紧接的一次单击不能被误算成
    // 双击选词，而应按普通单击语义清空选区。
    await tester.tapAt(start, kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(controller.text, isNull);
  });

  testWidgets('block 框选同步 eager 后仍由 winner 完成框选与终态', (tester) async {
    final controller = ElBoxSelectionController();
    addTearDown(controller.dispose);
    var ancestorMoves = 0;
    var ancestorUps = 0;
    const blockKey = ValueKey<String>('block-claim-target');

    await tester.pumpWidget(
      _app(
        ElView(
          style: const ElStyle(width: 320, height: 160),
          event: ElEvent(onPointerMove: (_) => ancestorMoves++, onPointerUp: (_) => ancestorUps++),
          child: ElBoxSelectionView(
            controller: controller,
            child: const ElBoxSelectable(
              value: 'atomic block',
              child: ElView(key: blockKey, style: ElStyle(width: 140, height: 60), child: 'atomic block'),
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(blockKey));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.down(rect.topLeft + const Offset(2, 2));
    await gesture.moveTo(rect.center);
    await tester.pump();
    expect(controller.selectedValues, {'atomic block'});
    expect(ancestorMoves, 0);

    await gesture.moveTo(rect.bottomRight - const Offset(2, 2));
    await tester.pump();
    expect(controller.selectedValues, {'atomic block'}, reason: 'winner 后续 move 必须继续维护框选');
    await gesture.up();
    await tester.pump();
    expect(ancestorUps, 0);
  });

  testWidgets('移动档 longPress 使用配置延时并固定保留 18px 微抖容差', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    const textKey = ValueKey<String>('precise-pointer-long-press');
    const delay = Duration(milliseconds: 60);

    await tester.pumpWidget(
      _app(
        ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(dragDevices: const {PointerDeviceKind.mouse}),
          child: SizedBox(
            width: 280,
            height: 80,
            child: SelectionView(
              controller: controller,
              controls: const DesktopSelectionControls(longPressDelay: delay, longPressHaptics: false),
              child: ElScroll(
                physics: NeverScrollableScrollPhysics(),
                children: const [
                  ElView(key: textKey, style: ElStyle(width: 260, height: 60, fontSize: 18), child: 'alpha beta gamma'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final textRect = tester.getRect(find.byKey(textKey));
    final start = Offset(textRect.left + 4, textRect.center.dy);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.down(start);
    await gesture.moveBy(const Offset(17, 0));
    await tester.pump(delay - const Duration(milliseconds: 1));
    expect(controller.text, isNull, reason: '必须使用 controls 解析出的平台延时');
    await tester.pump(const Duration(milliseconds: 2));
    expect(controller.text, isNotNull, reason: '精确指针进入移动档后，17px 微抖仍应允许长按');
    expect(_selectionRender(tester).isSelectionDragging, isTrue);
    await gesture.up();
    await tester.pump();

    controller.clear();
    final canceled = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(canceled.removePointer);
    await canceled.down(start);
    await canceled.moveBy(const Offset(19, 0));
    await tester.pump(delay + const Duration(milliseconds: 1));
    expect(controller.text, isNull, reason: '超过固定 18px 后必须取消移动档长按候选');
    expect(_selectionRender(tester).isSelectionDragging, isFalse);
    await canceled.up();
    await tester.pump();
  });

  testWidgets('Duration.zero 仍在同一次 down 内同步触发真实 onLongPress', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    const textKey = ValueKey<String>('zero-delay-long-press');

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 240,
          height: 60,
          child: SelectionView(
            controller: controller,
            controls: const DesktopSelectionControls(longPressDelay: Duration.zero, longPressHaptics: false),
            child: const ElView(key: textKey, style: ElStyle(fontSize: 18), child: 'zero delay text'),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    final rect = tester.getRect(find.byKey(textKey));
    await gesture.down(Offset(rect.left + 4, rect.center.dy));
    expect(controller.text, isNotNull);
    expect(_selectionRender(tester).isSelectionDragging, isTrue);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('移动端长按独占不误发 Tap，静止 cancel 后下次手势正常', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    var ancestorTaps = 0;
    var descendantTaps = 0;
    const textKey = ValueKey<String>('long-press-terminal-text');
    const delay = Duration(milliseconds: 20);

    await tester.pumpWidget(
      _app(
        ElView(
          style: const ElStyle(width: 280, height: 80),
          event: ElEvent(onTap: (_) => ancestorTaps++),
          child: SelectionView(
            controller: controller,
            controls: const DesktopSelectionControls(longPressDelay: delay, longPressHaptics: false),
            child: ElScroll(
              children: [
                ElView(
                  key: textKey,
                  style: const ElStyle(width: 260, height: 200, fontSize: 18),
                  event: ElEvent(onTap: (_) => descendantTaps++),
                  child: 'alpha beta gamma',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final position = tester.getRect(find.byKey(textKey)).topLeft + const Offset(8, 20);
    final released = await tester.createGesture(kind: PointerDeviceKind.touch);
    await released.down(position);
    await tester.pump(delay + const Duration(milliseconds: 1));
    expect(_selectionRender(tester).isSelectionDragging, isTrue);
    await released.up();
    await tester.pump();
    expect((ancestorTaps, descendantTaps), (0, 0), reason: '长按认领后上下游 Tap 都已失权');

    final canceled = await tester.createGesture(kind: PointerDeviceKind.touch);
    await canceled.down(position);
    await tester.pump(delay + const Duration(milliseconds: 1));
    expect(_selectionRender(tester).isSelectionDragging, isTrue);
    await canceled.cancel();
    await tester.pump();
    expect(_selectionRender(tester).isSelectionDragging, isFalse);
    expect(_selectionRender(tester).isHandleDragInProgress, isFalse);

    await tester.tapAt(position, kind: PointerDeviceKind.touch);
    await tester.pump();
    expect((ancestorTaps, descendantTaps), (1, 1), reason: 'PointerCancel 必须完整释放会话，下次 Tap 不受污染');
  });
}
