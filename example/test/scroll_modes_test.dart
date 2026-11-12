import 'package:example/src/pages/examples/scroll_examples/scroll_mode.dart';
import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('对照下拉保留原模式并切换 ElScrollView 三种生命周期，业务选择不丢失', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: RecyclerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('条目 00001'));
    await tester.pumpAndSettle();
    for (final mode in [SliverExampleMode.children, SliverExampleMode.builder, SliverExampleMode.elRecycler]) {
      await tester.tap(find.byKey(ValueKey('selection-menu')));
      await tester.pumpAndSettle();
      expect(find.byType(CheckedPopupMenuItem<Object>), findsNWidgets(5));
      await tester.tap(find.byKey(ValueKey('selection-mode-${mode.name}')));
      await tester.pumpAndSettle();
      expect(find.byType(ElScrollView), findsOneWidget);
      final sliver = tester.widget<ElSliverList>(find.byWidgetPredicate((widget) => widget is ElSliverList));
      expect(sliver.itemCount, 1000);
      expect(sliver.children.length, mode == .children ? 1000 : 0);
      final titles = find.byWidgetPredicate((widget) => widget is Text && (widget.data?.startsWith('条目 ') ?? false));
      expect(titles.evaluate().length, mode == .children ? 1000 : lessThan(30));
      expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, '1 / 1000');
      final scroll = tester.widget<ElScrollView>(find.byType(ElScrollView));
      expect(scroll.scrollCacheExtent!.value, 250);
      scroll.controller!.jumpTo(8800);
      await tester.pumpAndSettle();
      expect(find.text('条目 00101').hitTestable(), findsOneWidget);
      scroll.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('条目 00001').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
