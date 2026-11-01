import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/mobile.dart' show ElMobileTheme;
import 'package:flutter_base/desktop.dart' show ElDesktopTheme;
import 'package:flutter_test/flutter_test.dart';

void main() {
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
                ? ElMobileTheme(brightness: brightness, child: child)
                : ElDesktopTheme(
                    themeMode: ElThemeMode(brightness: brightness),
                    child: child,
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
        home: ElMobileTheme(
          brightness: .light,
          child: ElView(
            style: ElStyle(
              vars: {ElTheme.$primary: Colors.purple},
              onDark: ElStyle(vars: {ElTheme.$primary: Colors.green}),
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
    );
    expect(light.colorScheme.primary, Colors.purple);
    expect(dark.colorScheme.primary, Colors.green);
    expect(light.cardTheme.color, ElMobileTheme.lightVars[ElTheme.$cardColor]);
    expect(dark.cardTheme.color, ElMobileTheme.darkVars[ElTheme.$cardColor]);
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
            return ElMobileTheme(
              brightness: .light,
              style: ElStyle(onDark: ElStyle(vars: {ElTheme.$primary: darkColor})),
              child: visible ? reader : SizedBox(),
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
        home: ElMobileTheme(
          brightness: .light,
          style: ElStyle(onDark: ElStyle(vars: {ElTheme.$primary: Colors.orange})),
          child: ElView(
            themeMode: ElThemeMode(brightness: .dark),
            style: ElStyle(onDark: ElStyle(vars: {ElTheme.$cardColor: Colors.pink})),
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
    );
    portal.open();
    await tester.pumpAndSettle();
    expect(current.brightness, Brightness.dark);
    expect(current.cardTheme.color, Colors.pink);
    expect(opposite.brightness, Brightness.light);
    expect(opposite.cardTheme.color, ElMobileTheme.lightVars[ElTheme.$cardColor]);
    portal.close();
    await tester.pumpAndSettle();
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('无 ElView 时显式两轴使用通用默认值', (tester) async {
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
    expect(light.colorScheme.surface, ElTheme.lightVars[ElTheme.$bgColor]);
    expect(dark.colorScheme.surface, ElTheme.darkVars[ElTheme.$bgColor]);
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
          return ElMobileTheme(brightness: brightness, child: app);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(captured.brightness, Brightness.light);
    update(() => brightness = Brightness.dark);
    await tester.pumpAndSettle();
    expect(captured.brightness, Brightness.dark);
    expect(captured.scaffoldBackgroundColor, ElMobileTheme.darkVars[ElTheme.$bgColor]);
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
            return Row(
              children: [
                ElView(
                  style: ElStyle(onDark: ElStyle(vars: {ElTheme.$primary: firstDark})),
                  child: moved ? SizedBox() : reader,
                ),
                ElView(
                  style: ElStyle(onDark: ElStyle(vars: {ElTheme.$primary: Colors.orange})),
                  child: moved ? reader : SizedBox(),
                ),
              ],
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
