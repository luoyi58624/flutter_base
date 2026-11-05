import 'dart:io';

import 'package:flutter_base/flutter.dart' show ElEditableController, ElEditableStyle, ElEditableView, ElStyle, ElView;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('文本编辑公共入口为 View、Controller 和组合 Style', () {
    var directory = Directory.current;
    File? entry;
    while (true) {
      final candidate = File('${directory.path}/lib/flutter.dart');
      if (candidate.existsSync()) entry = candidate;
      if (entry != null || directory.parent.path == directory.path) break;
      directory = directory.parent;
    }
    final exports = RegExp("export 'src/flutter/views/editable/[^']+'\\s+show\\s+([^;]+);")
        .allMatches(entry!.readAsStringSync())
        .expand((match) => match.group(1)!.split(',').map((name) => name.trim()));
    expect(exports, unorderedEquals(['ElEditableView', 'ElEditableController', 'ElEditableStyle']));
  });

  test('普通编辑只需要 Controller 与 Flutter 选区类型', () {
    final controller = ElEditableController(text: 'hello');
    addTearDown(controller.dispose);
    controller.setSelection(TextSelection(baseOffset: 1, extentOffset: 4));
    controller.insertText('i');
    expect(controller.text, 'hio');
    expect(controller.selection, TextSelection.collapsed(offset: 2));
    expect(controller.undoEdit(), isTrue);
    expect(controller.text, 'hello');
    expect(controller.redoEdit(), isTrue);
    expect(controller.text, 'hio');
  });

  test('格式化规则直接接收 Flutter 输入值', () {
    final controller = ElEditableController(inputFormatters: [FilteringTextInputFormatter.digitsOnly]);
    addTearDown(controller.dispose);
    controller.insertText('a12b');
    expect(controller.text, '12');
    controller.configure(singleLine: true, maxLength: 2);
    controller.insertText('345');
    expect(controller.text, '12');
  });

  testWidgets('几何和滚动由 Controller 提供', (tester) async {
    final controller = ElEditableController(text: 'hello\nworld');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElView(
          style: ElStyle(width: 320, height: 160),
          child: ElEditableView(
            controller: controller,
            style: ElEditableStyle(view: ElStyle(fontSize: 16)),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.hasView, isTrue);
    expect(controller.caretRectGlobal(), isNotNull);
    expect(controller.rectsForRangeGlobal(TextRange(start: 0, end: 5)), isNotEmpty);
    controller.collapseTo(controller.length);
    final reveal = controller.revealCaret();
    await tester.pumpAndSettle();
    expect(await reveal, isTrue);
    await tester.pumpWidget(SizedBox.shrink());
    await tester.pump();
    expect(controller.hasView, isFalse);
    controller.dispose();
  });

  testWidgets('ElStyle 文字样式直接更新真实编辑排版', (tester) async {
    final controller = ElEditableController(text: '样式');
    final editable = ElEditableView(controller: controller);
    Widget host(double fontSize) => Directionality(
      textDirection: TextDirection.ltr,
      child: ElView(
        style: ElStyle(width: 300, height: 160, fontSize: fontSize),
        child: editable,
      ),
    );
    await tester.pumpWidget(host(12));
    await tester.pumpAndSettle();
    final before = controller.caretRectGlobal()!.height;
    await tester.pumpWidget(host(24));
    await tester.pumpAndSettle();
    expect(controller.caretRectGlobal()!.height, greaterThan(before * 1.5));
    await tester.pumpWidget(SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });
}
