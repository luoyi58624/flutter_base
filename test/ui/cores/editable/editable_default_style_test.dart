import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, MethodCall, SystemChannels;
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Align(
    alignment: .topLeft,
    child: SizedBox(width: 320, height: 120, child: child),
  ),
);

RenderEditableLine _line(WidgetTester tester) =>
    tester.renderObject<RenderEditableLine>(find.byType(EditableLineView).first);

Future<void> _pumpIme(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

MethodCall _lastImeStyle(WidgetTester tester) =>
    tester.testTextInput.log.lastWhere((call) => call.method == 'TextInput.setStyle');

void main() {
  testWidgets('稳定编辑器随祖先颜色过渡更新正文、caret 和选区，换父后释放旧来源', (tester) async {
    final controller = EditableController(text: 'theme')..collapseTo(2);
    final editorKey = GlobalKey<EditableViewTestState>();
    final firstKey = GlobalKey();
    final secondKey = GlobalKey();
    addTearDown(controller.dispose);
    final editor = EditableView(
      key: editorKey,
      controller: controller,
      style: EditableConfiguration(textStyle: TextStyle(inherit: false, fontSize: 14), lineHeightMode: .fixed),
    );
    var second = false;
    late StateSetter change;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return Row(
              children: [
                ElView(
                  key: firstKey,
                  style: ElStyle(width: 150, color: Color(0xffcc2200)),
                  child: second ? null : editor,
                ),
                ElView(
                  key: secondKey,
                  style: ElStyle(width: 150, color: Color(0xff0022cc)),
                  child: second ? editor : null,
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pump();
    final scope = _line(tester).scope;
    final metrics = scope.fixedLineHeight;
    expect(scope.config.textStyle.color, Color(0xffcc2200));
    final first = tester.renderObject<ElRenderView>(find.byKey(firstKey));
    first.style = ElStyle(
      width: 150,
      color: Color(0xff22cc00),
      onSelection: ElStyle(bgColor: Color(0xff112233), color: Color(0xffaabbcc)),
      transitions: [ElTransition.all(Duration(milliseconds: 200), Curves.linear)],
    );
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    expect(scope.config.textStyle.color, isNot(Color(0xffcc2200)));
    expect(scope.config.textStyle.color, isNot(Color(0xff22cc00)));
    expect(scope.fixedLineHeight, metrics);
    await tester.pumpAndSettle();
    expect(scope.config.textStyle.color, Color(0xff22cc00));
    expect(scope.config.caretColor, Color(0xff22cc00));
    expect(scope.config.selectionColor, Color(0xff112233));
    expect(scope.config.selectionTextColor, Color(0xffaabbcc));
    final caret = tester.allRenderObjects.whereType<RenderEditableCaretMotionOverlay>().toSet().single;
    expect(caret.caretColor, scope.config.caretColor);
    // 只有选区声明变化，也必须经渲染通道即时更新。
    first.style = ElStyle(
      width: 150,
      color: Color(0xff22cc00),
      onSelection: ElStyle(bgColor: Color(0xff445566)),
    );
    await tester.pump();
    expect(scope.config.selectionColor, Color(0xff445566));
    expect(scope.config.selectionTextColor, isNull);
    first.style = ElStyle(
      width: 150,
      color: Color(0xff22cc00),
      onFocus: ElStyle(onSelection: ElStyle(bgColor: Color(0xff778899))),
    );
    first.setFocus(true);
    await tester.pump();
    expect(scope.config.selectionColor, Color(0xff778899));
    change(() => second = true);
    await tester.pump();
    expect(_line(tester).scope, same(scope));
    expect(scope.config.textStyle.color, Color(0xff0022cc));
    first.style = ElStyle(width: 150, color: Color(0xffffffff));
    await tester.pump();
    expect(scope.config.textStyle.color, Color(0xff0022cc));
    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('EditableView 默认使用普通输入行为', (tester) async {
    final controller = EditableController(text: 'one\ntwo')..collapseTo(1);
    final focusNode = FocusNode();
    final clipboardWrites = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardWrites.add((call.arguments as Map<Object?, Object?>)['text'] as String);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          focusNode: focusNode,
          style: const EditableConfiguration(textStyle: TextStyle(fontSize: 10)),
        ),
      ),
    );
    await tester.pump();

    focusNode.requestFocus();
    await tester.pump();
    for (final key in <LogicalKeyboardKey>[LogicalKeyboardKey.keyC, LogicalKeyboardKey.keyX]) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }
    expect(clipboardWrites, isEmpty, reason: '空 caret 的普通输入不得复制或剪切整条逻辑行');
    expect(controller.text, 'one\ntwo');
    expect(controller.docRevision, 0);

    final origin = tester.getTopLeft(find.byType(EditableView));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(origin + const Offset(25, 5));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await gesture.removePointer();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(controller.selections.single, isTrue, reason: '普通输入默认不允许修饰键追加 caret');
  });

  testWidgets('默认宿主仅声明 CSS half-leading，不声明字号、行高或品牌色', (tester) async {
    final controller = EditableController(text: 'Ag');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(EditableView(controller: controller)));
    await tester.pump();

    final widget = tester.widget<EditableView>(find.byType(EditableView));
    final line = _line(tester);
    final config = line.scope.config;
    expect(widget.style.contentPadding, EdgeInsets.zero);
    const initialStyle = TextStyle(leadingDistribution: .even);
    expect(config.textStyle, initialStyle);
    expect(config.textStyle.fontSize, isNull);
    expect(config.textStyle.height, isNull);
    expect(config.textStyle.color, isNull);
    expect(config.textStyle.foreground, isNull);
    expect(config.textStyle.backgroundColor, isNull);
    expect(config.textStyle.background, isNull);
    expect(config.textStyle.shadows, isNull);
    expect(config.caretColor, const Color(0xff000000), reason: '无文本色来源时仍须提供可见 caret');
    expect(config.selectionColor, const Color(0x553B82F6), reason: '无外观不等于移除可辨识的选区反馈，默认色跟随 cores/selection 全局兜底');

    final hitSurface = tester
        .widgetList<ElView>(find.descendant(of: find.byType(EditableView), matching: find.byType(ElView)))
        .firstWhere((view) => view.style?.cursor == SystemMouseCursors.text);
    expect(hitSurface.style!.bgColor, const Color(0x00000000));
    expect(hitSurface.style!.border, isNull);
    expect(hitSurface.style!.boxShadow, isNull);
    expect(hitSurface.style!.outline, isNull);

    final actual = line.layoutedPainter!;
    final reference = TextPainter(
      text: const TextSpan(text: 'Ag', style: initialStyle),
      textDirection: config.textDirection,
      textAlign: config.textAlign,
      textScaler: config.textScaler,
    )..layout(minWidth: actual.width, maxWidth: actual.width);
    addTearDown(reference.dispose);
    expect(actual.preferredLineHeight, closeTo(reference.preferredLineHeight, 0.001));
    expect(actual.height, closeTo(reference.height, 0.001));
    final actualMetric = actual.computeLineMetrics().single;
    final referenceMetric = reference.computeLineMetrics().single;
    expect(actualMetric.baseline, closeTo(referenceMetric.baseline, 0.001));
    expect(actualMetric.ascent, closeTo(referenceMetric.ascent, 0.001));
    expect(actualMetric.descent, closeTo(referenceMetric.descent, 0.001));
    expect(actualMetric.height, closeTo(referenceMetric.height, 0.001));
  });

  testWidgets('祖先 currentColor 可热更新，显式文本与交互色拥有最终优先级', (tester) async {
    final controller = EditableController(text: 'inherit');
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);

    Widget editor({required Color ancestor, TextStyle? textStyle, Color? caretColor, Color? selectionColor}) => _host(
      ElView(
        style: ElStyle(color: ancestor, fontSize: 17, lineHeight: 1.4),
        child: EditableView(
          key: key,
          controller: controller,
          style: EditableConfiguration(textStyle: textStyle, caretColor: caretColor, selectionColor: selectionColor),
        ),
      ),
    );

    await tester.pumpWidget(editor(ancestor: const Color(0xffc02020)));
    await tester.pump();
    expect(_line(tester).scope.config.textStyle.color, const Color(0xffc02020));
    expect(_line(tester).scope.config.textStyle.leadingDistribution, TextLeadingDistribution.even);
    expect(_line(tester).scope.config.caretColor, const Color(0xffc02020));
    expect(_line(tester).scope.config.textStyle.fontSize, 17);
    expect(_line(tester).scope.config.textStyle.height, 1.4);

    await tester.pumpWidget(editor(ancestor: const Color(0xff2050c0)));
    await tester.pump();
    expect(_line(tester).scope.config.textStyle.color, const Color(0xff2050c0));
    expect(_line(tester).scope.config.caretColor, const Color(0xff2050c0));

    const explicitStyle = TextStyle(
      fontFamily: 'Ahem',
      fontSize: 18,
      height: 1.25,
      color: Color(0xff208040),
      letterSpacing: 1.5,
      wordSpacing: 2.5,
    );
    await tester.pumpWidget(
      editor(
        ancestor: const Color(0xff2050c0),
        textStyle: explicitStyle,
        caretColor: const Color(0xff7a20a0),
        selectionColor: const Color(0x66904020),
      ),
    );
    await tester.pump();
    final config = _line(tester).scope.config;
    expect(config.textStyle, explicitStyle.copyWith(leadingDistribution: .even));
    expect(config.caretColor, const Color(0xff7a20a0));
    expect(config.selectionColor, const Color(0x66904020));
  });

  testWidgets('IME style 不回填旧默认值，热更新只透传显式排版声明', (tester) async {
    final controller = EditableController(text: 'ime')..collapseTo(3);
    final focusNode = FocusNode();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    Widget editor(TextStyle? style) => _host(
      EditableView(
        key: key,
        controller: controller,
        focusNode: focusNode,
        style: EditableConfiguration(textStyle: style, autofocus: true),
      ),
    );

    await tester.pumpWidget(editor(null));
    await _pumpIme(tester);
    var arguments = _lastImeStyle(tester).arguments as Map<dynamic, dynamic>;
    expect(arguments['fontFamily'], isNull);
    expect(arguments['fontSize'], isNull, reason: 'IME 通道不得重新塞回旧 14px 默认值');
    expect(arguments['fontWeightIndex'], isNull);
    expect(arguments['letterSpacing'], isNull);
    expect(arguments['wordSpacing'], isNull);
    expect(arguments['lineHeight'], isNull, reason: 'IME 通道不得重新塞回旧 1.5 行高');

    tester.testTextInput.log.clear();
    const explicitStyle = TextStyle(fontFamily: 'Ahem', fontSize: 19, fontWeight: FontWeight.w600, height: 1.3);
    await tester.pumpWidget(editor(explicitStyle));
    await _pumpIme(tester);
    final styleCalls = tester.testTextInput.log.where((call) => call.method == 'TextInput.setStyle').toList();
    expect(styleCalls, hasLength(1));
    arguments = styleCalls.single.arguments as Map<dynamic, dynamic>;
    expect(arguments['fontFamily'], 'Ahem');
    expect(arguments['fontSize'], 19);
    expect(arguments['fontWeightIndex'], FontWeight.values.indexOf(FontWeight.w600));
    expect(arguments['textDirectionIndex'], TextDirection.ltr.index);
    expect(arguments['textAlignIndex'], TextAlign.start.index);
  });
}
