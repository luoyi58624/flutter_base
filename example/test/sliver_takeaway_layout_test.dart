import 'dart:io';
import 'dart:ui' as ui;

import 'package:example/src/pages/examples/sliver_takeaway/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

final _captureKey = GlobalKey();
// 编译期参数必须使用常量读取；只在显式导出截图时加载可读字体。
const _capturePath = String.fromEnvironment('TAKEAWAY_CAPTURE_PATH');

Future<void> _open(WidgetTester tester, {double width = 390, double scale = 1, bool dark = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            platform: .android,
            brightness: dark ? .dark : .light,
            fontFamily: _capturePath.isEmpty ? null : 'TakeawayPreview',
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ElView(
            style: ElStyle(fontFamily: _capturePath.isEmpty ? null : 'TakeawayPreview'),
            child: TakeawaySliverPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey('takeaway-sliver-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void _expectMenuGeometry(WidgetTester tester, double scale) {
  final cards = find.byKey(ValueKey('takeaway-dish-card')).evaluate().toList();
  expect(cards, isNotEmpty);
  final heights = <double>[];
  for (final element in cards) {
    final card = find.byElementPredicate((candidate) => identical(candidate, element));
    final rect = tester.getRect(card);
    heights.add(rect.height);
    expect(rect.width, closeTo(96, .01));
    final title = find.descendant(of: card, matching: find.byKey(ValueKey('takeaway-dish-name')));
    expect(tester.widget<ElView>(title).style!.maxLines, 1);
    expect(tester.widget<ElView>(title).style!.textOverflow, TextOverflow.ellipsis);
    expect(tester.widget<ElView>(title).style!.fontSize, 14);
    expect(tester.getSize(title).height, lessThanOrEqualTo(14 * scale * 1.4 + 2));
    final image = find.descendant(of: card, matching: find.byType(ElImage));
    expect(image, findsOneWidget);
    final viewport = find.ancestor(of: image, matching: find.byType(ClipRRect)).first;
    expect(tester.getSize(viewport), Size.square(96));
    final button = find.descendant(of: card, matching: find.byTooltip('加入购物车'));
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(rect.bottom + .01));
    expect(find.descendant(of: card, matching: find.byType(Image)), findsNothing);
  }
  expect(heights.every((height) => (height - heights.first).abs() < .01), isTrue);
  for (final title in tester.widgetList<ElView>(find.byKey(ValueKey('takeaway-title')))) {
    expect(title.style!.maxLines, 1);
  }
  expect(tester.takeException(), isNull);
}

Future<void> _capture(WidgetTester tester) async {
  if (_capturePath.isEmpty) return;
  await tester.runAsync(() async {
    for (final size in [Size(288, 216), Size(384, 288)]) {
      await ElImage.preload('assets/recycler_cards/takeaway-food.webp', size: size, devicePixelRatio: 1, fit: .fill);
    }
  });
  await tester.pumpAndSettle();
  final boundary = _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(_capturePath).writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    if (_capturePath.isEmpty) return;
    final font = File('C:/Windows/Fonts/msyh.ttc');
    if (!await font.exists()) return;
    final bytes = await font.readAsBytes();
    final loader = FontLoader('TakeawayPreview')..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
    final icons = File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
    if (await icons.exists()) {
      final bytes = await icons.readAsBytes();
      await (FontLoader('MaterialIcons')..addFont(Future.value(bytes.buffer.asByteData()))).load();
    }
  });
  for (final (width, scale, dark) in [(390.0, 1.0, false), (320.0, 1.6, false), (390.0, 1.6, true)]) {
    testWidgets('外卖普通布局 $width 宽 $scale 字号下商品单行等高且图片使用 ElImage', (tester) async {
      await _open(tester, width: width, scale: scale, dark: dark);
      _expectMenuGeometry(tester, scale);
      if (scale == 1) await _capture(tester);
      final controller = tester.widget<ElScroll>(find.byKey(ValueKey('takeaway-sliver'))).controller!;
      controller.jumpTo(20000);
      await tester.pumpAndSettle();
      _expectMenuGeometry(tester, scale);
      await tester.pumpWidget(SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('官方列表与网格共用普通卡片，大字下保留统一商品高度和控制器', (tester) async {
    await _open(tester, width: 320, scale: 1.6);
    final controller = tester.widget<ElScroll>(find.byKey(ValueKey('takeaway-sliver'))).controller!;
    await _choose(tester, 'takeaway-mode-official');
    expect(find.byType(SliverList), findsOneWidget);
    expect(find.byType(ElSliverRecyclerList), findsNothing);
    _expectMenuGeometry(tester, 1.6);
    await _choose(tester, 'takeaway-sliver-grid');
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(tester.widget<ElScroll>(find.byKey(ValueKey('takeaway-sliver'))).controller, same(controller));
    _expectMenuGeometry(tester, 1.6);
    await _choose(tester, 'takeaway-mode-recycler');
    expect(find.byType(ElSliverRecyclerGrid), findsOneWidget);
    _expectMenuGeometry(tester, 1.6);
    await tester.tap(find.byKey(ValueKey('takeaway-sliver-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('takeaway-render-card-mode')), findsNothing);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('普通商品加购支持触摸与辅助操作，读取当前价格', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _open(tester);
      final button = find.byTooltip('加入购物车').hitTestable().first;
      final card = find.ancestor(of: button, matching: find.byKey(ValueKey('takeaway-dish-card')));
      final price =
          tester.widget<ElView>(find.descendant(of: card, matching: find.byKey(ValueKey('takeaway-dish-price')))).child!
              as String;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-count'))).child, '已选 1 份');
      expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-total'))).child, price);
      final node = tester.getSemantics(button);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-count'))).child, '已选 2 份');
      final doubled = (double.parse(price.substring(1)) * 2).toStringAsFixed(1);
      expect(tester.widget<ElView>(find.byKey(ValueKey('takeaway-cart-total'))).child, '¥$doubled');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });
}
