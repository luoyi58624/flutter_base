import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (duration, curve) in [
    (Duration(milliseconds: 200), Curves.linear),
    (Duration(milliseconds: 400), Curves.easeInQuad),
    (Duration.zero, Curves.linear),
  ]) {
    testWidgets('背景、列表和底栏共享主题过渡：$duration，$curve', (tester) async {
      var brightness = Brightness.light;
      late StateSetter update;
      final content = Builder(
        builder: (context) {
          final mode = ElView.of(context).themeMode;
          return MaterialApp(
            theme: context.elMaterialThemeData,
            themeAnimationDuration: mode.duration!,
            themeAnimationCurve: mode.curve!,
            home: Scaffold(
              body: ElListGroup(
                children: [ElListTile(title: '列表行', onTap: () {})],
              ),
              bottomNavigationBar: ElBottomTabbar(
                onDestinationSelected: (_) {},
                destinations: [
                  NavigationDestination(icon: Icon(Icons.home), label: '首页'),
                  NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
                ],
              ),
            ),
          );
        },
      );
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ElView(
              themeMode: ElThemeMode(
                brightness: brightness,
                duration: duration == ElThemeMode.defaultDuration ? null : duration,
                curve: curve,
              ),
              child: ElComponentProvider(components: el.mobileComponents, child: content),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final group = find.byWidgetPredicate(
        (widget) => widget is ElView && widget.style?.borderRadius == BorderRadius.circular(16),
      );
      final bar = find.descendant(of: find.byType(ElBottomTabbar), matching: find.byType(ElView)).first;
      Color groupColor() => tester.renderObject<ElRenderView>(group).committedResolvedStyle.box.backgroundColor!;
      Color barColor() => tester.renderObject<ElRenderView>(bar).committedResolvedStyle.box.backgroundColor!;
      Color pageColor() => Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor;
      Color iconColor() => tester
          .renderObject<ElRenderView>(
            find.byWidgetPredicate((widget) => widget is ElView && widget.child == Icons.settings),
          )
          .committedResolvedStyle
          .inheritedBox
          .iconColor!;
      final row = find.byWidgetPredicate((widget) => widget is ElView && widget.style?.onTap?.backgroundColor != null);
      Color rowColor() => tester.renderObject<ElRenderView>(row).committedResolvedStyle.inheritedText.color!;
      final lightCard = el.mobileComponents.style!.vars![ElTokens.$cardColor] as Color;
      final darkCard = el.mobileComponents.style!.onDark!.vars![ElTokens.$cardColor] as Color;
      final lightBg = el.mobileComponents.style!.vars![ElTokens.$bgColor] as Color;
      final darkBg = el.mobileComponents.style!.onDark!.vars![ElTokens.$bgColor] as Color;
      final lightText = el.mobileComponents.style!.vars![ElTokens.$textColor] as Color;
      final darkText = el.mobileComponents.style!.onDark!.vars![ElTokens.$textColor] as Color;
      final lightIcon = el.mobileComponents.style!.vars![ElTokens.$textSecondary] as Color;
      final darkIcon = el.mobileComponents.style!.onDark!.vars![ElTokens.$textSecondary] as Color;
      expect(groupColor(), lightCard);
      expect(barColor(), lightCard);
      update(() => brightness = Brightness.dark);
      await tester.pump();
      await tester.pump();
      for (final progress in [.25, .5, .75, 1.0]) {
        await tester.pump(duration ~/ 4);
        final t = duration == Duration.zero ? 1.0 : curve.transform(progress);
        expect(pageColor(), isSameColorAs(Color.lerp(lightBg, darkBg, t)!, threshold: 1e-9));
        expect(groupColor(), isSameColorAs(Color.lerp(lightCard, darkCard, t)!, threshold: 1e-9));
        expect(barColor(), isSameColorAs(groupColor(), threshold: 1e-9));
        expect(rowColor(), isSameColorAs(Color.lerp(lightText, darkText, t)!, threshold: 1e-9));
        expect(iconColor(), isSameColorAs(Color.lerp(lightIcon, darkIcon, t)!, threshold: 1e-9));
      }
      expect(pageColor(), darkBg);
      expect(groupColor(), darkCard);
      expect(barColor(), darkCard);
      expect(tester.takeException(), isNull);
    });
  }

  for (final nestedOrigin in [false, true]) {
    testWidgets('LayoutBuilder 内的固定变量读者与 Material 同步主题过渡，来源独立构建范围：$nestedOrigin', (tester) async {
      var brightness = Brightness.light;
      late StateSetter update;
      late Color materialCardColor;
      final cardKey = ValueKey('layout-theme-card');
      final lightCard = el.mobileComponents.style!.vars![ElTokens.$cardColor] as Color;
      final darkCard = el.mobileComponents.style!.onDark!.vars![ElTokens.$cardColor] as Color;
      // 固定载荷实例，确保变量通知负责重建独立构建范围内的读者。
      final content = LayoutBuilder(
        builder: (_, constraints) => Builder(
          builder: (context) => ElView(
            key: cardKey,
            style: ElStyle(width: 80, height: 40, backgroundColor: context.elTheme.cardColor),
          ),
        ),
      );
      final materialReader = Builder(
        builder: (context) {
          materialCardColor = Theme.of(context).cardTheme.color!;
          return content;
        },
      );
      final themeReader = Builder(
        builder: (context) {
          final mode = ElView.of(context).themeMode;
          return MaterialApp(
            theme: context.elMaterialThemeData,
            themeAnimationDuration: mode.duration!,
            themeAnimationCurve: mode.curve!,
            home: Scaffold(body: materialReader),
          );
        },
      );
      final source = StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return ElView(
            themeMode: ElThemeMode(brightness: brightness, duration: Duration(milliseconds: 200), curve: Curves.linear),
            child: ElComponentProvider(components: el.mobileComponents, child: themeReader),
          );
        },
      );
      await tester.pumpWidget(nestedOrigin ? LayoutBuilder(builder: (_, constraints) => source) : source);
      await tester.pumpAndSettle();
      Color cardColor() =>
          tester.renderObject<ElRenderView>(find.byKey(cardKey)).committedResolvedStyle.box.backgroundColor!;
      expect(cardColor(), lightCard);
      expect(materialCardColor, lightCard);

      for (final target in [Brightness.dark, Brightness.light]) {
        final start = target == Brightness.dark ? lightCard : darkCard;
        final end = target == Brightness.dark ? darkCard : lightCard;
        update(() => brightness = target);
        await tester.pump();
        expect(cardColor(), start);
        expect(materialCardColor, start);
        var elapsed = Duration.zero;
        for (final delta in [Duration(milliseconds: 16), Duration(milliseconds: 84), Duration(milliseconds: 100)]) {
          elapsed += delta;
          await tester.pump(delta);
          final expected = Color.lerp(start, end, elapsed.inMilliseconds / 200)!;
          expect(materialCardColor, isSameColorAs(expected, threshold: 1e-9));
          expect(
            cardColor(),
            isSameColorAs(materialCardColor, threshold: 1e-9),
            reason: '切换到 $target 后 ${elapsed.inMilliseconds}ms',
          );
        }
        expect(cardColor(), end);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('主题读面补齐默认值，逐字段继承并响应动画参数更新', (tester) async {
    var duration = Duration(milliseconds: 400);
    var curve = Curves.easeIn;
    late StateSetter update;
    late ElThemeMode inherited, overridden;
    final readers = Row(
      children: [
        ElView(
          themeMode: ElThemeMode(brightness: Brightness.dark),
          child: Builder(
            builder: (context) {
              inherited = ElView.of(context).themeMode;
              return SizedBox();
            },
          ),
        ),
        ElView(
          themeMode: ElThemeMode(duration: Duration(milliseconds: 100)),
          child: Builder(
            builder: (context) {
              overridden = ElView.of(context).themeMode;
              return SizedBox();
            },
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ElView(
              themeMode: ElThemeMode(duration: duration, curve: curve),
              child: readers,
            );
          },
        ),
      ),
    );
    expect(inherited.brightness, Brightness.dark);
    expect(inherited.duration, duration);
    expect(inherited.curve, curve);
    expect(overridden.brightness, Brightness.light);
    expect(overridden.duration, Duration(milliseconds: 100));
    update(() {
      duration = Duration(milliseconds: 600);
      curve = Curves.easeOut;
    });
    await tester.pump();
    expect(inherited.duration, duration);
    expect(inherited.curve, curve);
    expect(overridden.duration, Duration(milliseconds: 100));
    expect(overridden.curve, curve);
    await tester.pumpWidget(
      ElView(
        child: Builder(
          builder: (context) {
            inherited = ElView.of(context).themeMode;
            return SizedBox();
          },
        ),
      ),
    );
    expect(inherited.brightness, Brightness.light);
    expect(inherited.duration, Duration(milliseconds: 200));
    expect(inherited.curve, Curves.linear);
  });
}
