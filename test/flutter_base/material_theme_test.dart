import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_base/desktop.dart' show ElDesktopExt;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('AppBar 在 ElScrollView 滚动后显示阴影，回到顶部恢复：$brightness', (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        ElView(
          themeMode: ElThemeMode(brightness: brightness),
          child: ElComponentProvider(
            components: el.mobileComponents,
            child: Builder(
              builder: (context) => MaterialApp(
                theme: context.elMaterialThemeData,
                home: Scaffold(
                  appBar: AppBar(title: Text('标题')),
                  body: ElScrollView(controller: controller, children: [SizedBox(height: 2000)]),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Material appBarMaterial() =>
          tester.widget<Material>(find.descendant(of: find.byType(AppBar), matching: find.byType(Material)).first);
      expect(appBarMaterial().elevation, 0);
      expect(appBarMaterial().shadowColor!.a, greaterThan(0));
      expect(appBarMaterial().surfaceTintColor, Colors.transparent);
      controller.jumpTo(100);
      await tester.pumpAndSettle();
      expect(appBarMaterial().elevation, 1);
      expect(appBarMaterial().shadowColor!.a, greaterThan(0));
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(appBarMaterial().elevation, 0);
      await tester.pumpWidget(SizedBox());
      controller.dispose();
    });
  }

  testWidgets('官方文字读取级联字体并随固定祖先样式更新，移除后恢复默认', (tester) async {
    var customized = true;
    var fontSize = 18.0;
    late StateSetter update;
    late ThemeData theme;
    final reader = Builder(
      builder: (context) {
        theme = context.elMaterialThemeData;
        return Theme(
          data: theme,
          child: Scaffold(
            appBar: AppBar(title: Text('标题')),
            body: Column(
              children: [
                Text('正文'),
                TextButton(onPressed: () {}, child: Text('按钮')),
              ],
            ),
          ),
        );
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ElComponentProvider(
              components: el.mobileComponents,
              child: ElView(
                style: customized
                    ? ElStyle(
                        vars: {
                          ElTokens.$fontFamily: '调用方字体',
                          ElTokens.$fontFamilyFallback: ['调用方回退'],
                          ElTokens.$fontWeightAction: 600,
                          ElTokens.$fontWeightTitle: 800,
                        },
                        fontSize: fontSize,
                        fontWeight: .w300,
                        fontStyle: .italic,
                        lineHeight: 1.5,
                        letterSpacing: 1.25,
                        wordSpacing: 2,
                        fontFeatureSettings: [FontFeature.tabularFigures()],
                        fontVariationSettings: [FontVariation('wght', 350)],
                      )
                    : null,
                child: ElView(child: reader),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final style in [
      theme.textTheme.bodyMedium!,
      theme.textTheme.headlineLarge!,
      theme.primaryTextTheme.bodyLarge!,
      theme.appBarTheme.titleTextStyle!,
      theme.textButtonTheme.style!.textStyle!.resolve({})!,
      theme.inputDecorationTheme.hintStyle!,
    ]) {
      expect(style.fontFamily, '调用方字体');
      expect(style.fontFamilyFallback, ['调用方回退']);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.height, 1.5);
      expect(style.letterSpacing, 1.25);
      expect(style.wordSpacing, 2);
      expect(style.fontFeatures, [FontFeature.tabularFigures()]);
      expect(style.fontVariations, [FontVariation('wght', 350)]);
    }
    expect(theme.textTheme.bodyMedium!.fontSize, 18);
    expect(theme.textTheme.bodyMedium!.fontWeight, FontWeight.w300);
    expect(theme.textTheme.bodyLarge!.fontWeight, FontWeight.w300);
    expect(theme.primaryTextTheme.bodyLarge!.fontWeight, FontWeight.w300);
    expect(theme.textTheme.labelLarge!.fontWeight, FontWeight.w600);
    expect(theme.textTheme.titleMedium!.fontWeight, FontWeight.w600);
    expect(theme.textTheme.headlineLarge!.fontWeight, FontWeight.w800);
    expect(theme.textButtonTheme.style!.textStyle!.resolve({})!.fontWeight, FontWeight.w600);
    expect(theme.appBarTheme.titleTextStyle!.fontWeight, FontWeight.w800);
    expect(theme.appBarTheme.titleTextStyle!.fontSize, closeTo(21.6, .001));
    expect(DefaultTextStyle.of(tester.element(find.text('正文'))).style.fontFamily, '调用方字体');
    update(() => fontSize = 20);
    await tester.pumpAndSettle();
    expect(theme.textTheme.bodyMedium!.fontSize, 20);
    update(() => customized = false);
    await tester.pumpAndSettle();
    final defaults = ThemeData();
    expect(theme.textTheme.bodyMedium!.fontFamily, defaults.textTheme.bodyMedium!.fontFamily);
    expect(theme.textTheme.bodyMedium!.fontFamilyFallback, defaults.textTheme.bodyMedium!.fontFamilyFallback);
    expect(theme.textTheme.bodyMedium!.fontVariations, isNull);
    expect(theme.textTheme.bodyMedium!.fontSize, 15);
    expect(theme.textTheme.bodyMedium!.fontWeight, FontWeight.w400);
    expect(tester.takeException(), isNull);
  });

  testWidgets('两套明暗主题读取各自字体变体，未激活字体更新也通知读者', (tester) async {
    var darkSize = 21.0;
    late StateSetter update;
    late ThemeData light, dark;
    final reader = Builder(
      builder: (context) {
        light = context.elMaterialTheme(.light);
        dark = context.elMaterialTheme(.dark);
        return SizedBox();
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ElView(
              themeMode: ElThemeMode(brightness: .light),
              child: ElComponentProvider(
                components: el.mobileComponents,
                child: ElView(
                  style: ElStyle(
                    vars: {ElTokens.$fontWeightAction: 600},
                    fontFamily: '浅色字体',
                    fontSize: 16,
                    onDark: ElStyle(
                      vars: {ElTokens.$fontWeightAction: 800},
                      fontFamily: '暗色字体',
                      fontSize: darkSize,
                      fontWeight: .w700,
                    ),
                  ),
                  child: ElView(child: reader),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(light.textTheme.bodyMedium!.fontFamily, '浅色字体');
    expect(light.textTheme.bodyMedium!.fontSize, 16);
    expect(dark.textTheme.bodyMedium!.fontFamily, '暗色字体');
    expect(dark.textTheme.bodyMedium!.fontSize, 21);
    expect(dark.textTheme.bodyMedium!.fontWeight, FontWeight.w700);
    expect(dark.textButtonTheme.style!.textStyle!.resolve({})!.fontWeight, FontWeight.w800);
    update(() => darkSize = 24);
    await tester.pumpAndSettle();
    expect(light.textTheme.bodyMedium!.fontSize, 16);
    expect(dark.textTheme.bodyMedium!.fontSize, 24);
    expect(tester.takeException(), isNull);
  });

  for (final mobile in [true, false]) {
    for (final brightness in Brightness.values) {
      testWidgets('${mobile ? 'mobile' : 'desktop'} $brightness 官方组件消费共同变量且保持默认字体', (tester) async {
        late ThemeData theme;
        late ElThemeExt tokens;
        final child = Builder(
          builder: (context) {
            tokens = context.elTheme;
            theme = context.elMaterialThemeData;
            return Theme(
              data: theme,
              child: Scaffold(body: Text('官方文本')),
            );
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: mobile
                ? ElView(
                    themeMode: ElThemeMode(brightness: brightness),
                    child: ElComponentProvider(components: el.mobileComponents, child: child),
                  )
                : ElView(
                    themeMode: ElThemeMode(brightness: brightness),
                    child: ElComponentProvider(components: el.desktopComponents, child: child),
                  ),
          ),
        );
        await tester.pumpAndSettle();
        expect(theme.brightness, brightness);
        expect(theme.colorScheme.primary, tokens.primary);
        expect(theme.colorScheme.error, tokens.error);
        expect(theme.colorScheme.surface, tokens.bgColor);
        expect(theme.scaffoldBackgroundColor, tokens.bgColor);
        expect(theme.cardTheme.color, tokens.cardColor);
        expect(theme.appBarTheme.backgroundColor, tokens.cardColor);
        expect(theme.dialogTheme.backgroundColor, tokens.bgColor);
        expect(theme.inputDecorationTheme.enabledBorder!.borderSide.color, tokens.borderColor);
        expect(theme.progressIndicatorTheme.color, tokens.primary);
        expect(theme.iconTheme.size, isNull);
        final defaults = ThemeData(brightness: brightness);
        expect(theme.textTheme.bodyMedium!.fontFamily, defaults.textTheme.bodyMedium!.fontFamily);
        expect(theme.textTheme.bodyMedium!.fontFamilyFallback, defaults.textTheme.bodyMedium!.fontFamilyFallback);
        expect(theme.textTheme.bodyMedium!.fontVariations, defaults.textTheme.bodyMedium!.fontVariations);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('浅色 context 同时生成两轴，读取各自品牌默认和局部覆写', (tester) async {
    late ThemeData light, dark;
    await tester.pumpWidget(
      MaterialApp(
        home: ElView(
          themeMode: ElThemeMode(brightness: .light),
          child: ElComponentProvider(
            components: el.mobileComponents,
            child: ElView(
              style: ElStyle(
                vars: {ElTokens.$primary: Colors.purple},
                onDark: ElStyle(vars: {ElTokens.$primary: Colors.green}),
              ),
              child: Builder(
                builder: (context) {
                  light = context.elMaterialTheme(.light);
                  dark = context.elMaterialTheme(.dark);
                  return SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(light.colorScheme.primary, Colors.purple);
    expect(dark.colorScheme.primary, Colors.green);
    expect(light.cardTheme.color, el.mobileComponents.style!.vars![ElTokens.$cardColor]);
    expect(dark.cardTheme.color, el.mobileComponents.style!.onDark!.vars![ElTokens.$cardColor]);
    expect(light.navigationBarTheme.indicatorColor, isNot(dark.navigationBarTheme.indicatorColor));
  });

  testWidgets('未激活暗色分支更新会通知固定读者，卸载后清理订阅', (tester) async {
    var darkColor = Colors.green;
    var visible = true;
    late StateSetter update;
    late ThemeData dark;
    var builds = 0;
    final reader = Builder(
      builder: (context) {
        builds++;
        dark = context.elMaterialTheme(.dark);
        return SizedBox();
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ElView(
              themeMode: ElThemeMode(brightness: .light),
              child: ElComponentProvider(
                components: el.mobileComponents,
                child: ElView(
                  style: ElStyle(onDark: ElStyle(vars: {ElTokens.$primary: darkColor})),
                  child: visible ? reader : SizedBox(),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = builds;
    expect(dark.colorScheme.primary, Colors.green);
    update(() => darkColor = Colors.red);
    await tester.pumpAndSettle();
    expect(builds, greaterThan(before));
    expect(dark.colorScheme.primary, Colors.red);
    update(() => visible = false);
    await tester.pumpAndSettle();
    final removed = builds;
    update(() => darkColor = Colors.blue);
    await tester.pumpAndSettle();
    expect(builds, removed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('局部当前明暗使用已提交变量，Overlay 中仍可读取相反轴', (tester) async {
    final portal = ElPortalController();
    addTearDown(portal.dispose);
    late ThemeData current, opposite;
    await tester.pumpWidget(
      MaterialApp(
        home: ElView(
          themeMode: ElThemeMode(brightness: .light),
          child: ElComponentProvider(
            components: el.mobileComponents,
            child: ElView(
              style: ElStyle(onDark: ElStyle(vars: {ElTokens.$primary: Colors.orange})),
              child: ElView(
                themeMode: ElThemeMode(brightness: .dark),
                style: ElStyle(onDark: ElStyle(vars: {ElTokens.$cardColor: Colors.pink})),
                child: ElPortal(
                  controller: portal,
                  overlayBuilder: (context) => ElView(
                    child: Builder(
                      builder: (context) {
                        current = context.elMaterialThemeData;
                        opposite = context.elMaterialTheme(.light);
                        return SizedBox(width: 40, height: 40);
                      },
                    ),
                  ),
                  child: SizedBox(width: 80, height: 30),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    portal.open();
    await tester.pumpAndSettle();
    expect(current.brightness, Brightness.dark);
    expect(current.cardTheme.color, Colors.pink);
    expect(opposite.brightness, Brightness.light);
    expect(opposite.cardTheme.color, el.mobileComponents.style!.vars![ElTokens.$cardColor]);
    portal.close();
    await tester.pumpAndSettle();
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('无 ElView 时显式两轴沿用官方默认主题', (tester) async {
    late ThemeData light, dark;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            light = context.elMaterialTheme(.light);
            dark = context.elMaterialTheme(.dark);
            return SizedBox();
          },
        ),
      ),
    );
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.surface, ThemeData(brightness: Brightness.light).colorScheme.surface);
    expect(dark.colorScheme.surface, ThemeData(brightness: Brightness.dark).colorScheme.surface);
  });

  testWidgets('MaterialApp 直接消费当前主题，固定子树随明暗翻转刷新', (tester) async {
    var brightness = Brightness.light;
    late StateSetter update;
    late ThemeData captured;
    final app = Builder(
      builder: (context) {
        captured = context.elMaterialThemeData;
        return MaterialApp(
          theme: captured,
          home: Scaffold(body: Text('官方页面')),
        );
      },
    );
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return ElView(
            themeMode: ElThemeMode(brightness: brightness),
            child: ElComponentProvider(components: el.mobileComponents, child: app),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(captured.brightness, Brightness.light);
    update(() => brightness = Brightness.dark);
    await tester.pumpAndSettle();
    expect(captured.brightness, Brightness.dark);
    expect(captured.scaffoldBackgroundColor, el.mobileComponents.style!.onDark!.vars![ElTokens.$bgColor]);
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(Scaffold), matching: find.byType(Material)).first,
    );
    expect(material.color, captured.scaffoldBackgroundColor);
    expect(tester.takeException(), isNull);
  });

  testWidgets('读取者换祖先后使用新级联，并退订旧祖先的未激活分支', (tester) async {
    var moved = false;
    var firstDark = Colors.green;
    late StateSetter update;
    late ThemeData captured;
    var builds = 0;
    final reader = Builder(
      key: GlobalKey(),
      builder: (context) {
        builds++;
        captured = context.elMaterialTheme(.dark);
        return SizedBox(width: 20, height: 20);
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ElComponentProvider(
              components: el.mobileComponents,
              child: Row(
                children: [
                  ElView(
                    style: ElStyle(onDark: ElStyle(vars: {ElTokens.$primary: firstDark})),
                    child: moved ? SizedBox() : reader,
                  ),
                  ElView(
                    style: ElStyle(onDark: ElStyle(vars: {ElTokens.$primary: Colors.orange})),
                    child: moved ? reader : SizedBox(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(captured.colorScheme.primary, Colors.green);
    update(() => moved = true);
    await tester.pumpAndSettle();
    expect(captured.colorScheme.primary, Colors.orange);
    final afterMove = builds;
    update(() => firstDark = Colors.blue);
    await tester.pumpAndSettle();
    expect(builds, afterMove);
    expect(tester.takeException(), isNull);
  });
}
