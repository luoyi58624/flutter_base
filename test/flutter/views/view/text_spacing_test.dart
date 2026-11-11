import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, MediaQueryData data) => Directionality(
  textDirection: .ltr,
  child: MediaQuery(data: data, child: child),
);

TextPainter _painter(WidgetTester tester, Key key) =>
    tester.renderObject<ElRenderView>(find.byKey(key)).textEngineForTest!.painterForTest;

(double?, double?, double?) _spacing(TextSpan span) =>
    (span.style?.height, span.style?.letterSpacing, span.style?.wordSpacing);

void main() {
  testWidgets('无障碍间距覆盖纯文本和富文本子段，取消后恢复各自样式', (tester) async {
    final plainKey = UniqueKey();
    final richKey = UniqueKey();
    final tree = ElView(
      style: ElStyle(alignment: .topLeft),
      child: Column(
        children: [
          ElView(key: plainKey, style: ElStyle(lineHeight: 1.1, letterSpacing: 1, wordSpacing: 2), child: 'plain text'),
          ElView(
            key: richKey,
            child: TextSpan(
              text: 'root ',
              style: TextStyle(height: 1.2, letterSpacing: 2, wordSpacing: 3),
              children: [
                TextSpan(
                  text: 'child text',
                  style: TextStyle(inherit: false, height: 1.3, letterSpacing: 3, wordSpacing: 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final normal = MediaQueryData();
    final override = MediaQueryData(lineHeightScaleFactorOverride: 2, letterSpacingOverride: 5, wordSpacingOverride: 6);
    for (final data in [normal, override, normal]) {
      await tester.pumpWidget(_host(tree, data));
      final plain = _painter(tester, plainKey).text! as TextSpan;
      final rich = _painter(tester, richKey).text! as TextSpan;
      final child = rich.children!.single as TextSpan;
      final overridden = data == override;
      expect(_spacing(plain), overridden ? (2.0, 5.0, 6.0) : (1.1, 1.0, 2.0));
      expect(_spacing(rich), overridden ? (2.0, 5.0, 6.0) : (1.2, 2.0, 3.0));
      expect(_spacing(child), overridden ? (2.0, 5.0, 6.0) : (1.3, 3.0, 4.0));
    }
  });

  testWidgets('ElText 由引擎应用和撤销系统粗体与间距，组件无需重建', (tester) async {
    final key = UniqueKey();
    var builds = 0;
    final tree = ElView(
      child: _CountingElText(
        'system bold',
        key: key,
        style: TextStyle(inherit: false, fontWeight: .w300, letterSpacing: 1),
        onBuild: () => builds++,
      ),
    );

    (FontWeight?, double?) style() {
      final style = (_painter(tester, key).text! as TextSpan).style!;
      return (style.fontWeight, style.letterSpacing);
    }

    await tester.pumpWidget(_host(tree, MediaQueryData()));
    final initialBuilds = builds;
    expect(style(), (FontWeight.w300, 1.0));
    await tester.pumpWidget(_host(tree, MediaQueryData(boldText: true, letterSpacingOverride: 5)));
    expect(style(), (FontWeight.bold, 5.0));
    await tester.pumpWidget(_host(tree, MediaQueryData()));
    expect(style(), (FontWeight.w300, 1.0));
    expect(builds, initialBuilds);
  });

  testWidgets('局部 MediaQuery 可覆盖和清除外层的文字无障碍设置', (tester) async {
    final outerKey = UniqueKey();
    final innerKey = UniqueKey();
    final style = ElStyle(fontWeight: .w300, letterSpacing: 1);
    final outerText = ElView(key: outerKey, style: style, child: 'outer');
    final innerView = ElView(
      child: ElView(key: innerKey, style: style, child: 'inner'),
    );
    final outerData = MediaQueryData(boldText: true, letterSpacingOverride: 5);
    final normal = MediaQueryData();
    final override = MediaQueryData(boldText: true, letterSpacingOverride: 7);

    (FontWeight?, double?) textStyle(Key key) {
      final style = (_painter(tester, key).text! as TextSpan).style!;
      return (style.fontWeight, style.letterSpacing);
    }

    for (final innerData in [normal, override, normal]) {
      await tester.pumpWidget(
        _host(
          ElView(
            child: Column(
              children: [
                outerText,
                MediaQuery(data: innerData, child: innerView),
              ],
            ),
          ),
          outerData,
        ),
      );
      expect(textStyle(outerKey), (FontWeight.bold, 5.0));
      expect(textStyle(innerKey), innerData == override ? (FontWeight.bold, 7.0) : (FontWeight.w300, 1.0));
    }
  });

  testWidgets('ElView 和 ElText 的 strutStyle 参与布局，跟随系统行高覆盖并可移除', (tester) async {
    final viewKey = UniqueKey();
    final textKey = UniqueKey();
    final nativeKey = UniqueKey();
    final strut = StrutStyle(fontFamily: 'Ahem', fontSize: 20, height: 1.0, forceStrutHeight: true);

    Widget tree(StrutStyle? strutStyle) => Column(
      children: [
        ElView(
          key: viewKey,
          style: ElStyle(fontFamily: 'Ahem', fontSize: 10),
          strutStyle: strutStyle,
          child: 'first\nsecond',
        ),
        ElText(
          'first\nsecond',
          key: textKey,
          style: TextStyle(fontFamily: 'Ahem', fontSize: 10),
          strutStyle: strutStyle,
        ),
        Text(
          'first\nsecond',
          key: nativeKey,
          style: TextStyle(fontFamily: 'Ahem', fontSize: 10),
          strutStyle: strutStyle,
        ),
      ],
    );

    final normal = MediaQueryData();
    final override = MediaQueryData(lineHeightScaleFactorOverride: 2);
    await tester.pumpWidget(_host(tree(strut), normal));
    expect(_painter(tester, viewKey).strutStyle, strut);
    final normalHeight = tester.getSize(find.byKey(viewKey)).height;

    await tester.pumpWidget(_host(tree(strut), override));
    final native = tester.renderObject<RenderParagraph>(find.byKey(nativeKey));
    expect(native.strutStyle?.height, 2);
    final overriddenHeight = native.size.height;
    expect(overriddenHeight, greaterThan(normalHeight));
    for (final key in [viewKey, textKey]) {
      expect(_painter(tester, key).strutStyle, native.strutStyle);
      expect(tester.getSize(find.byKey(key)).height, closeTo(overriddenHeight, 0.01));
    }
    final view = tester.renderObject<ElRenderView>(find.byKey(viewKey));
    expect(view.getDryLayout(BoxConstraints(maxWidth: 400)).height, closeTo(overriddenHeight, 0.01));
    expect(view.getMinIntrinsicHeight(400), closeTo(overriddenHeight, 0.01));

    await tester.pumpWidget(_host(tree(null), override));
    for (final key in [viewKey, textKey]) {
      expect(_painter(tester, key).strutStyle, isNull);
      expect(tester.getSize(find.byKey(key)).height, lessThan(overriddenHeight));
    }
  });

  testWidgets('ElText 的排版参数支持显式值和 Flutter 默认值', (tester) async {
    final explicitKey = UniqueKey();
    final defaultKey = UniqueKey();
    final legacyKey = UniqueKey();
    final explicitHeight = TextHeightBehavior(applyHeightToLastDescent: false);
    final defaultHeight = TextHeightBehavior(applyHeightToFirstAscent: false);
    await tester.pumpWidget(
      _host(
        DefaultTextStyle(
          style: TextStyle(fontSize: 12),
          textWidthBasis: .longestLine,
          textHeightBehavior: defaultHeight,
          child: Column(
            children: [
              ElText.rich(
                TextSpan(text: 'explicit'),
                key: explicitKey,
                textScaler: TextScaler.linear(1.5),
                textWidthBasis: .parent,
                textHeightBehavior: explicitHeight,
              ),
              ElText('defaults', key: defaultKey),
              ElText(
                'legacy',
                key: legacyKey,
                // ignore: deprecated_member_use
                textScaleFactor: 1.25,
              ),
            ],
          ),
        ),
        MediaQueryData(textScaler: TextScaler.linear(2)),
      ),
    );

    final explicit = _painter(tester, explicitKey);
    expect(explicit.textScaler.scale(12), 18);
    expect(explicit.textWidthBasis, TextWidthBasis.parent);
    expect(explicit.textHeightBehavior, explicitHeight);
    final defaults = _painter(tester, defaultKey);
    expect(defaults.textScaler.scale(12), 24);
    expect(defaults.textWidthBasis, TextWidthBasis.longestLine);
    expect(defaults.textHeightBehavior, defaultHeight);
    expect(_painter(tester, legacyKey).textScaler.scale(12), 15);
  });

  testWidgets('ElText 将显式或继承的选区颜色转交 ElView', (tester) async {
    final explicit = ElText('explicit', selectionColor: Color(0xFF008800));
    final inherited = ElText('inherited');
    final defaultColor = Color(0xFF000088);
    await tester.pumpWidget(
      _host(
        DefaultSelectionStyle(
          selectionColor: defaultColor,
          child: Column(children: [explicit, inherited]),
        ),
        MediaQueryData(),
      ),
    );

    Color? selectionColor(ElText text) => tester
        .widget<ElView>(find.descendant(of: find.byWidget(text), matching: find.byType(ElView)))
        .style
        ?.onSelection
        ?.backgroundColor;

    expect(selectionColor(explicit), explicit.selectionColor);
    expect(selectionColor(inherited), defaultColor);
  });
}

class _CountingElText extends ElText {
  const _CountingElText(super.data, {super.key, super.style, required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return super.build(context);
  }
}
