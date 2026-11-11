import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool bold = false, Size size = Size.zero}) => Directionality(
  textDirection: .ltr,
  child: MediaQuery(
    data: MediaQueryData(boldText: bold, size: size),
    child: child,
  ),
);

TextSpan _plain(WidgetTester tester, Key key) =>
    (((tester.renderObject<ElRenderView>(find.byKey(key)).content as TextEngine?)?.painterForTest.text) as TextSpan);

List<TextSpan> _runs(InlineSpan span) {
  final result = <TextSpan>[];
  span.visitChildren((span) {
    if (span is TextSpan && span.text?.isNotEmpty == true) result.add(span);
    return true;
  });
  return result;
}

void main() {
  testWidgets('文本环境监听粗体，父级不重建，切换只覆盖 fontWeight 并保留局部字体轴', (tester) async {
    final key = UniqueKey();
    var leafBuilds = 0;
    final tree = ElView(
      style: ElStyle(alignment: .topLeft),
      child: Builder(
        builder: (context) {
          leafBuilds++;
          return ElView(
            key: key,
            style: ElStyle(
              fontWeight: .w300,
              fontVariationSettings: [FontVariation('wght', 320), FontVariation('wdth', 90)],
            ),
            child: '系统粗体',
          );
        },
      ),
    );
    await tester.pumpWidget(_host(tree));
    final initialLeaf = leafBuilds;
    expect(_plain(tester, key).style!.fontWeight, FontWeight.w300);
    await tester.pumpWidget(_host(tree, bold: true));
    expect(leafBuilds, initialLeaf);
    expect(_plain(tester, key).style!.fontWeight, FontWeight.bold);
    expect(_plain(tester, key).style!.fontVariations, [FontVariation('wght', 320), FontVariation('wdth', 90)]);
    await tester.pumpWidget(_host(tree, bold: true, size: Size(900, 600)));
    expect(leafBuilds, initialLeaf);
    await tester.pumpWidget(_host(tree));
    expect(_plain(tester, key).style!.fontWeight, FontWeight.w300);
    expect(_plain(tester, key).style!.fontVariations!.first.value, 320);
    expect(leafBuilds, initialLeaf);
  });

  testWidgets('显式 wght 与系统粗体组合时，输出样式与 Flutter Text 一致', (tester) async {
    final viewKey = UniqueKey();
    final textKey = UniqueKey();
    final axes = [FontVariation('wght', 590), FontVariation('wdth', 90)];
    final tree = Column(
      children: [
        ElView(
          key: viewKey,
          style: ElStyle(fontWeight: .w300, fontVariationSettings: axes),
          child: '显式字重',
        ),
        Text(
          '显式字重',
          key: textKey,
          style: TextStyle(fontWeight: .w300, fontVariations: axes),
        ),
      ],
    );
    for (final bold in [false, true, false]) {
      await tester.pumpWidget(_host(tree, bold: bold));
      final actual = _plain(tester, viewKey).style!;
      final expected = tester.renderObject<RenderParagraph>(find.byKey(textKey)).text.style!;
      expect(actual.fontWeight, expected.fontWeight);
      expect(actual.fontVariations, expected.fontVariations);
      expect(actual.fontVariations, axes);
    }
  });

  testWidgets('系统粗体作用于富文本根样式，局部 TextSpan、图标与原生文本保留自己的规则', (tester) async {
    final richKey = UniqueKey();
    final iconKey = UniqueKey();
    final nativeKey = UniqueKey();
    final recognizer = TapGestureRecognizer()..onTap = () {};
    addTearDown(recognizer.dispose);
    final tree = ElView(
      style: ElStyle(fontWeight: .w300, alignment: .topLeft),
      child: Column(
        children: [
          ElView(
            key: richKey,
            child: [
              '普通',
              TextSpan(
                text: '内联',
                style: TextStyle(fontWeight: .w100),
              ),
              TextSpan(
                text: '交互',
                style: TextStyle(fontWeight: .w200),
                recognizer: recognizer,
              ),
            ],
          ),
          ElView(key: iconKey, child: IconsForTest.icon),
          MediaQuery(
            data: MediaQueryData(boldText: false),
            child: Text(
              '原生',
              key: nativeKey,
              style: TextStyle(fontWeight: .w200),
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(_host(tree, bold: true));
    final render = tester.renderObject<ElRenderView>(find.byKey(richKey));
    final runs = _runs(((render.content as TextEngine?)?.painterForTest.text)!);
    expect(runs.singleWhere((span) => span.text == '普通').style!.fontWeight, FontWeight.bold);
    expect(runs.singleWhere((span) => span.text == '内联').style!.fontWeight, FontWeight.w100);
    expect(runs.singleWhere((span) => span.text == '交互').style!.fontWeight, FontWeight.w200);
    expect(runs.singleWhere((span) => span.text == '交互').recognizer, same(recognizer));
    expect(_plain(tester, iconKey).style!.fontWeight, FontWeight.w300);
    final paragraph = tester.renderObject<RenderParagraph>(find.byKey(nativeKey));
    expect((paragraph.text as TextSpan).style!.fontWeight, FontWeight.w200);
    await tester.pumpWidget(_host(tree));
    final restored = _runs(((render.content as TextEngine?)?.painterForTest.text)!);
    expect(restored.singleWhere((span) => span.text == '内联').style!.fontWeight, FontWeight.w100);
    expect(restored.singleWhere((span) => span.text == '交互').style!.fontWeight, FontWeight.w200);
  });

  testWidgets('独立图标不因粗体开关重新排版', (tester) async {
    final key = UniqueKey();
    final tree = ElView(
      child: ElView(key: key, child: IconsForTest.icon),
    );
    await tester.pumpWidget(_host(tree));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final layouts = (((render.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0);
    await tester.pumpWidget(_host(tree, bold: true));
    expect((((render.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0), layouts);
  });

  testWidgets('GlobalKey 从继承节点变为根后开始监听系统粗体', (tester) async {
    final key = GlobalKey();
    final leaf = ElView(key: key, child: '根切换');
    await tester.pumpWidget(_host(ElView(child: leaf), bold: true));
    expect(_plain(tester, key).style!.fontWeight, FontWeight.bold);
    await tester.pumpWidget(_host(leaf));
    expect(_plain(tester, key).style!.fontWeight, isNot(FontWeight.bold));
    await tester.pumpWidget(_host(leaf, bold: true));
    expect(_plain(tester, key).style!.fontWeight, FontWeight.bold);
    await tester.pumpWidget(_host(ElView(child: leaf)));
    expect(_plain(tester, key).style!.fontWeight, isNot(FontWeight.bold));
  });

  testWidgets('GlobalKey 在不同继承根之间移动后重新继承粗体', (tester) async {
    final key = GlobalKey();
    final leaf = ElView(key: key, child: '移动');
    Widget tree(bool left) => Row(
      textDirection: .ltr,
      children: [
        _host(ElView(child: left ? leaf : null), bold: true),
        _host(ElView(child: left ? null : leaf)),
      ],
    );
    await tester.pumpWidget(tree(true));
    expect(_plain(tester, key).style!.fontWeight, FontWeight.bold);
    await tester.pumpWidget(tree(false));
    expect(_plain(tester, key).style!.fontWeight, isNot(FontWeight.bold));
  });
}

abstract final class IconsForTest {
  static const icon = IconData(0xe000, fontFamily: 'test-icons');
}
