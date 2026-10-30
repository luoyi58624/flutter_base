import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 选区快捷键 = 焦点冒泡链（2026-08-03 裁决）语义锁：
///
/// - 指针落进选区内容 → 选区根隐式持焦（更深可聚焦目标优先）
/// - Ctrl+A/Esc 只在选区根位于焦点链上时响应；失焦后快捷键失效
/// - 嵌套根独立保存选区，Ctrl+A 只操作当前持焦的文档
/// - editable 等自带键盘管线的内层控件消费 Ctrl+A 后外层不响应
void main() {
  Widget app(Widget child) {
    return MaterialApp(
      home: Align(
        alignment: .topLeft,
        child: SizedBox(
          width: 400,
          height: 300,
          child: Align(alignment: .topLeft, child: child),
        ),
      ),
    );
  }

  /// 鼠标单击（触摸 tap 证明不了桌面行为）；结尾多 pump 一拍冲刷仲裁微任务。
  Future<void> mouseTapAt(WidgetTester tester, Offset position) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(position);
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

  testWidgets('选区根未持焦时 Ctrl+A 不响应', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      app(
        ElSelectionView(
          controller: controller,
          child: const ElView(child: 'hello world'),
        ),
      ),
    );
    await pressCtrlA(tester);

    expect(controller.text, isNull, reason: '无焦点 → 快捷键无归属，不全选');
  });

  testWidgets(
    '指针落点授予选区根焦点，Ctrl+A 全选；点击外部失焦后快捷键失效',
    (tester) async {
      const textKey = ValueKey('text');
      final controller = ElSelectionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        app(
          ElSelectionView(
            controller: controller,
            child: const ElView(key: textKey, child: 'hello world'),
          ),
        ),
      );

      await mouseTapAt(tester, tester.getCenter(find.byKey(textKey)));
      await pressCtrlA(tester);
      expect(controller.text, 'hello world', reason: '落点授焦后 Ctrl+A 作用于持焦选区根');

      // 点击选区视图外空白（app 里无任何可聚焦目标/scope）→ 全局失焦。
      // 先显式清空再按 Ctrl+A：把"快捷键失效"与外点清选区口径（P3 收窄）解耦。
      await mouseTapAt(tester, const Offset(380, 280));
      controller.clear();
      await tester.pump();
      await pressCtrlA(tester);
      expect(controller.text, isNull, reason: '失焦后 Ctrl+A 不再作用于本选区根');
    },
  );

  testWidgets('点击选区内可聚焦元素：元素持焦不被根抢占，Ctrl+A 沿链冒泡到选区根', (tester) async {
    const textKey = ValueKey('text');
    const buttonKey = ValueKey('button');
    final node = FocusNode(debugLabel: 'inner-button');
    addTearDown(node.dispose);
    final controller = ElSelectionController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      app(
        ElSelectionView(
          controller: controller,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElView(key: textKey, child: 'hello world'),
              ElView(
                key: buttonKey,
                style: const ElStyle(width: 80, height: 36, userSelect: .none),
                focusNode: node,
                child: 'btn',
              ),
            ],
          ),
        ),
      ),
    );

    await mouseTapAt(tester, tester.getCenter(find.byKey(buttonKey)));
    expect(node.hasPrimaryFocus, isTrue, reason: '更深可聚焦目标认领本次 down，选区根让位');

    await pressCtrlA(tester);
    expect(controller.text, contains('hello world'), reason: '元素不吃 Ctrl+A → 沿链冒泡到选区根全选');
  });

  testWidgets('显式选区岛不改变嵌套根的 Ctrl+A 焦点范围', (tester) async {
    const innerKey = ValueKey('inner-text');
    final outer = ElSelectionController();
    final inner = ElSelectionController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);

    await tester.pumpWidget(
      app(
        ElSelectionView(
          controller: outer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElView(child: 'outer text'),
              SelectionIsland(
                child: ElSelectionView(
                  controller: inner,
                  child: const ElView(key: innerKey, child: 'inner text'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await mouseTapAt(tester, tester.getCenter(find.byKey(innerKey)));
    await pressCtrlA(tester);

    expect(outer.text, isNull, reason: '内层快捷键不修改外层文档');
    expect(inner.text, 'inner text');
  });

  /// 鼠标拖选（桌面档字符级拖选）。
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

  testWidgets('嵌套文档：Ctrl+A 只更新当前持焦文档的控制器', (tester) async {
    const outerTextKey = ValueKey('outer-text');
    const innerTextKey = ValueKey('inner-text');
    final outer = ElSelectionController();
    final inner = ElSelectionController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);

    await tester.pumpWidget(
      app(
        ElSelectionView(
          controller: outer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElView(key: outerTextKey, child: 'outer text'),
              ElSelectionView(
                controller: inner,
                child: const ElView(key: innerTextKey, child: 'inner text'),
              ),
            ],
          ),
        ),
      ),
    );

    // 点击内层后快捷键只操作内层文档。
    await mouseTapAt(tester, tester.getCenter(find.byKey(innerTextKey)));
    await pressCtrlA(tester);
    expect(outer.text, isNull);
    expect(inner.text, 'inner text');

    // 点击外层后全选外层文档，不跨入独立的内层。
    await mouseTapAt(tester, tester.getCenter(find.byKey(outerTextKey)));
    await pressCtrlA(tester);
    expect(outer.text, 'outer text');
  });

  testWidgets(
    '失焦不清选区：拖选后点击选区根外空白，高亮保留、快捷键失效',
    (tester) async {
      const textKey = ValueKey('text');
      final controller = ElSelectionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        app(
          ElSelectionView(
            controller: controller,
            child: const ElView(key: textKey, child: 'hello world'),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(textKey));
      await mouseDrag(tester, rect.centerLeft + const Offset(1, 0), rect.centerRight - const Offset(1, 0));
      final selected = controller.text;
      expect(selected, isNotNull);
      expect(selected, isNotEmpty);

      // 点击选区根外空白 → 根失焦，但选区保留（2026-08-03 裁决：失焦不清除）
      await mouseTapAt(tester, const Offset(380, 280));
      expect(controller.text, selected, reason: '失焦不清选区');

      // 失焦后 Esc 无归属，选区依旧保留
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.text, selected, reason: '失焦后 Esc 不再作用于本根');
    },
  );

  testWidgets('点击当前聚焦的选中区域内部才清除选区', (tester) async {
    const textKey = ValueKey('text');
    final controller = ElSelectionController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      app(
        ElSelectionView(
          controller: controller,
          child: const ElView(key: textKey, child: 'hello world'),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(textKey));
    await mouseDrag(tester, rect.centerLeft + const Offset(1, 0), rect.centerRight - const Offset(1, 0));
    expect(controller.text, isNotNull);

    // 单击落在聚焦选区区域内部 → 清除
    await mouseTapAt(tester, rect.center);
    expect(controller.text, isNull, reason: '点击聚焦区域内部清除选区');
  });

  testWidgets('editable 持焦时 Ctrl+A 归 editable，全选不冒泡到外层选区', (tester) async {
    final editable = EditableController(text: 'abcd');
    addTearDown(editable.dispose);
    final outer = ElSelectionController();
    addTearDown(outer.dispose);

    await tester.pumpWidget(
      app(
        ElSelectionView(
          controller: outer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElView(child: 'outer text'),
              SizedBox(
                width: 200,
                height: 40,
                child: EditableView(
                  controller: editable,
                  style: EditableConfiguration(
                    textStyle: const TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await mouseTapAt(tester, tester.getTopLeft(find.byType(EditableView)) + const Offset(5, 5));
    await pressCtrlA(tester);

    expect(editable.selection.start, 0);
    expect(editable.selection.end, 4, reason: 'editable 自己消费 Ctrl+A 全选文档');
    expect(outer.text, isNull, reason: '内层消费即阻断，外层不全选');
    // 卸载编辑器，结束 caret 闪烁 Timer。
    await tester.pumpWidget(const SizedBox());
  });
}
