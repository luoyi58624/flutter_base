import 'package:example/main.dart';
import 'package:example/router.dart';
import 'package:example/src/mobile/app.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/desktop.dart' show ElDesktopExt;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('首页 Material 图标按钮直接切换布尔暗黑状态', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    GlobalState.isDark.value = false;
    router.go(RouterUtil.home);
    addTearDown(() => GlobalState.isDark.value = false);
    await tester.pumpWidget(App());
    await tester.pumpAndSettle();

    for (final dark in [true, false]) {
      final button = find.widgetWithIcon(IconButton, dark ? Icons.dark_mode : Icons.light_mode);
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(GlobalState.isDark.value, dark);
      final context = tester.element(find.byType(IconButton).first);
      expect(Theme.of(context).brightness, dark ? Brightness.dark : Brightness.light);
      expect(
        context.elTheme.bgColor,
        (dark ? el.mobileComponents.style!.onDark!.vars! : el.mobileComponents.style!.vars!)[ElTokens.$bgColor],
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('桌面布局直接响应布尔暗黑状态', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(1280, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    GlobalState.isDark.value = false;
    router.go(RouterUtil.home);
    addTearDown(() => GlobalState.isDark.value = false);
    await tester.pumpWidget(App());
    await tester.pumpAndSettle();

    for (final dark in [true, false]) {
      GlobalState.isDark.value = dark;
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Navigator).first);
      expect(Theme.of(context).brightness, dark ? Brightness.dark : Brightness.light);
      expect(
        context.elTheme.bgColor,
        (dark ? el.desktopComponents.style!.onDark!.vars! : el.desktopComponents.style!.vars!)[ElTokens.$bgColor],
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('当前入口使用移动主题生成 Material 样式，路由沿用主题', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    router.go(RouterUtil.home);
    await tester.pumpWidget(App());
    await tester.pumpAndSettle();
    expect(find.byType(ElComponentProvider), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, el.mobileComponents.style!.vars![ElTokens.$primary]);
    final context = tester.element(find.byType(AppBar));
    expect(Theme.of(context).appBarTheme.backgroundColor, context.elTheme.cardColor);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => Scaffold(body: Text('新路由'))));
    await tester.pumpAndSettle();
    final routeContext = tester.element(find.text('新路由'));
    expect(Theme.of(routeContext).colorScheme.primary, routeContext.elTheme.primary);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('旧入口的官方样式与同一份 ElView 主题保持一致', (tester) async {
    await tester.pumpWidget(ElExampleApp(networkDelay: Duration.zero, replyDelay: Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(ElComponentProvider), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(Navigator).first);
    expect(app.theme!.colorScheme.primary, context.elTheme.primary);
    expect(app.theme!.textTheme.bodyMedium!.fontWeight, FontWeight.w400);
    expect(app.theme!.textTheme.bodyMedium!.fontVariations, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
