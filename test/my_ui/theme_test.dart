/// 参照：D:/project/html/my-ui/packages/core/my-ui.css:10-68、82-149。
/// 快照只保存该版本根token，不依赖Web仓库或联网。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/mobile.dart';

void main() {
  final expected = jsonDecode(_cssSnapshot) as Map<String, dynamic>;
  for (final mode in ['light', 'dark']) {
    test('$mode 全部根颜色、阴影、overlay与四档字重', () {
      final t = MyThemeData(
        brightness: mode == 'dark' ? Brightness.dark : Brightness.light,
      );
      expect(t.fontFamily, 'Times New Roman');
      expect(t.fontFamilyFallback, ['Microsoft YaHei', 'SimSun']);
      final colors = <String, Color>{
        'background': t.background,
        'card-background': t.cardBackground,
        'fill': t.fill,
        'border': t.border,
        'text': t.text,
        'text-secondary': t.textSecondary,
        'gray': t.gray,
        'hover': t.hover,
        'press': t.press,
        'selected-background': t.selectedBackground,
        'success': t.success,
        'warning': t.warning,
        'danger': t.danger,
        'primary': t.primary,
        'primary-text': t.primaryText,
      };
      for (final entry in colors.entries) {
        expect(
          entry.value.toARGB32(),
          expected[mode][entry.key],
          reason: entry.key,
        );
      }
      final shadows = <String, List<BoxShadow>>{
        'selected-shadow': t.selectedShadow,
        'small-shadow': t.smallShadow,
        'shadow': t.shadow,
        'popup-shadow': t.popupShadow,
        'modal-shadow': t.modalShadow,
      };
      for (final entry in shadows.entries) {
        final values = expected[mode][entry.key] as List;
        expect(entry.value.length, values.length, reason: entry.key);
        for (var i = 0; i < values.length; i++) {
          final shadow = entry.value[i], value = values[i] as List;
          expect(
            shadow.offset,
            Offset((value[0] as num).toDouble(), (value[1] as num).toDouble()),
          );
          expect(shadow.blurRadius, value[2]);
          expect(shadow.spreadRadius, value[3]);
          expect(shadow.color.toARGB32() & 0xffffff, value[4]);
          expect(shadow.color.a, closeTo(value[5] as num, .000001));
        }
      }
      expect(t.overlayBackdropBlur, 4);
      expect(
        t.overlayBackground.a,
        closeTo(mode == 'dark' ? .62 : .34, .000001),
      );
      expect(
        t.overlayBackground.toARGB32() & 0xffffff,
        mode == 'dark' ? 0 : 0x0c121c,
      );
      expect(
        [
          t.fontWeight,
          t.fontWeightAction,
          t.fontWeightSubtitle,
          t.fontWeightTitle,
        ],
        [400, 500, 600, 700],
      );
    });
  }

  test('主题字体 token 的覆写、保留和回退列表不可变', () {
    final fallback = ['Microsoft YaHei'];
    final data = MyThemeData(fontFamilyFallback: fallback);
    fallback.clear();
    expect(data.fontFamilyFallback, ['Microsoft YaHei']);
    expect(() => data.fontFamilyFallback.clear(), throwsUnsupportedError);
    final custom = data.copyWith(
      fontFamily: 'Arial',
      fontFamilyFallback: ['SimSun'],
    );
    expect(custom.fontFamily, 'Arial');
    expect(custom.fontFamilyFallback, ['SimSun']);
    expect(custom.copyWith(primary: Colors.blue).fontFamily, 'Arial');
    expect(custom.copyWith().fontFamilyFallback, ['SimSun']);
  });

  testWidgets('MyTheme 将默认和自定义字体同步给 Text 与 ElView，子级显式字体优先', (tester) async {
    final textKey = GlobalKey(),
        viewKey = GlobalKey(),
        explicitKey = GlobalKey();
    for (final data in [
      MyThemeData(),
      MyThemeData().copyWith(
        fontFamily: 'Arial',
        fontFamilyFallback: ['SimSun'],
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MyTheme(
            data: data,
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
        ),
      );
      final text = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(textKey),
          matching: find.byType(RichText),
        ),
      );
      final view = tester.renderObject<ElRenderView>(find.byKey(viewKey));
      expect(text.text.style!.height, kTextHeightNone);
      expect(text.text.style!.fontFamily, data.fontFamily);
      expect(text.text.style!.fontFamilyFallback, data.fontFamilyFallback);
      expect(
        view.committedResolvedStyle.inheritedText.lineHeight,
        kTextHeightNone,
      );
      expect(
        view.committedResolvedStyle.inheritedText.fontFamily,
        data.fontFamily,
      );
      expect(
        view.committedResolvedStyle.inheritedText.fontFamilyFallback,
        data.fontFamilyFallback,
      );
      expect(
        tester
            .renderObject<ElRenderView>(find.byKey(explicitKey))
            .committedResolvedStyle
            .inheritedText
            .fontFamily,
        'Courier New',
      );
      final explicitText = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Text 局部'),
          matching: find.byType(RichText),
        ),
      );
      expect(explicitText.text.style!.fontFamily, 'Courier New');
      expect(tester.takeException(), isNull);
    }
  });
}

final _cssSnapshot =
    r'''{"light":{"background":4294112245,"card-background":4294967295,"fill":4294046452,"border":4292731109,"text":4279703838,"text-secondary":4284639348,"gray":4290429646,"hover":4293520624,"press":4292928746,"selected-background":4294967295,"selected-shadow":[[0,1,4,0,1186085,0.1],[0,0,0,1,1186085,0.05]],"small-shadow":[[0,1,2,0,1186085,0.1]],"shadow":[[0,1,3,0,1186085,0.045],[0,4,12,0,1186085,0.025]],"popup-shadow":[[0,0,0,1,1186085,0.07],[0,4,12,0,1186085,0.12],[0,18,44,-8,1186085,0.24]],"modal-shadow":[[0,0,0,1,1186085,0.08],[0,8,24,0,1186085,0.14],[0,32,80,-12,1186085,0.3]],"success":4279724860,"warning":4286600448,"danger":4290062396,"primary":4280571078,"primary-text":4294967295},"dark":{"background":4279374873,"card-background":4280625457,"fill":4281547076,"border":4284048758,"text":4294244090,"text-secondary":4291087318,"gray":4286351772,"hover":4282139472,"press":4282797659,"selected-background":4282468694,"selected-shadow":[[0,1,5,0,0,0.28],[0,0,0,1,6846348,1]],"small-shadow":[[0,1,2,0,0,0.32]],"shadow":[[0,1,3,0,0,0.16],[0,4,12,0,0,0.12]],"popup-shadow":[[0,0,0,1,16777215,0.2],[0,4,12,0,0,0.36],[0,20,48,-8,0,0.7]],"modal-shadow":[[0,0,0,1,16777215,0.22],[0,8,24,0,0,0.44],[0,32,80,-12,0,0.82]],"success":4288995252,"warning":4294171522,"danger":4294945966,"primary":4289382655,"primary-text":4278190080}}''';
