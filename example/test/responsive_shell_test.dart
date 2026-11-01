import 'package:example/src/mobile/app.dart';
import 'package:example/src/pages/index.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.75;
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ElExampleApp(networkDelay: Duration.zero, replyDelay: Duration.zero));
  await tester.pumpAndSettle();
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('宽屏为侧栏和多列内容，缩窄后按逻辑宽度切回底部导航', (tester) async {
    await _open(tester, Size(1280, 800));
    final sidebar = find.byKey(ValueKey('desktop-nav'));
    final bottom = find.byKey(ValueKey('bottom-nav'));
    final first = find.byKey(ValueKey('article-0'));
    final second = find.byKey(ValueKey('article-1'));
    final home = find.byKey(PageStorageKey('home-list'));
    final scroll = tester.state<ElScrollViewState>(home);
    expect(sidebar, findsOneWidget);
    expect(bottom, findsNothing);
    expect(find.byType(ElMobileTheme), findsOneWidget);
    expect(tester.getTopLeft(first).dx, greaterThan(tester.getRect(sidebar).right));
    expect(tester.getTopLeft(first).dy, closeTo(tester.getTopLeft(second).dy, 1));
    expect(tester.getTopLeft(second).dx, greaterThan(tester.getRect(first).right));
    for (final tab in ['分类', '消息', '我的', '推荐']) {
      await tester.tap(find.byKey(ValueKey('tab-$tab')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('page-$tab')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await _resize(tester, Size(390, 844));
    expect(sidebar, findsNothing);
    expect(bottom, findsOneWidget);
    expect(find.byKey(ValueKey('home-grid')), findsNothing);
    expect(tester.state<ElScrollViewState>(home), same(scroll));
    expect(tester.getTopLeft(second).dy, greaterThan(tester.getRect(first).bottom));

    await _resize(tester, Size(767, 800));
    expect(bottom, findsOneWidget);
    await _resize(tester, Size(768, 800));
    expect(sidebar, findsOneWidget);
    expect(bottom, findsNothing);
    await _resize(tester, Size(1920, 1080));
    expect(tester.getSize(home).width, lessThanOrEqualTo(1120));
    expect(tester.state<ElScrollViewState>(home), same(scroll));
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('缩放保留当前页面、开关和已读状态，两种导航都能跳转', (tester) async {
    await _open(tester, Size(390, 844));
    await tester.tap(find.byKey(ValueKey('tab-我的')));
    await tester.pumpAndSettle();
    final setting = find.byKey(ValueKey('switch-消息推送'));
    tester.widget<ElSwitch>(setting).onChanged!(false);
    await tester.pumpAndSettle();
    // 提示条消失后再点击桌面底部入口，避免点击被临时提示层拦截。
    await tester.pump(Duration(seconds: 4));
    await tester.pumpAndSettle();
    await _resize(tester, Size(1280, 800));
    expect(find.byKey(ValueKey('page-我的')), findsOneWidget);
    expect(tester.widget<ElSwitch>(setting).value, isFalse);

    await tester.tap(find.byKey(ValueKey('desktop-demos')));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('tab-消息')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部已读'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('unread-0')), findsNothing);
    await tester.pump(Duration(seconds: 4));
    await tester.pumpAndSettle();
    await _resize(tester, Size(390, 844));
    expect(find.byKey(ValueKey('page-消息')), findsOneWidget);
    expect(find.byKey(ValueKey('unread-0')), findsNothing);
    await tester.tap(find.byKey(ValueKey('tab-我的')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElSwitch>(setting).value, isFalse);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('桌面详情限宽，打开后仍可缩到手机尺寸', (tester) async {
    await _open(tester, Size(1440, 900));
    await tester.tap(find.byKey(ValueKey('article-0')));
    await tester.pumpAndSettle();
    final title = find.byKey(ValueKey('detail-title'));
    final scroll = find.ancestor(of: title, matching: find.byType(ElScrollView)).first;
    expect(tester.getSize(scroll).width, lessThanOrEqualTo(960));
    await _resize(tester, Size(390, 844));
    expect(title, findsOneWidget);
    await tester.tap(find.byKey(ValueKey('back')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('bottom-nav')), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });
}
