import 'package:example/src/pages/components/event/advanced/examples/editable.dart';
import 'package:example/src/pages/components/event/advanced/examples/selection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

String? _text(WidgetTester tester, String key) => tester.widget<Text>(_key(key)).data;

Future<void> _show(WidgetTester tester, Widget example, {double width = 248}) async {
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: example),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() => tester.pumpWidget(SizedBox()));
}

void main() {
  testWidgets('正文鼠标拖选显示真实选中文本，外层状态收尾且卡片留白仍可打开', (tester) async {
    await _show(tester, ElSelectionClaimExample());
    final controller = tester.widget<ElSelectionView>(_key('advanced-selection-area')).controller!;
    final origin = tester.getTopLeft(_key('advanced-selection-text'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.down(origin + Offset(3, 10));
    await tester.pump();
    expect(_text(tester, 'advanced-selection-pressed'), '按下');
    await mouse.moveTo(origin + Offset(110, 10));
    await tester.pump();
    expect(controller.text, isNotEmpty);
    expect(_text(tester, 'advanced-selection-result'), controller.text);
    expect(_text(tester, 'advanced-selection-moves'), startsWith('外层移动 '));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_text(tester, 'advanced-selection-pressed'), '松开');
    expect(_text(tester, 'advanced-selection-opens'), '打开 0');

    await tester.tap(_key('advanced-selection-header'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'advanced-selection-opens'), '打开 1');
    await tester.tap(_key('advanced-selection-reset'));
    await tester.pumpAndSettle();
    expect(controller.text, isNull);
    expect(_text(tester, 'advanced-selection-result'), '—');
    expect(_text(tester, 'advanced-selection-opens'), '打开 0');
    expect(_text(tester, 'advanced-selection-moves'), '外层移动 0');
  });

  testWidgets('编辑器从正文直接跨过10px拖动，应产生真实选区并结束外层按压', (tester) async {
    await _show(tester, ElEditableSelectionExample());
    final editor = _key('advanced-editable-editor');
    final controller = tester.widget<ElEditableView>(editor).controller!;
    final origin = tester.getTopLeft(editor);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.down(origin + Offset(14, 22));
    await tester.pump(Duration(milliseconds: 16));
    expect(_text(tester, 'advanced-editable-pressed'), '按下');
    await mouse.moveTo(origin + Offset(120, 68));
    await tester.pump(Duration(milliseconds: 16));
    expect(_text(tester, 'advanced-editable-range'), '选区 ${controller.selection.start}–${controller.selection.end}');
    expect(_text(tester, 'advanced-editable-result'), controller.selectedText.isEmpty ? '—' : controller.selectedText);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(
      controller.selection.isCollapsed,
      isFalse,
      reason:
          '真实拖选现场：${_text(tester, 'advanced-editable-range')}，'
          '${_text(tester, 'advanced-editable-opens')}，'
          '外层${_text(tester, 'advanced-editable-pressed')}；不得用预设选区掩盖未起拖',
    );
    expect(_text(tester, 'advanced-editable-pressed'), '松开');
    expect(_text(tester, 'advanced-editable-opens'), '打开 0');
  });

  testWidgets('窄屏编辑器接收真实输入、显示选区并复位正文与焦点', (tester) async {
    await _show(tester, ElEditableSelectionExample(), width: 220);
    final editor = _key('advanced-editable-editor');
    final view = tester.widget<ElEditableView>(editor);
    final controller = view.controller!;
    final original = controller.text;
    expect(tester.getSize(editor).height, 200);
    expect(tester.takeException(), isNull);
    await tester.tapAt(tester.getTopLeft(editor) + Offset(20, 22));
    await tester.pump();
    controller.selectAll();
    await tester.pump();
    tester.testTextInput.enterText('修改后的备忘');
    await tester.pump();
    expect(controller.text, '修改后的备忘');
    controller.selectAll();
    await tester.pump();
    expect(_text(tester, 'advanced-editable-result'), '修改后的备忘');
    expect(_text(tester, 'advanced-editable-range'), '选区 0–6');
    await tester.tap(_key('advanced-editable-reset'));
    await tester.pumpAndSettle();
    expect(controller.text, original);
    expect(controller.selection, TextSelection.collapsed(offset: 0));
    expect(view.focusNode!.hasFocus, isFalse);
    expect(_text(tester, 'advanced-editable-result'), '—');
    expect(_text(tester, 'advanced-editable-opens'), '打开 0');
    expect(_text(tester, 'advanced-editable-pressed'), '松开');
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏文本区域可触屏长按选择并清空', (tester) async {
    await _show(tester, ElSelectionClaimExample(), width: 220);
    final controller = tester.widget<ElSelectionView>(_key('advanced-selection-area')).controller!;
    final origin = tester.getTopLeft(_key('advanced-selection-text'));
    final touch = await tester.startGesture(origin + Offset(20, 12));
    await tester.pump(Duration(milliseconds: 650));
    expect(controller.text, isNotEmpty);
    expect(_text(tester, 'advanced-selection-result'), controller.text);
    await touch.up();
    await tester.pumpAndSettle();
    expect(_text(tester, 'advanced-selection-pressed'), '松开');
    expect(_text(tester, 'advanced-selection-opens'), '打开 0');
    await tester.tap(_key('advanced-selection-reset'));
    await tester.pumpAndSettle();
    expect(controller.text, isNull);
    expect(_text(tester, 'advanced-selection-result'), '—');
    expect(tester.takeException(), isNull);
  });
}
