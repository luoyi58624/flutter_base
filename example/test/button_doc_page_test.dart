import 'package:example/src/pages/components/basic/button/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

Future<void> _openPage(WidgetTester tester, {required double width, required ElComponents components}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 720);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: components,
      child: MaterialApp(home: ButtonPage()),
    ),
  );
  await tester.pumpAndSettle();
}

String _examplePath(int number) => 'lib/src/pages/components/basic/button/examples/example$number.dart';

Finder _example(int number) => find.byKey(ValueKey(_examplePath(number)));

Finder _buttons(int number, Object child) => find.descendant(
  of: _example(number),
  matching: find.byWidgetPredicate((widget) => widget is ElButton && widget.child == child),
);

void main() {
  testWidgets('窄屏保留现有按钮演示，使用旧版折叠条展开和收起源码', (tester) async {
    final path = _examplePath(1);
    final source = (await tester.runAsync(() => rootBundle.loadString(path)))!;
    final toggle = find.descendant(of: _example(1), matching: find.byKey(ValueKey('el-code-example-toggle')));

    await _openPage(tester, width: 320, components: el.mobileComponents);
    expect(find.text('Button 按钮'), findsOneWidget);
    expect(find.text('本页目录'), findsNothing);
    expect(find.text(source), findsNothing);
    final controller = tester.widget<ElScrollView>(find.byType(ElScrollView)).controller!;
    final offset = tester.getCenter(toggle).dy - 500;
    if (offset > 0) {
      controller.jumpTo(controller.offset + offset);
      await tester.pumpAndSettle();
    }
    expect(tester.getSize(toggle).height, 44);
    expect(_buttons(1, 'Hello'), findsNWidgets(30));
    await tester.tap(toggle);
    await tester.pump();
    await tester.runAsync(() => rootBundle.loadString(path));
    await tester.pumpAndSettle();
    expect(tester.widget<ElButtonView>(toggle).semantics?.properties.label, '收起代码');
    expect(find.text('无法读取示例源码'), findsNothing);
    expect(find.text(source), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text(source), findsNothing);
    expect(_buttons(1, 'Hello'), findsNWidgets(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏目录按原示例顺序定位，禁用、加载和共享切换可操作', (tester) async {
    await _openPage(tester, width: 1100, components: el.desktopComponents);
    expect(find.text('本页目录'), findsOneWidget);

    Future<void> openSection(String title) async {
      await tester.tap(find.widgetWithText(TextButton, title));
      await tester.pumpAndSettle();
    }

    expect(
      tester
          .widgetList<TextButton>(find.byType(TextButton))
          .map((widget) => widget.child)
          .whereType<Text>()
          .map((text) => text.data),
      containsAllInOrder(['基础使用', '自定义颜色', '禁用按钮', '链接按钮', '图标按钮', '圆形图标按钮', '加载状态', '块级按钮', 'Toggle 切换']),
    );

    await openSection('自定义颜色');
    final custom = _buttons(2, 'Hello');
    expect(custom, findsNWidgets(24));
    expect(tester.getCenter(custom.at(0)).dy, tester.getCenter(custom.at(1)).dy);
    expect(ElView.of(tester.element(custom.first)).getVar<Color>(ElTokens.$primary), Colors.teal);

    await openSection('禁用按钮');
    final disabled = _buttons(3, 'Hello');
    expect(tester.widgetList<ElButton>(disabled).map((button) => button.disabled), everyElement(isTrue));
    await tester.tap(find.byType(ElSwitch).hitTestable());
    await tester.pumpAndSettle();
    expect(tester.widgetList<ElButton>(disabled).map((button) => button.disabled), everyElement(isFalse));

    await openSection('加载状态');
    final loaders = _buttons(7, 'loading');
    expect(loaders, findsNWidgets(12));
    await tester.tap(loaders.hitTestable().first);
    await tester.pump();
    expect(tester.widgetList<ElButton>(loaders).where((button) => button.loading), hasLength(1));
    await tester.pump(Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.widgetList<ElButton>(loaders).map((button) => button.loading), everyElement(isFalse));

    await openSection('Toggle 切换');
    expect(_buttons(9, 'false'), findsNWidgets(6));
    await tester.tap(_buttons(9, 'false').hitTestable().first);
    await tester.pumpAndSettle();
    expect(_buttons(9, 'true'), findsNWidgets(6));
    await openSection('基础使用');
    await openSection('Toggle 切换');
    expect(_buttons(9, 'true'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });
}
