import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/ui/mobile/cores/theme.dart' as theme;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final originalReader = theme.readSystemFontWeight;
  tearDown(() => theme.readSystemFontWeight = originalReader);

  testWidgets('系统小数字重轴同步到普通 Text、ElView 与官方主题，保留组件字重档位', (tester) async {
    theme.readSystemFontWeight = () => 590.5;
    final textKey = GlobalKey(), viewKey = GlobalKey();
    late ThemeData material;
    late ElThemeExt tokens;
    await tester.pumpWidget(
      MaterialApp(
        home: ElMobileTheme(
          brightness: .dark,
          child: Builder(
            builder: (context) {
              tokens = context.elTheme;
              material = context.elMaterialThemeData;
              return Column(
                children: [
                  Text('普通文字', key: textKey),
                  ElView(key: viewKey, child: '视图文字'),
                  Expanded(
                    child: Theme(
                      data: material,
                      child: Scaffold(
                        appBar: AppBar(title: Text('官方标题')),
                        body: TextButton(onPressed: () {}, child: Text('官方按钮')),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final expected = [FontVariation('wght', 590.5)];
    final text = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(textKey), matching: find.byType(RichText)),
    );
    expect(text.text.style!.fontVariations, expected);
    expect(text.text.style!.fontWeight, FontWeight.w400);
    final view = tester.renderObject<ElRenderView>(find.byKey(viewKey));
    expect(view.committedResolvedStyle.inheritedText.fontVariationSettings, expected);
    expect(view.committedResolvedStyle.inheritedText.fontWeight, FontWeight.w400);
    for (final style in [
      material.textTheme.bodyMedium!,
      material.primaryTextTheme.bodyLarge!,
      material.appBarTheme.titleTextStyle!,
      material.textButtonTheme.style!.textStyle!.resolve({})!,
    ]) {
      expect(style.fontVariations, expected);
    }
    expect(DefaultTextStyle.of(tester.element(find.text('官方按钮'))).style.fontVariations, expected);
    expect([tokens.fontWeight, tokens.fontWeightAction, tokens.fontWeightTitle], [400, 500, 700]);
    expect(material.appBarTheme.titleTextStyle!.fontWeight, FontWeight.w700);
    expect(material.textButtonTheme.style!.textStyle!.resolve({})!.fontWeight, FontWeight.w500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('显式轴与空列表覆盖系统轴，后代仍可局部覆写', (tester) async {
    theme.readSystemFontWeight = () => 590.5;
    final textKey = GlobalKey(), localKey = GlobalKey();
    late ThemeData material;
    for (final axes in [
      <FontVariation>[],
      [FontVariation('wght', 350), FontVariation('wdth', 90)],
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ElMobileTheme(
            style: ElStyle(fontVariationSettings: axes),
            child: Builder(
              builder: (context) {
                material = context.elMaterialThemeData;
                return Column(
                  children: [
                    Text('普通文字', key: textKey),
                    ElView(
                      key: localKey,
                      style: ElStyle(fontVariationSettings: [FontVariation('wght', 700)]),
                      child: '局部文字',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.byKey(textKey), matching: find.byType(RichText)),
      );
      expect(text.text.style!.fontVariations, axes);
      expect(material.textTheme.bodyMedium!.fontVariations, axes);
      expect(
        tester
            .renderObject<ElRenderView>(find.byKey(localKey))
            .committedResolvedStyle
            .inheritedText
            .fontVariationSettings,
        [FontVariation('wght', 700)],
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('未支持平台或无效返回值保留默认字体，合法边界原样传递', (tester) async {
    for (final value in [null, double.nan, double.infinity, 99.0, 1001.0, 100.0, 1000.0]) {
      theme.readSystemFontWeight = () => value;
      late ThemeData material;
      await tester.pumpWidget(
        ElMobileTheme(
          child: Builder(
            builder: (context) {
              material = context.elMaterialThemeData;
              return MaterialApp(
                theme: material,
                home: Scaffold(body: Text('正文')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        material.textTheme.bodyMedium!.fontVariations,
        value == 100 || value == 1000 ? [FontVariation('wght', value!)] : isNull,
      );
      expect(material.textTheme.bodyMedium!.fontFamily, ThemeData().textTheme.bodyMedium!.fontFamily);
      expect(material.textTheme.bodyMedium!.fontWeight, FontWeight.w400);
      expect(tester.takeException(), isNull);
    }
  });
}
