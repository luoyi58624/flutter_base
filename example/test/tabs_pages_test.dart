// 应用内部文件沿用相对路径约定。
// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt, ElBottomTabbar;
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';
import '../lib/src/router/index.dart';
import '../lib/src/pages/examples/index.dart';
import '../lib/src/pages/examples/bibi/index.dart';
import '../lib/src/pages/examples/view/index.dart';

Future<void> _host(WidgetTester tester, {double width = 1280, String path = '/home'}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  routingConfig.isMobile = width <= 640;
  router.go(path);
  await tester.pumpWidget(App());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('homepage keeps application navigation and installs mobile components', (tester) async {
    await _host(tester, width: 390);
    expect(find.byKey(ValueKey('showcase-hero')), findsOneWidget);
    expect(find.byKey(ValueKey('showcase-chapters')), findsOneWidget);
    final home = tester.element(find.byKey(ValueKey('showcase-explore')));
    expect(ElComponentProvider.of(home).button, same(el.mobileComponents.button));
    expect(find.byType(ElBottomTabbar), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('homepage uses mobile components inside the desktop application shell', (tester) async {
    await _host(tester);
    final home = tester.element(find.byKey(ValueKey('showcase-explore')));
    expect(ElComponentProvider.of(home).input, same(el.mobileComponents.input));
    expect(find.byType(ElNavMenu<WidgetBuilder>), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  for (final width in [1280.0, 390.0]) {
    testWidgets('高级目录使用移动列表，宽度 $width 点击原生 push 且返回地址不变', (tester) async {
      await _host(tester, width: width, path: '/examples');
      expect(find.byType(ExamplesPage), findsOneWidget);
      for (final page in advancedExamples) {
        final tile = find.byKey(ValueKey('advanced-${page.key}'));
        expect(tile, findsOneWidget);
        expect(ElComponentProvider.of(tester.element(tile)).listTile, same(el.mobileComponents.listTile));
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/examples');
        expect(find.byType(ElBottomTabbar), findsNothing);
        if (page.key == 'bibi-home' || page.key == 'bibi-plain') {
          expect(find.byType(page.key == 'bibi-home' ? BibiPage : BibiPlainPage), findsOneWidget);
          expect(find.byKey(ValueKey('bibi-search-row')).hitTestable(), findsOneWidget);
          await tester.tap(find.text('我的').hitTestable());
        } else {
          expect(find.widgetWithText(AppBar, page.title), findsOneWidget);
          expect(find.byType(BackButton), findsOneWidget);
          await tester.pageBack();
        }
        await tester.pumpAndSettle();
        expect(find.byType(ExamplesPage), findsOneWidget);
        expect(tile, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(router.routeInformationProvider.value.uri.path, '/examples');
      await tester.pumpWidget(SizedBox());
    });
  }

  testWidgets('独立示例不重复显示全局菜单，返回目录后仍可由侧栏进入设置', (tester) async {
    await _host(tester, path: '/examples');
    await tester.tap(find.byKey(ValueKey('advanced-view')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('全局设置'), findsNothing);
    expect(find.byKey(ValueKey('navbar-menu')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ElViewPage), findsNothing);
    expect(find.byType(ExamplesPage), findsOneWidget);
    final label = find.descendant(
      of: find.byType(ElNavMenu<WidgetBuilder>),
      matching: find.byWidgetPredicate((widget) => widget is ElView && widget.child == '设置'),
    );
    final row = find
        .ancestor(
          of: label,
          matching: find.byWidgetPredicate((widget) => widget is ElView && widget.event?.onTap != null),
        )
        .first;
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
