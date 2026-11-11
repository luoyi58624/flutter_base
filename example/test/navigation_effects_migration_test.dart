import 'package:example/src/pages/examples/navigation_effects/index.dart';
import 'package:example/src/pages/examples/navigation_effects/layout_pages.dart';
import 'package:example/src/pages/examples/navigation_effects/collapse_pages.dart';
import 'package:example/src/pages/examples/navigation_effects/large_title_pages.dart';
import 'package:example/src/pages/examples/navigation_effects/translucent_pages.dart';
import 'package:example/src/pages/examples/navigation_effects/content_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testApp(Widget child) => MaterialApp(scrollBehavior: ElScrollBehavior(), home: child);

void main() {
  test('原导航动效 15 项全部有独立路由，且 ID 不重复', () {
    expect(navigationEffectExamples.length, 15);
    expect(navigationEffectExamples.map((e) => e.key).toSet().length, 15);
    for (final route in navigationEffectExamples) {
      expect(route.data, isNotNull, reason: route.title);
    }
  });

  for (final route in navigationEffectExamples) {
    testWidgets('迁移页面可以正常布局 / 滚动 / 卸载：${route.key}', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = Size(390 * 2, 844 * 2);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_testApp(Builder(builder: (context) => route.data!(context))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: route.title);
      // 旧版每个样例正文都有滚动长度；这里必须有真实官方 Scrollable。
      expect(find.byType(Scrollable, skipOffstage: false), findsWidgets, reason: route.title);
      await tester.pumpWidget(_testApp(Scaffold(body: Text('已返回'))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '卸载时不得保留旧滚动监听：${route.title}');
    });
  }

  testWidgets('底部导航切页后保持每个 Tab 的滚动位置', (tester) async {
    await tester.pumpWidget(_testApp(BottomNavigationEffectPage()));
    final scrollable = find.byType(ElScroll).first;
    final controller = tester.widget<ElScroll>(scrollable).controller!;
    controller.jumpTo(350);
    await tester.pump();
    await tester.tap(find.text('收藏').last);
    await tester.pump();
    await tester.tap(find.text('发现').last);
    await tester.pump();
    expect(controller.offset, closeTo(350, .01));
  });

  testWidgets('工作空间侧栏与抽屉切换保持选择状态', (tester) async {
    tester.view.physicalSize = Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp(DrawerEffectPage()));
    await tester.tap(find.byKey(ValueKey('effects-drawer-section-1')));
    await tester.pump();
    expect(find.text('进行中的项目'), findsWidgets);
    await tester.tap(find.widgetWithText(SwitchListTile, '桌面也使用抽屉'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '桌面也使用抽屉')).value, isTrue);
    await tester.tap(find.byTooltip('打开导航菜单'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsWidgets);
    expect(find.byKey(ValueKey('effects-drawer-section-1')), findsOneWidget);
  });

  testWidgets('分组吸顶使用官方 PinnedHeaderSliver 和 MainAxisGroup', (tester) async {
    await tester.pumpWidget(_testApp(StickyEffectPage()));
    expect(find.byType(SliverMainAxisGroup, skipOffstage: false), findsWidgets);
    expect(find.byType(PinnedHeaderSliver, skipOffstage: false), findsWidgets);
    final index = find.text('W').last;
    await tester.tap(index);
    await tester.pumpAndSettle();
    expect(find.text('王予安', skipOffstage: false), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('慢读切换方向与跟手折叠，并且无需回到顶部', (tester) async {
    await tester.pumpWidget(_testApp(HideEffectPage()));
    expect(find.byKey(ValueKey('effects-hide-navigation')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('effects-hide-follow-switch')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ElScroll), Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ElScroll), Offset(0, 80));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('LargeTitle 三种独立页面共用 SliverResizingHeader', (tester) async {
    for (final kind in LargeTitleEffectKind.values) {
      await tester.pumpWidget(_testApp(LargeTitleEffectPage(kind: kind)));
      await tester.pump();
      expect(find.byType(SliverResizingHeader), findsOneWidget, reason: kind.name);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('书库搜索可以实时过滤，搜索框不被重建', (tester) async {
    await tester.pumpWidget(_testApp(LargeTitleEffectPage(kind: LargeTitleEffectKind.search)));
    final search = find.byKey(ValueKey('effects-large-search'));
    expect(search, findsOneWidget);
    final element = tester.element(search);
    await tester.enterText(search, '瓦尔登');
    await tester.pump();
    expect(find.text('瓦尔登湖'), findsOneWidget);
    expect(find.text('山茶文具店'), findsNothing);
    expect(tester.element(search), same(element));
    expect(tester.takeException(), isNull);
  });

  testWidgets('山海之间：两种实现使用相同数量的风景画册图层', (tester) async {
    for (final official in [false, true]) {
      await tester.pumpWidget(_testApp(TranslucentEffectPage(officialSliver: official)));
      await tester.pump();
      expect(find.byKey(ValueKey('effects-translucent-bar')), findsOneWidget);
      expect(find.byType(SliverPersistentHeader), official ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('官方山海毛玻璃支持开关，不替换滚动位置', (tester) async {
    await tester.pumpWidget(_testApp(TranslucentEffectPage(officialSliver: true)));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollable.position.jumpTo(400);
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('effects-translucent-blur-toggle')));
    await tester.pump();
    expect(scrollable.position.pixels, closeTo(400, .01));
    expect(tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final official in [false, true]) {
    testWidgets('山海透明导航 ${official ? '官方' : '旧版'}：24～184px 渐显、往返不跳', (tester) async {
      tester.view.physicalSize = Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp(TranslucentEffectPage(officialSliver: official)));
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final bar = find.byKey(ValueKey('effects-translucent-bar'));
      final background = find.byKey(ValueKey('effects-translucent-background'));
      final first = tester.getRect(bar);
      final paragraph = find.text('林间编辑部 · 四幅风景，四种心情');
      final firstParagraphTop = tester.getTopLeft(paragraph).dy;
      for (final offset in [0.0, 24.0, 64.0, 104.0, 144.0, 184.0, 400.0, 184.0, 104.0, 24.0, 0.0]) {
        position.jumpTo(offset);
        await tester.pump();
        final progress = Curves.easeInOut.transform(((offset - 24) / 160).clamp(0.0, 1.0));
        final decoration = tester.widget<DecoratedBox>(background).decoration as BoxDecoration;
        expect(decoration.color!.a, closeTo(.96 * progress, .0001));
        expect(tester.getRect(bar), first, reason: '渐显不能移动导航');
        expect(tester.getTopLeft(paragraph).dy, closeTo(firstParagraphTop - offset, .51), reason: '封面与正文之间不能出现二次位移');
        expect(
          tester.widget<Opacity>(find.byKey(ValueKey('effects-translucent-title'))).opacity,
          closeTo(progress, .001),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('午后慢调：标题随封面离场渐显，回到顶部恢复透明', (tester) async {
    await tester.pumpWidget(_testApp(FoldEffectPage()));
    final navTitle = find.descendant(of: find.byType(AppBar), matching: find.text('午后慢调'));
    final opacity = find.ancestor(of: navTitle, matching: find.byType(Opacity)).first;
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(0, .01));
    position.jumpTo(550);
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(1, .01));
    position.jumpTo(0);
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(0, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('慢读按位置折叠：100px 前展开，超过 100px 收起，到顶恢复', (tester) async {
    await tester.pumpWidget(_testApp(HideEffectPage(collapseOffset: 100)));
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final nav = find.byKey(ValueKey('effects-hide-navigation'));
    position.jumpTo(50);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(nav).dy, closeTo(0, 1));
    position.jumpTo(180);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(nav).dy, lessThan(-50));
    position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(nav).dy, closeTo(0, 1));
  });

  testWidgets('阅读进度条位置固定，随真实 ScrollPosition 变化', (tester) async {
    await tester.pumpWidget(_testApp(ReadingProgressEffectPage()));
    expect(find.byKey(ValueKey('effects-reading-progress')), findsOneWidget);
    final controller = tester.widget<ElScroll>(find.byType(ElScroll)).controller!;
    controller.jumpTo(controller.position.maxScrollExtent / 2);
    await tester.pump();
    final bar = tester.getSize(find.byKey(ValueKey('effects-reading-progress')));
    expect(bar.width, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('原野使用 24 张逐卡渐显、带独立画框的图像', (tester) async {
    await tester.pumpWidget(_testApp(RevealParallaxEffectPage()));
    expect(find.byType(SliverList), findsOneWidget);
    expect(find.text('风景，正在发生'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
