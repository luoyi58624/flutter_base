import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
// 选区岛（嵌套选区作用域）行为锁——对齐浏览器 <input> 分工：
// - 内不出岛：岛内起手（鼠标拖拽 / 触摸长按）外层选区 down 即弃权，不 arm；
// - 外可进岛：岛内文本仍是外层参与者，从岛外扫进来照常选中/复制；
// - 点入岛清外层已有选区（浏览器同款）；
// - 可编辑 EditableView 自动成岛；readOnly 关闭岛，完全交给外层文档选区。

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

Future<void> _mouseDrag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.down(from);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(to);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await tester.pump();
  await gesture.removePointer();
}

void main() {
  const keyA = Key('text-a');
  const keyM = Key('island-text');
  const keyB = Key('text-b');

  Widget host(ElSelectionController controller) {
    return _app(
      ElSelectionView(
        controller: controller,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElView(key: keyA, child: 'alpha alpha alpha'),
            SelectionIsland(
              child: ElView(key: keyM, child: 'middle middle'),
            ),
            ElView(key: keyB, child: 'beta beta beta'),
          ],
        ),
      ),
    );
  }

  testWidgets('内不出岛：鼠标拖拽起手在岛内，外层选区不 arm', (tester) async {
    final controller = ElSelectionController();
    await tester.pumpWidget(host(controller));

    final mid = tester.getCenter(find.byKey(keyM));
    await _mouseDrag(tester, mid + const Offset(-30, 0), mid + const Offset(40, 0));

    expect(controller.text, isNull, reason: '岛内起手的拖拽外层必须完全弃权');
  });

  testWidgets('内不出岛：触摸长按在岛内不进入选中', (tester) async {
    final controller = ElSelectionController();
    await tester.pumpWidget(host(controller));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await gesture.down(tester.getCenter(find.byKey(keyM)));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pump();

    expect(controller.text, isNull, reason: '岛内长按外层不得 arm');
  });

  testWidgets('外可进岛：从岛外扫过岛，外层选区包含岛内文本', (tester) async {
    final controller = ElSelectionController();
    await tester.pumpWidget(host(controller));

    final start = tester.getTopLeft(find.byKey(keyA)) + const Offset(4, 6);
    final end = tester.getBottomRight(find.byKey(keyB)) - const Offset(4, 6);
    await _mouseDrag(tester, start, end);

    final text = controller.text ?? '';
    expect(text, contains('alpha'));
    expect(text, contains('middle'), reason: '岛内文本仍是外层参与者，扫进来照常选中');
    expect(text, contains('beta'));
  });

  testWidgets(
    '点入岛清掉外层已有选区（浏览器同款）',
    (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(host(controller));

      final start = tester.getTopLeft(find.byKey(keyA)) + const Offset(4, 6);
      final endA = tester.getBottomRight(find.byKey(keyA)) - const Offset(4, 6);
      await _mouseDrag(tester, start, endA);
      expect(controller.text ?? '', contains('alpha'), reason: '先建立外层选区');

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.down(tester.getCenter(find.byKey(keyM)));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump();
      await gesture.removePointer();

      expect(controller.text, isNull, reason: '点入岛即清外层选区');
    },
  );

  testWidgets('EditableView 自动成岛：编辑器内拖选不惊动外层选区', (tester) async {
    final controller = ElSelectionController();
    final editable = EditableController(text: 'hello world editable');
    addTearDown(editable.dispose);

    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElView(key: keyA, child: 'alpha alpha alpha'),
              SizedBox(
                width: 300,
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

    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseDrag(tester, origin + const Offset(5, 5), origin + const Offset(80, 5));

    expect(controller.text, isNull, reason: '编辑器即选区岛，外层不 arm');
    expect(editable.selection.isCollapsed, isFalse, reason: '编辑器自己的拖选照常工作');

    // 编辑器 caret 闪烁 Timer：卸载取消
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('外可进岛（编辑器）：从岛外扫入编辑器，外层选区含编辑器文本且逐行 join', (tester) async {
    final controller = ElSelectionController();
    final editable = EditableController(text: 'line-one\nline-two');
    addTearDown(editable.dispose);

    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElView(key: keyA, child: 'alpha alpha alpha'),
              SizedBox(
                width: 300,
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

    final start = tester.getTopLeft(find.byKey(keyA)) + const Offset(4, 6);
    final end = tester.getTopLeft(find.byType(EditableView)) + const Offset(85, 15); // 第二行 'line-two' 全词之后
    await _mouseDrag(tester, start, end);

    final text = controller.text ?? '';
    expect(text, contains('alpha'));
    expect(text, contains('line-one'));
    expect(text, contains('line-two'), reason: '扫入编辑器第二行');
    expect(text, contains('line-one\nline-two'), reason: '行参与者 join 保持换行结构');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('只读编辑器关闭选区岛：从正文内部起手由外层选区跨边界拖选', (tester) async {
    final controller = ElSelectionController();
    const internalSelection = TextSelection(baseOffset: 0, extentOffset: 5);
    final editable = EditableController(text: 'readonly text')..setSelection(internalSelection);
    final focusNode = FocusNode();
    addTearDown(editable.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                height: 40,
                child: EditableView(
                  controller: editable,
                  focusNode: focusNode,
                  style: EditableConfiguration(
                    readOnly: true,
                    textStyle: const TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000)),
                  ),
                ),
              ),
              const ElView(key: keyB, child: 'beta beta beta'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    controller.selectAll();
    await tester.pump();
    expect(controller.text, contains('readonly'), reason: '外层 Ctrl+A/selectAll 必须包含只读编辑器正文');
    controller.clear();
    await tester.pump();

    final start = tester.getTopLeft(find.byType(EditableView)) + const Offset(1, 5);
    final end = tester.getBottomRight(find.byKey(keyB)) - const Offset(4, 6);
    await _mouseDrag(tester, start, end);

    final text = controller.text ?? '';
    expect(text, contains('readonly'));
    expect(text, contains('beta'));
    expect(editable.selection, internalSelection, reason: '通用文档拖选不得改写只读编辑器自己的 controller 选区');
    expect(focusNode.hasFocus, isFalse);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('外层文档全选只读取只读编辑器当前有效挂载行', (tester) async {
    final controller = ElSelectionController();
    final text = List<String>.generate(200, (index) => 'readonly-line-$index').join('\n');
    final editable = EditableController(text: text);
    addTearDown(editable.dispose);

    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: SizedBox(
            width: 300,
            height: 40,
            child: EditableView(
              controller: editable,
              style: const EditableConfiguration(
                readOnly: true,
                textStyle: TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.selectAll();
    await tester.pump();
    expect(controller.text, contains('readonly-line-0'));
    final selectedLines = controller.text!.split('\n');
    expect(selectedLines.length, lessThan(200), reason: '不走查未挂载的编辑器全文');
    expect(selectedLines, [for (var index = 0; index < selectedLines.length; index++) 'readonly-line-$index']);
    expect(editable.text, text, reason: '文档选择不改变编辑器自身的全文模型');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('外层文档选区只能读取只读密码编辑器的等长掩码', (tester) async {
    final controller = ElSelectionController();
    final editable = EditableController(text: 'secret');
    addTearDown(editable.dispose);

    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: SizedBox(
            width: 160,
            height: 30,
            child: EditableView(
              controller: editable,
              style: const EditableConfiguration(readOnly: true, obscureText: true, obscuringCharacter: '•'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.selectAll();
    await tester.pump();
    expect(controller.text, '••••••');

    await tester.pumpWidget(const SizedBox());
  });
}
