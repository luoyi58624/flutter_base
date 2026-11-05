import 'package:example/main.dart';
import 'package:example/router.dart';
import 'package:example/src/layout/mobile/pages/2.dart';
import 'package:example/src/pages/components/basic/button/index.dart';
import 'package:example/src/pages/components/start/shadow/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openCatalog(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  routingConfig.isMobile = true;
  router.go('/components');
  await tester.pumpWidget(App());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('移动目录通过路由打开占位页和阴影页面，返回后仍能再次进入', (tester) async {
    await _openCatalog(tester);
    for (final (key, title) in [('quick-start', '快速开始'), ('theme-design', '主题设计'), ('quick-start', '快速开始')]) {
      await tester.tap(find.byKey(ValueKey('component-$key')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/components/$key');
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/components');
      expect(find.byType(ComponentPage), findsOneWidget);
    }

    await tester.tap(find.byKey(ValueKey('component-shadow-design')));
    await tester.pumpAndSettle();
    expect(find.byType(ShadowPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '阴影'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ShadowPage), findsNothing);
    expect(find.byKey(ValueKey('component-shadow-design')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('四个一级导航与组件深度路由对应，详情返回到组件目录', (tester) async {
    await _openCatalog(tester);
    final tabbar = find.byType(ElBottomTabbar);
    expect(tester.widget<ElBottomTabbar>(tabbar).destinations.map((item) => item.label), ['首页', '组件', '示例', '设置']);
    tester.widget<ElBottomTabbar>(tabbar).onDestinationSelected!(2);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/examples');
    tester.widget<ElBottomTabbar>(tabbar).onDestinationSelected!(3);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    tester.widget<ElBottomTabbar>(tabbar).onDestinationSelected!(1);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/components');
    await tester.tap(find.byKey(ValueKey('component-button')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/components/button');
    expect(find.byType(ButtonPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(tabbar, findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ComponentPage), findsOneWidget);
    expect(find.byKey(ValueKey('component-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
