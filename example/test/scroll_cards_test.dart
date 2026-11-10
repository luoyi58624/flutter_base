import 'package:example/src/pages/examples/scroll_examples/cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/src/widgets/panel.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _card() => _key('cards-activate').hitTestable().first;
Finder _within(Finder root, Finder child) => find.descendant(of: root, matching: child);
String _text(WidgetTester tester, Finder root, String key) => tester.widget<Text>(_within(root, _key(key))).data!;

Future<void> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(home: RecyclerCardsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String action) async {
  await tester.tap(_key('cards-menu'));
  await tester.pumpAndSettle();
  await tester.tap(_key('cards-$action'));
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in ['recycler', 'official']) {
    testWidgets('$mode 卡片保留按压、统计叶子更新、滚动和跨模式选择状态', (tester) async {
      await _open(tester);
      if (mode == 'official') await _choose(tester, 'mode-official');
      final first = _card();
      final title = _text(tester, first, 'cards-title');
      final visits = _text(tester, first, 'cards-visits');
      final imageFinder = _within(first, find.byType(Image));
      final image = tester.widget(imageFinder);
      final imageElement = tester.element(imageFinder);
      final card = _within(first, find.byType(ExamplePanel)).first;
      final render = tester.renderObject<ElRenderView>(card);
      final gesture = await tester.startGesture(tester.getCenter(first));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 120));
      expect(render.committedResolvedStyle.box.transform, ElTransform.scale(.98));
      expect(tester.widget<Semantics>(first).properties.selected, isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(first).properties.selected, isTrue);
      await _choose(tester, 'refresh-visible');
      expect(_text(tester, first, 'cards-title'), title);
      expect(_text(tester, first, 'cards-visits'), isNot(visits));
      expect(tester.element(imageFinder), same(imageElement));
      expect(tester.widget(imageFinder), same(image));
      if (mode == 'recycler') {
        await _choose(tester, 'last');
        expect(find.textContaining('观测 #10000').hitTestable(), findsOneWidget);
      } else {
        final controller = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
        controller.jumpTo(5400);
        await tester.pumpAndSettle();
        expect(find.textContaining('观测 #00011').hitTestable(), findsOneWidget);
      }
      await _choose(tester, 'first');
      expect(tester.widget<Semantics>(_card()).properties.selected, isTrue);
      await _choose(tester, mode == 'recycler' ? 'mode-official' : 'mode-recycler');
      expect(tester.widget<Semantics>(_card()).properties.selected, isTrue);
      expect(_text(tester, _card(), 'cards-visits'), isNot(visits));
      await _choose(tester, 'clear');
      expect(tester.widget<Semantics>(_card()).properties.selected, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('卡片换绑保留固定图片与结构，点击读取新记录且旧记录选择不丢失', (tester) async {
    await _open(tester);
    await tester.tap(_card());
    await tester.pumpAndSettle();
    final originals = <Element, Widget>{
      for (final element in _key('cards-activate').evaluate())
        element: tester.widget(_within(find.byElementPredicate((e) => identical(e, element)), find.byType(Image))),
    };
    final controller = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    controller.jumpTo(8000 * 540);
    await tester.pumpAndSettle();
    final reused = _key('cards-activate').evaluate().where(originals.containsKey).toList();
    expect(reused, isNotEmpty);
    for (final element in reused) {
      final root = find.byElementPredicate((e) => identical(e, element));
      expect(tester.widget(_within(root, find.byType(Image))), same(originals[element]));
      expect((element.widget as Semantics).properties.selected, isFalse);
    }
    final title = _text(tester, _card(), 'cards-title');
    await tester.tap(_card());
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(_key('cards-active-count')).data, '2 / 10000');
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(_card()).properties.selected, isTrue);
    controller.jumpTo(8000 * 540);
    await tester.pumpAndSettle();
    expect(_text(tester, _card(), 'cards-title'), title);
    expect(tester.widget<Semantics>(_card()).properties.selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
