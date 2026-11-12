import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_base/desktop.dart';

import 'package:flutter/semantics.dart' show SemanticsNode, SemanticsRole;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) => MediaQuery(
  data: const MediaQueryData(size: Size(800, 600)),
  child: Directionality(
    textDirection: .ltr,
    child: ElView(
      themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
      child: ElComponentProvider(
        components: el.desktopComponents,
        child: Overlay.wrap(
          clipBehavior: Clip.none,
          alwaysSizeToContent: true,
          child: ElView(
            style: const ElStyle(width: 560, height: 420, alignment: .center),
            child: ElView(style: const ElStyle(width: 360), child: child),
          ),
        ),
      ),
    ),
  ),
);

Finder _option(int index) => find.byKey(ValueKey<(String, int)>(('el-mention-option', index)));

Finder get _panel => find.byKey(const ValueKey<String>('el-mention-panel'));

ElEditableController _controller(WidgetTester tester) =>
    tester.widget<ElEditableView>(find.byType(ElEditableView)).controller!;

Future<void> _focusAt(WidgetTester tester, FocusNode node, int offset) async {
  node.requestFocus();
  await tester.pump();
  _controller(tester).collapseTo(offset);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

/// 候选滚动区内承载 list 角色的语义节点。
SemanticsNode _listNode(WidgetTester tester, Finder finder) {
  SemanticsNode? result;
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.role == SemanticsRole.list) {
      result = node;
      return;
    }
    node.visitChildren((child) {
      visit(child);
      return result == null;
    });
  }

  visit(tester.getSemantics(finder));
  return result!;
}

void main() {
  testWidgets('提及输入与候选同步普通和紧凑模式', (tester) async {
    for (final compact in [false, true]) {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _host(
          ElMention<String>(
            key: ValueKey(compact),
            value: '@',
            focusNode: focusNode,
            style: ElStyle(vars: {ElDesktopExt.$compact: compact}),
            options: [ElMentionOption(value: 'alice', label: 'Alice')],
          ),
        ),
      );
      await _focusAt(tester, focusNode, 1);
      expect(tester.getSize(_option(0)).height, compact ? 32 : 36);
      expect(editableTextStyleOf(tester.element(find.byType(ElEditableView)))?.fontSize, compact ? 13 : 14);
    }
  });

  testWidgets('输入语义唯一，候选列表和 option 暴露 list/listItem/disabled/selected', (tester) async {
    final focusNode = FocusNode();
    final semantics = tester.ensureSemantics();
    addTearDown(focusNode.dispose);
    try {
      await tester.pumpWidget(
        _host(
          ElMention<String>(
            value: '@',
            focusNode: focusNode,
            semanticLabel: '提及输入',
            options: const [
              ElMentionOption<String>(value: 'alice', label: 'Alice'),
              ElMentionOption<String>(value: 'archived', label: 'Archived', disabled: true),
            ],
          ),
        ),
      );
      await _focusAt(tester, focusNode, 1);

      expect(find.bySemanticsLabel('提及输入'), findsOneWidget);
      final input = tester.getSemantics(find.bySemanticsLabel('提及输入'));
      expect(input.getSemanticsData().flagsCollection.isTextField, isTrue);

      final list = _listNode(tester, find.descendant(of: _panel, matching: find.byType(ElScrollView)));
      expect(list.getSemanticsData().role, SemanticsRole.list);
      final first = tester.getSemantics(_option(0)).getSemanticsData();
      expect(first.label, 'Alice');
      expect(first.role, SemanticsRole.listItem);
      expect(first.flagsCollection.isSelected, Tristate.isTrue);
      expect(first.flagsCollection.isEnabled, Tristate.isTrue);

      final disabled = tester.getSemantics(_option(1)).getSemanticsData();
      expect(disabled.label, 'Archived');
      expect(disabled.role, SemanticsRole.listItem);
      expect(disabled.flagsCollection.isSelected, Tristate.isFalse);
      expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('生产输入只有一个 ElEditableView、零 Flutter EditableText，普通输入禁止多光标', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      _host(
        ElMention<String>(
          value: '@a',
          focusNode: focusNode,
          options: const [ElMentionOption<String>(value: 'alice')],
        ),
      ),
    );
    await _focusAt(tester, focusNode, 2);

    expect(find.byType(ElEditableView), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);

    final line = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView).first);
    expect(line.paintStateForTest.carets, hasLength(1), reason: '输入框场景任何时候都只能绘制一个真实 caret');
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} 主题下文本/caret/selection 与 mention panel 颜色可见', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _host(
          ElMention<String>(
            value: '@a',
            focusNode: focusNode,
            options: const [ElMentionOption<String>(value: 'alice')],
          ),
          brightness: brightness,
        ),
      );
      await _focusAt(tester, focusNode, 2);

      final line = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView).first);
      final config = line.scope.config;
      final textColor = config.textStyle.color;
      expect(textColor, isNotNull);
      expect(textColor!.a, greaterThan(0));
      expect(config.caretColor.a, greaterThan(0));
      expect(config.selectionColor.a, greaterThan(0));
      expect(config.caretColor, textColor);

      final panel = tester.renderObject<ElRenderView>(_panel);
      expect(
        panel.committedResolvedStyle.box.backgroundColor,
        brightness == Brightness.dark ? const Color.fromRGBO(43, 43, 43, 1) : const Color(0xffffffff),
      );
    });
  }
}
