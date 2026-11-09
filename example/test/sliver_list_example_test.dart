import 'package:example/src/pages/examples/sliver_list.dart';
import 'package:example/src/pages/home.dart';
import 'package:example/src/utils/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(Widget page) => ElComponentProvider(
  components: el.mobileComponents,
  child: MaterialApp(navigatorKey: RouterUtil.rootNavigatorKey, home: page),
);

void main() {
  testWidgets('首页入口打开全量常驻文档，末段已挂载并可返回', (tester) async {
    _viewport(tester);
    await tester.pumpWidget(_app(HomePage()));
    await tester.pumpAndSettle();

    final tile = find.byKey(ValueKey('home-sliver-list'));
    expect(tester.widget(tile), isA<ListTile>());
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('文档滚动（全量常驻）'), findsOneWidget);
    expect(find.byType(ElSliverList), findsOneWidget);
    final scroll = find.byKey(ValueKey('document-scroll'));
    expect(find.ancestor(of: scroll, matching: find.byType(SelectionArea)), findsOneWidget);
    expect(find.byKey(ValueKey('document-paragraph-79'), skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('阅读宽度和段落长度改变真实布局，末段保持挂载', (tester) async {
    _viewport(tester);
    await tester.pumpWidget(_app(ElSliverListExamplePage()));
    await tester.pumpAndSettle();

    final scroll = find.byKey(ValueKey('document-scroll'));
    final first = find.byKey(ValueKey('document-paragraph-0'), skipOffstage: false);
    final last = find.byKey(ValueKey('document-paragraph-79'), skipOffstage: false);
    final lastElement = tester.element(last);
    final fullWidth = tester.getSize(scroll).width;

    await tester.tap(find.byKey(ValueKey('document-width-toggle')));
    await tester.pumpAndSettle();
    expect(tester.getSize(scroll).width, lessThan(fullWidth));
    expect(find.byTooltip('恢复完整宽度'), findsOneWidget);

    final shortHeight = tester.getSize(first).height;
    await tester.tap(find.byKey(ValueKey('document-expand-toggle')));
    await tester.pumpAndSettle();
    expect(tester.getSize(first).height, greaterThan(shortHeight));
    expect(find.textContaining('补充记录：'), findsOneWidget);
    expect(tester.element(last), same(lastElement));

    await tester.tap(find.byKey(ValueKey('document-expand-toggle')));
    await tester.pumpAndSettle();
    expect(tester.getSize(first).height, closeTo(shortHeight, .01));
    expect(find.textContaining('补充记录：'), findsNothing);

    await tester.tap(find.byKey(ValueKey('document-width-toggle')));
    await tester.pumpAndSettle();
    expect(tester.getSize(scroll).width, closeTo(fullWidth, .01));
    expect(tester.element(last), same(lastElement));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
