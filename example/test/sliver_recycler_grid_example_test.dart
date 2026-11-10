import 'package:example/src/pages/examples/sliver_recycler_grid.dart';
import 'package:example/src/pages/home.dart';
import 'package:example/src/utils/router.dart';
import 'package:example/src/widgets/example_scrollbar.dart';
import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/src/widgets/panel.dart';

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(Widget page) => ElComponentProvider(
  components: el.mobileComponents,
  child: MaterialApp(navigatorKey: RouterUtil.rootNavigatorKey, home: page),
);

void main() {
  testWidgets('网格两种模式共用位置控制，大字四列仍可布局', (tester) async {
    _viewport(tester);
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: MediaQueryData(size: Size(390, 844), textScaler: TextScaler.linear(1.6)),
          child: ElSliverRecyclerGridExamplePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller;
    await tester.tap(find.byKey(ValueKey('grid-mode-menu')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckedPopupMenuItem<bool>), findsNWidgets(2));
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<bool>, 'SliverGrid'));
    await tester.pumpAndSettle();
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(ElSliverRecyclerGrid), findsNothing);
    await tester.tap(find.byTooltip('选择列数'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem<int> && widget.value == 4));
    await tester.pumpAndSettle();
    expect(tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller, same(controller));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(ValueKey('grid-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<bool>, 'ElSliverRecyclerGrid'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElSliverRecyclerGrid>(find.byType(ElSliverRecyclerGrid)).crossAxisCount, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页 ListTile 能打开列表、网格和瀑布流并返回', (tester) async {
    _viewport(tester);
    await tester.pumpWidget(_app(HomePage()));
    await tester.pumpAndSettle();

    for (final entry in [
      (key: 'sliver-recycler', title: 'SliverRecycler 滚动对照'),
      (key: 'sliver-recycler-grid', title: '网格示例'),
      (key: 'sliver-recycler-masonry', title: '瀑布流示例'),
    ]) {
      final tile = find.byKey(ValueKey('home-${entry.key}'));
      expect(tester.widget(tile), isA<ListTile>());
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text(entry.title), findsOneWidget);
      if (entry.key == 'sliver-recycler') {
        expect(find.byType(ElSliverRecyclerList), findsOneWidget);
      } else {
        expect(find.byType(ElSliverRecyclerGrid), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    }

    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('网格与瀑布流示例支持自然高度、修改列数和长列表滚动', (tester) async {
    _viewport(tester);
    for (final masonry in [false, true]) {
      await tester.pumpWidget(
        _app(masonry ? ElSliverRecyclerGridExamplePage.masonry() : ElSliverRecyclerGridExamplePage()),
      );
      await tester.pumpAndSettle();
      final grid = find.byType(ElSliverRecyclerGrid);
      final cards = find.descendant(of: grid, matching: find.byType(ExamplePanel));
      expect(tester.widget<ElSliverRecyclerGrid>(grid).crossAxisCount, 2);
      final first = find.ancestor(of: find.text('观察记录 1'), matching: cards);
      final second = find.ancestor(of: find.text('观察记录 2'), matching: cards);
      expect(tester.getSize(second).height, greaterThan(tester.getSize(first).height));

      await tester.tap(find.byTooltip('选择列数'));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem<int> && widget.value == 3));
      await tester.pumpAndSettle();
      expect(tester.widget<ElSliverRecyclerGrid>(grid).crossAxisCount, 3);
      expect(find.text('1000 条记录 · 3 列'), findsOneWidget);

      final scroll = find.byKey(ValueKey(masonry ? 'sliver-masonry-scroll' : 'sliver-grid-scroll'));
      final scrollbar = find.ancestor(of: scroll, matching: find.byType(CupertinoScrollbar));
      expect(scrollbar, findsOneWidget);
      final bar = tester.widget<CupertinoScrollbar>(scrollbar);
      expect(bar.controller, same(tester.widget<CustomScrollView>(scroll).controller));
      expect(bar.thumbVisibility, isTrue);
      final wrapper = find.ancestor(of: scroll, matching: find.byType(RecyclerExampleScrollbar));
      expect(tester.widget<RecyclerExampleScrollbar>(wrapper).stopOnThumbRelease, isFalse);
      await tester.drag(scroll, Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(cards, findsWidgets);
      expect(cards.evaluate().length, lessThan(40));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
    }
  });
}
