import 'dart:async';

import 'package:example/src/pages/examples/sliver_takeaway/takeaway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show MatrixUtils, RenderParagraph;
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  bool dark = false,
  bool network = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        theme: ThemeData(platform: .android, brightness: dark ? .dark : .light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: TakeawaySliverPage(networkPhotos: network),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String key) async {
  await _tap(tester, 'takeaway-sliver-menu');
  await _tap(tester, key);
}

Future<void> _warmAtlas(WidgetTester tester) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(TakeawaySliverPage));
    final stream = AssetImage('assets/recycler_cards/takeaway-food.webp')
        .resolve(createLocalImageConfiguration(context));
    final ready = Completer<void>();
    final listener = ImageStreamListener((info, _) {
      info.dispose();
      ready.complete();
    }, onError: (error, stack) => ready.completeError(error, stack));
    stream.addListener(listener);
    try {
      await ready.future;
    } finally {
      stream.removeListener(listener);
    }
  });
  await tester.pumpAndSettle();
}

Finder _cards({bool skipOffstage = true}) => find.byKey(ValueKey('takeaway-render-card'), skipOffstage: skipOffstage);

ScrollController _list(WidgetTester tester) =>
    (tester.widget(find.byKey(ValueKey('takeaway-sliver'))) as CustomScrollView).controller!;

SemanticsNode _node(WidgetTester tester, String identifier) {
  final root = tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!;
  SemanticsNode? found;
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().identifier == identifier) found = node;
    node.visitChildren((child) {
      if (found == null) visit(child);
      return found == null;
    });
  }

  visit(root);
  expect(found, isNotNull, reason: '缺少 $identifier 的可访问性节点');
  return found!;
}

Rect _globalRect(SemanticsNode node) {
  var rect = node.rect;
  for (SemanticsNode? ancestor = node; ancestor != null; ancestor = ancestor.parent) {
    if (ancestor.transform case final transform?) rect = MatrixUtils.transformRect(transform, rect);
  }
  return rect;
}

double _menuOffset(WidgetTester tester, int id) =>
    _node(tester, 'takeaway-menu-$id').getSemanticsData().scrollPosition!;

String _cartText(WidgetTester tester, String key) => tester.widget<ElView>(find.byKey(ValueKey(key))).child! as String;

void main() {
  testWidgets('官方列表与网格在大字下保留外卖内容，切换实现共用控制器', (tester) async {
    await _open(tester, scale: 1.6);
    final controller = _list(tester);
    await _choose(tester, 'takeaway-mode-official');
    expect(find.byType(SliverList), findsOneWidget);
    expect(find.byType(ElSliverRecyclerList), findsNothing);
    await _choose(tester, 'takeaway-sliver-grid');
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(_list(tester), same(controller));
    expect(find.byKey(ValueKey('takeaway-title')), findsWidgets);
    expect(tester.takeException(), isNull);
    await _choose(tester, 'takeaway-mode-recycler');
    expect(find.byType(ElSliverRecyclerGrid), findsOneWidget);
    expect(_list(tester), same(controller));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('纯绘制卡片切换两种模式并在窄屏大字下绘制图集，不挂载卡片子元素', (tester) async {
    await _open(tester, width: 320, scale: 1.6, dark: true, network: true);
    expect(_cards(), findsNothing);
    await _choose(tester, 'takeaway-render-card-mode');
    await _warmAtlas(tester);
    await _tap(tester, 'takeaway-sliver-menu');
    final network = tester.widget<PopupMenuItem<Object>>(find.byKey(ValueKey('takeaway-network-photos')));
    expect(network.enabled, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    for (final mode in ['recycler', 'official']) {
      if (mode != 'recycler') await _choose(tester, 'takeaway-mode-$mode');
      expect(tester.widget(find.byKey(ValueKey('takeaway-sliver'))), isA<CustomScrollView>());
      expect(_cards(), findsWidgets);
      expect(_cards().evaluate().length, lessThan(12));
      for (final card in _cards().evaluate()) {
        expect(card.widget, isA<LeafRenderObjectWidget>());
        final children = <Element>[];
        card.visitChildren(children.add);
        expect(children, isEmpty);
      }
      final firstStore = _node(tester, 'takeaway-store-0');
      expect(firstStore.getSemanticsData().label, contains('1店'));
      expect(_cards().first, paints..drawImageRect());
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('纯绘制加购支持触摸和辅助操作，Sliver 换绑后按店保存菜单位置', (tester) async {
    await _open(tester);
    final widgetMenu = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.identifier == 'takeaway-menu-0'),
      matching: find.byType(ListView),
    );
    final price = tester
        .renderObject<RenderParagraph>(
          find.descendant(of: widgetMenu, matching: find.byKey(ValueKey('takeaway-dish-price'))).first,
        )
        .text
        .toPlainText();
    await _choose(tester, 'takeaway-render-card-mode');
    final list = _list(tester);
    await tester.pumpAndSettle();

    final button = _node(tester, 'takeaway-add-0-0');
    expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await tester.tapAt(_globalRect(button).center);
    await tester.pumpAndSettle();
    expect(_cartText(tester, 'takeaway-cart-count'), '已选 1 份');
    expect(_cartText(tester, 'takeaway-cart-total'), price);
    await _tap(tester, 'takeaway-cart-clear');
    final accessibleButton = _node(tester, 'takeaway-add-0-0');
    accessibleButton.owner!.performAction(accessibleButton.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(_cartText(tester, 'takeaway-cart-count'), '已选 1 份');
    expect(_cartText(tester, 'takeaway-cart-total'), price);

    final vertical = list.offset;
    final menuRect = _globalRect(_node(tester, 'takeaway-menu-0'));
    await tester.timedDragFrom(menuRect.center, Offset(-170, 0), Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final saved = _menuOffset(tester, 0);
    expect(saved, greaterThan(40));
    expect(list.offset, closeTo(vertical, .1));
    await tester.timedDragFrom(menuRect.center, Offset(0, -145), Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(list.offset, greaterThan(vertical + 40));
    list.jumpTo(0);
    await tester.pumpAndSettle();
    expect(_menuOffset(tester, 0), closeTo(saved, .1));

    final before = _cards().evaluate().toSet();
    list.jumpTo(5000 * 400);
    await tester.pumpAndSettle();
    expect(_cards().evaluate().toSet().intersection(before), isNotEmpty);
    list.jumpTo(0);
    await tester.pumpAndSettle();
    expect(_menuOffset(tester, 0), closeTo(saved, .1));

    await _choose(tester, 'takeaway-render-card-mode');
    expect(_cards(), findsNothing);
    expect(tester.widget<ListView>(widgetMenu).controller!.offset, closeTo(saved, .1));
    await _choose(tester, 'takeaway-render-card-mode');
    expect(_menuOffset(tester, 0), closeTo(saved, .1));
    expect(_cartText(tester, 'takeaway-cart-count'), '已选 1 份');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
