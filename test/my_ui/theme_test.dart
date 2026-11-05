/// 参照：D:/project/html/my-ui/packages/core/my-ui.css:10-68、82-149。
/// 颜色以 Web 为基线，页面使用中性灰，五档阴影以同色背景校准并按卡片和弹窗用途分档。
/// 语义色例外：移动端语义色以设计稿为准（#1076FD / #56B329 / #F9A907 / #FC4646），
/// Web 原型 `--primary` 仍是 #2454c6，两者不再逐值对齐。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/mobile.dart';

void main() {
  final expected = jsonDecode(_themeSnapshot) as Map<String, dynamic>;
  expected['light']['background'] = 0xffeeeeee;
  for (final mode in ['light', 'dark']) {
    testWidgets('$mode 全部根颜色、阴影、overlay与四档字重', (tester) async {
      late ElThemeExt t;
      await tester.pumpWidget(
        MaterialApp(
          home: ElView(
            themeMode: ElThemeMode(brightness: mode == 'dark' ? Brightness.dark : Brightness.light),
            child: ElComponentProvider(
              components: el.mobileComponents,
              child: Builder(
                builder: (context) {
                  t = context.elTheme;
                  return SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(t.fontFamily, isEmpty);
      expect(t.fontFamilyFallback, isEmpty);
      expect(t.cardPressColor, Color(mode == 'dark' ? 0xff464e5b : 0xffe0e0e0));
      expect(t.dividerColor, Color(mode == 'dark' ? 0xff596576 : 0xffe0e0e0));
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
        'extra-small-shadow': t.shadowXs,
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
    expect(el.mobileComponents.style!.vars![ElTokens.$fontFamily], isEmpty);
    expect(el.mobileComponents.style!.vars![ElTokens.$fontFamilyFallback], isEmpty);
    expect(() => el.mobileComponents.style!.vars!.clear(), throwsUnsupportedError);
    expect(el.mobileComponents.style!.onDark!.vars!.containsKey(ElTokens.$fontFamily), isFalse);
    expect(el.mobileComponents.style!.onDark!.vars!.containsKey(ElTokens.$fontWeight), isFalse);
    expect(
      () => (el.mobileComponents.style!.vars![ElTokens.$fontFamilyFallback] as List<String>).clear(),
      throwsUnsupportedError,
    );
  });

  testWidgets('暗色差量保留基础字体和字重 token 的局部覆写', (tester) async {
    late ElThemeExt theme;
    await tester.pumpWidget(
      MaterialApp(
        home: ElView(
          themeMode: ElThemeMode(brightness: Brightness.dark),
          child: ElComponentProvider(
            components: el.mobileComponents,
            child: ElView(
              style: ElStyle(
                vars: {
                  ElTokens.$fontFamily: 'Arial',
                  ElTokens.$fontFamilyFallback: ['SimSun'],
                  ElTokens.$fontWeight: 500,
                  ElTokens.$fontWeightAction: 600,
                },
              ),
              child: Builder(
                builder: (context) {
                  theme = context.elTheme;
                  return SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(theme.brightness, Brightness.dark);
    expect(theme.fontFamily, 'Arial');
    expect(theme.fontFamilyFallback, ['SimSun']);
    expect(theme.fontWeight, 500);
    expect(theme.fontWeightAction, 600);
  });

  testWidgets('应用管理 Text 的排版，ElView 可独立设置并覆写字体', (tester) async {
    final textKey = GlobalKey(), viewKey = GlobalKey(), explicitKey = GlobalKey();
    String? ambientFamily;
    List<String>? ambientFallback;
    double? ambientHeight;
    for (final data in [
      ElStyle(),
      ElStyle(fontFamily: 'Arial', fontFamilyFallback: ['SimSun'], lineHeight: 1.4),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final ambient = DefaultTextStyle.of(context).style;
              ambientFamily = ambient.fontFamily;
              ambientFallback = ambient.fontFamilyFallback;
              ambientHeight = ambient.height;
              return ElComponentProvider(
                components: el.mobileComponents,
                child: ElView(
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
      expect(text.text.style!.height, ambientHeight);
      expect(text.text.style!.fontFamily, ambientFamily);
      expect(text.text.style!.fontFamilyFallback, ambientFallback);
      expect(view.committedResolvedStyle.inheritedText.lineHeight, data.lineHeight ?? 1.2);
      expect(view.committedResolvedStyle.inheritedText.fontFamily, data.fontFamily);
      expect(view.committedResolvedStyle.inheritedText.fontFamilyFallback, data.fontFamilyFallback);
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
      home: ElComponentProvider(
        components: el.mobileComponents,
        child: ElView(
          style: ElStyle(vars: {ElTokens.$primary: color}),
          child: child,
        ),
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
        home: ElView(
          themeMode: ElThemeMode(brightness: Brightness.dark),
          child: ElComponentProvider(
            components: el.mobileComponents,
            child: Column(
              children: [
                ElView(
                  style: ElStyle(
                    vars: {ElTokens.$primary: Color(0xff123456), ElTokens.$radiusLg: 18},
                    onDark: ElStyle(vars: {ElTokens.$primary: Color(0xff654321)}),
                  ),
                  child: Builder(
                    builder: (context) {
                      local = context.elTheme.primary;
                      radius = ElView.of(context).getVar<num>(ElTokens.$radiusLg)?.toDouble();
                      return ElCard(
                        style: ElStyle(borderRadius: .circular(context.elTheme.radiusLg)),
                        child: SizedBox(),
                      );
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
      ),
    );
    expect(local, Color(0xff654321));
    expect(sibling, el.mobileComponents.style!.onDark!.vars![ElTokens.$primary]);
    expect(radius, 18);
  });
}

final _themeSnapshot =
    r'''{"light":{"background":4294112245,"card-background":4294967295,"fill":4294046452,"border":4292731109,"text":4279703838,"text-secondary":4284639348,"gray":4290429646,"hover":4293520624,"press":4292928746,"selected-background":4294967295,"selected-shadow":[[0,1,4,0,1186085,0.1],[0,0,0,1,1186085,0.05]],"small-shadow":[[0,1,4,0,3229289,0.055],[0,2,7,-1,3229289,0.04]],"shadow":[[0,1,5,0,3229289,0.065],[0,4,14,-1,3229289,0.065]],"popup-shadow":[[0,2,7,0,3229289,0.075],[0,8,22,-2,3229289,0.095]],"modal-shadow":[[0,3,9,0,3229289,0.085],[0,14,34,-4,3229289,0.12]],"success":4283872041,"warning":4294551815,"danger":4294723142,"primary":4279269117,"primary-text":4294967295,"extra-small-shadow":[[0,1,3,0,3229289,0.055]]},"dark":{"background":4279374873,"card-background":4280625457,"fill":4281547076,"border":4284048758,"text":4294244090,"text-secondary":4291087318,"gray":4286351772,"hover":4282139472,"press":4282797659,"selected-background":4282468694,"selected-shadow":[[0,1,5,0,0,0.28],[0,0,0,1,6846348,1]],"small-shadow":[[0,1,4,0,0,0.2],[0,2,7,-1,0,0.16]],"shadow":[[0,1,5,0,0,0.24],[0,4,14,-1,0,0.22]],"popup-shadow":[[0,2,7,0,0,0.28],[0,8,22,-2,0,0.3]],"modal-shadow":[[0,3,9,0,0,0.32],[0,14,34,-4,0,0.38]],"success":4288995252,"warning":4294171522,"danger":4294945966,"primary":4289382655,"primary-text":4278190080,"extra-small-shadow":[[0,1,3,0,0,0.18]]}}''';
