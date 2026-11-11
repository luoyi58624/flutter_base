import 'package:example/main.dart';
import 'package:example/src/layout/desktop/navbar.dart';
import 'package:example/src/layout/page_scope.dart';
import 'package:example/src/layout/example_page.dart';
import 'package:example/src/router/index.dart';
import 'package:example/src/state/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

Future<void> _openRoute(WidgetTester tester, {required double width, required String path}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  routingConfig.isMobile = width <= 640;
  router.go(path);
  await tester.pumpWidget(App());
  await tester.pumpAndSettle();
}

Future<void> _openPage(WidgetTester tester, Widget page, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: width <= 640 ? el.mobileComponents : el.desktopComponents,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
}

PopupMenuButton<String> _pageMenu() => PopupMenuButton<String>(
  key: ValueKey('page-specific-menu'),
  tooltip: '页面操作',
  itemBuilder: (context) => [PopupMenuItem(value: 'action', child: Text('执行页面操作'))],
);

void main() {
  late bool previousDark;
  setUp(() {
    previousDark = GlobalState.isDark.rawValue;
    GlobalState.isDark.value = false;
  });
  tearDown(() => GlobalState.isDark.value = previousDark);

  testWidgets('移动首页保留可用主题切换且没有导航设置按钮', (tester) async {
    await _openRoute(tester, width: 390, path: '/home');
    expect(find.byKey(ValueKey('navbar-menu')), findsOneWidget);
    expect(find.byTooltip('切换到暗黑模式'), findsOneWidget);
    expect(find.byTooltip('全局设置'), findsNothing);
    await tester.tap(find.byTooltip('切换到暗黑模式'));
    await tester.pumpAndSettle();
    expect(GlobalState.isDark.value, isTrue);
    expect(find.byTooltip('切换到浅色模式'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('移动组件示例设置及独立详情头都没有全局主题或设置入口', (tester) async {
    await _openRoute(tester, width: 390, path: '/home');
    for (final path in [
      '/components',
      '/examples',
      '/settings',
      '/components/button',
      '/examples/recycler-selection',
      '/examples/recycler-chat',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('navbar-menu')), findsNothing, reason: path);
      expect(find.byTooltip('全局设置'), findsNothing, reason: path);
      expect(find.byTooltip('切换到暗黑模式'), findsNothing, reason: path);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('桌面公共头按真实路由只在首页显示主题切换', (tester) async {
    await _openRoute(tester, width: 1280, path: '/home');
    expect(find.byKey(ValueKey('navbar-menu')), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byTooltip('全局设置'), findsNothing);
    await tester.tap(find.byTooltip('切换到暗黑模式'));
    await tester.pumpAndSettle();
    expect(GlobalState.isDark.value, isTrue);

    for (final path in ['/components/button', '/examples', '/settings', '/examples/recycler-selection']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('navbar-menu')), findsNothing, reason: path);
      expect(find.byTooltip('全局设置'), findsNothing, reason: path);
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('页面标题叫首页也不会被误判为真正首页', (tester) async {
    for (final width in [390.0, 1280.0]) {
      await _openPage(tester, ExamplePage(title: '首页', child: Text('普通页面')), width);
      expect(find.byKey(ValueKey('navbar-menu')), findsNothing);
      expect(find.byTooltip('全局设置'), findsNothing);
      await tester.pumpWidget(SizedBox());
    }
  });

  testWidgets('独立页面专用菜单放进两端导航头且不占正文工具行', (tester) async {
    for (final width in [390.0, 1280.0]) {
      await _openPage(
        tester,
        ExamplePage(
          title: '独立示例',
          actions: [_pageMenu()],
          child: SizedBox.expand(key: ValueKey('full-page-content')),
        ),
        width,
      );
      final menu = find.byKey(ValueKey('page-specific-menu'));
      final appBar = find.byType(AppBar);
      expect(find.ancestor(of: menu, matching: appBar), findsOneWidget);
      expect(
        tester.getRect(find.byKey(ValueKey('full-page-content'))).top,
        closeTo(tester.getRect(appBar).bottom, .01),
      );
      expect(find.byKey(ValueKey('navbar-menu')), findsNothing);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('执行页面操作'), findsOneWidget);
      await tester.tap(find.text('执行页面操作'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    }
  });

  testWidgets('桌面公共壳内页面仍保留自己的操作且不重复导航头', (tester) async {
    await _openPage(
      tester,
      DesktopPageScope(
        child: Scaffold(
          appBar: DesktopNavbar(title: '组件'),
          body: ExamplePage(
            title: '正文',
            actions: [_pageMenu()],
            child: SizedBox.expand(key: ValueKey('shell-page-content')),
          ),
        ),
      ),
      1280,
    );
    expect(find.byType(DesktopPageScope), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(ValueKey('page-specific-menu')), findsOneWidget);
    expect(find.byKey(ValueKey('navbar-menu')), findsNothing);
    expect(find.byTooltip('全局设置'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
