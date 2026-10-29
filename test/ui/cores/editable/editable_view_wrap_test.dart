import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000));

Widget _host(Widget child, {double width = 100, double height = 200}) {
  return MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: SizedBox(width: width, height: height, child: child),
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

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('wrap：点击第二视觉行定位到正确 offset', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'a' * 20);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(22, 15)); // 第二视觉行 x=22
    expect(controller.selection.extentOffset, 12);
    await _unmount(tester);
  });

  testWidgets('wrap：End/Home 走视觉行 + caret 亲和几何', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'a' * 20);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(32, 5)); // 第一视觉行
    expect(controller.selection.extentOffset, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(controller.selection.extentOffset, 10);
    expect(controller.selection.affinity, TextAffinity.upstream);
    // upstream：caret 画在第一视觉行行尾。
    final upstreamRect = key.currentState!.caretRectInEditor()!;
    expect(upstreamRect.top, 0);

    controller.setSelection(const TextSelection.collapsed(offset: 10)); // downstream
    await tester.pump();
    final downstreamRect = key.currentState!.caretRectInEditor()!;
    expect(downstreamRect.top, 10);
    expect(downstreamRect.left, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(controller.selection.extentOffset, 10); // downstream 归属第二视觉行,Home 回其行首
    await _unmount(tester);
  });

  testWidgets('wrap：上下移动穿越视觉行', (tester) async {
    final controller = EditableController(text: '${'a' * 20}\nzz');
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
    await _mouseTapAt(tester, origin + const Offset(32, 5));
    expect(controller.selection.extentOffset, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.selection.extentOffset, 13); // 同逻辑行第二视觉行

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.selection.extentOffset, 23); // 'zz' 行(xGoal 钳行尾)
    await _unmount(tester);
  });

  testWidgets('nowrap 双轴：行尾输入横向自动跟随', (tester) async {
    final controller = EditableController(text: 'x' * 30);
    addTearDown(controller.dispose);
    final hController = ScrollController();
    addTearDown(hController.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          horizontalScrollController: hController,
          style: EditableConfiguration(softWrap: false, textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(50, 5));
    await tester.pump();

    controller.collapseTo(30); // 行尾 x=300,视口宽 100
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(hController.position.pixels, greaterThan(150));
    await _unmount(tester);
  });

  testWidgets('几何门面：positionAtGlobal / rectAtOffset / caretRectGlobal', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: List.generate(200, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
        width: 300,
      ),
    );
    await tester.pump();
    final state = key.currentState!;
    final origin = tester.getTopLeft(find.byType(EditableView));

    // 命中第 3 行第 2 列。
    final position = state.positionAtGlobal(origin + const Offset(22, 25));
    expect(position.offset, controller.document.lineStart(2) + 2);

    // 视口下方越界钳到最近 mounted 行。
    final below = state.positionAtGlobal(origin + const Offset(5, 5000));
    expect(controller.document.lineIndexOf(below.offset), greaterThan(10));

    // mounted 行 caret 几何;未 mounted 行返回 null。
    controller.collapseTo(controller.document.lineStart(1) + 3);
    await tester.pump();
    final rect = state.caretRectInEditor()!;
    expect(rect.left, 30);
    expect(rect.top, 10);
    final global = state.caretRectGlobal()!;
    expect(global.topLeft, origin + rect.topLeft);
    expect(state.rectAtOffset(controller.document.lineStart(199)), isNull);
    await _unmount(tester);
  });

  testWidgets('caretRectGlobal 完整应用祖先 scale 与 translation', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abcd')..collapseTo(2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: Transform.translate(
            offset: const Offset(37, 23),
            child: Transform.scale(
              scaleX: 2,
              scaleY: 3,
              alignment: .topLeft,
              child: SizedBox(
                width: 100,
                height: 80,
                child: EditableView(
                  key: key,
                  controller: controller,
                  style: EditableConfiguration(textStyle: _style),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final local = key.currentState!.caretRectInEditor()!;
    final global = key.currentState!.caretRectGlobal()!;
    expect(global.left, closeTo(37 + local.left * 2, 0.001));
    expect(global.top, closeTo(23 + local.top * 3, 0.001));
    expect(global.width, closeTo(local.width * 2, 0.001));
    expect(global.height, closeTo(local.height * 3, 0.001));
    await _unmount(tester);
  });

  testWidgets('caretRectGlobal 对祖先 rotation 返回四角包围矩形', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abcd')..collapseTo(2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: Transform.rotate(
            angle: math.pi / 2,
            alignment: .topLeft,
            child: SizedBox(
              width: 100,
              height: 80,
              child: EditableView(
                key: key,
                controller: controller,
                style: EditableConfiguration(textStyle: _style),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final local = key.currentState!.caretRectInEditor()!;
    final global = key.currentState!.caretRectGlobal()!;
    expect(global.left, closeTo(-local.bottom, 0.001));
    expect(global.top, closeTo(local.left, 0.001));
    expect(global.right, closeTo(-local.top, 0.001));
    expect(global.bottom, closeTo(local.right, 0.001));
    await _unmount(tester);
  });

  testWidgets('caretRectGlobal 在不可逆变换与卸载后返回 null', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abcd')..collapseTo(2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: Transform.scale(
            scale: 0,
            alignment: .topLeft,
            child: SizedBox(
              width: 100,
              height: 80,
              child: EditableView(
                key: key,
                controller: controller,
                style: EditableConfiguration(textStyle: _style),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final state = key.currentState!;
    expect(state.caretRectInEditor(), isNotNull);
    expect(state.caretRectGlobal(), isNull);

    await _unmount(tester);
    expect(state.caretRectGlobal(), isNull);
  });

  testWidgets('textScaler 变化触发整体重排且几何缩放', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abcd');
    addTearDown(controller.dispose);

    Widget build(double scale) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 300,
              height: 200,
              child: EditableView(
                key: key,
                controller: controller,
                style: EditableConfiguration(textStyle: _style),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(1.0));
    await tester.pump();
    controller.collapseTo(2);
    await tester.pump();
    expect(key.currentState!.caretRectInEditor()!.left, 20);

    await tester.pumpWidget(build(2.0));
    await tester.pump();
    expect(key.currentState!.caretRectInEditor()!.left, 40);
    await _unmount(tester);
  });
}
