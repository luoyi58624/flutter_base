import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 10, height: 1, color: Color(0xff000000));
const _timeout = Timeout(Duration(seconds: 30));

Widget _host(Widget child, {double width = 240, double height = 120}) => MaterialApp(
  home: Align(
    alignment: .topLeft,
    child: SizedBox(width: width, height: height, child: child),
  ),
);

String _document(int lines, {int columns = 1}) =>
    List<String>.generate(lines, (line) => String.fromCharCode(97 + line % 26) * columns).join('\n');

Future<void> _pumpFrames(WidgetTester tester, [int count = 24]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('selectAllRevealsCaret=false：全选后视口停留在原地', (tester) async {
    final controller = EditableController(text: _document(200))..collapseTo(0);
    final vertical = ScrollController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          scrollController: vertical,
          style: EditableConfiguration(
            textStyle: _style,
            cacheExtent: 0,
            autofocus: true,
            selectAllRevealsCaret: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    await _pumpFrames(tester, 4);
    expect(vertical.offset, 0.0);

    controller.selectAll();
    await _pumpFrames(tester, 10);

    expect(
      controller.selection,
      TextSelection(baseOffset: 0, extentOffset: controller.document.length),
      reason: '全选选区语义不变',
    );
    expect(vertical.offset, closeTo(0, 0.01), reason: '关闭全选 reveal 时视口必须保持原地');
  }, timeout: _timeout);

  testWidgets('selectAllRevealsCaret=false：全选后光标留在全选前的位置且保持可见', (tester) async {
    final controller = EditableController(text: _document(200))..collapseTo(10);
    final vertical = ScrollController();
    final focusNode = FocusNode();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          focusNode: focusNode,
          scrollController: vertical,
          style: EditableConfiguration(
            textStyle: _style,
            cacheExtent: 0,
            autofocus: true,
            selectAllRevealsCaret: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    await _pumpFrames(tester, 4);
    final rectBefore = key.currentState!.caretRectInEditor();
    expect(rectBefore, isNotNull, reason: '全选前光标在第 5 行（视口内）应有几何');

    controller.selectAll();
    await _pumpFrames(tester, 10);

    final rectAfter = key.currentState!.caretRectInEditor();
    expect(rectAfter, rectBefore, reason: '全选后光标必须留在全选前的位置（offset 10，第 5 行）且保持可见');
  }, timeout: _timeout);

  testWidgets('默认 style：全选后视口 reveal 到文档末尾', (tester) async {
    final controller = EditableController(text: _document(200))..collapseTo(0);
    final vertical = ScrollController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          scrollController: vertical,
          style: EditableConfiguration(textStyle: _style, cacheExtent: 0, autofocus: true),
        ),
      ),
    );
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    await _pumpFrames(tester, 4);
    expect(vertical.offset, 0.0);

    controller.selectAll();
    await _pumpFrames(tester, 24);

    expect(vertical.offset, greaterThan(0), reason: '默认全选后光标与视口跳到文档末尾');
  }, timeout: _timeout);
}
