import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

Widget _host({
  required EditableController controller,
  ElEvent? event,
  ElEvent? ancestorEvent,
  bool readOnly = false,
  bool interactive = true,
}) => MaterialApp(
  home: Align(
    alignment: .topLeft,
    child: ElView(
      style: ElStyle(width: 300, height: 200),
      event: ancestorEvent,
      child: EditableView(
        controller: controller,
        event: event,
        style: EditableConfiguration(
          readOnly: readOnly,
          enableInteractiveSelection: interactive,
          textStyle: TextStyle(fontSize: 10, height: 1, color: Colors.black),
        ),
      ),
    ),
  ),
);

Future<EditableController> _mount(WidgetTester tester, {ElEvent? event, ElEvent? ancestorEvent}) async {
  final controller = EditableController(text: 'alpha beta gamma\ndelta epsilon');
  addTearDown(controller.dispose);
  addTearDown(() => tester.pumpWidget(SizedBox()));
  await tester.pumpWidget(_host(controller: controller, event: event, ancestorEvent: ancestorEvent));
  await tester.pump();
  return controller;
}

Future<void> _move(WidgetTester tester, TestGesture gesture, Offset position) async {
  await gesture.moveTo(position);
  await tester.pump(Duration(milliseconds: 16));
}

void main() {
  setUp(EventDispatcher.debugReset);

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.stylus]) {
    testWidgets('${kind.name} 跨过点击取消距离仍从按下位置拖选，松手不误点外层', (tester) async {
      var opens = 0;
      final controller = await _mount(tester, ancestorEvent: ElEvent(onTap: (_) => opens++));
      final origin = tester.getTopLeft(find.byType(EditableView));
      final pointer = await tester.createGesture(kind: kind);
      addTearDown(pointer.removePointer);
      await pointer.down(origin + Offset(2, 5));
      await tester.pump(Duration(milliseconds: 16));
      await _move(tester, pointer, origin + Offset(62, 5));
      expect(controller.selection, TextSelection(baseOffset: 0, extentOffset: 6));
      await _move(tester, pointer, origin + Offset(122, 5));
      expect(controller.selection, TextSelection(baseOffset: 0, extentOffset: 12));
      await pointer.up();
      await tester.pump();
      expect(controller.selection, TextSelection(baseOffset: 0, extentOffset: 12));
      expect(opens, 0);
    });
  }

  for (final canceled in [false, true]) {
    testWidgets('手写笔仅取消点击后${canceled ? '取消指针' : '松手'}，下一次拖选使用新锚点', (tester) async {
      final controller = await _mount(tester);
      final origin = tester.getTopLeft(find.byType(EditableView));
      final pointer = await tester.createGesture(kind: PointerDeviceKind.stylus);
      addTearDown(pointer.removePointer);
      await pointer.down(origin + Offset(2, 5));
      await tester.pump(Duration(milliseconds: 16));
      await _move(tester, pointer, origin + Offset(14, 5));
      expect(controller.selection, TextSelection.collapsed(offset: 0));
      if (canceled) {
        await pointer.cancel();
      } else {
        await pointer.up();
      }
      await tester.pump(Duration(milliseconds: 400));
      expect(controller.selection, TextSelection.collapsed(offset: 0));
      await pointer.down(origin + Offset(82, 5));
      await tester.pump(Duration(milliseconds: 16));
      await _move(tester, pointer, origin + Offset(142, 5));
      expect(controller.selection, TextSelection(baseOffset: 8, extentOffset: 14));
      await pointer.up();
      await tester.pump();
    });
  }

  testWidgets('手写笔在 Up 内补发短快划时，仍能消费按下时的选择候选', (tester) async {
    final controller = await _mount(tester);
    final origin = tester.getTopLeft(find.byType(EditableView));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.stylus);
    addTearDown(pointer.removePointer);
    await pointer.down(origin + Offset(2, 5));
    await tester.pump();
    await pointer.moveTo(origin + Offset(14, 5), timeStamp: Duration(milliseconds: 8));
    await tester.pump();
    expect(controller.selection, TextSelection.collapsed(offset: 0));
    await pointer.up(timeStamp: Duration(milliseconds: 16));
    await tester.pump();
    expect(controller.selection, TextSelection(baseOffset: 0, extentOffset: 1));
  });

  testWidgets('外层官方纵向手势胜出后旧候选不再扩选，下次鼠标拖选仍正常', (tester) async {
    final controller = EditableController(text: 'alpha beta gamma\ndelta epsilon');
    addTearDown(controller.dispose);
    addTearDown(() => tester.pumpWidget(SizedBox()));
    var scrollUpdates = 0;
    await tester.pumpWidget(
      GestureDetector(
        onVerticalDragUpdate: (_) => scrollUpdates++,
        child: _host(controller: controller),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    final stylus = await tester.createGesture(kind: PointerDeviceKind.stylus);
    addTearDown(stylus.removePointer);
    await stylus.down(origin + Offset(2, 5));
    await tester.pump(Duration(milliseconds: 16));
    await _move(tester, stylus, origin + Offset(2, 25));
    await _move(tester, stylus, origin + Offset(2, 65));
    expect(scrollUpdates, greaterThan(0));
    expect(controller.selection, TextSelection.collapsed(offset: 0));
    await stylus.up();
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.down(origin + Offset(82, 5));
    await tester.pump(Duration(milliseconds: 16));
    await _move(tester, mouse, origin + Offset(142, 5));
    expect(controller.selection, TextSelection(baseOffset: 8, extentOffset: 14));
    await mouse.up();
    await tester.pump();
  });

  testWidgets('双击拖词越过点击取消距离后仍按整词扩选，松手不重复改选区', (tester) async {
    final controller = await _mount(tester);
    final origin = tester.getTopLeft(find.byType(EditableView));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(pointer.removePointer);
    await pointer.down(origin + Offset(72, 5));
    await tester.pump(Duration(milliseconds: 16));
    await pointer.up();
    await tester.pump(Duration(milliseconds: 60));
    await pointer.down(origin + Offset(72, 5));
    await tester.pump(Duration(milliseconds: 16));
    expect(controller.selection, TextSelection(baseOffset: 6, extentOffset: 10));
    await _move(tester, pointer, origin + Offset(122, 5));
    expect(controller.selection, TextSelection(baseOffset: 6, extentOffset: 16));
    await pointer.up();
    await tester.pump();
    expect(controller.selection, TextSelection(baseOffset: 6, extentOffset: 16));
  });

  testWidgets('鼠标按键组合变化属于真正取消，后续主键移动不沿用原锚点', (tester) async {
    final controller = await _mount(tester);
    final origin = tester.getTopLeft(find.byType(EditableView));
    final pointer = await tester.createGesture(pointer: 41, kind: PointerDeviceKind.mouse);
    addTearDown(pointer.removePointer);
    await pointer.down(origin + Offset(2, 5));
    await tester.pump(Duration(milliseconds: 16));
    await tester.sendEventToBinding(
      PointerMoveEvent(
        pointer: 41,
        kind: PointerDeviceKind.mouse,
        position: origin + Offset(62, 5),
        delta: Offset(60, 0),
        buttons: kPrimaryMouseButton | kSecondaryMouseButton,
      ),
    );
    await tester.pump();
    await _move(tester, pointer, origin + Offset(122, 5));
    expect(controller.selection, TextSelection.collapsed(offset: 0));
    await pointer.up();
    await tester.pump();
  });

  for (final transition in ['readOnly', '禁选', '卸载']) {
    testWidgets('候选阶段$transition再恢复，旧指针不能继续扩选且新拖选正常', (tester) async {
      final controller = await _mount(tester);
      final origin = tester.getTopLeft(find.byType(EditableView));
      final pointer = await tester.createGesture(kind: PointerDeviceKind.stylus);
      addTearDown(pointer.removePointer);
      await pointer.down(origin + Offset(2, 5));
      await tester.pump(Duration(milliseconds: 16));
      await _move(tester, pointer, origin + Offset(14, 5));
      expect(controller.selection, TextSelection.collapsed(offset: 0));
      await tester.pumpWidget(
        transition == '卸载'
            ? SizedBox()
            : _host(controller: controller, readOnly: transition == 'readOnly', interactive: transition != '禁选'),
      );
      await tester.pump();
      await tester.pumpWidget(_host(controller: controller));
      await tester.pump();
      await _move(tester, pointer, origin + Offset(62, 5));
      expect(controller.selection, TextSelection.collapsed(offset: 0));
      await pointer.up();
      await tester.pump(Duration(milliseconds: 400));
      await pointer.down(origin + Offset(82, 5));
      await tester.pump(Duration(milliseconds: 16));
      await _move(tester, pointer, origin + Offset(142, 5));
      expect(controller.selection, TextSelection(baseOffset: 8, extentOffset: 14));
      await pointer.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('点击取消回调改写文档后不能套用按下时的选择快照', (tester) async {
    final controller = EditableController(text: 'alpha beta gamma');
    addTearDown(controller.dispose);
    addTearDown(() => tester.pumpWidget(SizedBox()));
    await tester.pumpWidget(
      _host(
        controller: controller,
        event: ElEvent(
          onTapCancel: (_) {
            controller.text = 'other content';
            controller.setSelection(TextSelection.collapsed(offset: 5));
          },
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(pointer.removePointer);
    await pointer.down(origin + Offset(2, 5));
    await tester.pump(Duration(milliseconds: 16));
    await _move(tester, pointer, origin + Offset(62, 5));
    expect(controller.text, 'other content');
    expect(controller.selection, TextSelection.collapsed(offset: 5));
    await _move(tester, pointer, origin + Offset(122, 5));
    expect(controller.selection, TextSelection.collapsed(offset: 5));
    await pointer.up();
    await tester.pump();
  });
}
