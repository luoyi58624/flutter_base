import 'package:example/src/layout/mobile/index.dart';
import 'package:example/src/pages/home/showcase/panel.dart';
import 'package:example/src/router/mobile.dart';
import 'package:example/src/utils/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'home_showcase_test.dart' as fixture;

Finder _button(String label) => find.byWidgetPredicate((w) => w is ElButton && w.child == label);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _finishTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  setUpAll(fixture.loadShowcaseFonts);

  testWidgets('首页分享面板按 Web 尺寸覆盖外层底栏', (tester) async {
    _phone(tester);
    final navigation = GoRouter(
      navigatorKey: RouterUtil.rootNavigatorKey,
      initialLocation: RouterUtil.home,
      routes: mobileRoute.routes,
    );
    addTearDown(navigation.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: navigation));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.widget<ShowcaseScope>(find.byType(ShowcaseScope)).onNavigate('actions-buttons');
    await tester.pumpAndSettle();

    final popup = find.byType(ElPopup);
    final share = find.byWidgetPredicate((w) => w is ElButton && w.semanticLabel == '分享').first;
    await tester.ensureVisible(share);
    await tester.pumpAndSettle();
    await tester.tap(share);
    await tester.pumpAndSettle();
    final surface = tester.getRect(popup);
    final shell = tester.widget<Scaffold>(
      find.descendant(of: find.byType(MobileLayout), matching: find.byType(Scaffold)).first,
    );
    final bar = tester.getRect(find.byWidget(shell.bottomNavigationBar!));
    expect(surface.left, 16);
    expect(surface.bottom, 828);
    expect(surface.width, 358);
    expect(surface.bottom, greaterThan(bar.top));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(Navigator.of(tester.element(popup)), RouterUtil.rootNavigatorKey.currentState);
    expect(tester.getCenter(fixture.copy('分享这份灵感').last).dx, surface.center.dx);

    final rows = find.descendant(of: popup, matching: find.byType(ElListTile));
    expect(rows, findsNWidgets(3));
    for (final (index, height) in [(0, 56.0), (1, 54.0), (2, 56.0)]) {
      final tile = rows.at(index);
      final bounds = tester.getRect(tile);
      final component = tester.widget<ElListTile>(tile);
      expect(bounds.width, surface.width);
      expect(bounds.height, height);
      final glyph = find.descendant(of: tile, matching: find.byWidgetPredicate((w) => identical(w, component.leading)));
      expect(tester.getRect(glyph).left - bounds.left, 25);
      expect(tester.getRect(fixture.copy(component.title as String).last).left - bounds.left, 56);
    }
    expect(surface.height, 304);
    expect(tester.getSize(_button('取消')), Size(358, 66));

    // 点在底栏上的遮罩区，只关闭弹层，导航仍停留在首页。
    await tester.tapAt(Offset(195, 838));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(navigation.routeInformationProvider.value.uri.path, RouterUtil.home);
  });

  testWidgets('反馈示例的分享、单双选和抽屉返回选中的业务值', (tester) async {
    await fixture.host(tester, height: 844);

    Future<void> open(String anchor, Finder action) async {
      await fixture.reveal(tester, anchor);
      await Scrollable.ensureVisible(tester.element(action), alignment: .5);
      await tester.pump();
      await tester.tap(action);
      await _finishTransition(tester);
    }

    final popup = find.byType(ElPopup);
    await open('feedback-share', fixture.copy('展开操作面板').first);
    expect(tester.getRect(popup), Rect.fromLTWH(16, 524, 358, 304));
    await tester.tap(fixture.copy('收藏到本地').last);
    await _finishTransition(tester);
    expect(popup, findsNothing);
    expect(fixture.copy('已收藏到本地'), findsWidgets);
    expect(Obs.localStorage.getItem<bool>('showcase.liked'), isTrue);

    await open('feedback-selection', _button('打开单选面板'));
    await tester.tap(fixture.copy('锁屏').last);
    await _finishTransition(tester);
    expect(popup, findsNothing);
    expect(fixture.copy('已选择：锁屏'), findsWidgets);

    await open('feedback-selection', _button('打开多选面板'));
    final choices = find.descendant(
      of: popup,
      matching: find.byWidgetPredicate((w) => w is ElView && w.semantics?.properties.checked != null),
    );
    expect(choices, findsNWidgets(3));
    for (final (i, height) in [(0, 80.0), (1, 78.0), (2, 80.0)]) {
      expect(tester.getSize(choices.at(i)).height, height);
    }
    expect(tester.widget<ElView>(choices.last).semantics!.properties.checked, isFalse);
    await tester.tap(choices.last);
    await tester.pump();
    expect(popup, findsOneWidget);
    expect(tester.widget<ElView>(choices.last).semantics!.properties.checked, isTrue);
    expect(tester.getSize(_button('完成')), Size(179, 66));
    await tester.tap(_button('完成'));
    await _finishTransition(tester);
    expect(popup, findsNothing);
    expect(fixture.copy('已选择 3 项同步内容'), findsWidgets);

    await open('feedback-overlays', fixture.copy('打开抽屉').first);
    final drawer = find.byType(ElDrawer);
    expect(tester.getRect(drawer), Rect.fromLTWH(30, 0, 360, 844));
    final name = find.descendant(of: drawer, matching: find.byType(ElEditableView)).first;
    await tester.tap(name);
    await tester.pump();
    tester.testTextInput.enterText('新的显示名称');
    await tester.pump();
    await tester.tap(_button('保存资料').hitTestable());
    await _finishTransition(tester);
    expect(find.byType(ElDialog), findsOneWidget);
    await tester.tap(_button('保存'));
    await _finishTransition(tester);
    expect(drawer, findsNothing);
    expect(find.byType(ElDialog), findsNothing);
    expect(fixture.copy('资料已保存：新的显示名称'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
