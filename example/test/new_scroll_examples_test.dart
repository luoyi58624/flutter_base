import 'package:example/src/pages/examples/new_scroll_nested.dart';
import 'package:example/src/pages/examples/new_scroll_navigation.dart';
import 'package:example/src/pages/examples/new_scroll_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget page) => MaterialApp(scrollBehavior: ElScrollBehavior(), home: page);

void main() {
  testWidgets('导航特效：LargeTitle 与三种折叠构造可以切换', (tester) async {
    await tester.pumpWidget(_app(NewScrollNavigationPage()));
    await tester.pumpAndSettle();
    expect(find.byType(ElSliverLargeTitle), findsOneWidget);

    await tester.tap(find.text('位置折叠'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is ElSliverCollapse), findsOneWidget);
    expect(find.byType(SliverPersistentHeader), findsOneWidget);

    await tester.tap(find.text('方向浮现'));
    await tester.pumpAndSettle();
    expect(find.byType(SliverFloatingHeader), findsOneWidget);

    await tester.tap(find.text('Bibi 吸收'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is ElSliverCollapse), findsOneWidget);
    expect(find.text('搜索视频、话题与用户'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新版滚动：纵横嵌套与 shrinkWrap 页面可以正常挂载', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(NewScrollNestedPage()));
    await tester.pumpAndSettle();

    expect(find.text('纵横轴嵌套矩阵'), findsOneWidget);
    expect(find.text('外层纵向 / 内层纵向', skipOffstage: false), findsOneWidget);
    expect(find.text('外层横向 / 内层纵向', skipOffstage: false), findsOneWidget);
    expect(find.byType(ShrinkWrappingViewport, skipOffstage: false), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新版滚动：Widget 与 Sliver 刷新入口可以切换', (tester) async {
    await tester.pumpWidget(_app(NewScrollRefreshPage()));
    await tester.pumpAndSettle();
    expect(find.byType(ElRefresh), findsOneWidget);

    await tester.tap(find.text('Sliver · ElSliverRefresh'));
    await tester.pumpAndSettle();
    expect(find.byType(ElRefresh), findsNothing);
    expect(find.byType(ElSliverRefresh, skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('iOS · 内容让位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('反向列表'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
