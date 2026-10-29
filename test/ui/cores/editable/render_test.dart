import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 通过布局、创建、索引与 IME 负载计数验证渲染窗口和局部失效，不测量耗时。
const _style = TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000));

/// 远大于视口（~20 行 + cache）即可证明挂载窗口有界；勿再上探到 100k。
const _docLines = 2000;

/// 单个用例硬上限：防死锁拖到默认 10 分钟。
const _testTimeout = Timeout(Duration(seconds: 10));

Widget _host(Widget child) {
  return MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: SizedBox(width: 300, height: 200, child: child),
    ),
  );
}

Future<void> _mouseTapAt(WidgetTester tester, Offset position) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.down(position);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.removePointer();
}

String _bigDoc(int lines) => List.generate(lines, (i) => 'line $i lorem ipsum').join('\n');

/// [scrollToIndex] 经 post-frame 收敛；必须先发起 Future 再 [pump]，否则 await 永不到达。
Future<void> _jumpToIndex(WidgetTester tester, ElScrollController controller, int index) async {
  final done = controller.scrollToIndex(index);
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await done.timeout(const Duration(seconds: 2));
}

void main() {
  testWidgets('大文档：挂载窗口与 render 实例数有界', (tester) async {
    final controller = EditableController(text: _bigDoc(_docLines));
    addTearDown(controller.dispose);
    RenderEditableLine.debugResetCounters();

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();

    final mounted = tester.renderObjectList<RenderEditableLine>(find.byType(EditableLineView)).length;
    // 视口 20 行 + cacheExtent 500/10=50 行×2,余量 ×2 兜底。
    expect(mounted, lessThan(250));
    expect(RenderEditableLine.debugCreatedCount, lessThan(400));
    await tester.pumpWidget(const SizedBox());
  }, timeout: _testTimeout);

  testWidgets('caret 可见性翻转只重绘编辑状态层且不重绘正文', (tester) async {
    final controller = EditableController(text: _bigDoc(_docLines));
    addTearDown(controller.dispose);
    controller.collapseTo(controller.document.lineStart(5) + 2);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();

    final mounted = tester.renderObjectList<RenderEditableLine>(find.byType(EditableLineView)).toList();
    final scope = mounted.first.scope;
    scope.pump(focused: true, regularCaretVisible: true);
    await tester.pump();
    expect(mounted.where((line) => line.paintStateForTest.carets.isNotEmpty).map((line) => line.index), [5]);

    RenderEditableLine.debugResetCounters();
    scope.pump(regularCaretVisible: false);
    await tester.pump();

    expect(RenderEditableLine.debugLayoutCount, 0, reason: 'blink phase 不能触发任何 Paragraph 重排');
    expect(RenderEditableLine.debugPaintCount, 0, reason: 'blink phase 复用所有行的正文缓存');
    expect(RenderEditableLine.debugCaretPaintCount, 0, reason: '隐藏相位不能继续绘制 caret');
    await tester.pumpWidget(const SizedBox());
  }, timeout: _testTimeout);

  testWidgets('大文档击键：只重排 1 行、IME 负载与行长同阶、索引不全量重建', (tester) async {
    final controller = EditableController(text: _bigDoc(_docLines));
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
    await _mouseTapAt(tester, origin + const Offset(22, 55)); // 第 6 行
    await tester.pump();
    expect(controller.document.lineIndexOf(controller.selection.extentOffset), 5);

    RenderEditableLine.debugResetCounters();
    TextDocument.debugMaxGetTextSpan = 0;
    final windowText = controller.document.lineAt(5);
    final indexBefore = controller.document.debugValidStartCount;

    // 模拟平台击键：窗口文本插入一个字符。
    tester.testTextInput.updateEditingValue(
      TextEditingValue(text: 'x$windowText', selection: const TextSelection.collapsed(offset: 3)),
    );
    await tester.pump();

    expect(controller.document.lineAt(5).length, windowText.length + 1);
    // 击键最小失效：只有被编辑的行真实重排。
    expect(RenderEditableLine.debugLayoutCount, lessThanOrEqualTo(2));
    // 重绘限于窗口内行（含 caret / 缓存邻行），不得逼近文档规模。
    expect(RenderEditableLine.debugPaintCount, lessThan(40));
    // IME 通道负载与行长同阶（无全文序列化）。
    expect(TextDocument.debugMaxGetTextSpan, lessThan(500));
    // 击键不得触发行首索引全量重建（增量钳制：本拍增长远小于文档行数）。
    expect(controller.document.debugValidStartCount - indexBefore, lessThan(64));
    await tester.pumpWidget(const SizedBox());
  }, timeout: _testTimeout);

  testWidgets('大文档回车（行数变化）：重排 / 创建限于 mounted 窗口', (tester) async {
    final controller = EditableController(text: _bigDoc(_docLines));
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
    await _mouseTapAt(tester, origin + const Offset(22, 55));
    await tester.pump();

    RenderEditableLine.debugResetCounters();
    final remote = tester.testTextInput.editingState!;
    final remoteText = remote['text'] as String;
    final remoteOffset = remote['selectionExtent'] as int;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: remoteText.replaceRange(remoteOffset, remoteOffset, '\n'),
        selection: TextSelection.collapsed(offset: remoteOffset + 1),
      ),
    );
    await tester.pump();
    final revision = controller.docRevision;
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
    await tester.pump();

    expect(controller.document.lineCount, _docLines + 1);
    expect(controller.docRevision, revision, reason: 'newline action 不得在 full update 后再新增一行');
    // itemCount 变化触发窗口 reconcile,重排规模 = mounted 窗口,与文档规模无关。
    expect(RenderEditableLine.debugLayoutCount, lessThan(300));
    expect(RenderEditableLine.debugCreatedCount, lessThan(50));
    await tester.pumpWidget(const SizedBox());
  }, timeout: _testTimeout);

  testWidgets('大文档远距跳转：增量挂载 ~窗口大小', (tester) async {
    final controller = EditableController(text: _bigDoc(_docLines));
    addTearDown(controller.dispose);
    final scrollController = ElScrollController();
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
    RenderEditableLine.debugResetCounters();

    const target = _docLines ~/ 2;
    await _jumpToIndex(tester, scrollController, target);

    final indices = tester
        .renderObjectList<RenderEditableLine>(find.byType(EditableLineView))
        .map((line) => line.index)
        .toList();
    expect(indices, contains(target));
    // 跳转只物化落点窗口(复用 + 新建),不线性扫描中间行。
    expect(RenderEditableLine.debugCreatedCount, lessThan(500));
    expect(RenderEditableLine.debugLayoutCount, lessThan(800));
    await tester.pumpWidget(const SizedBox());
  }, timeout: _testTimeout);
}
