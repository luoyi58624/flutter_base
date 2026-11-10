import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 大选区 IME 窗口钳制与运行期 prop 更新的回归：直接 import src（与
/// editable_controller_test 同惯例），不受公开入口其他模块编译状态影响。
const _style = TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000));

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

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('大文档 ctrl+A：IME 窗口钳制不整篇推通道，输入仍替换全文', (tester) async {
    final controller = EditableController(text: List.generate(120, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: const EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(5, 5));
    await tester.pump();

    final docLen = controller.document.length;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.selection, TextSelection(baseOffset: 0, extentOffset: docLen));

    // 全选推给平台的"全文"只是 caret 邻域窗口，不得整篇物化过通道。
    final pushed = tester.testTextInput.editingState?['text'] as String?;
    expect(pushed, isNotNull);
    expect(pushed!.length, lessThan(docLen ~/ 2), reason: '全选不得把全文推平台通道');

    // 平台替换其窗口视图里的钳制选区 = 用户对整个选区的替换。
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'x', selection: TextSelection.collapsed(offset: 1)),
    );
    await tester.pump();
    expect(controller.text, 'x');
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
    await _unmount(tester);
  });

  testWidgets('运行期换 scrollController：监听随迁，滚动仍驱动 IME 几何同步', (tester) async {
    final controller = EditableController(text: List.generate(300, (i) => 'line $i').join('\n'));
    addTearDown(controller.dispose);
    final external = ScrollController();
    addTearDown(external.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: const EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EditableView));
    await _mouseTapAt(tester, origin + const Offset(5, 5));
    await tester.pump();

    // 换成外部滚动控制器（受控滚动的合法运行期操作）。
    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          scrollController: external,
          style: const EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();

    tester.testTextInput.log.clear();
    external.jumpTo(50);
    await tester.pump();
    await tester.pump(); // post-frame 合并推几何
    // 盒尺寸/变换没变会被 connection 同值缓存吸收，滚动后必变的是 caret 矩形。
    expect(
      tester.testTextInput.log.where((c) => c.method == 'TextInput.setCaretRect'),
      isNotEmpty,
      reason: '新 controller 必须接管滚动监听，滚动后仍推 IME caret 几何',
    );
    await _unmount(tester);
  });
}
