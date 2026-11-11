// 测试沿用项目内部相对路径约定。
// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';
import '../lib/src/router/index.dart';
import '../lib/src/utils/router.dart';
import '../lib/src/pages/components/index.dart';
import '../lib/src/pages/components/basic/button/index.dart';
import '../lib/src/pages/components/list/list_tile/index.dart';
import '../lib/src/pages/components/start/shadow/index.dart';

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
  testWidgets('移动组件分组在目录末尾并能打开底部导航栏示例', (tester) async {
    await _openCatalog(tester);
    final catalog = find.byKey(PageStorageKey('component-catalog'));
    final groups = tester.widgetList<ElListGroup>(find.descendant(of: catalog, matching: find.byType(ElListGroup)));
    expect(groups.last.title, 'Mobile 组件');
    expect(groups.any((group) => group.title == 'Desktop 组件'), isFalse);
    final position = _scrollable(tester, catalog).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('component-bottom-tabbar')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/components/bottom-tabbar');
    final tabbar = find.byType(ElBottomTabbar);
    expect(tester.widget<ElBottomTabbar>(tabbar).selectedIndex, 0);
    await tester.tap(find.descendant(of: tabbar, matching: find.bySemanticsLabel('发现')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElBottomTabbar>(tabbar).selectedIndex, 1);
    await tester.pumpWidget(SizedBox());
  });

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

  testWidgets('每个未实现的组件条目都能点击进入对应标题的空白页并返回目录', (tester) async {
    await _openCatalog(tester);
    final catalog = find.byKey(PageStorageKey('component-catalog'));
    final placeholders = RouterUtil.pages.where(
      (page) => [
        'quick-start',
        'theme-design',
        'input-number',
        'input-otp',
        'input-tag',
        'mention',
        'empty',
      ].contains(page.key),
    );

    for (final page in placeholders) {
      expect(page.data, isNotNull, reason: page.key);
      final tile = find.byKey(ValueKey('component-${page.key}'));
      final position = _scrollable(tester, catalog).position;
      final delta = tester.getCenter(tile).dy - tester.getCenter(catalog).dy;
      position.jumpTo((position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble());
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/components/${page.key}');
      final header = find.widgetWithText(AppBar, page.title);
      expect(header, findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      final scaffold = find.ancestor(of: header, matching: find.byType(Scaffold)).first;
      expect(tester.widget<Scaffold>(scaffold).body, isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/components');
      expect(tester.widget<ElBottomTabbar>(find.byType(ElBottomTabbar)).selectedIndex, 1);
      expect(tester.takeException(), isNull, reason: page.key);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('移动目录进入列表行文档并返回后仍能再次进入', (tester) async {
    await _openCatalog(tester);
    final catalog = find.byKey(PageStorageKey('component-catalog'));
    for (var index = 0; index < 2; index++) {
      final tile = find.byKey(ValueKey('component-list-tile'));
      final position = _scrollable(tester, catalog).position;
      final delta = tester.getCenter(tile).dy - tester.getCenter(catalog).dy;
      position.jumpTo((position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble());
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/components/list-tile');
      expect(find.byType(ListTilePage), findsOneWidget);
      expect(find.widgetWithText(AppBar, '组件文档'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/components');
      expect(find.byType(ComponentPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
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

/// 读取 [host] 内最近的官方滚动状态。
ScrollableState _scrollable(WidgetTester tester, Finder host) =>
    tester.state<ScrollableState>(find.descendant(of: host, matching: find.byType(Scrollable)).first);
