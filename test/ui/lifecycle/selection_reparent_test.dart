import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/reparent.dart';

/// 重挂（临时离树、同帧 attach 回来）不得结算选区的在途指针交互。
///
/// 场景来自已清理的示例页 `example/lib/reparent_drag_demo.dart` 的"文本拖选"区；
/// paint 相位那一半的契约在 `selection_reparent_paint_contract_test.dart`。
/// 本文件管手势账和事件层，同一口径：用户还按着，就不许中途断；真销毁才由 dispose 收尾。
///
/// 覆盖：桌面鼠标拖选 / 移动端长按拖选 / 长按计时中重挂 / 双击词选 / 全选 /
/// 单击待决（pendingTap）。
void main() {
  const text = 'alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike';

  Widget host(Widget child) => MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: child),
  );

  Widget selectable({required Key key, ElSelectionController? controller, required String body}) => ElSelectionView(
    key: key,
    controller: controller,
    child: ElView(style: const ElStyle(width: 420, height: 60), child: body),
  );

  ElRenderView textParticipant(WidgetTester tester) =>
      tester.allRenderObjects.whereType<ElRenderView>().firstWhere((r) => r.content is TextEngine);

  /// 某字符偏移处的全局坐标（落在该字内部）。
  Offset posAt(WidgetTester tester, int offset) {
    final render = textParticipant(tester);
    final participant = selectionParticipantOf(render)!;
    final line = participant.selectionLineGeometryAt(offset)!;
    final caret = participant.selectionCaretGeometryAt(offset)!;
    return render.localToGlobal(Offset(caret.position.dx + 1, line.lineTop + line.lineHeight / 2));
  }

  Future<void> pumpFrames(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  // ---------------------------------------------------------------------------
  // 桌面端：鼠标拖选
  // ---------------------------------------------------------------------------

  testWidgets('桌面：鼠标拖选中途重挂，选区保留且同一手势继续扩展', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final key = UniqueKey();
    final selection = ElSelectionController();
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      host(
        ReparentHarness(
          key: move,
          child: selectable(key: key, controller: selection, body: text),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(posAt(tester, 0), kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await tester.pump();
    for (var i = 1; i <= 6; i++) {
      await gesture.moveTo(posAt(tester, i * 2));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = selection.text;
    expect(before, isNotNull, reason: '前置：拖了一段之后应当已经建立选区');
    expect(before, isNotEmpty);

    await reparent(tester, move);

    expect(selection.text, before, reason: '重挂不是手势结束，已建立的选区不得被清掉');

    await gesture.moveTo(posAt(tester, 26));
    await pumpFrames(tester, 2);
    expect(
      selection.text!.length,
      greaterThan(before!.length),
      reason: '重挂后同一条鼠标手势必须继续扩展选区：before="$before" after="${selection.text}"',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('桌面：鼠标按下未过阈值时重挂，抬起仍按连击规则结算', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final key = UniqueKey();
    final selection = ElSelectionController();
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      host(
        ReparentHarness(
          key: move,
          child: selectable(key: key, controller: selection, body: text),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 先建立一段选区，再在别处按下（pendingTap）后重挂、抬起：
    // 单击应当照常清除选区，而不是因为重挂被吞掉或误保留。
    selection.selectAll();
    await tester.pumpAndSettle();
    expect(selection.text, isNotNull);

    final gesture = await tester.startGesture(posAt(tester, 4), kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await reparent(tester, move);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(selection.text, isNull, reason: '重挂后的单击仍要按连击规则结算（单击清除）');
  });

  // ---------------------------------------------------------------------------
  // 移动端：长按选词 + 长按拖选
  // ---------------------------------------------------------------------------

  testWidgets('移动端：长按拖选中途重挂，选区保留且同一手势继续扩展', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final key = UniqueKey();
    final selection = ElSelectionController();
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      host(
        ReparentHarness(
          key: move,
          child: selectable(key: key, controller: selection, body: text),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 长按选词（触摸 450ms）。
    final gesture = await tester.startGesture(posAt(tester, 7), kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 450));
    expect(selection.text, isNotNull, reason: '前置：长按应选中词');
    final word = selection.text!;
    expect(word, isNotEmpty);

    // 进入拖选并拖一段。
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(22, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = selection.text;
    expect(before, isNotNull);

    await reparent(tester, move);

    expect(selection.text, before, reason: '重挂不是手势结束，移动端长按拖选的选区不得被清掉');

    final lengthBefore = selection.text!.length;
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(22, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(selection.text!.length, greaterThan(lengthBefore), reason: '重挂后同一条触摸手势必须继续扩展选区');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('移动端：长按计时中重挂，长按仍要照常触发选词', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final key = UniqueKey();
    final selection = ElSelectionController();
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      host(
        ReparentHarness(
          key: move,
          child: selectable(key: key, controller: selection, body: text),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(posAt(tester, 7), kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    // 长按计时未到就重挂。
    await tester.pump(const Duration(milliseconds: 120));
    expect(selection.text, isNull, reason: '前置：计时未到不该有选区');

    await reparent(tester, move);

    await tester.pump(const Duration(milliseconds: 400));
    expect(selection.text, isNotNull, reason: '重挂不是手势结束，长按计时必须继续走完并选中词');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  // ---------------------------------------------------------------------------
  // 点击类：双击词选 / 三击段选 / 全选
  // ---------------------------------------------------------------------------

  testWidgets('桌面：双击词选后重挂，选区保留', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final key = UniqueKey();
    final selection = ElSelectionController();
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      host(
        ReparentHarness(
          key: move,
          child: selectable(key: key, controller: selection, body: text),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(posAt(tester, 7), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(posAt(tester, 7), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    final word = selection.text;
    expect(word, isNotNull, reason: '前置：双击应选中词');
    expect(word, isNotEmpty);

    await reparent(tester, move);
    expect(selection.text, word, reason: '重挂不得清掉已建立的词选');
  });

  testWidgets('程序化全选后重挂，选区保留', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final key = UniqueKey();
    final selection = ElSelectionController();
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      host(
        ReparentHarness(
          key: move,
          child: selectable(key: key, controller: selection, body: text),
        ),
      ),
    );
    await tester.pumpAndSettle();

    selection.selectAll();
    await tester.pumpAndSettle();
    final all = selection.text;
    expect(all, isNotNull, reason: '前置：全选应建立选区');

    await reparent(tester, move);
    expect(selection.text, all, reason: '重挂不得清掉全选选区');
  });
}
