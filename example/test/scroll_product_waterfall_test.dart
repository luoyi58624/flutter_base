import 'package:example/src/pages/examples/scroll_examples/product_waterfall.dart';
import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/src/widgets/panel.dart';

Widget _app({ThemeData? theme, double textScale = 1}) => MaterialApp(
  theme: theme ?? ThemeData(platform: .android),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: ElComponentProvider(components: el.mobileComponents, child: RecyclerProductWaterfallPage()),
);

Future<void> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 840);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('product-waterfall-mode')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('product-waterfall-mode-recycler')));
  await tester.pumpAndSettle();
}

Future<void> _chooseFlutter(WidgetTester tester) async {
  await tester.tap(find.byKey(ValueKey('product-waterfall-mode')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('product-waterfall-mode-sliverGrid')));
  await tester.pumpAndSettle();
}

Finder _card(String title) => find.ancestor(of: find.text(title), matching: find.byType(ExamplePanel));

ScrollPosition _position(WidgetTester tester) =>
    tester.widget<CupertinoScrollbar>(find.byType(CupertinoScrollbar)).controller!.position;

Future<void> _dragThumb(WidgetTester tester) async {
  final rect = tester.getRect(find.byType(CupertinoScrollbar));
  final gesture = await tester.startGesture(Offset(rect.right - 4.5, rect.top + 21));
  await tester.pump(Duration(milliseconds: 130));
  await gesture.moveBy(Offset(0, 120));
  await tester.pump(Duration(milliseconds: 16));
  await gesture.up();
  await tester.pump(Duration(milliseconds: 16));
}

Finder _tile(Element element) =>
    find.byElementPredicate((candidate) => identical(candidate, element), skipOffstage: false);

Finder _within(Element element, Finder matching) =>
    find.descendant(of: _tile(element), matching: matching, skipOffstage: false);

typedef _TileSnapshot = ({
  String title,
  Element panel,
  Widget panelWidget,
  RenderObject render,
  Image image,
  Text caption,
});

_TileSnapshot _snapshot(WidgetTester tester, Element element) {
  final texts = tester.widgetList<Text>(_within(element, find.byType(Text, skipOffstage: false))).toList();
  final panel = tester.element(_within(element, find.byType(ExamplePanel, skipOffstage: false)));
  return (
    title: texts.singleWhere((text) => RegExp(r' #\d{4}$').hasMatch(text.data ?? '')).data!,
    panel: panel,
    panelWidget: panel.widget,
    render: panel.findRenderObject()!,
    image: tester.widget<Image>(_within(element, find.byType(Image, skipOffstage: false))),
    caption: texts.singleWhere((text) => text.data == '自然影像 · 无酸艺术纸'),
  );
}

