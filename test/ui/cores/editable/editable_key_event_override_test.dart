import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 10, height: 1, color: Color(0xff000000));

Widget _host(Widget child) {
  return MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: SizedBox(width: 240, height: 120, child: child),
    ),
  );
}

Future<void> _unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  testWidgets('前置回调 handled 时方向键不移动 caret', (tester) async {
    final controller = EditableController(text: 'abc');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var calls = 0;

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          style: EditableConfiguration(
            textStyle: _style,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
                calls++;
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    controller.collapseTo(1);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

    expect(calls, 1, reason: 'keyup 不应重复触发业务动作');
    expect(controller.selection.extentOffset, 1, reason: 'handled 必须截断编辑器 caret 导航');
    await _unmount(tester);
  });

  testWidgets('前置回调 ignored 时回落编辑器默认处理', (tester) async {
    final controller = EditableController(text: 'abc');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          style: EditableConfiguration(textStyle: _style, onKeyEvent: (_, _) => KeyEventResult.ignored),
        ),
      ),
    );
    focusNode.requestFocus();
    controller.collapseTo(1);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

    expect(controller.selection.extentOffset, 2, reason: 'ignored 必须保留编辑器原有行为');
    await _unmount(tester);
  });

  testWidgets('readOnly 只调用业务与外借 handler，不进入内建 keymap 并返回向外冒泡', (tester) async {
    const selection = TextSelection.collapsed(offset: 1);
    final controller = EditableController(text: 'abc')..setSelection(selection);
    final focusNode = FocusNode();
    final calls = <String>[];
    focusNode.onKeyEvent = (_, _) {
      calls.add('external');
      return KeyEventResult.ignored;
    };
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          style: EditableConfiguration(
            readOnly: true,
            textStyle: _style,
            onKeyEvent: (_, _) {
              calls.add('business');
              return KeyEventResult.ignored;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final result = focusNode.onKeyEvent!(
      focusNode,
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowRight,
        logicalKey: LogicalKeyboardKey.arrowRight,
        timeStamp: Duration.zero,
      ),
    );

    expect(calls, <String>['business', 'external']);
    expect(result, KeyEventResult.ignored);
    expect(controller.selection, selection);
    await _unmount(tester);
  });
}
