import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 10, height: 1, color: Color(0xff000000));
const _testTimeout = Timeout(Duration(seconds: 40));

Widget _host(Widget child, {double width = 320, double height = 180}) {
  return MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, height: height, child: child),
    ),
  );
}

String _largeDocument(int lineCount, {int? longLine, int longLineLength = 0}) {
  final buffer = StringBuffer();
  for (var line = 0; line < lineCount; line++) {
    if (line > 0) buffer.write('\n');
    buffer.write(line == longLine ? 'w' * longLineLength : 'x');
  }
  return buffer.toString();
}

Future<void> _pumpFrames(WidgetTester tester, [int count = 24]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

List<RenderEditableLine> _mountedLines(WidgetTester tester) =>
    tester.renderObjectList<RenderEditableLine>(find.byType(EditableLineView)).toList(growable: false);

({RenderEditableLine line, double delta}) _firstVisibleLine(WidgetTester tester) {
  final viewport = tester.getRect(find.byType(EditableView));
  final visible =
      _mountedLines(tester)
          .map((line) => (line: line, top: line.localToGlobal(Offset.zero).dy))
          .where((entry) => entry.top + entry.line.size.height > viewport.top && entry.top < viewport.bottom)
          .toList()
        ..sort((a, b) => a.top.compareTo(b.top));
  final first = visible.first;
  return (line: first.line, delta: first.top - viewport.top);
}

final class _VariableHeightComposer extends EditableComposer {
  const _VariableHeightComposer();

  @override
  InlineSpan compose(EditableLineContext context) {
    return TextSpan(
      text: context.text,
      style: context.baseStyle.copyWith(fontSize: context.line.isEven ? 8 : 24, height: 1),
    );
  }
}

void main() {
  testWidgets('百万行远跳 latest-wins，远列双轴精调且挂载保持窗口级', (tester) async {
    const lineCount = 1000000;
    const firstTarget = 900000;
    const latestTarget = 123456;
    const longLine = 750000;
    final controller = EditableController(text: _largeDocument(lineCount, longLine: longLine, longLineLength: 12000));
    final vertical = ElScrollController();
    final horizontal = ScrollController();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);
    addTearDown(horizontal.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          scrollController: vertical,
          horizontalScrollController: horizontal,
          style: EditableConfiguration(textStyle: _style, softWrap: false, cacheExtent: 0),
        ),
      ),
    );
    await tester.pump();

    controller.collapseTo(controller.document.lineStart(firstTarget));
    final supersededReveal = key.currentState!.revealCaret();
    controller.collapseTo(controller.document.lineStart(latestTarget));
    final latestReveal = key.currentState!.revealCaret();
    await _pumpFrames(tester);

    expect(await supersededReveal.timeout(const Duration(seconds: 2)), isFalse);
    expect(await latestReveal.timeout(const Duration(seconds: 2)), isTrue);
    expect(_mountedLines(tester).map((line) => line.index), contains(latestTarget));
    expect(_mountedLines(tester).map((line) => line.index), isNot(contains(firstTarget)));
    final latestCaret = key.currentState!.caretRectInEditor();
    expect(latestCaret, isNotNull);
    expect(latestCaret!.top, greaterThanOrEqualTo(-0.5));
    expect(latestCaret.bottom, lessThanOrEqualTo(180.5));

    controller.collapseTo(controller.document.lineEnd(longLine));
    final farColumnReveal = key.currentState!.revealCaret();
    await _pumpFrames(tester, 32);
    expect(await farColumnReveal.timeout(const Duration(seconds: 2)), isTrue);
    final farCaret = key.currentState!.caretRectInEditor();
    expect(farCaret, isNotNull);
    expect(farCaret!.top, greaterThanOrEqualTo(-0.5));
    expect(farCaret.bottom, lessThanOrEqualTo(180.5));
    expect(farCaret.left, greaterThanOrEqualTo(-0.5));
    expect(farCaret.right, lessThanOrEqualTo(320.5));
    expect(horizontal.offset, greaterThan(1000));
    expect(_mountedLines(tester).length, lessThan(80));
  }, timeout: _testTimeout);

  testWidgets('百万行变量高度远跳在有限帧内收敛到真实 caret', (tester) async {
    const target = 876543;
    final controller = EditableController(text: _largeDocument(1000000));
    final vertical = ElScrollController();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          scrollController: vertical,
          style: EditableConfiguration(composer: const _VariableHeightComposer(), textStyle: _style, cacheExtent: 0),
        ),
      ),
    );
    await tester.pump();
    controller.collapseTo(controller.document.lineStart(target));
    final reveal = key.currentState!.revealCaret();
    await _pumpFrames(tester, 32);

    expect(await reveal.timeout(const Duration(seconds: 2)), isTrue);
    expect(_mountedLines(tester).map((line) => line.index), contains(target));
    final caret = key.currentState!.caretRectInEditor();
    expect(caret, isNotNull);
    expect(caret!.top, greaterThanOrEqualTo(-0.5));
    expect(caret.bottom, lessThanOrEqualTo(180.5));
    expect(_mountedLines(tester).length, lessThan(100));
  }, timeout: _testTimeout);

  testWidgets('soft-wrap 超高行末端经真实几何二次精调可见', (tester) async {
    final controller = EditableController(text: 'wrap ' * 10000);
    final vertical = ElScrollController();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          scrollController: vertical,
          style: EditableConfiguration(textStyle: _style),
        ),
        width: 180,
        height: 120,
      ),
    );
    await tester.pump();
    controller.collapseTo(controller.document.length);
    final reveal = key.currentState!.revealCaret();
    await _pumpFrames(tester, 24);

    expect(await reveal.timeout(const Duration(seconds: 2)), isTrue);
    final caret = key.currentState!.caretRectInEditor();
    expect(caret, isNotNull);
    expect(caret!.bottom, lessThanOrEqualTo(120.5));
    expect(caret.top, greaterThanOrEqualTo(-0.5));
    expect(vertical.offset, greaterThan(1000));
  }, timeout: _testTimeout);

  testWidgets('可等待 reveal 在结构变化、controller 换绑与卸载时明确取消', (tester) async {
    final first = EditableController(text: _largeDocument(10000));
    final second = EditableController(text: _largeDocument(10000));
    final vertical = ElScrollController();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(vertical.dispose);

    Widget editor(EditableController controller) => _host(
      EditableView(
        key: key,
        controller: controller,
        scrollController: vertical,
        style: EditableConfiguration(textStyle: _style, cacheExtent: 0),
      ),
    );

    await tester.pumpWidget(editor(first));
    await tester.pump();

    first.collapseTo(first.document.lineStart(9000));
    final changed = key.currentState!.revealCaret();
    first.replaceRange(0, 0, 'prefix\n');
    expect(await changed.timeout(const Duration(seconds: 2)), isFalse, reason: '结构变化必须终止旧坐标请求');

    first.collapseTo(first.document.lineStart(8000));
    final rebound = key.currentState!.revealCaret();
    await tester.pumpWidget(editor(second));
    expect(await rebound.timeout(const Duration(seconds: 2)), isFalse, reason: 'controller 换绑不得让旧请求继续滚动');

    second.collapseTo(second.document.lineStart(7000));
    final disposed = key.currentState!.revealCaret();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(await disposed.timeout(const Duration(seconds: 2)), isFalse, reason: '卸载必须结清公开 Future');
  }, timeout: _testTimeout);

  testWidgets('nowrap 已知最长宽度滚离不缩水，短行编辑稳定，删除最长回落第二宽', (tester) async {
    final longest = 'W' * 600;
    final second = 'W' * 300;
    final controller = EditableController(text: <String>[longest, second, ...List<String>.filled(800, 'x')].join('\n'));
    final vertical = ElScrollController();
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
          style: EditableConfiguration(textStyle: _style, softWrap: false, cacheExtent: 0),
        ),
      ),
    );
    await _pumpFrames(tester, 4);
    final longestExtent = horizontal.position.maxScrollExtent;
    expect(longestExtent, greaterThan(1000));

    final jump = vertical.scrollToIndex(500);
    await _pumpFrames(tester, 16);
    await jump;
    expect(horizontal.position.maxScrollExtent, closeTo(longestExtent, 1));

    final shortStart = controller.document.lineStart(500);
    controller.replaceRange(shortStart, shortStart + 1, 'yy');
    await _pumpFrames(tester, 4);
    expect(horizontal.position.maxScrollExtent, closeTo(longestExtent, 1));

    controller.deleteRange(0, controller.document.lineStart(1));
    await _pumpFrames(tester, 6);
    final fallbackExtent = horizontal.position.maxScrollExtent;
    expect(fallbackExtent, lessThan(longestExtent - 500));
    expect(fallbackExtent, greaterThan(500));
  }, timeout: _testTimeout);

  testWidgets('头部插删与删除当前 anchor 保持幸存正文及行内像素位置，API 编辑不拉回 caret', (tester) async {
    final controller = EditableController(text: List<String>.generate(1200, (i) => 'row-$i').join('\n'));
    final vertical = ElScrollController();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          scrollController: vertical,
          style: EditableConfiguration(textStyle: _style, cacheExtent: 0),
        ),
      ),
    );
    await tester.pump();
    final jump = vertical.scrollToIndex(600, alignment: 0.35);
    await _pumpFrames(tester, 16);
    await jump;
    final before = _firstVisibleLine(tester);
    final anchoredText = controller.document.lineAt(before.line.index);
    final offsetBefore = vertical.offset;

    controller.replaceRange(0, 0, 'prepended-a\nprepended-b\n');
    await _pumpFrames(tester, 6);
    final afterPrepend = _firstVisibleLine(tester);
    expect(controller.document.lineAt(afterPrepend.line.index), anchoredText);
    expect(afterPrepend.delta, closeTo(before.delta, 0.75));
    expect(vertical.offset, greaterThan(offsetBefore), reason: '前缀增高应补偿 pixels，而不是把正文向下推');

    final beforeDelete = _firstVisibleLine(tester);
    final beforeDeleteText = controller.document.lineAt(beforeDelete.line.index);
    controller.deleteRange(0, controller.document.lineStart(4));
    await _pumpFrames(tester, 6);
    final afterDelete = _firstVisibleLine(tester);
    expect(controller.document.lineAt(afterDelete.line.index), beforeDeleteText);
    expect(afterDelete.delta, closeTo(beforeDelete.delta, 0.75));

    final deletedAnchor = _firstVisibleLine(tester);
    final survivorText = controller.document.lineAt(deletedAnchor.line.index + 1);
    final anchorStart = controller.document.lineStart(deletedAnchor.line.index);
    final survivorStart = controller.document.lineStart(deletedAnchor.line.index + 1);
    controller.deleteRange(anchorStart, survivorStart);
    await _pumpFrames(tester, 6);
    final afterAnchorDelete = _firstVisibleLine(tester);
    expect(controller.document.lineAt(afterAnchorDelete.line.index), survivorText);
    expect(afterAnchorDelete.delta, closeTo(deletedAnchor.delta, 0.75));
  }, timeout: _testTimeout);

  testWidgets('离屏脏行丢弃陈旧实测高度，并保持当前可视 anchor', (tester) async {
    final controller = EditableController(
      text: <String>['wide ' * 120, ...List<String>.generate(500, (i) => 'row-$i')].join('\n'),
    );
    final vertical = ElScrollController();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          scrollController: vertical,
          style: EditableConfiguration(textStyle: _style, cacheExtent: 0),
        ),
        width: 180,
        height: 120,
      ),
    );
    await _pumpFrames(tester, 4);
    final state = tester.state<ElScrollViewState>(find.byType(ElScrollView));
    expect(state.debugCounters.debugMeasuredItemCount, greaterThan(0));

    final jump = vertical.scrollToIndex(250);
    await _pumpFrames(tester, 16);
    await jump;
    final anchorBefore = _firstVisibleLine(tester);
    final anchorText = controller.document.lineAt(anchorBefore.line.index);
    final measuredBeforeEdit = state.debugCounters.debugMeasuredItemCount;

    controller.replaceRange(0, controller.document.lineEnd(0), 'short');
    await _pumpFrames(tester, 5);
    final anchorAfter = _firstVisibleLine(tester);
    expect(controller.document.lineAt(anchorAfter.line.index), anchorText);
    expect(anchorAfter.delta, closeTo(anchorBefore.delta, 0.75));
    expect(
      state.debugCounters.debugMeasuredItemCount,
      lessThan(measuredBeforeEdit),
      reason: '离屏第 0 行必须退回 estimate，不能把旧超高 extent 永久标成 measured',
    );

    final back = vertical.scrollToIndex(0);
    await _pumpFrames(tester, 16);
    await back;
    expect(_mountedLines(tester).firstWhere((line) => line.index == 0).size.height, lessThan(20));
  }, timeout: _testTimeout);
}
