import 'package:example/src/pages/examples/scroll_examples/scroll_mode.dart';
import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('列表、网格与瀑布流共用四种模式和默认勾选', () {
    for (final kind in ['list', 'grid', 'masonry']) {
      final entries = SliverExampleMode.initial.menuItems(grid: kind == 'grid', masonry: kind == 'masonry');
      final container = switch (kind) {
        'grid' => 'ElSliverGrid',
        'masonry' => 'ElSliverMasonry',
        _ => 'ElSliverList',
      };
      expect(entries.map((entry) => entry.value), [
        SliverExampleMode.recycler,
        SliverExampleMode.builder,
        SliverExampleMode.children,
        SliverExampleMode.official,
      ]);
      expect(entries.map((entry) => (entry.child as Text).data), [
        '$container.recycler',
        '$container.builder',
        container,
        kind == 'list' ? 'SliverList' : 'SliverGrid',
      ]);
      expect(entries.map((entry) => entry.checked), [true, false, false, false]);
    }
  });

  testWidgets('默认复用且菜单优先展示，四种 Sliver 切换不丢业务选择', (tester) async {
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
    expect(find.byType(SliverList), findsNothing);
    expect(find.byWidgetPredicate((widget) => widget is ElSliverList), findsOneWidget);
    final controller = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller;
    await tester.tap(find.text('条目 00001'));
    await tester.pumpAndSettle();
    for (final mode in [SliverExampleMode.children, SliverExampleMode.builder, SliverExampleMode.recycler]) {
      await tester.tap(find.byKey(ValueKey('selection-menu')));
      await tester.pumpAndSettle();
      final entries = tester.widgetList<CheckedPopupMenuItem<SliverExampleMode>>(
        find.byType(CheckedPopupMenuItem<SliverExampleMode>),
      );
      expect(entries.map((entry) => entry.value), SliverExampleMode.values);
      expect(entries.map((entry) => (entry.child as Text).data), [
        'ElSliverList.recycler',
        'ElSliverList.builder',
        'ElSliverList',
        'SliverList',
      ]);
      await tester.tap(find.byKey(ValueKey('selection-mode-${mode.name}')));
      await tester.pumpAndSettle();
      expect(find.byType(ElScrollView), findsNothing);
      final sliver = tester.widget<ElSliverList>(find.byWidgetPredicate((widget) => widget is ElSliverList));
      expect(sliver.itemCount, 1000);
      expect(sliver.children.length, mode == .children ? 1000 : 0);
      final titles = find.byWidgetPredicate((widget) => widget is Text && (widget.data?.startsWith('条目 ') ?? false));
      expect(titles.evaluate().length, mode == .children ? 1000 : lessThan(30));
      expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, '1 / 1000');
      final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(scroll.controller, same(controller));
      expect(scroll.scrollCacheExtent!.value, 250);
      scroll.controller!.jumpTo(8800);
      await tester.pumpAndSettle();
      expect(find.text('条目 00101').hitTestable(), findsOneWidget);
      scroll.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('条目 00001').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(ValueKey('selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('selection-mode-official')));
    await tester.pumpAndSettle();
    expect(find.byType(SliverList), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, '1 / 1000');
  });
}
