import 'package:example/main.dart';
import 'package:example/router.dart';
import 'package:example/src/pages/components/basic/button/index.dart';
import 'package:example/src/pages/components/catalog.dart';
import 'package:example/src/pages/components/start/shadow/index.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElBottomTabbar;
import 'package:flutter_test/flutter_test.dart';

Finder _navLabel(String label) => find.descendant(
  of: find.byType(ElNavMenu<WidgetBuilder>),
  matching: find.byWidgetPredicate((widget) => widget is ElView && widget.child == label),
);

Future<void> _host(WidgetTester tester, {double width = 1280, String path = '/components'}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  routingConfig.isMobile = width <= 640;
  router.go(path);
  await tester.pumpWidget(App());
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String label) async {
  final row = find
      .ancestor(
        of: _navLabel(label),
        matching: find.byWidgetPredicate((widget) => widget is ElView && widget.event?.onTap != null),
      )
      .first;
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  test('共同菜单生成所有叶子路由，分组只参与展示', () {
    expect(RouterUtil.pages.length, componentCatalog.fold<int>(0, (count, group) => count + group.children.length));
    expect(RouterUtil.pages.every((page) => !page.group && page.children.isEmpty), isTrue);
    final paths = RouterUtil.desktopPages.map((page) => page.key);
    expect(paths.toSet().length, paths.length);
    expect(paths, containsAll(['/components/button', '/components/shadow-design', '/examples/gestures']));
    expect(paths, isNot(contains('/components/基础组件')));
    expect(RouterUtil.desktopMenus.map((menu) => menu.title), ['首页', '组件', '示例', '设置']);
    expect(RouterUtil.titleOf(Uri.parse('/components/button?source=test#example')), 'Button 按钮');
  });

  testWidgets('桌面公共头覆盖整行，标识和标题不跳转，公共菜单可切换主题和打开设置', (tester) async {
    GlobalState.isDark.value = false;
    addTearDown(() => GlobalState.isDark.value = false);
    await _host(tester, path: '/components/button');
    final navbar = find.byKey(ValueKey('desktop-navbar'));
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.getRect(navbar).left, 0);
    expect(tester.getRect(navbar).width, 1280);
    final title = find.descendant(of: navbar, matching: find.text('Button 按钮'));
    final logo = find.descendant(
      of: navbar,
      matching: find.byWidgetPredicate((widget) => widget is ElIcon && widget.semanticLabel == 'El UI'),
    );
    expect(title, findsOneWidget);
    expect(logo, findsOneWidget);
    expect(tester.getCenter(logo).dx, lessThan(tester.getCenter(title).dx));
    await tester.tap(logo);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/components/button');
    final menu = find.byKey(ValueKey('navbar-menu'));
    expect(menu, findsOneWidget);
    expect(tester.getCenter(menu).dx, greaterThan(tester.getCenter(title).dx));
    await tester.tap(find.byTooltip('切换到暗黑模式'));
    await tester.pumpAndSettle();
    expect(GlobalState.isDark.value, isTrue);
    await tester.tap(find.byTooltip('全局设置'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('桌面按路由显示侧栏和正文，菜单高亮跟随地址', (tester) async {
    await _host(tester);
    expect(router.routeInformationProvider.value.uri.path, '/components/quick-start');
    expect(_navLabel('开始使用'), findsOneWidget);
    expect(_navLabel('基础组件'), findsOneWidget);
    expect(find.byType(ButtonPage, skipOffstage: false), findsNothing);
    expect(find.byType(ShadowPage, skipOffstage: false), findsNothing);

    await _select(tester, 'Button 按钮');
    expect(router.routeInformationProvider.value.uri.path, '/components/button');
    expect(find.byType(ButtonPage), findsOneWidget);
    expect(tester.widget<ElNavMenu<WidgetBuilder>>(find.byType(ElNavMenu<WidgetBuilder>)).router, same(router));
    router.go('/components/slider');
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('example-page-slider')), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Slider 滑块'), findsOneWidget);

    await _select(tester, '首页');
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.byType(ElNavMenu<WidgetBuilder>), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('文档和设置地址在两端切换时保留，组件列表有桌面入口', (tester) async {
    await _host(tester, path: '/components/button?source=test#example');
    expect(find.byType(ElNavMenu<WidgetBuilder>), findsOneWidget);
    tester.view.physicalSize = Size(640, 900);
    await tester.pumpAndSettle();
    expect(find.byType(ElBottomTabbar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(ElNavMenu<WidgetBuilder>), findsNothing);
    expect(find.byType(ButtonPage), findsOneWidget);
    expect(tester.widget<ElBottomTabbar>(find.byType(ElBottomTabbar, skipOffstage: false)).selectedIndex, 1);
    expect(router.routeInformationProvider.value.uri.toString(), '/components/button?source=test#example');
    tester.view.physicalSize = Size(1280, 900);
    await tester.pumpAndSettle();
    expect(find.byType(ButtonPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.toString(), '/components/button?source=test#example');
    final selectedButton = find.ancestor(
      of: _navLabel('Button 按钮'),
      matching: find.byWidgetPredicate((widget) => widget is ElView && widget.semantics?.properties.selected == true),
    );
    expect(selectedButton, findsOneWidget);
    tester.view.physicalSize = Size(640, 900);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/components');
    expect(tester.widget<ElBottomTabbar>(find.byType(ElBottomTabbar)).selectedIndex, 1);

    tester.view.physicalSize = Size(641, 900);
    await tester.pumpAndSettle();
    expect(find.byType(ElNavMenu<WidgetBuilder>), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/components/quick-start');
    expect(find.byType(AppBar), findsOneWidget);
    tester.view.physicalSize = Size(390, 900);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '快速开始'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('component-quick-start')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/components/quick-start');
    expect(find.widgetWithText(AppBar, '快速开始'), findsOneWidget);
    router.go('/settings');
    await tester.pumpAndSettle();
    tester.view.physicalSize = Size(1280, 900);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('桌面设置路由使用原有页面并能切换主题', (tester) async {
    GlobalState.isDark.value = false;
    addTearDown(() => GlobalState.isDark.value = false);
    await _host(tester, path: '/components/button');
    router.go('/settings');
    await tester.pumpAndSettle();
    final toggle = find.byWidgetPredicate((widget) => widget is ElListTile && widget.title == '主题模式');
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(GlobalState.isDark.value, isTrue);
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('页面转场未结束时连续跨断点，导航键保持唯一并保留深度地址', (tester) async {
    final location = '/components/button?source=resize#example';
    await _host(tester, path: location);
    // 每次只推进一帧，覆盖旧导航壳仍在退出时再次切回的情况。
    for (final width in [390.0, 1280.0, 640.0, 641.0, 480.0, 1280.0, 390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pump();
      await tester.pump(Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.toString(), location);
    expect(find.byType(ButtonPage), findsOneWidget);
    expect(find.byType(ElNavMenu<WidgetBuilder>), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
