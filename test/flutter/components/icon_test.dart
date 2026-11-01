import 'package:flutter/widgets.dart';
import 'package:flutter_base/desktop.dart' show ElDesktopTheme;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = IconData(0x41, fontFamily: 'Ahem', matchTextDirection: true);
  for (final desktop in [false, true]) {
    Widget host(Widget child, {ElStyle? style, Brightness brightness = Brightness.light}) => Directionality(
      textDirection: .ltr,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(3)),
        child: desktop
            ? ElDesktopTheme(
                themeMode: ElThemeMode(brightness: brightness),
                style: style,
                child: Center(child: child),
              )
            : ElMobileTheme(
                brightness: brightness,
                style: style,
                child: Center(child: child),
              ),
      ),
    );
    ElRenderView glyph(WidgetTester tester) => tester.renderObject<ElRenderView>(
      find.byWidgetPredicate((widget) => widget is ElView && widget.child is IconData).last,
    );

    testWidgets('公共 ElIcon 继承样式，显式样式优先且不读取 IconTheme：desktop=$desktop', (tester) async {
      await tester.pumpWidget(
        host(
          IconTheme(
            data: IconThemeData(size: 80, color: Color(0xff00ff00)),
            child: ElIcon(data),
          ),
          style: ElStyle(iconSize: 32, iconColor: Color(0xff123456), fontSize: 60),
        ),
      );
      await tester.pumpAndSettle();
      expect(glyph(tester).size, Size.square(32));
      expect(glyph(tester).committedResolvedStyle.inheritedBox.iconColor, Color(0xff123456));
      await tester.pumpWidget(
        host(
          ElIcon(
            data,
            size: 40,
            color: Color(0xff000000),
            style: ElStyle(iconSize: 20, iconColor: Color(0xffabcdef)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(glyph(tester).size, Size.square(20));
      expect(glyph(tester).committedResolvedStyle.inheritedBox.iconColor, Color(0xffabcdef));
      expect(tester.takeException(), isNull);
    });

    testWidgets('空图标保留占位和辅助名称：desktop=$desktop', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(ElIcon(null, size: 26, semanticLabel: '占位图标')));
      expect(glyph(tester).size, Size.square(26));
      expect(find.bySemanticsLabel('占位图标'), findsOneWidget);
      await tester.pumpWidget(SizedBox());
      semantics.dispose();
    });

    testWidgets('公共图标的颜色和尺寸沿主题过渡继承：desktop=$desktop', (tester) async {
      final icon = ElIcon(data);
      final style = ElStyle(
        iconSize: 20,
        iconColor: Color(0xff000000),
        onDark: ElStyle(iconSize: 40, iconColor: Color(0xffffffff)),
      );
      await tester.pumpWidget(host(icon, style: style));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(icon, style: style, brightness: Brightness.dark));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 100));
      expect(glyph(tester).size, Size.square(30));
      expect(
        glyph(tester).committedResolvedStyle.inheritedBox.iconColor,
        Color.lerp(Color(0xff000000), Color(0xffffffff), .5),
      );
      await tester.pump(Duration(milliseconds: 100));
      expect(glyph(tester).size, Size.square(40));
      expect(glyph(tester).committedResolvedStyle.inheritedBox.iconColor, Color(0xffffffff));
    });
  }
}
