import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double extent = 20}) => Directionality(
  textDirection: .ltr,
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(2)),
    child: ElView(
      style: ElStyle(iconSize: extent, alignment: .topLeft),
      child: child,
    ),
  ),
);

void main() {
  testWidgets('混排的独立图标使用正方形布局，不受文本字号和缩放影响', (tester) async {
    final key = GlobalKey();
    final icon = IconData(0x41, fontFamily: 'Ahem');
    final content = ElView(child: icon);
    for (final extent in [20.0, 30.0]) {
      await tester.pumpWidget(
        _host(
          ElView(
            key: key,
            style: ElStyle(fontSize: 80, lineHeight: 3, letterSpacing: 14),
            child: [WidgetSpan(child: content)],
          ),
          extent: extent,
        ),
      );
      await tester.pumpAndSettle();
      final glyph = find.byWidget(content);
      expect(glyph, findsOneWidget);
      final render = tester.renderObject<ElRenderView>(glyph);
      expect(render.size, Size.square(extent));
      expect(render.getDryLayout(BoxConstraints()), Size.square(extent));
      expect(render.getMinIntrinsicHeight(100), extent);
      final style = (((render.content as TextEngine?)?.painterForTest.text) as TextSpan).style!;
      expect(style.letterSpacing, isNull);
      expect(style.height, 1);
    }
  });

  testWidgets('图标继承状态尺寸与颜色，紧约束测量一致', (tester) async {
    final iconKey = GlobalKey();
    for (final selected in [false, true]) {
      await tester.pumpWidget(
        _host(
          ElView(
            style: ElStyle(iconSize: selected ? 32 : 20, iconColor: selected ? Color(0xff12ac75) : null),
            child: ElView(
              key: iconKey,
              child: IconData(0x41, fontFamily: 'Ahem'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final render = tester.renderObject<ElRenderView>(find.byKey(iconKey));
      expect(render.size, Size.square(selected ? 32 : 20));
      if (selected) {
        expect((((render.content as TextEngine?)?.painterForTest.text) as TextSpan).style!.color, Color(0xff12ac75));
      }
    }
    await tester.pumpWidget(
      _host(
        ElView(
          style: ElStyle(width: 12, height: 10),
          child: ElView(
            key: iconKey,
            child: IconData(0x41, fontFamily: 'Ahem'),
          ),
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(find.byKey(iconKey));
    expect(render.size, Size(12, 10));
    expect(render.getDryLayout(BoxConstraints.tight(Size(12, 10))), Size(12, 10));
  });
}
