import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart' as desktop;
import 'package:flutter_base/mobile.dart' as mobile;
import 'package:flutter_base/ui.dart' show ElTokens, ElThemeContextExt;
import 'package:flutter_test/flutter_test.dart';

Finder _action(String label) =>
    find.byWidgetPredicate((widget) => widget is mobile.ElView && widget.semantics?.properties.label == label);

void main() {
  for (final (name, host) in <(String, Widget Function(desktop.ElStyle, Widget))>[
    (
      'desktop',
      (style, child) => desktop.ElComponentProvider(
        components: desktop.ElDesktopExt(desktop.el).desktopComponents,
        child: desktop.ElView(style: style, child: child),
      ),
    ),
    (
      'mobile',
      (style, child) => mobile.ElComponentProvider(
        components: mobile.ElMobileExt(mobile.el).mobileComponents,
        child: mobile.ElView(style: style, child: child),
      ),
    ),
  ]) {
    testWidgets('$name 主题根只应用一次用户实际样式', (tester) async {
      final childKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: host(desktop.ElStyle(padding: EdgeInsets.all(8)), SizedBox(key: childKey, width: 20, height: 10)),
          ),
        ),
      );
      final root = find.byType(mobile.ElComponentProvider);
      expect(tester.getSize(root), Size(36, 26));
      expect(tester.getTopLeft(find.byKey(childKey)) - tester.getTopLeft(root), Offset(8, 8));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('两端读取同一组主题键和同一个 context.elTheme 扩展', (tester) async {
    final primary = Color(0xff123456);
    final shadow = [BoxShadow(color: Color(0x22000000), blurRadius: 3)];
    final seen = <(Color, List<BoxShadow>)>[];
    Widget reader() => desktop.ElView(
      style: desktop.ElStyle(vars: {ElTokens.$primary: primary, ElTokens.$shadowSm: shadow}),
      child: Builder(
        builder: (context) {
          seen.add((context.elTheme.primary, context.elTheme.shadowSm));
          return SizedBox();
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            desktop.ElComponentProvider(
              components: desktop.ElDesktopExt(desktop.el).desktopComponents,
              child: reader(),
            ),
            mobile.ElComponentProvider(components: mobile.ElMobileExt(mobile.el).mobileComponents, child: reader()),
          ],
        ),
      ),
    );
    expect(seen, [(primary, shadow), (primary, shadow)]);
    expect(tester.takeException(), isNull);
  });

  test('两端入口导出同一套通用组件声明', () {
    expect(mobile.ElButton(), isA<desktop.ElButton>());
    expect(desktop.ElSwitch(value: false), isA<mobile.ElSwitch>());
    expect(mobile.ElTag(child: '标签'), isA<desktop.ElTag>());
  });

  testWidgets('嵌套品牌各自安装配置，通用按钮各切换一次', (tester) async {
    final mobileModel = ValueNotifier(false);
    final desktopModel = ValueNotifier(false);
    addTearDown(mobileModel.dispose);
    addTearDown(desktopModel.dispose);
    final mobileChanges = <bool>[];
    final desktopChanges = <bool>[];
    late mobile.ElComponents outer;
    late desktop.ElComponents inner;
    late mobile.ElComponents after;
    late Color outerPrimary, innerPrimary;

    await tester.pumpWidget(
      MaterialApp(
        home: mobile.ElComponentProvider(
          components: mobile.ElMobileExt(mobile.el).mobileComponents,
          child: Column(
            mainAxisSize: .min,
            children: [
              Builder(
                builder: (context) {
                  outer = mobile.ElComponentProvider.of(context);
                  outerPrimary = context.elTheme.primary;
                  return mobile.ElButton.toggle(
                    key: ValueKey('mobile'),
                    modelValue: mobileModel,
                    onChanged: mobileChanges.add,
                    semanticLabel: '移动端按钮',
                    child: '移动端',
                  );
                },
              ),
              desktop.ElComponentProvider(
                components: desktop.ElDesktopExt(desktop.el).desktopComponents,
                child: Builder(
                  builder: (context) {
                    inner = desktop.ElComponentProvider.of(context);
                    innerPrimary = context.elTheme.primary;
                    return desktop.ElButton.toggle(
                      key: ValueKey('desktop'),
                      modelValue: desktopModel,
                      onChanged: desktopChanges.add,
                      semanticLabel: '桌面端按钮',
                      child: '桌面端',
                    );
                  },
                ),
              ),
              Builder(
                builder: (context) {
                  after = mobile.ElComponentProvider.of(context);
                  return SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(outer, same(after));
    expect(inner.button, isNot(same(outer.button)));
    expect(outer.button, isNotNull);
    expect(inner.button, isNotNull);
    expect(outer.radio, isNull);
    expect(inner.radio, isNull);
    expect(outer.checkbox, isNull);
    expect(inner.checkbox, isNull);
    expect(outer.listTile, isNotNull);
    expect(inner.listTile, isNull);
    expect(outerPrimary, outer.token!.vars![ElTokens.$primary]);
    expect(innerPrimary, inner.token!.vars![ElTokens.$primary]);

    await tester.tap(_action('移动端按钮'));
    await tester.pump();
    expect(mobileModel.value, isTrue);
    expect(desktopModel.value, isFalse);
    expect(mobileChanges, [true]);

    await tester.tap(_action('桌面端按钮'));
    await tester.pump();
    expect(desktopModel.value, isTrue);
    expect(desktopChanges, [true]);
    expect(mobileChanges, [true]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
