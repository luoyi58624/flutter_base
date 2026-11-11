import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart';

ResolvedStyle _resolve(ElStyle? style, {ResolvedStyle? parent, int state = 0}) =>
    StyleResolver.resolve(style: style, parent: parent, state: state);

void main() {
  test('高级配置逐字段合并，copyWith 区分未传入与显式清空', () {
    final base = ElTextOptions(
      locale: Locale('ja'),
      textWidthBasis: TextWidthBasis.longestLine,
      leadingDistribution: TextLeadingDistribution.proportional,
    );
    final merged = ElStyle(textOptions: base).merge(
      ElStyle(
        textOptions: ElTextOptions(textWidthBasis: TextWidthBasis.parent, textBaseline: TextBaseline.ideographic),
      ),
    );
    expect(merged.textOptions!.locale, Locale('ja'));
    expect(merged.textOptions!.textWidthBasis, TextWidthBasis.parent);
    expect(merged.textOptions!.textBaseline, TextBaseline.ideographic);
    expect(base.copyWith().locale, Locale('ja'));
    expect(base.copyWith(locale: null).locale, isNull);
    expect(base.copyWith(leadingDistribution: null).leadingDistribution, isNull);
    expect(merged.copyWith(textOptions: null).textOptions, isNull);
  });

  test('全部高级选项留在本地声明，不进入继承快照', () {
    final options = ElTextOptions(
      locale: Locale('ja'),
      textScaler: TextScaler.linear(2),
      strutStyle: StrutStyle(fontSize: 20),
      textWidthBasis: TextWidthBasis.longestLine,
      textHeightBehavior: TextHeightBehavior(applyHeightToFirstAscent: false),
      leadingDistribution: TextLeadingDistribution.proportional,
      textBaseline: TextBaseline.ideographic,
    );
    final style = ElStyle(textOptions: options);
    final parent = _resolve(style);
    expect(style.textOptions, same(options));
    expect(parent, _resolve(null));
    expect(_resolve(null, parent: parent), _resolve(null));
  });

  test('项目全局字体的四个常用字段保持继承与变体', () {
    final base = ElStyle(
      fontFamilyFallback: ['Ahem'],
      fontFeatureSettings: [FontFeature.tabularFigures()],
      fontVariationSettings: [FontVariation('wght', 590)],
      wordSpacing: 2,
      onHover: ElStyle(
        fontFamilyFallback: ['Roboto'],
        fontFeatureSettings: [FontFeature.disable('liga')],
        fontVariationSettings: [FontVariation('wght', 350)],
        wordSpacing: 4,
      ),
    );
    for (final active in [false, true]) {
      final parent = _resolve(base, state: active ? 1 << ViewState.hover.index : 0);
      final child = _resolve(null, parent: parent).inheritedText;
      final expected = active ? base.onHover! : base;
      expect(child.fontFamilyFallback, expected.fontFamilyFallback);
      expect(child.fontFeatureSettings, expected.fontFeatureSettings);
      expect(child.fontVariationSettings, expected.fontVariationSettings);
      expect(child.wordSpacing, expected.wordSpacing);
    }
  });

  final variants = <String, ElStyle Function(ElStyle)>{
    'onHover': (value) => ElStyle(onHover: value),
    'onTap': (value) => ElStyle(onTap: value),
    'onFocus': (value) => ElStyle(onFocus: value),
    'onFocusVisible': (value) => ElStyle(onFocusVisible: value),
    'onFocusWithin': (value) => ElStyle(onFocusWithin: value),
    'onDisabled': (value) => ElStyle(onDisabled: value),
    'onSelection': (value) => ElStyle(onSelection: value),
    'onDark': (value) => ElStyle(onDark: value),
    'xs': (value) => ElStyle(xs: value),
    'sm': (value) => ElStyle(sm: value),
    'md': (value) => ElStyle(md: value),
    'lg': (value) => ElStyle(lg: value),
    'xl': (value) => ElStyle(xl: value),
    'starting': (value) => ElStyle(starting: value),
    'keyframe': (value) => ElStyle(
      animation: [
        ElAnimation(keyframes: {0: value, 100: ElStyle(opacity: 1)}, animationDuration: Duration(milliseconds: 100)),
      ],
    ),
  };
  for (final variant in variants.entries) {
    test('高级配置禁止进入 ${variant.key}，未命中的声明也拒绝', () {
      final invalid = variant.value(
        ElStyle(textOptions: ElTextOptions(leadingDistribution: TextLeadingDistribution.even)),
      );
      expect(() => _resolve(invalid), throwsArgumentError);
      expect(() => _resolve(ElStyle(onHover: invalid)), throwsArgumentError);
    });
  }

  testWidgets('祖先高级选项不会穿过纯盒影响文本，常用字段变体保持有效', (tester) async {
    final parentKey = GlobalKey();
    final leafKey = GlobalKey();
    final bridgeKey = GlobalKey();
    final leaf = ElView(
      key: leafKey,
      style: ElStyle(
        fontWeight: FontWeight.w400,
        onHover: ElStyle(fontWeight: FontWeight.w700),
      ),
      child: 'one two',
    );
    Widget tree(TextLeadingDistribution? distribution) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: ElView(
          key: parentKey,
          style: ElStyle(textOptions: distribution == null ? null : ElTextOptions(leadingDistribution: distribution)),
          child: ElView(key: bridgeKey, child: leaf),
        ),
      ),
    );
    await tester.pumpWidget(tree(TextLeadingDistribution.proportional));
    final render = tester.renderObject<ElRenderView>(find.byKey(leafKey));
    final engine = render.content as TextEngine;
    expect(engine.painterForTest.text!.style!.leadingDistribution, TextLeadingDistribution.even);
    render.setHover(true);
    await tester.pump();
    expect(engine.painterForTest.text!.style!.fontWeight, FontWeight.w700);
    for (final distribution in <TextLeadingDistribution?>[TextLeadingDistribution.even, null]) {
      await tester.pumpWidget(tree(distribution));
      expect(render.content, same(engine));
      expect(engine.painterForTest.text!.style!.leadingDistribution, TextLeadingDistribution.even);
      expect(engine.painterForTest.text!.style!.fontWeight, FontWeight.w700);
      expect(tester.renderObject<ElRenderView>(find.byKey(parentKey)).content, isNull);
      expect(tester.renderObject<ElRenderView>(find.byKey(bridgeKey)).content, isNull);
    }
  });

  testWidgets('移除局部选项恢复当前环境与默认值，不读取祖先高级选项', (tester) async {
    final key = GlobalKey();
    Widget tree(ElTextOptions? local) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Align(
          alignment: Alignment.topLeft,
          child: ElView(
            style: ElStyle(
              fontWeight: FontWeight.w500,
              textOptions: ElTextOptions(
                leadingDistribution: TextLeadingDistribution.proportional,
                textScaler: TextScaler.linear(3),
                textBaseline: TextBaseline.ideographic,
              ),
            ),
            child: ElView(
              key: key,
              style: ElStyle(textOptions: local),
              child: 'local options',
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      tree(ElTextOptions(leadingDistribution: TextLeadingDistribution.proportional, textScaler: TextScaler.noScaling)),
    );
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = render.content as TextEngine;
    expect(engine.painterForTest.text!.style!.leadingDistribution, TextLeadingDistribution.proportional);
    expect(engine.painterForTest.textScaler.scale(10), 10);
    await tester.pumpWidget(tree(null));
    expect(render.content, same(engine));
    expect(engine.painterForTest.text!.style!.leadingDistribution, TextLeadingDistribution.even);
    expect(engine.painterForTest.text!.style!.textBaseline, isNull);
    expect(engine.painterForTest.text!.style!.fontWeight, FontWeight.w500);
    expect(engine.painterForTest.textScaler.scale(10), 15);
  });
}
