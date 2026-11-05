// 应用内部文件沿用相对路径约定。
// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt, ElBottomTabbar;
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';
import '../lib/src/router/index.dart';
import '../lib/src/pages/custom_gestures.dart';
import '../lib/src/pages/examples.dart';
import '../lib/src/pages/examples/catalog.dart';

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

Future<void> _reveal(WidgetTester tester, String key) async {
  final host = find.byKey(PageStorageKey('showcase-scroll'));
  final target = find.byKey(ValueKey(key));
  final position = tester.state<ElScrollViewState>(host).position;
  final delta = tester.getCenter(target).dy - tester.getCenter(host).dy;
  position.jumpTo((position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('综合展示按正文宽度排列首屏和独立按钮卡片', (tester) async {
    await _host(tester);
    for (final width in [1280.0, 820.0, 390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      final hero = tester.getRect(find.byKey(ValueKey('showcase-hero')));
      final copy = tester.getRect(find.byKey(ValueKey('showcase-hero-copy')));
      final scene = tester.getRect(find.byKey(ValueKey('showcase-hero-scene')));
      expect(hero.width, lessThanOrEqualTo(width));
      if (width == 1280) {
        expect(scene.left, greaterThan(copy.right));
      } else {
        expect(scene.top, greaterThan(copy.bottom));
      }
      await tester.tap(find.byKey(ValueKey('showcase-explore')));
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byKey(ValueKey('showcase-basic-panel')));
      final second = tester.getRect(find.byKey(ValueKey('showcase-state-panel')));
      if (width == 1280) {
        expect(second.top, closeTo(first.top, .1));
        expect(second.left, greaterThan(first.right));
      } else {
        expect(second.top, greaterThan(first.bottom));
      }
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      final scroll = tester.state<ElScrollViewState>(find.byKey(PageStorageKey('showcase-scroll'))).position;
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('首页按钮有真实操作反馈、收藏切换和提交状态', (tester) async {
    await _host(tester, width: 390);
    await tester.tap(find.byKey(ValueKey('showcase-explore')));
    await tester.pumpAndSettle();
    await _reveal(tester, 'showcase-primary');
    await tester.tap(find.byKey(ValueKey('showcase-primary')));
    await tester.pumpAndSettle();
    expect(find.text('主要操作已完成'), findsOneWidget);
    await _reveal(tester, 'showcase-favorite');
    await tester.tap(find.byKey(ValueKey('showcase-favorite')));
    await tester.pumpAndSettle();
    expect(find.text('已收藏 · 已添加 0 项'), findsOneWidget);
    await _reveal(tester, 'showcase-submit');
    await tester.tap(find.byKey(ValueKey('showcase-submit')));
    await tester.pump();
    expect(tester.widget<ElButton>(find.byKey(ValueKey('showcase-submit'))).loading, isTrue);
    await tester.pump(Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.widget<ElButton>(find.byKey(ValueKey('showcase-submit'))).loading, isFalse);
    expect(tester.widget<ElButton>(find.byKey(ValueKey('showcase-submit'))).child, '已提交');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('窄屏放大文字后，综合展示仍能滚动访问两个按钮区域', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _host(tester, width: 320);
    await tester.tap(find.byKey(ValueKey('showcase-explore')));
    await tester.pumpAndSettle();
    await _reveal(tester, 'showcase-favorite');
    await tester.tap(find.byKey(ValueKey('showcase-favorite')));
    await tester.pumpAndSettle();
    expect(find.text('已收藏 · 已添加 0 项'), findsOneWidget);
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
        expect(find.widgetWithText(AppBar, page.title), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
        expect(find.byType(ElBottomTabbar), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(ExamplesPage), findsOneWidget);
        expect(tile, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(router.routeInformationProvider.value.uri.path, '/examples');
      await tester.pumpWidget(SizedBox());
    });
  }

  testWidgets('独立示例在快速跨断点时保持页面和交互状态，返回原目录', (tester) async {
    await _host(tester, path: '/examples');
    await tester.tap(find.byKey(ValueKey('advanced-gestures')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('gesture.basic.target')));
    await tester.pump(Duration(milliseconds: 700));
    expect(tester.widget<Text>(find.byKey(ValueKey('count.tap'))).data, '1');
    for (final width in [390.0, 1280.0, 640.0, 641.0, 320.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pump();
      await tester.pump(Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.byType(CustomGesturesPage), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(ValueKey('count.tap'))).data, '1');
    expect(router.routeInformationProvider.value.uri.path, '/examples');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ExamplesPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/examples');
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('独立示例不重复显示全局菜单，返回目录后仍可由侧栏进入设置', (tester) async {
    await _host(tester, path: '/examples');
    await tester.tap(find.byKey(ValueKey('advanced-gestures')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('全局设置'), findsNothing);
    expect(find.byKey(ValueKey('navbar-menu')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CustomGesturesPage), findsNothing);
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
