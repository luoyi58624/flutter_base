import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> host(WidgetTester tester, Widget child) => tester.pumpWidget(
    ElComponentProvider(
      components: el.desktopComponents,
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  for (final variant in ElButtonVariant.values) {
    testWidgets('桌面 $variant 按钮按 Enter 沿用声明的按压样式，松开恢复且不重复激活', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var taps = 0;
      await host(
        tester,
        ElButton(focusNode: node, variant: variant, type: .primary, onPressed: () => taps++, child: 'Hello'),
      );
      await tester.pumpAndSettle();
      node.requestFocus();
      await tester.pumpAndSettle();
      final button = find.byType(ElButtonView);
      final render = tester.renderObject<ElRenderView>(button);
      final before = render.committedResolvedStyle;
      final tap = tester.widget<ElButtonView>(button).style!.onTap;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(Duration(milliseconds: 100));
      final active = render.committedResolvedStyle;
      expect(taps, 1);
      if (tap == null) {
        expect(active.box.backgroundColor, before.box.backgroundColor);
        expect(active.inheritedText.color, before.inheritedText.color);
      } else {
        expect(
          active.box.backgroundColor != before.box.backgroundColor ||
              active.inheritedText.color != before.inheritedText.color,
          isTrue,
        );
        if (tap.backgroundColor != null) expect(active.box.backgroundColor, tap.backgroundColor);
        if (tap.color != null) expect(active.inheritedText.color, tap.color);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(render.committedResolvedStyle.box.backgroundColor, before.box.backgroundColor);
      expect(render.committedResolvedStyle.inheritedText.color, before.inheritedText.color);
    });
  }

  testWidgets('键盘点击引起页面重建后仍保留用户 onTap，Enter 连发与 Space 释放沿用原激活时机', (tester) async {
    final node = FocusNode();
    final count = ValueNotifier(0);
    addTearDown(node.dispose);
    addTearDown(count.dispose);
    await host(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: count,
        builder: (context, value, _) => ElButton(
          focusNode: node,
          type: .primary,
          variant: .text,
          style: ElStyle(onTap: ElStyle(opacity: 0.4)),
          onPressed: () => count.value++,
          child: '$value',
        ),
      ),
    );
    await tester.pumpAndSettle();
    node.requestFocus();
    await tester.pump();
    final render = tester.renderObject<ElRenderView>(find.byType(ElButtonView));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(count.value, 1);
    expect(render.committedResolvedStyle.box.opacity, 0.4);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(count.value, 2);
    expect(render.committedResolvedStyle.box.opacity, 0.4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.opacity, isNull);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(count.value, 2);
    expect(render.committedResolvedStyle.box.opacity, 0.4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(count.value, 3);
    expect(render.committedResolvedStyle.box.opacity, isNull);
  });
}
