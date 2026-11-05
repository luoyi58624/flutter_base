import 'package:example/src/pages/components/basic/button/index.dart';
import 'package:example/src/pages/components/doc_page.dart';
import 'package:example/src/widgets/code_preview/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _openButtonRoute(WidgetTester tester, String location) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
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
}