void main() {
  testWidgets('真实回收瀑布流与 Flutter SliverGrid 在初始元数据下共享两列几何', (tester) async {
    await _open(tester);
    final list = tester.widget<ElSliverMasonry>(
      find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry),
    );
    expect(list.itemCount, 1000);
    final names = ['夜色观察 #0001', '夜色观察 #0002', '林间来客 #0003', '林间来客 #0004'];
    final expected = names.map((title) => tester.getRect(_card(title))).toList();
    expect(expected[0].top, expected[1].top);
    expect(expected[0].left, lessThan(expected[1].left));
    expect(expected[0].height, greaterThan(expected[1].height));
    expect(expected[2].left, expected[1].left, reason: '第三项跟随较短的右列');
    expect(expected[2].top, closeTo(expected[1].bottom + 10, .01));

    await _chooseFlutter(tester);
    expect(find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry), findsNothing);
    expect(find.byType(SliverGrid), findsOneWidget);
    for (final (index, title) in names.indexed) {
      final actual = tester.getRect(_card(title));
      final baseline = expected[index];
      expect(actual.top, closeTo(baseline.top, .01));
      expect(actual.left, closeTo(baseline.left, .01));
      expect(actual.size, baseline.size);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('商品换绑保留卡片结构与同图配置，点击打开当前商品', (tester) async {
    await _open(tester);
    var rebound = 0;
    var sameImage = 0;
    final reboundTitles = <Element, String>{};
    String? opened;
    for (var step = 0; step < 12 && (sameImage == 0 || opened == null); step++) {
      final before = <Element, _TileSnapshot>{
        for (final element
            in find
                .byWidgetPredicate((widget) => widget.runtimeType.toString() == '_ProductTile', skipOffstage: false)
                .evaluate())
          element: _snapshot(tester, element),
      };
      _position(tester).jumpTo(_position(tester).pixels + 240);
      await tester.pumpAndSettle();
      for (final entry in before.entries) {
        if (!entry.key.mounted) continue;
        final previous = entry.value;
        final current = _snapshot(tester, entry.key);
        if (current.title == previous.title) continue;
        rebound++;
        expect(current.panel, same(previous.panel));
        expect(current.panelWidget, same(previous.panelWidget));
        expect(current.render, same(previous.render));
        expect(current.caption, same(previous.caption));
        reboundTitles.remove(entry.key);
        if (current.image.image == previous.image.image) {
          sameImage++;
          expect(current.image, same(previous.image));
          reboundTitles[entry.key] = current.title;
        }
      }
      // 新记录先在缓存区换绑，随后进入视口时再验证这个槽位的点击目标。
      for (final entry in reboundTitles.entries) {
        if (!entry.key.mounted || _snapshot(tester, entry.key).title != entry.value) continue;
        if (find.text(entry.value).hitTestable().evaluate().isNotEmpty) opened = entry.value;
      }
    }
    expect(rebound, greaterThan(0));
    expect(sameImage, greaterThan(0));
    expect(opened, isNotNull);
    final name = opened!;
    await tester.tap(find.text(name).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('product-waterfall-details')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(ValueKey('product-waterfall-details')), matching: find.text(name)),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });

  for (final flutter in [false, true]) {
    final mode = flutter ? 'Flutter SliverGrid' : 'RecyclerView';

    testWidgets('$mode 在 450ms 后揭晓本地图片实际比例', (tester) async {
      await _open(tester);
      if (flutter) await _chooseFlutter(tester);
      final first = _card('夜色观察 #0001');
      final image = find.descendant(of: first, matching: find.byType(Image));
      final initial = tester.getSize(image);
      expect(initial.width / initial.height, closeTo(4 / 3, .01));

      await tester.tap(find.byKey(ValueKey('product-waterfall-reveal')));
      await tester.pump(Duration(milliseconds: 449));
      expect(tester.getSize(image), initial);
      await tester.pump(Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('已揭晓 12 张'), findsOneWidget);
      expect(tester.getSize(image).height, closeTo(initial.width, .01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode 滑块远拖、更新较早图片尺寸和详情返回都保住当前卡片', (tester) async {
      await _open(tester);
      if (flutter) await _chooseFlutter(tester);
      await tester.tap(find.byKey(ValueKey('product-waterfall-reveal')));
      await tester.pump();
      await _dragThumb(tester);
      expect(_position(tester).pixels, greaterThan(1000));
      final titles = find.textContaining(RegExp(r' #\d{4}$')).hitTestable();
      final name = tester.widget<Text>(titles.first).data!;
      final title = find.text(name).hitTestable();
      final before = tester.getTopLeft(title).dy;
      await tester.pump(Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('已揭晓 12 张'), findsOneWidget);
      expect(tester.getTopLeft(title).dy, closeTo(before, 1));

      final offset = _position(tester).pixels;
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('product-waterfall-details')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, closeTo(offset, .01));
      expect(tester.getTopLeft(title).dy, closeTo(before, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode 固定卡片仍响应主题、字号、宽度和像素比', (tester) async {
      await _open(tester);
      if (flutter) await _chooseFlutter(tester);
      final first = _card('夜色观察 #0001');
      final beforeElement = tester.element(first);
      final initial = tester.getSize(first);
      final image = find.descendant(of: first, matching: find.byType(Image));
      final imageHeight = tester.getSize(image).height;
      final dark = ThemeData.dark();
      final theme = dark.copyWith(
        platform: .android,
        colorScheme: dark.colorScheme.copyWith(primary: Colors.amber),
        textTheme: dark.textTheme.copyWith(labelSmall: TextStyle(fontSize: 17)),
      );
      await tester.pumpWidget(_app(theme: theme, textScale: 1.5));
      await tester.pumpAndSettle();
      expect(tester.element(first), same(beforeElement));
      expect(tester.getSize(first).height, greaterThan(initial.height));
      expect(tester.getSize(image).height, closeTo(imageHeight, .01));
      final price = tester.widget<Text>(find.descendant(of: first, matching: find.text('¥29')));
      expect(price.style!.color, Colors.amber);
      final caption = tester.widget<Text>(find.descendant(of: first, matching: find.text('自然影像 · 无酸艺术纸')));
      expect(caption.style!.fontSize, 17);

      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = Size(960, 1680);
      await tester.pumpAndSettle();
      expect(tester.element(first), same(beforeElement));
      expect(tester.getSize(first).width, greaterThan(initial.width));
      final updatedImage = tester.widget<Image>(image);
      expect((updatedImage.image as ResizeImage).width, 480);
      expect(tester.getSize(image).width / tester.getSize(image).height, closeTo(4 / 3, .01));
      expect(tester.takeException(), isNull);
    });
  }
}
