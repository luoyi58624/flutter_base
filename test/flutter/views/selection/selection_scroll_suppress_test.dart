// P3 — 长按激活拖选后，在长按自动滚动位移门禁内页面不得滚动。
//
// 机制：真实 ElEvent.onLongPress 回调完成校验后同步 eager，内层 ElScrollView
// 随即失去该 pointer 的后续事件资格；Selection winner 保留自身 move/up，达到
// 长按自动滚动位移门禁后只允许选区的边缘自动滚动，抬手自动释放。反向案例
// （滚动先胜出 → 长按取消）已由
// `enabled_and_eager_test.dart` 锁定。
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

RenderSelectionView _selectionRender(WidgetTester tester) {
  return tester.allRenderObjects.whereType<RenderSelectionView>().first;
}

/// 选区套滚动宿主：240 高视口 + 30 行文本（可滚动余量充足）。
({ElSelectionController selection, ScrollController scroll, Key firstRow}) _buildHost() {
  return (selection: ElSelectionController(), scroll: ScrollController(), firstRow: const Key('suppress-row-0'));
}

Future<void> _pumpHost(
  WidgetTester tester,
  ({ElSelectionController selection, ScrollController scroll, Key firstRow}) host,
) async {
  final rows = List<Widget>.generate(30, (index) {
    return SizedBox(
      height: 36,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ElView(child: 'row $index word text', key: index == 0 ? host.firstRow : ValueKey('row-$index')),
      ),
    );
  });
  await tester.pumpWidget(
    _app(
      SizedBox(
        width: 240,
        height: 240,
        child: ElSelectionView(
          controller: host.selection,
          child: ElScroll(controller: host.scroll, physics: ClampingScrollPhysics(), children: rows),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('长按激活拖选后移动不足自动滚动门禁：页面不滚动、选区词级延伸', (tester) async {
    final host = _buildHost();
    addTearDown(host.scroll.dispose);
    await _pumpHost(tester, host);

    final start = tester.getCenter(find.byKey(host.firstRow));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);

    await gesture.down(start);
    await tester.pump(const Duration(milliseconds: 450)); // 400ms 长按触发
    expect(host.selection.text, isNotNull, reason: '前置：长按已激活词选');
    final wordOnly = host.selection.text!;
    expect(host.scroll.offset, 0);

    // 长按会话内向下拖共 60px（小于默认 100px 门禁）：逐步移动并断言
    // 每一步页面都纹丝不动、选区在延伸。
    for (var step = 1; step <= 4; step++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump();
      expect(host.scroll.offset, 0, reason: 'step=$step：长按拖选期间页面不得滚动');
    }
    expect(_selectionRender(tester).isSelectionDragging, isTrue);
    expect(host.selection.text!.length, greaterThan(wordOnly.length), reason: '拖动应在延伸选区而不是滚动');

    await gesture.up();
    await tester.pump();
  });

  testWidgets('拖选抬手后，新的触摸拖动恢复滚动（独占随指针释放）', (tester) async {
    final host = _buildHost();
    addTearDown(host.scroll.dispose);
    await _pumpHost(tester, host);

    // 第一轮：长按拖选（期间滚动被压制）。
    final start = tester.getCenter(find.byKey(host.firstRow));
    final press = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(press.removePointer);
    await press.down(start);
    await tester.pump(const Duration(milliseconds: 450));
    await press.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(host.scroll.offset, 0);
    await press.up();
    // 隔开 400ms + 换位置：避免第二轮 down 被判成连击干扰长按路径。
    await tester.pump(const Duration(milliseconds: 400));

    // 第二轮：普通触摸上滑 → 必须恢复正常滚动。
    final swipe = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(swipe.removePointer);
    await swipe.down(tester.getCenter(find.byKey(const ValueKey('row-2'))));
    await swipe.moveBy(Offset(0, -(kTouchSlop + 30)));
    await tester.pump();
    await swipe.moveBy(const Offset(0, -30));
    await tester.pump();
    expect(host.scroll.offset, greaterThan(0), reason: '独占必须随指针抬起释放，普通拖动恢复滚动');
    await swipe.up();
    await tester.pump();
  });
}
