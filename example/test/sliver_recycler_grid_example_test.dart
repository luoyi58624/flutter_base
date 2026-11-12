import 'package:example/src/pages/examples/scroll_examples/scroll_mode.dart';
import 'package:example/src/pages/examples/sliver_recycler_grid/index.dart';
import 'package:example/src/pages/examples/index.dart';
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

Future<void> _official(WidgetTester tester) async {
  await tester.tap(find.byKey(ValueKey('grid-mode-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckedPopupMenuItem<SliverExampleMode>, 'SliverGrid'));
  await tester.pumpAndSettle();
}

double _officialExtent(WidgetTester tester) =>
    (tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
        .mainAxisExtent!;

Finder _element(Element element) => find.byElementPredicate((candidate) => identical(candidate, element));

int _recordNumber(WidgetTester tester, Finder card) {
  for (final text in tester.widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))) {
    if (text.data?.startsWith('观察记录 ') == true) return int.parse(text.data!.substring(5));
  }
  throw StateError('未找到卡片编号');
}

List<Widget> _structure(WidgetTester tester, Finder card) {
  final result = <Widget>[];
  void visit(Element element) {
    final widget = element.widget;
    // 图标和文字是可变叶子，其内部布局不属于示例承诺复用的卡片结构。
    if (widget is Icon || widget is Text) return;
    if (widget is Column || widget is Padding || widget is SizedBox || widget is Align) result.add(widget);
    element.visitChildren(visit);
  }

  tester.element(card).visitChildren(visit);
  return result;
}

Future<void> _settleJump(WidgetTester tester, ScrollController controller, String phase) async {
  final frames = <String>[];
  for (var frame = 0; frame < 120; frame++) {
    await tester.pump(Duration(milliseconds: 16));
    if (!tester.binding.hasScheduledFrame) return;
    if (frame < 3 || frame >= 117) {
      frames.add(
        '$frame: pixels=${controller.offset}, max=${controller.position.maxScrollExtent}, '
        'callbacks=${tester.binding.transientCallbackCount}',
      );
    }
  }
  final reason = '$phase 在 120 帧后仍持续请求帧：${frames.join('; ')}';
  tester.binding.debugAssertNoTransientCallbacks(reason);
  fail(reason);
}

Future<void> _recycler(WidgetTester tester) async {
  tester.widget<PopupMenuButton<SliverExampleMode>>(find.byKey(ValueKey('grid-mode-menu'))).onSelected!(.recycler);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('网格与瀑布流跨记录换绑保留卡片排版结构', (tester) async {
    _viewport(tester);
    for (final masonry in [false, true]) {
      await tester.pumpWidget(
        _app(masonry ? ElSliverRecyclerGridExamplePage.masonry() : ElSliverRecyclerGridExamplePage()),
      );
      await tester.pumpAndSettle();
      await _recycler(tester);
      final card = find.ancestor(of: find.text('观察记录 1'), matching: find.byType(ExamplePanel));
      final element = tester.element(card);
      final panel = element.widget;
      final structure = _structure(tester, card);
      final controller = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
      var current = 1;
      for (var step = 0; step < 12 && current == 1; step++) {
        controller.jumpTo(controller.offset + 900);
        await _settleJump(tester, controller, 'masonry=$masonry, step=$step');
        expect(element.mounted, isTrue);
        current = _recordNumber(tester, _element(element));
      }
      expect(current, isNot(1));
      expect(element.widget, same(panel));
      final rebound = _structure(tester, _element(element));
      expect(rebound.length, structure.length);
      for (var index = 0; index < structure.length; index++) {
        expect(rebound[index], same(structure[index]));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
    }
  });

  testWidgets('真实卡片工厂对同内容换绑保留图标和描述，只更新编号字段', (tester) async {
    _viewport(tester);
    await tester.pumpWidget(_app(ElSliverRecyclerGridExamplePage()));
    await tester.pumpAndSettle();
    await _recycler(tester);
    final factory = (tester.widget<ElSliverGrid>(
      find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry),
    ) as dynamic).itemBuilder;
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(_app(SingleChildScrollView(child: Builder(builder: (context) => factory(context, index)))));
    await tester.pumpAndSettle();
    final card = find.byType(ExamplePanel);
    final structure = _structure(tester, card);
    final icon = tester.widget<Icon>(find.descendant(of: card, matching: find.byType(Icon)));
    final description = tester.widget<Text>(find.text('清晨的树影落在小路上。'));
    index.value = 6;
    await tester.pumpAndSettle();
    expect(find.text('林间漫步 #7'), findsOneWidget);
    expect(find.text('观察记录 7'), findsOneWidget);
    expect(tester.widget<Text>(find.text('清晨的树影落在小路上。')), same(description));
    expect(tester.widget<Icon>(find.descendant(of: card, matching: find.byType(Icon))), same(icon));
    index.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('沿河骑行 #2'), findsOneWidget);
    expect(find.byIcon(Icons.directions_bike_outlined), findsOneWidget);
    expect(find.text('清晨的树影落在小路上。'), findsNothing);
    final rebound = _structure(tester, card);
    expect(rebound.length, structure.length);
    for (var offset = 0; offset < structure.length; offset++) {
      expect(rebound[offset], same(structure[offset]));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('官方网格高度缓存随宽度和排版环境失效，与重新挂载的测量一致', (tester) async {
    _viewport(tester);
    var pageKey = 0;
    var width = 390.0;
    var scale = 1.0;
    var bold = false;
    var fontSize = 14.0;
    var lineHeight = 1.2;
    var direction = TextDirection.ltr;
    var locale = Locale('en');
    late StateSetter rebuild;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            final theme = Theme.of(context);
            return Theme(
              data: theme.copyWith(
                textTheme: theme.textTheme.copyWith(
                  titleSmall: theme.textTheme.titleSmall?.copyWith(fontSize: fontSize),
                  bodyMedium: theme.textTheme.bodyMedium?.copyWith(fontSize: fontSize, height: lineHeight),
                ),
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), boldText: bold),
                child: Localizations.override(
                  context: context,
                  locale: locale,
                  child: Directionality(
                    textDirection: direction,
                    child: DefaultTextStyle(
                      style: TextStyle(height: lineHeight),
                      textHeightBehavior: TextHeightBehavior(applyHeightToFirstAscent: lineHeight < 2),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: width,
                          child: ElSliverRecyclerGridExamplePage(key: ValueKey(pageKey)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _official(tester);
    final first = _officialExtent(tester);
    final firstGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final firstCards = {
      for (final element
          in find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_RecordCard').evaluate())
        element: element.widget,
    };
    final controller = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    controller.jumpTo(1);
    await tester.pumpAndSettle();
    expect(_officialExtent(tester), first);
    expect(tester.widget<SliverGrid>(find.byType(SliverGrid)), same(firstGrid));
    for (final entry in firstCards.entries.where((entry) => entry.key.mounted)) {
      expect(entry.key.widget, same(entry.value), reason: '纯滚动保留 delegate，不刷新仍在窗口内的记录。');
    }

    for (final change in <VoidCallback>[
      () => width = 320,
      () => fontSize = 18,
      () => scale = 1.4,
      () => bold = true,
      () => lineHeight = 2.2,
      () => locale = Locale('en', 'GB'),
      () => direction = TextDirection.rtl,
    ]) {
      rebuild(change);
      await tester.pumpAndSettle();
      final updated = _officialExtent(tester);
      rebuild(() => pageKey++);
      await tester.pumpAndSettle();
      await _official(tester);
      expect(_officialExtent(tester), updated, reason: '保留页面的缓存结果应与当前环境下的首次测量一致');
      expect(tester.takeException(), isNull);
    }
    expect(_officialExtent(tester), greaterThan(first));
  });

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
    expect(find.byType(CheckedPopupMenuItem<SliverExampleMode>), findsNWidgets(4));
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<SliverExampleMode>, 'SliverGrid'));
    await tester.pumpAndSettle();
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry), findsNothing);
    final twoColumnExtent = _officialExtent(tester);
    await tester.tap(find.byTooltip('选择列数'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem<int> && widget.value == 4));
    await tester.pumpAndSettle();
    expect(tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller, same(controller));
    expect(_officialExtent(tester), greaterThan(twoColumnExtent));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(ValueKey('grid-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<SliverExampleMode>, 'ElSliverGrid.recycler'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElSliverGrid>(find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry))
          .crossAxisCount,
      4,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('示例目录能打开列表、网格和瀑布流并返回', (tester) async {
    _viewport(tester);
    await tester.pumpWidget(_app(ExamplesPage()));
    await tester.pumpAndSettle();

    for (final entry in [
      (key: 'sliver-recycler', title: 'SliverRecycler 滚动对照'),
      (key: 'sliver-recycler-grid', title: '网格示例'),
      (key: 'sliver-recycler-masonry', title: '瀑布流示例'),
    ]) {
      final tile = find.byKey(ValueKey('advanced-${entry.key}'));
      expect(tester.widget(tile), isA<ElListTile>());
      await Scrollable.ensureVisible(tester.element(tile), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text(entry.title), findsOneWidget);
      if (entry.key == 'sliver-recycler') {
        expect(find.byType(SliverList), findsOneWidget);
      } else {
        expect(find.byType(SliverGrid), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ExamplesPage), findsOneWidget);
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
      await _recycler(tester);
      final grid = find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry);
      final cards = find.descendant(of: grid, matching: find.byType(ExamplePanel));
      expect(tester.widget<ElSliverGrid>(grid).crossAxisCount, 2);
      final first = find.ancestor(of: find.text('观察记录 1'), matching: cards);
      final second = find.ancestor(of: find.text('观察记录 2'), matching: cards);
      expect(tester.getSize(second).height, greaterThan(tester.getSize(first).height));

      await tester.tap(find.byTooltip('选择列数'));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem<int> && widget.value == 3));
      await tester.pumpAndSettle();
      expect(tester.widget<ElSliverGrid>(grid).crossAxisCount, 3);
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
