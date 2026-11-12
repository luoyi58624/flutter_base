import 'package:example/src/pages/examples/scroll_examples/cards.dart';
import 'package:example/src/pages/examples/scroll_examples/comparison_list.dart';
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
    final access = mode == 'recycler' ? '远跳只生成目标窗口' : '近跳和回访保留记录';
    testWidgets('$mode 首屏按需创建，类型查询不分配，$access', (tester) async {
      await _open(tester);
      await _choose(tester, 'mode-$mode');
      final listFinder = find.byType(SliverComparisonList);
      final list = tester.widget<SliverComparisonList>(listFinder);
      final frame = list.itemBuilder(tester.element(listFinder), 0) as RepaintBoundary;
      // 观察已有记录仓库，不给生产代码增加测试探针。
      final dynamic row = frame.child;
      final dynamic adapter = row.adapter;
      final Map records = adapter.records;
      expect(list.itemCount, 1000);
      expect(records.length, inInclusiveRange(1, 40));
      final firstRecord = records[0];
      final firstCount = records.length;
      expect(list.itemType!(998), 0);
      expect(list.itemType!(999), 1);
      expect(records.length, firstCount, reason: '判断复用类型不应创建离屏业务记录。');

      final targetIndex = mode == 'recycler' ? 400 : 10;
      adapter.refreshRange(targetIndex, targetIndex);
      final dynamic distantRecord = records[targetIndex];
      expect(distantRecord.visits, 1200 + targetIndex * 13 + 7 + targetIndex % 5);
      expect(distantRecord.revision, 1);
      expect(records.length, firstCount + 1);
      // 官方自然高度列表需要布局中间行，使用近跳验证数据，远跳工作量只约束回收容器。
      list.controller.jumpTo(targetIndex * 540.0);
      await tester.pumpAndSettle();
      final distantTitle = find.textContaining('观测 #${(targetIndex + 1).toString().padLeft(5, '0')}').hitTestable();
      expect(distantTitle, findsOneWidget);
      final distantCard = find.ancestor(of: distantTitle, matching: _key('cards-activate'));
      expect(_text(tester, distantCard, 'cards-visits'), '${distantRecord.visits}');
      expect(records[targetIndex], same(distantRecord));
      expect(records.length, lessThan(80));
      if (mode == 'recycler') expect(records.containsKey(200), isFalse);
      await _choose(tester, 'first');
      expect(records[0], same(firstRecord));
      list.controller.jumpTo(targetIndex * 540.0);
      await tester.pumpAndSettle();
      expect(records[targetIndex], same(distantRecord));
      expect(_text(tester, distantCard, 'cards-visits'), '${distantRecord.visits}');
      final countBeforeRemoteUpdate = records.length;
      adapter.refreshRange(900, 900);
      expect(records.length, countBeforeRemoteUpdate + 1);
      expect((records[900] as dynamic).revision, 1);
      expect(records.containsKey(800), isFalse, reason: '直接更新未访问记录不应生成到该编号之间的全部记录。');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
      expect(records, isEmpty);
    });

    testWidgets('$mode 卡片保留按压、统计叶子更新、滚动和跨模式选择状态', (tester) async {
      await _open(tester);
      await _choose(tester, 'mode-$mode');
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
        expect(find.textContaining('观测 #01000').hitTestable(), findsOneWidget);
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
    await _choose(tester, 'mode-recycler');
    await tester.tap(_card());
    await tester.pumpAndSettle();
    final originals = <Element, Widget>{
      for (final element in _key('cards-activate').evaluate())
        element: tester.widget(_within(find.byElementPredicate((e) => identical(e, element)), find.byType(Image))),
    };
    final controller = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    controller.jumpTo(800 * 540);
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
    expect(tester.widget<Text>(_key('cards-active-count')).data, '2 / 1000');
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(_card()).properties.selected, isTrue);
    controller.jumpTo(800 * 540);
    await tester.pumpAndSettle();
    expect(_text(tester, _card(), 'cards-title'), title);
    expect(tester.widget<Semantics>(_card()).properties.selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
