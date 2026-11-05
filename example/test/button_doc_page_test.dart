import 'package:example/src/pages/components/basic/button/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Finder _button(String label) =>
    find.byWidgetPredicate((widget) => widget is ElButton && widget.child == label).hitTestable();

void main() {
  testWidgets('窄屏单列布局可以展开、复制和收起演示源码', (tester) async {
    final path = 'lib/src/pages/components/basic/button/examples/appearance.dart';
    final source = (await tester.runAsync(() => rootBundle.loadString(path)))!;
    final example = find.byKey(ValueKey(path));
    Finder action(String label) => find.descendant(of: example, matching: find.text(label));
    String? copied;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await _openPage(tester, width: 320, components: el.mobileComponents);
    expect(find.text('Button 按钮'), findsOneWidget);
    expect(find.text('本页目录'), findsNothing);
    expect(find.text(source.trimRight()), findsNothing);
    await tester.tap(action('查看源码'));
    await tester.pump();
    await tester.runAsync(() => rootBundle.loadString(path));
    await tester.pumpAndSettle();
    expect(action('收起源码'), findsOneWidget);
    expect(action('无法读取示例源码'), findsNothing);
    expect(action('正在读取源码…'), findsNothing);
    expect(find.text(source.trimRight()), findsOneWidget);
    await tester.tap(action('复制源码'));
    await tester.pumpAndSettle();
    expect(copied, source);
    expect(action('已复制'), findsOneWidget);
    await tester.tap(action('收起源码'));
    await tester.pumpAndSettle();
    expect(find.text(source.trimRight()), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏目录定位到真实示例，并保留已访问的交互状态', (tester) async {
    await _openPage(tester, width: 1100, components: el.desktopComponents);
    expect(find.text('本页目录'), findsOneWidget);

    Future<void> openSection(String title) async {
      await tester.tap(find.widgetWithText(TextButton, title));
      await tester.pumpAndSettle();
    }

    await openSection('点击事件');
    expect(_button('增加'), findsOneWidget);
    await tester.tap(_button('增加'));
    await tester.pumpAndSettle();
    await tester.tap(_button('拦截点击'));
    await tester.pumpAndSettle();
    expect(find.text('点击次数：1').hitTestable(), findsOneWidget);

    await openSection('切换状态');
    await tester.tap(_button('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('已收藏').hitTestable(), findsOneWidget);

    await openSection('基础用法');
    await openSection('点击事件');
    expect(find.text('点击次数：1').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
