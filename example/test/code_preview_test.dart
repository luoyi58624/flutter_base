import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

// 测试沿用项目内部文件的相对路径约定。
// ignore: avoid_relative_lib_imports
import '../lib/src/widgets/code_preview/index.dart';

Future<void> _host(WidgetTester tester, Widget child, {double width = 480, bool dark = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElView(
      themeMode: ElThemeMode(brightness: dark ? .dark : .light, duration: .zero),
      child: ElComponentProvider(
        components: el.desktopComponents,
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _button(String label) =>
    find.byWidgetPredicate((widget) => widget is ElButtonView && widget.semantics?.properties.label == label);

void main() {
  testWidgets('示例卡保持旧版边距和折叠条，悬停整栏时箭头左移并展开源码', (tester) async {
    await _host(tester, ElCodeExample(code: "ElView(child: '当前内容');", children: [Text('当前演示')]));
    final stage = find.byKey(ValueKey('el-code-example-stage'));
    final toggle = find.byKey(ValueKey('el-code-example-toggle'));
    final arrow = find.byKey(ValueKey('el-code-example-arrow'));
    final stageRect = tester.getRect(stage);
    final demoRect = tester.getRect(find.text('当前演示'));
    expect(demoRect.left - stageRect.left, 20);
    expect(demoRect.top - stageRect.top, 20);
    expect(tester.getRect(toggle).height, 44);
    expect(tester.getCenter(arrow).dx, closeTo(tester.getCenter(toggle).dx, 0.1));
    expect(find.byType(ElCodePreview), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(1, 1));
    final idleX = tester.getCenter(arrow).dx;
    // 指针落在整栏边缘，覆盖后代共享栏状态而非只响应文字区域的行为。
    await mouse.moveTo(tester.getRect(toggle).centerLeft + Offset(5, 0));
    await tester.pumpAndSettle();
    expect(tester.getCenter(arrow).dx, closeTo(idleX - 36, 0.1));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(ElCodePreview), findsOneWidget);
    expect(tester.widget<ElCodePreview>(find.byType(ElCodePreview)).showToolbar, isFalse);
    expect(find.text('当前演示'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(ElCodePreview), findsNothing);
    expect(find.text('当前演示'), findsOneWidget);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('多文件沿用 ui.dart 默认入口，切换与替换文件后显示对应源码', (tester) async {
    Widget preview(List<ElCodeFile> files) =>
        ElCodeExample(key: ValueKey('files'), expanded: true, files: files, children: [Text('演示内容')]);
    await _host(
      tester,
      preview([
        ElCodeFile(name: 'data.dart', code: 'final value = 1;'),
        ElCodeFile(name: 'ui.dart', code: "ElView(child: '预览');"),
      ]),
    );
    expect(tester.widget<ElCodePreview>(find.byType(ElCodePreview)).code, "ElView(child: '预览');");
    await tester.tap(_button('data.dart'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElCodePreview>(find.byType(ElCodePreview)).code, 'final value = 1;');
    await _host(tester, preview([ElCodeFile(name: 'replacement.dart', code: 'final replacement = true;')]));
    expect(tester.widget<ElCodePreview>(find.byType(ElCodePreview)).code, 'final replacement = true;');
    expect(find.byKey(ValueKey('el-code-example-file-bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('复制保留完整源码，后续点击或源码变化清除已复制状态', (tester) async {
    final source = "// 当前源码\nfinal text = 'Hello';\n";
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _host(tester, ElCodePreview(code: source));
    await tester.tap(_button('复制代码'));
    await tester.pumpAndSettle();
    expect(copied, source);
    expect(_button('已复制'), findsOneWidget);
    await tester.tapAt(Offset(2, 250));
    await tester.pumpAndSettle();
    expect(_button('复制代码'), findsOneWidget);
    await tester.tap(_button('复制代码'));
    await tester.pumpAndSettle();
    await _host(tester, ElCodePreview(code: 'final changed = 2;'));
    expect(_button('复制代码'), findsOneWidget);
    expect(find.text('final changed = 2;'), findsOneWidget);
    await tester.pumpWidget(SizedBox());
    await tester.tapAt(Offset(2, 250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('源码着色保持完整文本，字符串和注释不被 Widget 类型色覆盖', (tester) async {
    final source = "// ElButton\nElButton(child: 'Hello');\n";
    await _host(tester, ElCodePreview(code: source, showToolbar: false));
    final span = tester.widget<Text>(find.text(source)).textSpan!;
    final fragments = <(String, Color?)>[];
    void visit(InlineSpan span, Color? inherited) {
      final color = span.style?.color ?? inherited;
      if (span is TextSpan) {
        if (span.text != null) fragments.add((span.text!, color));
        for (final child in span.children ?? <InlineSpan>[]) {
          visit(child, color);
        }
      }
    }

    visit(span, null);
    expect(span.toPlainText(), source);
    expect(fragments.where((part) => part.$1.contains('Hello')).map((part) => part.$2), [Color(0xff98c379)]);
    expect(fragments.where((part) => part.$1.startsWith('//')).map((part) => part.$2), [Color(0xff5c6370)]);
    expect(fragments, contains(('ElButton', Color(0xffe5c07b))));
    expect(fragments, contains(('child', Color(0xff61afef))));
  });

  testWidgets('明暗主题共用 Atom 配色和字体，长代码可横向滚动且按需限高', (tester) async {
    final source = "// 注释\nfinal text = '${'宽源码' * 60}';\n" * 8;
    for (final dark in [false, true]) {
      await _host(tester, ElCodePreview(code: source, maxHeight: 160, showToolbar: false), width: 320, dark: dark);
      final shell = tester.widget<ElCardView>(
        find.descendant(of: find.byType(ElCodePreview), matching: find.byType(ElCardView)).first,
      );
      expect(shell.style?.backgroundColor, Color(0xff282c34));
      expect(shell.themeMode?.brightness, Brightness.dark);
      expect(tester.getSize(find.byType(ElCodePreview)).height, 160);
      final text = tester.widget<Text>(find.text(source));
      expect(text.style?.fontFamily, 'Consolas');
      expect(text.textSpan?.toPlainText(), source);
      final scroll = tester
          .widgetList<Scrollable>(find.byType(Scrollable))
          .where((widget) => widget.axisDirection == AxisDirection.right)
          .single;
      expect(scroll.controller, isNull);
      final horizontal = find.byWidget(scroll);
      await tester.dragFrom(tester.getTopLeft(find.byType(ElCodePreview)) + Offset(160, 60), Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(horizontal).position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('联动域可以强制展开和收起示例卡', (tester) async {
    final expanded = ValueNotifier<bool?>(true);
    addTearDown(expanded.dispose);
    await _host(
      tester,
      ValueListenableBuilder<bool?>(
        valueListenable: expanded,
        builder: (context, value, child) => ElCodeExampleScope(expandedAll: value, child: child!),
        child: ElCodeExample(code: 'final visible = true;', children: [Text('当前演示')]),
      ),
    );
    expect(find.byType(ElCodePreview), findsOneWidget);
    expanded.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(ElCodePreview), findsNothing);
    expanded.value = null;
    await tester.pumpAndSettle();
    await tester.tap(_button('展开代码'));
    await tester.pumpAndSettle();
    expect(find.byType(ElCodePreview), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
