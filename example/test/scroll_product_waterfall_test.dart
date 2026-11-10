import 'package:example/src/pages/examples/scroll_examples/product_waterfall.dart';
import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/src/widgets/panel.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 840);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: .android),
      home: ElComponentProvider(components: el.mobileComponents, child: RecyclerProductWaterfallPage()),
    ),
  );
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

void main() {
  testWidgets('真实回收瀑布流与 Flutter SliverGrid 在初始元数据下共享两列几何', (tester) async {
    await _open(tester);
    final list = tester.widget<ElSliverRecyclerGrid>(find.byType(ElSliverRecyclerGrid));
    expect(list.itemCount, 1000);
    final names = ['夜色观察 #0001', '夜色观察 #0002', '林间来客 #0003', '林间来客 #0004'];
    final expected = names.map((title) => tester.getRect(_card(title))).toList();
    expect(expected[0].top, expected[1].top);
    expect(expected[0].left, lessThan(expected[1].left));
    expect(expected[0].height, greaterThan(expected[1].height));
    expect(expected[2].left, expected[1].left, reason: '第三项跟随较短的右列');
    expect(expected[2].top, closeTo(expected[1].bottom + 10, .01));

    await _chooseFlutter(tester);
    expect(find.byType(ElSliverRecyclerGrid), findsNothing);
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
  }
}
