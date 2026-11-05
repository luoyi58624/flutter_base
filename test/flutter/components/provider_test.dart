import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _outerButton(BuildContext context, ElButton component, Obs<bool> model) => ElView(child: 'outer:${component.child}');
Widget _innerButton(BuildContext context, ElButton component, Obs<bool> model) => ElView(child: 'inner:${component.child}');
Widget _tag(BuildContext context, ElTag component) => ElView(child: 'tag:${component.child}');

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElComponentProvider(
    builders: ElComponents(button: _outerButton, tag: _tag),
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
              builders: ElComponents(button: _innerButton),
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

  testWidgets('弹层捕获保留合并后的配置', (tester) async {
    late CapturedThemes captured;
    await tester.pumpWidget(
      _host(
        ElComponentProvider(
          builders: ElComponents(button: _innerButton),
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
