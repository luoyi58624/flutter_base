import 'package:example/src/pages/components/basic/button/index.dart';
import 'package:example/src/pages/components/doc_page.dart';
import 'package:example/src/widgets/code_preview/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _openButtonRoute(WidgetTester tester, String location, {double width = 390}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/components/button', builder: (context, state) => ButtonPage()),
      GoRoute(
        path: '/empty',
        builder: (context, state) => Scaffold(body: Text('空页面')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void _expectRealExample(rv.RecyclerView recyclerView, int position) {
  final holder = recyclerView.findViewHolderForAdapterPosition(position);
  expect(holder, isNotNull, reason: '目标位置 $position 应已进入可见布局');
  final item = find.byWidget(holder!.itemView);
  expect(item, findsOneWidget);
  expect(find.descendant(of: item, matching: find.byType(ElCodeExample)), findsOneWidget);
  expect(find.descendant(of: item, matching: find.byType(ElButton)), findsWidgets);
  final layout = recyclerView.getLayoutManager()! as rv.LinearLayoutManager;
  expect(layout.findFirstVisibleItemPosition(), lessThanOrEqualTo(position));
  expect(layout.findLastVisibleItemPosition(), greaterThanOrEqualTo(position));
}

Finder _scrollSwitch() => find.byKey(ValueKey('button-scroll-recycler-switch'));

void _expectScrollMode(WidgetTester tester, {required bool recycler, required int repeat}) {
  expect(_scrollSwitch(), findsOneWidget);
  expect(tester.widget<Switch>(_scrollSwitch()).value, recycler);
  expect(find.text(recycler ? 'RecyclerView' : 'ElScrollView'), findsOneWidget);
  final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
  expect(page.useRecyclerView, recycler);
  expect(page.repeatCount, repeat);
  final itemCount = page.sections.length * repeat + 1;
  if (recycler) {
    expect(find.byType(rv.RecyclerView), findsOneWidget);
    final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
    expect(list.getAdapter()!.getItemCount(), itemCount);
  } else {
    expect(find.byType(rv.RecyclerView), findsNothing);
    expect(find.byType(ElScrollView), findsOneWidget);
    final list = tester.widget<ElListView>(find.byType(ElListView).first);
    expect(list.itemCount, itemCount);
    expect(list.keepAlive, isFalse);
  }
}

void main() {
  testWidgets('Button 查询参数用 RecyclerView 重复真实文档并支持远处定位和回滑', (tester) async {
    await _openButtonRoute(tester, '/components/button?recycler=true&repeat=3');
    expect(find.byType(ButtonPage), findsOneWidget);
    expect(find.byType(rv.RecyclerView), findsOneWidget);
    final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
    final recyclerView = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
    expect(page.useRecyclerView, isTrue);
    expect(page.repeatCount, 3);
    expect(recyclerView.getAdapter()!.getItemCount(), page.sections.length * 3 + 1);

    // 三轮中的同一真实按钮模板都必须经过位置绑定，而不是只验证首屏。
    final thirdRound = page.sections.length * 2 + 1;
    for (final position in [thirdRound, 1, page.sections.length + 1, thirdRound, 1]) {
      recyclerView.scrollToPosition(position);
      await tester.pumpAndSettle();
      _expectRealExample(recyclerView, position);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('RecyclerView 文档反复离开和重新进入会重新连接模板且没有遗留异常', (tester) async {
    final router = await _openButtonRoute(tester, '/components/button?recycler=true&repeat=3');
    for (var attempt = 0; attempt < 2; attempt++) {
      final previous = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
      router.go('/empty');
      await tester.pumpAndSettle();
      expect(find.byType(rv.RecyclerView), findsNothing);
      expect(tester.takeException(), isNull);

      router.go('/components/button?recycler=true&repeat=3');
      await tester.pumpAndSettle();
      final current = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
      expect(identical(current, previous), isFalse);
      current.scrollToPosition(1);
      await tester.pumpAndSettle();
      _expectRealExample(current, 1);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Button 无查询参数保留 ElScrollView 与关闭 keepAlive 的原文档分支', (tester) async {
    await _openButtonRoute(tester, '/components/button');
    final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
    expect(page.useRecyclerView, isFalse);
    expect(page.repeatCount, 1);
    expect(find.byType(rv.RecyclerView), findsNothing);
    expect(find.byType(ElScrollView), findsOneWidget);
    final list = tester.widget<ElListView>(find.byType(ElListView).first);
    expect(list.keepAlive, isFalse);
    expect(list.itemCount, page.sections.length + 1);
    expect(find.byType(ElCodeExample), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('窄屏按钮页可点开关往返两条滚动管线并保留查询参数和片段', (tester) async {
    final router = await _openButtonRoute(
      tester,
      '/components/button?repeat=3&source=phone&flag=yes#compare',
      width: 320,
    );
    _expectScrollMode(tester, recycler: false, repeat: 3);
    expect(_scrollSwitch().hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(_scrollSwitch());
    await tester.pumpAndSettle();
    _expectScrollMode(tester, recycler: true, repeat: 3);
    var uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/components/button');
    expect(uri.queryParameters['recycler'], 'true');
    expect(uri.queryParameters['repeat'], '3');
    expect(uri.queryParameters['source'], 'phone');
    expect(uri.queryParameters['flag'], 'yes');
    expect(uri.fragment, 'compare');

    final switchCenter = tester.getCenter(_scrollSwitch());
    final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
    final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
    list.scrollToPosition(page.sections.length * 2 + 1);
    await tester.pumpAndSettle();
    expect(tester.getCenter(_scrollSwitch()), switchCenter);
    expect(_scrollSwitch().hitTestable(), findsOneWidget);

    await tester.tap(_scrollSwitch());
    await tester.pumpAndSettle();
    _expectScrollMode(tester, recycler: false, repeat: 3);
    uri = router.routeInformationProvider.value.uri;
    expect(uri.queryParameters['recycler'], isNot('true'));
    expect(uri.queryParameters['repeat'], '3');
    expect(uri.queryParameters['source'], 'phone');
    expect(uri.queryParameters['flag'], 'yes');
    expect(uri.fragment, 'compare');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('外部深链 true 和 false 同步开关与当前滚动管线', (tester) async {
    final router = await _openButtonRoute(tester, '/components/button?repeat=2');
    _expectScrollMode(tester, recycler: false, repeat: 2);

    router.go('/components/button?recycler=true&repeat=2');
    await tester.pumpAndSettle();
    _expectScrollMode(tester, recycler: true, repeat: 2);
    expect(tester.takeException(), isNull);

    router.go('/components/button?recycler=false&repeat=2');
    await tester.pumpAndSettle();
    _expectScrollMode(tester, recycler: false, repeat: 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('不安装 GoRouter 时按钮页仍可在窄屏本地切换', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(320, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: ButtonPage()),
      ),
    );
    await tester.pumpAndSettle();
    _expectScrollMode(tester, recycler: false, repeat: 1);

    await tester.tap(_scrollSwitch());
    await tester.pumpAndSettle();
    _expectScrollMode(tester, recycler: true, repeat: 1);
    expect(tester.takeException(), isNull);

    await tester.tap(_scrollSwitch());
    await tester.pumpAndSettle();
    _expectScrollMode(tester, recycler: false, repeat: 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
