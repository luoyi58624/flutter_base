import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试字体 Ahem：fontSize 10 + height 1.0 → 行高 10、字宽 10，几何可算。
const _style = TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000));

Widget _host(Widget child, {double width = 300, double height = 200}) {
  return MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: SizedBox(width: width, height: height, child: child),
    ),
  );
}

Iterable<RenderEditableLine> _mountedLines(WidgetTester tester) {
  return tester.renderObjectList<RenderEditableLine>(find.byType(EditableLineView));
}

/// 鼠标点击（触摸 tap 证明不了桌面行为）。
Future<void> _mouseTapAt(WidgetTester tester, Offset position, {int taps = 1}) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  for (var i = 0; i < taps; i++) {
    await gesture.down(position);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.removePointer();
}

/// 卸载编辑器并清理输入连接与动画资源。
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('按行渲染且大文档只挂载可视窗口', (tester) async {
    final controller = EditableController(text: List.generate(5000, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();

    final mounted = _mountedLines(tester).length;
    expect(mounted, greaterThan(0));
    // 视口 200 高 / 行高 10 = 20 行可见 + 预挂载,远小于 5000。
    expect(mounted, lessThan(200));
    await _unmount(tester);
  });

  testWidgets('鼠标点击定位 caret 并获得焦点', (tester) async {
    final controller = EditableController(text: 'aaaa\nbbbb\ncccc');
    addTearDown(controller.dispose);
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(EditableView));
    // 第 2 行(index 1)第 2 列:x=22 → offset 2,行首 offset 5 → doc 7。
    await _mouseTapAt(tester, origin + const Offset(22, 15));
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(controller.selection, const TextSelection.collapsed(offset: 7));
    await _unmount(tester);
  });

  testWidgets('关闭交互式选区后鼠标仍可聚焦，但点击、连击与拖动都不能改选区', (tester) async {
    final controller = EditableController(text: 'aaaa\nbbbb\ncccc')
      ..setSelection(const TextSelection.collapsed(offset: 1));
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          style: EditableConfiguration(textStyle: _style, enableInteractiveSelection: false),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));

    await _mouseTapAt(tester, origin + const Offset(22, 15), taps: 2);
    expect(focusNode.hasFocus, isTrue);
    expect(controller.selection, const TextSelection.collapsed(offset: 1));

    final drag = await tester.startGesture(origin + const Offset(2, 5), kind: PointerDeviceKind.mouse);
    await drag.moveTo(origin + const Offset(42, 25));
    await drag.up();
    await tester.pump();
    expect(controller.selection, const TextSelection.collapsed(offset: 1));

    focusNode.unfocus();
    await tester.pump();
    final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
    await touch.down(origin + const Offset(42, 25));
    await tester.pump(const Duration(milliseconds: 16));
    await touch.up();
    await touch.removePointer();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue, reason: '关闭选区交互不能连触摸聚焦和软键盘一起禁掉');
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
    await _unmount(tester);
  });

  testWidgets('双击选词 / 三击选整行', (tester) async {
    final controller = EditableController(text: 'foo bar\nbaz');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));

    await _mouseTapAt(tester, origin + const Offset(52, 5), taps: 2); // 'bar' 内
    expect(controller.selection, const TextSelection(baseOffset: 4, extentOffset: 7));

    await tester.pump(const Duration(milliseconds: 400)); // 连击窗口冷却
    await _mouseTapAt(tester, origin + const Offset(12, 5), taps: 3);
    // 整行含行尾换行。
    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 8));
    await _unmount(tester);
  });

  testWidgets('三击选整行：active 端带 upstream 亲和，光标绘制在选中行行尾而非下一行行首', (tester) async {
    final controller = EditableController(text: 'foo bar\nbaz');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));

    await tester.pump(const Duration(milliseconds: 400));
    await _mouseTapAt(tester, origin + const Offset(12, 5), taps: 3);
    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 8), reason: '三击选行含行尾换行符');
    expect(controller.selection.affinity, TextAffinity.upstream, reason: 'active 端必须带 upstream 亲和（光标停在换行符左侧）');

    final lines = _mountedLines(tester).toList();
    expect(lines, hasLength(2));
    final firstLine = lines.singleWhere((line) => line.index == 0);
    final secondLine = lines.singleWhere((line) => line.index == 1);
    expect(firstLine.paintStateForTest.carets, const [
      EditableLineCaretPaint(offset: 7, upstream: true),
    ], reason: '光标必须绘制在选中行行尾（换行符左侧），不得跳到下一行');
    expect(secondLine.paintStateForTest.carets, isEmpty, reason: '下一行不得绘制 active 光标');
    await _unmount(tester);
  });

  testWidgets('IME 挂客户端携带 viewId（多视图引擎强校验，缺失时桌面端 setClient 抛 view ID is null）', (tester) async {
    final controller = EditableController(text: 'aa');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(5, 5));
    await tester.pump();

    expect(
      tester.testTextInput.setClientArgs?['viewId'],
      tester.view.viewId,
      reason: 'TextInputConfiguration 必须携带所在 FlutterView 的 viewId',
    );
    await _unmount(tester);
  });

  testWidgets('IME 组合期零 setEditingState 回推——Windows 组合被打断=候选拼音无限叠加', (tester) async {
    final controller = EditableController(text: '');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(5, 5));
    await tester.pump();

    tester.testTextInput.log.clear();

    // 真实引擎序列回放（Windows 线级日志录制）：compose-begin 先发 collapsed
    // composing [0,0]——它与本地 empty(-1,-1) 的差异若被当结构偏差回推，
    // 引擎组合跟踪即被打死、后续组合退化为光标处插入（叠加事故实锤触发点）
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange(start: 0, end: 0),
      ),
    );
    await tester.pump();
    // 组合序列 n → ni；'n' 带引擎侧选区微差（-1），钳制归一同样不得回推
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'n',
        selection: TextSelection.collapsed(offset: -1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    // 官方护栏（flutter#65811）：引擎对同值重复通知，必须原样吸收不重放
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();

    expect(controller.text, 'ni', reason: '重复通知不得重放（diff 基线=本地真值，失步单步自愈）');
    expect(
      tester.testTextInput.log.where((c) => c.method == 'TextInput.setEditingState'),
      isEmpty,
      reason: '组合期任何 setEditingState（含选区钳制微差）都会打断 Windows IME 组合，拼音重插',
    );

    // 候选提交：composing 清空、文本替换为汉字
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: '你', selection: TextSelection.collapsed(offset: 1)),
    );
    await tester.pump();
    expect(controller.text, '你');
    expect(controller.composing, TextRange.empty);
    await _unmount(tester);
  });

  testWidgets('IME 输入走窗口化通道', (tester) async {
    final controller = EditableController(text: 'aa\nbb');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(22, 15)); // 'bb' 行尾
    await tester.pump();
    expect(controller.selection.extentOffset, 5);

    // 平台侧眼中的"全文"只是当前行窗口 'bb'。
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'bbX', selection: TextSelection.collapsed(offset: 3)),
    );
    await tester.pump();
    expect(controller.text, 'aa\nbbX');
    expect(controller.selection, const TextSelection.collapsed(offset: 6));

    // composing 映射到 doc 坐标。
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'bbXni',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 3, end: 5),
      ),
    );
    await tester.pump();
    expect(controller.text, 'aa\nbbXni');
    expect(controller.composing, const TextRange(start: 6, end: 8));
    await _unmount(tester);
  });

  testWidgets('平台 full update 插入换行，performAction newline 不重复写入', (tester) async {
    final controller = EditableController(text: 'ab');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(12, 5));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'a\nb', selection: TextSelection.collapsed(offset: 2)),
    );
    await tester.pump();
    final revision = controller.docRevision;
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
    expect(controller.text, 'a\nb');
    expect(controller.document.lineCount, 2);
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
    expect(controller.docRevision, revision);
    await _unmount(tester);
  });

  testWidgets('键盘导航 / 选区扩展 / 删除 / 撤销', (tester) async {
    final controller = EditableController(text: 'abc\ndef');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(2, 5)); // 行首
    await tester.pump();
    expect(controller.selection.extentOffset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection, const TextSelection.collapsed(offset: 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.selection.extentOffset, 5); // 'def' 第 2 列

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(controller.selection.extentOffset, 7);

    // shift+左 扩展选区。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.selection, const TextSelection(baseOffset: 7, extentOffset: 6));

    // 退格删除选区。
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.text, 'abc\nde');

    // 行首退格合并行。
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.text, 'abcde');
    expect(controller.selection, const TextSelection.collapsed(offset: 3));

    // ctrl+Z 撤销(测试平台默认非 mac)。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.text, 'abc\nde');
    await _unmount(tester);
  });

  testWidgets('ctrl+A 全选后输入替换全文', (tester) async {
    final controller = EditableController(text: 'aa\nbb\ncc');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(5, 5));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 8));

    // 全选态窗口覆盖全文,IME 替换 → 全文替换。
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'x', selection: TextSelection.collapsed(offset: 1)),
    );
    await tester.pump();
    expect(controller.text, 'x');
    await _unmount(tester);
  });

  testWidgets('caret 移出视口自动滚动跟随', (tester) async {
    final controller = EditableController(text: List.generate(300, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          scrollController: scrollController,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(5, 5));
    await tester.pump();
    expect(scrollController.position.pixels, 0);

    // 光标跳到文末 → 滚动位置必须跟随(index 定位多帧收敛)。
    controller.collapseTo(controller.document.length);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scrollController.position.pixels, greaterThan(0));
    final mounted = _mountedLines(tester).map((line) => line.index);
    expect(mounted, contains(299));
    await _unmount(tester);
  });

  testWidgets('readOnly 不聚焦、不导航或改选区，并拦截平台编辑', (tester) async {
    const selection = TextSelection(baseOffset: 0, extentOffset: 2);
    final controller = EditableController(text: 'abc')..setSelection(selection);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          style: EditableConfiguration(readOnly: true, textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(2, 5));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
    expect(controller.selection, selection);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.text, 'abc');
    expect(controller.selection, selection);
    await _unmount(tester);
  });

  testWidgets('初始 readOnly 会释放外借 FocusNode 在挂载前已有的焦点', (tester) async {
    final controller = EditableController(text: 'abc');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(_host(Focus(focusNode: focusNode, child: const SizedBox.expand())));
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          style: EditableConfiguration(readOnly: true, autofocus: true, textStyle: _style),
        ),
      ),
    );
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    await _unmount(tester);
  });

  testWidgets('拖选越出下边缘后指针停住：ticker 持续滚动并扩选', (tester) async {
    final controller = EditableController(text: List.generate(200, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(EditableView));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(origin + const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 16));
    // 两段移动（先界内再越界）确保 dragStart+dragUpdate 都派发，
    // 最终拖出下边缘 40px 后**停住不动**
    await gesture.moveTo(origin + const Offset(5, 100));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(origin + const Offset(5, 240));
    await tester.pump(const Duration(milliseconds: 16));
    final extentAfterMove = controller.selection.extentOffset;

    // 指针零移动：自动滚动 ticker 驱动持续扩选（200 行只挂 ~20 行，
    // extent 显著超出首屏即证明滚动真实发生）
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.selection.extentOffset, greaterThan(extentAfterMove), reason: '鼠标不动仍持续滚动扩选（越界深度²曲线）');

    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    await _unmount(tester);
  });

  testWidgets('单行输入底边拖选只允许水平自动滚动，纵向始终钉在起点', (tester) async {
    final controller = EditableController(text: 'a' * 200, singleLine: true);
    final vertical = ScrollController();
    final horizontal = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);
    addTearDown(horizontal.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          scrollController: vertical,
          horizontalScrollController: horizontal,
          style: EditableConfiguration(
            softWrap: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            textStyle: const TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1),
            scrollbars: false,
          ),
        ),
        width: 100,
        height: 30,
      ),
    );
    await tester.pump();
    expect(vertical.position.maxScrollExtent, greaterThan(0), reason: '测试必须覆盖真实行高超过单行视口的现场');
    expect(horizontal.position.maxScrollExtent, greaterThan(0));

    vertical.jumpTo(vertical.position.maxScrollExtent);
    tester.state<EditableViewTestState>(find.byType(EditableView)).ensureCaretVisible();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(vertical.position.pixels, vertical.position.minScrollExtent, reason: '单行显隐收敛必须清除遗留纵向 offset');

    final origin = tester.getTopLeft(find.byType(EditableView));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(origin + const Offset(10, 27));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(origin + const Offset(70, 27));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(origin + const Offset(99, 27));
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.selection.isCollapsed, isFalse);
    expect(vertical.position.pixels, vertical.position.minScrollExtent);
    expect(horizontal.position.pixels, greaterThan(0), reason: '禁用单行纵向滚动不得误伤 nowrap 横向拖选滚动');

    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    expect(vertical.position.pixels, vertical.position.minScrollExtent);
    await _unmount(tester);
  });

  testWidgets('鼠标拖选跨行扩展选区', (tester) async {
    final controller = EditableController(text: 'aaaa\nbbbb\ncccc');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(origin + const Offset(2, 5)); // (0,0) 附近
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(origin + const Offset(60, 5));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(origin + const Offset(22, 25)); // 第 3 行第 2 列
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump();
    await gesture.removePointer();

    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, 12); // 行首 10 + 2
    await _unmount(tester);
  });
}
