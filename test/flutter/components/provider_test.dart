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

  testWidgets('只装配组件时不创建 ElView', (tester) async {
    await tester.pumpWidget(_host(SizedBox()));
    expect(find.byType(ElView), findsNothing);
  });

  testWidgets('预设 token 拒绝非变量样式', (tester) async {
    await tester.pumpWidget(
      ElComponentProvider(
        components: ElComponents(token: ElStyle(onDark: ElStyle(fontSize: 20))),
        child: SizedBox(),
      ),
    );
    expect(
      tester.takeException(),
      isA<AssertionError>().having(
        (error) => error.message,
        'message',
        contains('ElComponents.token only supports vars'),
      ),
    );
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
