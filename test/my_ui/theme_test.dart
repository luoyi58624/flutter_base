/// 参照：D:/project/html/my-ui/packages/core/my-ui.css:10-68、82-149。
/// 快照只保存该版本根token，不依赖Web仓库或联网。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/ui/mobile/components/card/index.dart' as skin;

void main() {
  final expected = jsonDecode(_cssSnapshot) as Map<String, dynamic>;
  for (final mode in ['light', 'dark']) {
    testWidgets('$mode 全部根颜色、阴影、overlay与四档字重', (tester) async {
      late ElThemeExt t;
      await tester.pumpWidget(
        MaterialApp(
          home: ElMobileTheme(
            brightness: mode == 'dark' ? Brightness.dark : Brightness.light,
            child: Builder(
              builder: (context) {
                t = context.elTheme;
                return SizedBox();
              },
            ),
          ),
        ),
      );
      expect(t.fontFamily, isEmpty);
      expect(t.fontFamilyFallback, isEmpty);
      final colors = <String, Color>{
        'background': t.bgColor,
        'card-background': t.cardColor,
        'fill': t.fill,
        'border': t.borderColor,
        'text': t.textColor,
        'text-secondary': t.textSecondary,
        'gray': t.gray,
        'hover': t.hover,
        'press': t.press,
        'selected-background': t.selectedBackground,
        'success': t.success,
        'warning': t.warning,
        'danger': t.error,
        'primary': t.primary,
        'primary-text': t.primaryText,
      };
      for (final entry in colors.entries) {
        expect(entry.value.toARGB32(), expected[mode][entry.key], reason: entry.key);
      }
      final shadows = <String, List<BoxShadow>>{
        'selected-shadow': t.selectedShadow,
        'small-shadow': t.shadowSm,
        'shadow': t.shadowMd,
        'popup-shadow': t.shadowLg,
        'modal-shadow': t.shadowXl,
      };
      for (final entry in shadows.entries) {
        final values = expected[mode][entry.key] as List;
        expect(entry.value.length, values.length, reason: entry.key);
        for (var i = 0; i < values.length; i++) {
          final shadow = entry.value[i], value = values[i] as List;
          expect(shadow.offset, Offset((value[0] as num).toDouble(), (value[1] as num).toDouble()));
          expect(shadow.blurRadius, value[2]);
          expect(shadow.spreadRadius, value[3]);
          expect(shadow.color.toARGB32() & 0xffffff, value[4]);
          expect(shadow.color.a, closeTo(value[5] as num, .000001));
        }
      }
      expect(t.overlayBackdropBlur, 4);
      expect(t.overlayColor.a, closeTo(mode == 'dark' ? .62 : .34, .000001));
      expect(t.overlayColor.toARGB32() & 0xffffff, mode == 'dark' ? 0 : 0x0c121c);
      expect([t.fontWeight, t.fontWeightAction, t.fontWeightSubtitle, t.fontWeightTitle], [400, 500, 600, 700]);
    });
  }

  test('默认字体未指定，变量表保持只读', () {
    expect(ElMobileTheme.lightVars[ElTheme.$fontFamily], isEmpty);
    expect(ElMobileTheme.lightVars[ElTheme.$fontFamilyFallback], isEmpty);
    expect(() => ElMobileTheme.lightVars.clear(), throwsUnsupportedError);
    expect(ElMobileTheme.darkVars.containsKey(ElTheme.$fontFamily), isFalse);
    expect(ElMobileTheme.darkVars.containsKey(ElTheme.$fontWeight), isFalse);
    expect(
      () => (ElMobileTheme.lightVars[ElTheme.$fontFamilyFallback] as List<String>).clear(),
      throwsUnsupportedError,
    );
  });

  testWidgets('暗色增量不遮蔽基础字体和字重覆写，Text 与 ElView 同步', (tester) async {
    final textKey = GlobalKey(), viewKey = GlobalKey();
    late ElThemeExt theme;
    await tester.pumpWidget(
      MaterialApp(
        home: ElMobileTheme(
          brightness: Brightness.dark,
          style: ElStyle(
            vars: {
              ElTheme.$fontFamily: 'Arial',
              ElTheme.$fontFamilyFallback: ['SimSun'],
              ElTheme.$fontWeight: 500,
              ElTheme.$fontWeightAction: 600,
            },
          ),
          child: Builder(
            builder: (context) {
              theme = context.elTheme;
              return Column(
                children: [
                  Text('暗色正文', key: textKey),
                  ElView(key: viewKey, child: '暗色视图'),
                ],
              );
            },
          ),
        ),
      ),
    );
    expect(theme.fontFamily, 'Arial');
    expect(theme.fontFamilyFallback, ['SimSun']);
    expect(theme.fontWeight, 500);
    expect(theme.fontWeightAction, 600);
    final text = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(textKey), matching: find.byType(RichText)),
    );
    expect(text.text.style!.fontFamily, 'Arial');
    expect(text.text.style!.fontFamilyFallback, ['SimSun']);
    expect(text.text.style!.fontWeight, FontWeight.w500);
    expect(text.text.style!.fontVariations, isNull);
    final view = tester.renderObject<ElRenderView>(find.byKey(viewKey));
    expect(view.committedResolvedStyle.inheritedText.fontFamily, 'Arial');
    expect(view.committedResolvedStyle.inheritedText.fontWeight, FontWeight.w500);
    expect(view.committedResolvedStyle.inheritedText.fontVariationSettings, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ElMobileTheme 将默认和自定义字体同步给 Text 与 ElView，子级显式字体优先', (tester) async {
    final textKey = GlobalKey(), viewKey = GlobalKey(), explicitKey = GlobalKey();
    String? ambientFamily;
    List<String>? ambientFallback;
    for (final data in [
      ElStyle(),
      ElStyle(
        vars: {
          ElTheme.$fontFamily: 'Arial',
          ElTheme.$fontFamilyFallback: ['SimSun'],
        },
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final ambient = DefaultTextStyle.of(context).style;
              ambientFamily = ambient.fontFamily;
              ambientFallback = ambient.fontFamilyFallback;
              return ElMobileTheme(
                style: data,
                child: Column(
                  children: [
                    Text('Text 默认', key: textKey),
                    ElView(key: viewKey, child: 'ElView 默认'),
                    ElView(
                      key: explicitKey,
                      style: ElStyle(fontFamily: 'Courier New'),
                      child: '局部字体',
                    ),
                    Text('Text 局部', style: TextStyle(fontFamily: 'Courier New')),
                  ],
                ),
              );
            },
          ),
        ),
      );
      final text = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.byKey(textKey), matching: find.byType(RichText)),
      );
      final view = tester.renderObject<ElRenderView>(find.byKey(viewKey));
      expect(text.text.style!.height, kTextHeightNone);
      expect(text.text.style!.fontFamily, data.vars?[ElTheme.$fontFamily] ?? ambientFamily);
      expect(text.text.style!.fontFamilyFallback, data.vars?[ElTheme.$fontFamilyFallback] ?? ambientFallback);
      expect(view.committedResolvedStyle.inheritedText.lineHeight, kTextHeightNone);
      expect(view.committedResolvedStyle.inheritedText.fontFamily, data.vars?[ElTheme.$fontFamily]);
      expect(view.committedResolvedStyle.inheritedText.fontFamilyFallback, data.vars?[ElTheme.$fontFamilyFallback]);
      expect(
        tester.renderObject<ElRenderView>(find.byKey(explicitKey)).committedResolvedStyle.inheritedText.fontFamily,
        'Courier New',
      );
      final explicitText = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text('Text 局部'), matching: find.byType(RichText)),
      );
      expect(explicitText.text.style!.fontFamily, 'Courier New');
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('固定子树按键订阅，改主色不重建只读正文色的读取者', (tester) async {
    var color = Color(0xff123456);
    var primaryBuilds = 0, textBuilds = 0;
    Color? primary;
    final child = Column(
      children: [
        Builder(
          builder: (context) {
            primaryBuilds++;
            primary = context.elTheme.primary;
            return SizedBox();
          },
        ),
        Builder(
          builder: (context) {
            textBuilds++;
            context.elTheme.textColor;
            return SizedBox();
          },
        ),
      ],
    );
    Widget host() => MaterialApp(
      home: ElMobileTheme(
        style: ElStyle(vars: {ElTheme.$primary: color}),
        child: child,
      ),
    );
    await tester.pumpWidget(host());
    expect(primary, color);
    expect(primaryBuilds, 1);
    expect(textBuilds, 1);
    color = Color(0xff654321);
    await tester.pumpWidget(host());
    expect(primary, color);
    expect(primaryBuilds, 2);
    expect(textBuilds, 1);
  });

  testWidgets('普通 ElView 局部变量覆盖与暗色变体按键级联，兄弟继续继承', (tester) async {
    Color? local, sibling;
    double? radius;
    await tester.pumpWidget(
      MaterialApp(
        home: ElMobileTheme(
          brightness: Brightness.dark,
          child: Column(
            children: [
              ElView(
                style: ElStyle(
                  vars: {ElTheme.$primary: Color(0xff123456), skin.Card.$radius: 18},
                  onDark: ElStyle(vars: {ElTheme.$primary: Color(0xff654321)}),
                ),
                child: Builder(
                  builder: (context) {
                    local = context.elTheme.primary;
                    radius = ElView.of(context).getVar<num>(skin.Card.$radius)?.toDouble();
                    return skin.Card(child: SizedBox());
                  },
                ),
              ),
              Builder(
                builder: (context) {
                  sibling = context.elTheme.primary;
                  return SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );
    expect(local, Color(0xff654321));
    expect(sibling, ElMobileTheme.darkVars[ElTheme.$primary]);
    expect(radius, 18);
  });
}

final _cssSnapshot =
    r'''{"light":{"background":4294112245,"card-background":4294967295,"fill":4294046452,"border":4292731109,"text":4279703838,"text-secondary":4284639348,"gray":4290429646,"hover":4293520624,"press":4292928746,"selected-background":4294967295,"selected-shadow":[[0,1,4,0,1186085,0.1],[0,0,0,1,1186085,0.05]],"small-shadow":[[0,1,2,0,1186085,0.1]],"shadow":[[0,1,3,0,1186085,0.045],[0,4,12,0,1186085,0.025]],"popup-shadow":[[0,0,0,1,1186085,0.07],[0,4,12,0,1186085,0.12],[0,18,44,-8,1186085,0.24]],"modal-shadow":[[0,0,0,1,1186085,0.08],[0,8,24,0,1186085,0.14],[0,32,80,-12,1186085,0.3]],"success":4279724860,"warning":4286600448,"danger":4290062396,"primary":4280571078,"primary-text":4294967295},"dark":{"background":4279374873,"card-background":4280625457,"fill":4281547076,"border":4284048758,"text":4294244090,"text-secondary":4291087318,"gray":4286351772,"hover":4282139472,"press":4282797659,"selected-background":4282468694,"selected-shadow":[[0,1,5,0,0,0.28],[0,0,0,1,6846348,1]],"small-shadow":[[0,1,2,0,0,0.32]],"shadow":[[0,1,3,0,0,0.16],[0,4,12,0,0,0.12]],"popup-shadow":[[0,0,0,1,16777215,0.2],[0,4,12,0,0,0.36],[0,20,48,-8,0,0.7]],"modal-shadow":[[0,0,0,1,16777215,0.22],[0,8,24,0,0,0.44],[0,32,80,-12,0,0.82]],"success":4288995252,"warning":4294171522,"danger":4294945966,"primary":4289382655,"primary-text":4278190080}}''';
