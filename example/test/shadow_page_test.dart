import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/src/pages/components/start/shadow/index.dart';

Future<void> _host(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: Builder(
        builder: (context) => MaterialApp(theme: context.elMaterialThemeData, home: ShadowPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ElStyle _card(WidgetTester tester, ElLevelType level) =>
    tester.widget<ElCardView>(find.byKey(ValueKey('shadow-${level.name}'), skipOffstage: false)).style!;

void main() {
  for (final size in [Size(320, 700), Size(800, 400), Size(1280, 900)]) {
    testWidgets('五级卡片使用 Wrap 自适应布局 $size', (tester) async {
      final original = el.mobileComponents.style!.vars![ElTokens.$shadowMd];
      await _host(tester, size);
      for (final level in ElLevelType.values) {
        final style = _card(tester, level);
        expect(style.boxShadow, hasLength(3));
        expect(style.borderRadius, BorderRadius.circular(16));
        expect(
          find.ancestor(
            of: find.byKey(ValueKey('shadow-${level.name}'), skipOffstage: false),
            matching: find.byType(Wrap),
          ),
          findsWidgets,
        );
      }
      expect(find.byKey(ValueKey('shadow-type')), findsOneWidget);
      final first = tester.getTopLeft(find.byKey(ValueKey('shadow-xs'), skipOffstage: false));
      final last = tester.getTopLeft(find.byKey(ValueKey('shadow-xl'), skipOffstage: false));
      if (size.width == 320) {
        expect(last.dy, greaterThan(first.dy));
        expect(last.dx, first.dx);
      } else if (size.width == 1280) {
        expect(last.dy, first.dy);
        expect(last.dx, greaterThan(first.dx));
      }
      expect(find.text('阴影游乐场'), findsNothing);
      expect(find.byType(ElSlider<double>), findsNothing);
      expect(el.mobileComponents.style!.vars![ElTokens.$shadowMd], same(original));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('导航栏下拉切换全部风格，所有层级同步更新', (tester) async {
    await _host(tester, Size(1280, 900));
    final initial = _card(tester, .md).boxShadow;
    await tester.tap(find.byKey(ValueKey('shadow-type')));
    await tester.pumpAndSettle();
    expect(find.text('四周均匀'), findsOneWidget);
    await tester.tap(find.text('四周均匀'));
    await tester.pumpAndSettle();
    for (final level in ElLevelType.values) {
      expect(_card(tester, level).boxShadow!.every((shadow) => shadow.offset == Offset.zero), isTrue);
    }
    expect(_card(tester, .md).boxShadow, isNot(initial));
    for (final type in ElShadowType.values) {
      final dropdown = tester.widget<DropdownButton<ElShadowType>>(find.byKey(ValueKey('shadow-type')));
      expect(dropdown.items!.map((item) => item.value), ElShadowType.values);
      dropdown.onChanged!(type);
      await tester.pumpAndSettle();
      for (final level in ElLevelType.values) {
        final shadows = _card(tester, level).boxShadow!;
        expect(shadows.every((shadow) => (shadow as ElBoxShadow).inset), type == .inset);
      }
    }
    expect(tester.takeException(), isNull);
  });
}
