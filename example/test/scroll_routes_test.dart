import 'package:example/src/pages/examples/index.dart';
import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:example/src/pages/examples/sliver_recycler/index.dart';
import 'package:example/src/pages/examples/sliver_takeaway/index.dart';
import 'package:example/src/utils/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('业务目录保留十五个深链，重复负载入口复用现有 Sliver 页面', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    expect(scrollBusinessExamples.map((page) => page.key), [
      'recycler-rectangles',
      'recycler-text',
      'recycler-selection',
      'recycler-chat',
      'recycler-cards',
      'recycler-takeaway',
      'recycler-video-grid',
      'recycler-gallery-grid',
      'recycler-waterfall',
      'recycler-social-feed',
      'recycler-live-chat',
      'recycler-orders',
      'recycler-product-waterfall',
      'recycler-rich-document',
      'recycler-spike',
    ]);
    final routes = RouterUtil.exampleRoutes();
    expect(routes.map((route) => route.path), containsAll(scrollBusinessExamples.map((page) => page.key)));
    final router = GoRouter(
      navigatorKey: RouterUtil.rootNavigatorKey,
      initialLocation: '/examples',
      routes: [GoRoute(path: '/examples', builder: (_, _) => ExamplesPage(), routes: routes)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is ElListGroup && widget.title == 'Sliver 业务示例'), findsOneWidget);
    for (final entry in [
      (key: 'recycler-rectangles', type: ElSliverRecyclerExamplePage),
      (key: 'recycler-text', type: ElSliverRecyclerExamplePage),
      (key: 'recycler-takeaway', type: TakeawaySliverPage),
      (key: 'recycler-selection', type: RecyclerSelectionPage),
    ]) {
      router.go('/examples/${entry.key}');
      await tester.pumpAndSettle();
      expect(find.byType(entry.type), findsOneWidget);
      expect(find.byType(ElSliverRecyclerList), findsOneWidget);
      expect(find.byType(ElScrollView), findsNothing);
      if (entry.key == 'recycler-text') {
        expect(
          tester.widget<ElSliverRecyclerExamplePage>(find.byType(ElSliverRecyclerExamplePage)).initialContent,
          ElSliverRecyclerExampleContent.text,
        );
      }
      expect(tester.takeException(), isNull);
      router.go('/examples');
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
