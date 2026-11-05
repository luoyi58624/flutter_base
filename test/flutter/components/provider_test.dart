import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _outerButton(BuildContext context, ElButton component, Obs<bool> model) =>
    ElView(child: 'outer:${component.child}');
Widget _innerButton(BuildContext context, ElButton component, Obs<bool> model) =>
    ElView(child: 'inner:${component.child}');
Widget _tag(BuildContext context, ElTag component) => ElView(child: 'tag:${component.child}');

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElComponentProvider(
    components: ElComponents(button: _outerButton, tag: _tag),
    child: child,
  ),
);

Iterable<Object?> _texts(WidgetTester tester) =>
    tester.widgetList<ElView>(find.byType(ElView)).map((view) => view.child).whereType<String>();

void main() {
  testWidgets('局部覆写只替换传入的实现，其余沿用外层', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            ElButton(child: 'a'),
            ElComponentProvider(
              components: ElComponents(button: _innerButton),
              child: Column(
                children: [
                  ElButton(child: 'b'),
                  ElTag(child: 'c'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    expect(_texts(tester), containsAll(['outer:a', 'inner:b', 'tag:c']));
  });

  testWidgets('缺少实现时报出组件名', (tester) async {
    await tester.pumpWidget(_host(ElSwitch(value: false)));
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('ElSwitch'));
  });

  testWidgets('组件提供器自身承载视图，不再额外包一层 ElView', (tester) async {
    await tester.pumpWidget(_host(SizedBox()));
    expect(find.byType(ElView), findsNothing);
    expect(tester.renderObject(find.byType(ElComponentProvider)), isA<ElRenderView>());
  });

  testWidgets('预设样式与主题模式一起应用到子树', (tester) async {
    final key = GlobalKey();
    Color? primary;
    await tester.pumpWidget(
      _host(
        Center(
          child: ElComponentProvider(
            components: ElComponents(
              style: ElStyle(
                padding: EdgeInsets.all(8),
                onDark: ElStyle(vars: {ElTokens.$primary: Color(0xff224466)}),
              ),
            ),
            themeMode: ElThemeMode(brightness: .dark),
            child: Builder(
              builder: (context) {
                primary = context.elTheme.primary;
                return SizedBox(key: key, width: 20, height: 10);
              },
            ),
          ),
        ),
      ),
    );
    final view = find.byType(ElComponentProvider).last;
    expect(tester.getSize(view), Size(36, 26));
    expect(tester.getTopLeft(find.byKey(key)) - tester.getTopLeft(view), Offset(8, 8));
    expect(primary, Color(0xff224466));
  });

  testWidgets('仅设置主题模式时沿用外层组件实现', (tester) async {
    Brightness? brightness;
    await tester.pumpWidget(
      _host(
        ElComponentProvider(
          themeMode: ElThemeMode(brightness: .dark),
          child: Builder(
            builder: (context) {
              brightness = context.elTheme.brightness;
              return ElButton(child: 'button');
            },
          ),
        ),
      ),
    );
    expect(brightness, Brightness.dark);
    expect(_texts(tester), contains('outer:button'));
  });

  testWidgets('调用方样式覆盖预设并保留未覆写的变量', (tester) async {
    final preset = Color(0xff224466);
    final override = Color(0xff6688aa);
    Color? primary;
    Color? background;
    await tester.pumpWidget(
      _host(
        Center(
          child: ElComponentProvider(
            components: ElComponents(
              style: ElStyle(padding: .all(8), vars: {ElTokens.$primary: preset, ElTokens.$bgColor: preset}),
            ),
            style: ElStyle(padding: .all(4), vars: {ElTokens.$primary: override}),
            child: Builder(
              builder: (context) {
                primary = context.elTheme.primary;
                background = context.elTheme.bgColor;
                return SizedBox(width: 20, height: 10);
              },
            ),
          ),
        ),
      ),
    );
    expect(primary, override);
    expect(background, preset);
    expect(tester.getSize(find.byType(ElComponentProvider).last), Size(28, 18));
  });

  testWidgets('直接切换提供器主题，稳定子树更新暗色变量并采用统一过渡', (tester) async {
    final childKey = GlobalKey();
    final boxKey = GlobalKey();
    Brightness? brightness;
    Color? tokenBackground;
    final child = Builder(
      key: childKey,
      builder: (context) {
        brightness = context.elTheme.brightness;
        tokenBackground = context.elTheme.bgColor;
        return ElView(
          key: boxKey,
          style: ElStyle(
            width: 20,
            height: 20,
            backgroundColor: Color(0xffffffff),
            onDark: ElStyle(backgroundColor: Color(0xff000000)),
            transition: [.all(Duration(milliseconds: 500))],
          ),
        );
      },
    );
    final components = ElComponents(
      style: ElStyle(
        vars: {ElTokens.$bgColor: Color(0xffffffff)},
        onDark: ElStyle(vars: {ElTokens.$bgColor: Color(0xff000000)}),
      ),
    );
    Widget host(bool dark) => _host(
      ElComponentProvider(
        components: components,
        themeMode: ElThemeMode(
          brightness: dark ? .dark : .light,
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
        child: child,
      ),
    );
    Color background() =>
        (boxKey.currentContext!.findRenderObject()! as ElRenderView).committedResolvedStyle.box.backgroundColor
            as Color;

    await tester.pumpWidget(host(false));
    final element = childKey.currentContext;
    expect(brightness, Brightness.light);
    expect(background(), Color(0xffffffff));
    for (final dark in [true, false]) {
      await tester.pumpWidget(host(dark));
      expect(childKey.currentContext, same(element));
      expect(brightness, dark ? Brightness.dark : Brightness.light);
      expect(tokenBackground, dark ? Color(0xff000000) : Color(0xffffffff));
      await tester.pump(Duration(milliseconds: 100));
      expect(background().r, closeTo(0.5, 1 / 255));
      await tester.pump(Duration(milliseconds: 100));
      expect(background(), dark ? Color(0xff000000) : Color(0xffffffff));
      expect(tokenBackground, background());
    }
  });

  testWidgets('仅注入变量时继承外层组件，撤销组件配置保留子树', (tester) async {
    final key = GlobalKey();
    final local = Color(0xff224466);
    Color? primary;
    final child = Builder(
      key: key,
      builder: (context) {
        primary = context.elTheme.primary;
        return ElButton(child: 'button');
      },
    );
    Widget host(ElComponents? components) => _host(
      ElComponentProvider(
        components: components,
        child: ElView(
          style: ElStyle(vars: {ElTokens.$primary: local}),
          child: child,
        ),
      ),
    );

    await tester.pumpWidget(host(ElComponents(button: _innerButton)));
    final element = key.currentContext;
    expect(primary, local);
    expect(_texts(tester), contains('inner:button'));

    await tester.pumpWidget(host(null));
    expect(key.currentContext, same(element));
    expect(primary, local);
    expect(_texts(tester), contains('outer:button'));
  });

  testWidgets('弹层捕获保留合并后的配置', (tester) async {
    late CapturedThemes captured;
    await tester.pumpWidget(
      _host(
        ElComponentProvider(
          components: ElComponents(button: _innerButton),
          child: Builder(
            builder: (context) {
              captured = InheritedTheme.capture(from: context, to: null);
              return SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: captured.wrap(
          Column(
            children: [
              ElButton(child: 'x'),
              ElTag(child: 'y'),
            ],
          ),
        ),
      ),
    );
    expect(_texts(tester), containsAll(['inner:x', 'tag:y']));
  });
}
