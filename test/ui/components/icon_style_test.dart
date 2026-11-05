import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/desktop.dart' show ElDesktopTheme, ElNavMenu;
import 'package:flutter_base/src/flutter/components/icon/content.dart';
import 'package:flutter_base/src/ui/mobile/cores/glyph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = IconData(0x41, fontFamily: 'Ahem', matchTextDirection: true);
  Widget host(Widget child, {bool desktop = false}) => MaterialApp(
    home: IconTheme(
      data: IconThemeData(size: 90, color: Colors.green),
      child: desktop
          ? ElDesktopTheme(
              child: Center(child: SizedBox(width: 300, child: child)),
            )
          : ElMobileTheme(
              child: Center(child: SizedBox(width: 300, child: child)),
            ),
    ),
  );
  Finder glyphs() => find.byWidgetPredicate((widget) => widget is ElView && widget.child == data);

  for (final desktop in [false, true]) {
    for (final (name, component) in <(String, Widget Function(Widget, ElStyle))>[
      ('按钮', (icon, style) => ElButton(icon: icon, style: style, onPressed: () {}, child: '按钮')),
      ('标签', (icon, style) => ElTag(style: style, child: icon)),
      if (desktop) ...[
        ('输入框', (icon, style) => ElInput(value: '', prefix: icon, style: style)),
        ('标签输入', (icon, style) => ElInputTag(prefix: icon, style: style)),
        ('选择器', (icon, style) => ElSelect<String>(value: 'value', leadingIcon: icon, style: style, children: [])),
      ],
    ]) {
      testWidgets('$name 的标准 Icon 使用样式字形通道：desktop=$desktop', (tester) async {
        await tester.pumpWidget(
          host(component(Icon(data), ElStyle(iconSize: 18, iconColor: Colors.purple)), desktop: desktop),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Icon), findsNothing);
        expect(glyphs(), findsOneWidget);
        final render = tester.renderObject<ElRenderView>(glyphs());
        expect(render.committedResolvedStyle.inheritedBox.iconSize, 18);
        expect(render.committedResolvedStyle.inheritedBox.iconColor, Colors.purple);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('桌面菜单的模型图标与后缀统一使用 ElStyle', (tester) async {
    await tester.pumpWidget(
      host(
        ElNavMenu<void>(
          value: 'none',
          style: ElStyle(iconColor: Colors.purple, iconSize: 18),
          children: [
            ElMenuModel<void>(
              key: 'parent',
              title: '菜单',
              icon: Icon(data),
              children: [ElMenuModel<void>(key: 'child', title: '子项')],
            ),
          ],
        ),
        desktop: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Icon), findsNothing);
    final render = tester.renderObject<ElRenderView>(glyphs());
    expect(render.committedResolvedStyle.inheritedBox.iconColor, Colors.purple);
    expect(render.committedResolvedStyle.inheritedBox.iconSize, 18);
  });

  testWidgets('底栏保留 NavigationDestination 调用并正确切换选中图标', (tester) async {
    final selectedData = IconData(0x42, fontFamily: 'Ahem');
    final custom = SizedBox(key: GlobalKey(), width: 8, height: 12);
    var selected = 0;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ElBottomTabbar(
              selectedIndex: selected,
              onDestinationSelected: (_) {},
              destinations: [
                NavigationDestination(icon: Icon(data), selectedIcon: Icon(selectedData), label: '首页'),
                NavigationDestination(icon: custom, label: '自定义'),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final selectedGlyph = find.byWidgetPredicate((widget) => widget is ElView && widget.child == selectedData);
    expect(selectedGlyph, findsOneWidget);
    final customElement = tester.element(find.byWidget(custom));
    update(() => selected = 1);
    await tester.pumpAndSettle();
    expect(selectedGlyph, findsNothing);
    expect(glyphs(), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(tester.element(find.byWidget(custom)), same(customElement));
  });

  testWidgets('标准 Icon 的显式参数、字体轴、缩放及辅助名称转换后保留', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: buildIconContent(
              Icon(
                data,
                key: key,
                size: 22,
                color: Colors.blue,
                weight: 600,
                fill: 1,
                applyTextScaling: true,
                textDirection: TextDirection.rtl,
                semanticLabel: '字体图标',
              ),
            ),
          ),
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    expect(render.size, Size.square(44));
    expect(render.committedResolvedStyle.inheritedBox.iconColor, Colors.blue);
    expect(render.committedResolvedStyle.inheritedBox.direction, TextDirection.rtl);
    expect(render.committedResolvedStyle.inheritedText.fontVariationSettings, [
      FontVariation('FILL', 1),
      FontVariation('wght', 600),
    ]);
    expect(find.bySemanticsLabel('字体图标'), findsOneWidget);
  });

  testWidgets('自定义 Widget 保留原实例及已挂载 Element', (tester) async {
    final custom = SizedBox(key: GlobalKey(), width: 9, height: 11);
    await tester.pumpWidget(host(ElButton(icon: custom, child: '按钮')));
    final element = tester.element(find.byWidget(custom));
    await tester.pumpWidget(
      host(
        ElButton(
          icon: custom,
          style: ElStyle(iconColor: Colors.red),
          child: '按钮',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.element(find.byWidget(custom)), same(element));
  });

  testWidgets('SVG 字形继承尺寸颜色并在 Render 层过渡，不重新构建内容', (tester) async {
    final key = GlobalKey();
    var builds = 0;
    final glyph = Builder(
      builder: (_) {
        builds++;
        return Glyph(name: 'plus');
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: ElView(
            key: key,
            style: ElStyle(
              iconSize: 20,
              iconColor: Colors.black,
              onHover: ElStyle(iconSize: 40, iconColor: Colors.white),
              transition: [ElTransition.all(Duration(milliseconds: 200), Curves.linear)],
            ),
            child: glyph,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.renderObject<ElRenderView>(find.byKey(key)).setHover(true);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    final render = tester.renderObject(find.byType(Glyph));
    expect(tester.getSize(find.byType(Glyph)), Size.square(30));
    expect(
      render,
      paints..something(
        (method, arguments) =>
            method == #drawPath && (arguments[1] as Paint).color == Color.lerp(Colors.black, Colors.white, .5),
      ),
    );
    expect(builds, 1);
    await tester.pump(Duration(milliseconds: 100));
    expect(tester.getSize(find.byType(Glyph)), Size.square(40));
  });
}
