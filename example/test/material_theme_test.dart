// 测试沿用项目内部相对路径约定。
// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/desktop.dart' show ElDesktopExt;
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';
import '../lib/src/router/index.dart';
import '../lib/src/utils/router.dart';
import '../lib/src/mobile/app.dart';
import '../lib/src/state/index.dart';

void main() {
  for (final weight in [590.5, null]) {
    testWidgets('入口字重 $weight 同步到新路由与两端布局，主题切换保留且局部可覆盖', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      GlobalState.isDark.value = false;
      addTearDown(() => GlobalState.isDark.value = false);
      router.go(RouterUtil.home);
      await tester.pumpWidget(App(systemFontWeight: weight));
      await tester.pumpAndSettle();

      final viewKey = GlobalKey(), localKey = GlobalKey();
      RouterUtil.rootNavigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Text('路由普通文字'),
                ElView(
                  key: viewKey,
                  style: ElStyle(fontWeight: .w700),
                  child: '路由视图文字',
                ),
                ElView(
                  key: localKey,
                  style: ElStyle(fontVariationSettings: [FontVariation('wght', 350)]),
                  child: '局部字重',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      void verifyFonts() {
        final axes = weight == null ? null : [FontVariation('wght', weight)];
        final material = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
        for (final style in [
          material.textTheme.bodyMedium!,
          material.primaryTextTheme.bodyLarge!,
          material.appBarTheme.titleTextStyle!,
          material.textButtonTheme.style!.textStyle!.resolve({})!,
        ]) {
          expect(style.fontVariations, axes);
        }
        final text = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text('路由普通文字'), matching: find.byType(RichText)),
        );
        expect(text.text.style!.fontVariations, axes);
        final view = tester.renderObject<ElRenderView>(find.byKey(viewKey));
        expect(view.committedResolvedStyle.inheritedText.fontVariationSettings, axes);
        expect(view.committedResolvedStyle.inheritedText.fontWeight, FontWeight.w700);
        final local = tester.renderObject<ElRenderView>(find.byKey(localKey));
        expect(local.committedResolvedStyle.inheritedText.fontVariationSettings, [FontVariation('wght', 350)]);
      }

      verifyFonts();
      GlobalState.isDark.value = true;
      await tester.pumpAndSettle();
      verifyFonts();
      tester.view.physicalSize = Size(1280, 844);
      await tester.pumpAndSettle();
      verifyFonts();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    });
  }

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
