import 'package:example/src/pages/components/basic/icon/examples/example3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt, ElMobileIcons;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('图标库 $width 首次按布局初始化、完整切换并保留手动选择，重新进入时重新初始化', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final initiallyMobile = width <= ElBreakpoint.defaultSm;
      Widget host() => ElComponentProvider(
        components: initiallyMobile ? el.mobileComponents : el.desktopComponents,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(padding: .all(16), child: Example3()),
          ),
        ),
      );
      void expectCatalog(bool mobile) {
        final names = mobile ? ElMobileIcons.values.keys : ElDesktopIcons.values.keys;
        final grid = find.byKey(ValueKey('icon-catalog-grid'));
        expect(tester.widget<Wrap>(grid).children, hasLength(names.length));
        final labels = tester
            .widgetList<Text>(find.descendant(of: grid, matching: find.byType(Text)))
            .map((widget) => widget.data);
        expect(labels, unorderedEquals(names));
        expect(find.text('共 ${names.length} 个图标'), findsOneWidget);
      }

      Finder switchLabel() {
        final label = initiallyMobile ? '桌面端' : '移动端';
        // 桌面按钮的文字由 ElView 直接绘制，移动端沿用 Material Text。
        return find
            .byWidgetPredicate(
              (widget) => widget is Text && widget.data == label || widget is ElView && widget.child == label,
            )
            .last;
      }

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expectCatalog(initiallyMobile);
      await tester.tap(switchLabel());
      await tester.pumpAndSettle();
      expectCatalog(!initiallyMobile);
      await tester.tap(switchLabel());
      await tester.pumpAndSettle();
      expectCatalog(!initiallyMobile);
      for (final nextWidth in [initiallyMobile ? 1280.0 : 390.0, width]) {
        tester.view.physicalSize = Size(nextWidth, 844);
        await tester.pumpAndSettle();
        expectCatalog(!initiallyMobile);
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(SizedBox());
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expectCatalog(initiallyMobile);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    });
  }
}
