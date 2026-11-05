import 'dart:convert';

import 'package:example/src/pages/examples/recycler_view/cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('复杂卡片按下缩放且不提前激活，松开恢复并只激活当前记录', (tester) async {
    await _open(tester, RecyclerCardsPage());
    final holder = _list(tester).findViewHolderForItemId(0)!;
    final card = _inside(holder, find.byType(ElCardView));
    final render = tester.renderObject<ElRenderView>(card);
    expect(render.committedResolvedStyle.box.transform, isNull);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 120));
    expect(render.committedResolvedStyle.box.transform, ElTransform.scale(.98));
    expect(_selected(holder), isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.transform, isNull);
    expect(_selected(holder), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['recyclerView', 'listView']) {
    testWidgets('复杂卡片 $mode 支持离线图文、数据刷新及激活状态跨容器保留', (tester) async {
      await _open(tester, RecyclerCardsPage());
      if (mode == 'listView') await _choose(tester, 'mode-listView');
      final first = find.byKey(ValueKey('cards-activate')).hitTestable().first;
      expect(tester.widget<Semantics>(first).properties.selected, isFalse);
      expect(find.descendant(of: first, matching: find.byType(Image)), findsOneWidget);
      expect(find.descendant(of: first, matching: find.byType(Icon)).evaluate().length, greaterThan(6));
      final title = _textInside(tester, first, 'cards-title');
      final visits = _textInside(tester, first, 'cards-visits');
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(first).properties.selected, isTrue);
      expect(tester.widget<Text>(find.byKey(ValueKey('cards-active-count'))).data, '1 / 10000');
      await _choose(tester, 'refresh-visible');
      expect(_textInside(tester, first, 'cards-title'), title);
      expect(_textInside(tester, first, 'cards-visits'), isNot(visits));
      await _choose(tester, 'last');
      expect(find.textContaining('观测 #10000').hitTestable(), findsOneWidget);
      await _choose(tester, 'first');
      expect(tester.widget<Semantics>(first).properties.selected, isTrue);
      await _choose(tester, mode == 'listView' ? 'mode-recyclerView' : 'mode-listView');
      expect(tester.widget<Semantics>(first).properties.selected, isTrue);
      expect(_textInside(tester, first, 'cards-title'), title);
      expect(_textInside(tester, first, 'cards-visits'), isNot(visits));
      await _choose(tester, 'clear');
      expect(tester.widget<Semantics>(first).properties.selected, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('真实复杂卡片跨业务记录复用且激活回调指向新记录，返回后保持旧记录状态', (tester) async {
    await _open(tester, RecyclerCardsPage());
    final list = _list(tester)..setItemViewCacheSize(0);
    final layout = list.getLayoutManager()! as rv.LinearLayoutManager;
    layout.setItemPrefetchEnabled(false);
    for (final type in [0, 1]) {
      list.getRecycledViewPool().setMaxRecycledViews(type, 20);
    }
    await tester.pumpAndSettle();
    expect(list.getAdapter()!.getItemCount(), 10000);
    expect(layout.getChildCount(), lessThan(6));
    final originals = {for (final holder in _visible(list)) holder: _CardTree.capture(holder)};
    final originalIds = {for (final holder in originals.keys) holder: holder.getItemId()};
    final first = list.findViewHolderForItemId(0)!;
    await tester.tap(_inside(first, find.byKey(ValueKey('cards-activate'))));
    await tester.pumpAndSettle();
    expect(_selected(first), isTrue);
    list.scrollToPosition(8000);
    await tester.pump();
    await tester.pump();
    final shared = originals.keys.toSet().intersection(_visible(list));
    expect(shared, isNotEmpty, reason: '必须实际让同一holder换绑独立业务记录');
    for (final holder in shared) {
      expect(holder.getItemId(), isNot(originalIds[holder]));
      expect(_selected(holder), isFalse);
      _CardTree.capture(holder).expectSameFixedTree(originals[holder]!);
    }
    final rebound = shared.first;
    final reboundId = rebound.getItemId();
    await tester.tap(_inside(rebound, find.byKey(ValueKey('cards-activate'))));
    await tester.pumpAndSettle();
    expect(_selected(rebound), isTrue);
    expect(tester.widget<Text>(find.byKey(ValueKey('cards-active-count'))).data, '2 / 10000');
    list.scrollToPosition(0);
    await tester.pumpAndSettle();
    expect(_selected(list.findViewHolderForItemId(0)!), isTrue);
    expect(_selected(list.findViewHolderForItemId(1)!), isFalse);
    list.scrollToPosition(reboundId);
    await tester.pumpAndSettle();
    expect(_selected(list.findViewHolderForItemId(reboundId)!), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('复杂卡片在窄屏暗色及放大文字下保持可阅读，主题变化不丢失激活状态', (tester) async {
    final page = RecyclerCardsPage();
    await _open(tester, page);
    final list = _list(tester);
    await tester.tap(_inside(list.findViewHolderForItemId(0)!, find.byKey(ValueKey('cards-activate'))));
    await tester.pumpAndSettle();
    for (final (width, scale) in [(320.0, 1.4), (900.0, 1.4), (320.0, 2.0)]) {
      await _open(tester, page, width: width, brightness: Brightness.dark, textScale: scale);
      final first = list.findViewHolderForItemId(0)!;
      expect(_selected(first), isTrue);
      expect(Theme.of(tester.element(_inside(first, find.byType(Image)))).brightness, Brightness.dark);
      expect(_text(tester, first, 'cards-title'), contains('观测 #00001'));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('反复切换容器会释放已卸载卡片模型，当前可见卡片仍能局部刷新', (tester) async {
    await _open(tester, RecyclerCardsPage());
    for (final mode in ['listView', 'recyclerView', 'listView']) {
      final visits = find.byKey(ValueKey('cards-visits')).hitTestable().first;
      final builder = tester.widget<ValueListenableBuilder<int>>(
        find.ancestor(of: visits, matching: find.byType(ValueListenableBuilder<int>)).first,
      );
      final previous = builder.valueListenable;
      await _choose(tester, 'mode-$mode');
      // 已卸载页面不能在适配器集合中持续持有旧模型，否则切换越多内存越大。
      expect(() => previous.addListener(() {}), throwsFlutterError);
      final before = tester.widget<Text>(find.byKey(ValueKey('cards-visits')).hitTestable().first).data;
      await _choose(tester, 'refresh-visible');
      expect(tester.widget<Text>(find.byKey(ValueKey('cards-visits')).hitTestable().first).data, isNot(before));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('复杂卡片数据刷新与激活仅构建动态叶子，固定图片图标和排版保持不变', (tester) async {
    await _open(tester, RecyclerCardsPage());
    final list = _list(tester);
    final holder = list.findViewHolderForItemId(0)!;
    await _loadImages(tester, holder);
    final before = _CardTree.capture(holder);
    final title = _text(tester, holder, 'cards-title');
    final visits = _text(tester, holder, 'cards-visits');
    final updated = _text(tester, holder, 'cards-updated');
    final visitsElement = _inside(holder, find.byKey(ValueKey('cards-visits'))).evaluate().single;

    await tester.tap(find.byKey(ValueKey('cards-menu')));
    await tester.pumpAndSettle();
    final refreshBuilds = _BuildCapture(_elements(holder));
    try {
      await tester.tap(find.byKey(ValueKey('cards-refresh-visible')));
      await tester.pumpAndSettle();
    } finally {
      refreshBuilds.dispose();
    }
    expect(_text(tester, holder, 'cards-title'), title);
    expect(_text(tester, holder, 'cards-visits'), isNot(visits));
    expect(_text(tester, holder, 'cards-updated'), isNot(updated));
    _CardTree.capture(holder).expectSameFixedTree(before);
    expect(refreshBuilds.count(visitsElement), greaterThan(0), reason: '必须确认真实动态文本确实参与构建');
    expect(refreshBuilds.countAll(before.fixedWidgets.keys), 0, reason: '静态图片、图标和布局不应因统计更新重新构建');

    final activateBuilds = _BuildCapture(_elements(holder));
    try {
      await tester.tap(_inside(holder, find.byKey(ValueKey('cards-activate'))));
      await tester.pumpAndSettle();
    } finally {
      activateBuilds.dispose();
    }
    expect(_selected(holder), isTrue);
    _CardTree.capture(holder).expectSameFixedTree(before);
    expect(activateBuilds.countAll(before.fixedWidgets.keys), 0, reason: '选中外观变化不能重新构建固定内容');
    expect(_text(tester, holder, 'cards-visits'), isNot(visits));
    expect(tester.takeException(), isNull);
    debugPrint(
      'RECYCLER_CARD_LEAF_BUILDS ${jsonEncode({'refresh_static_builds': refreshBuilds.countAll(before.fixedWidgets.keys), 'refresh_visits_builds': refreshBuilds.count(visitsElement), 'selection_static_builds': activateBuilds.countAll(before.fixedWidgets.keys), 'static_elements_observed': before.fixedWidgets.length})}',
    );
  });

  for (final type in [0, 1]) {
    testWidgets('真实复杂卡片类型 $type 连续绑定 32 条独立记录，保留图片和固定渲染结构', (tester) async {
      final content = ValueNotifier<Widget>(SizedBox.shrink());
      await _open(
        tester,
        Scaffold(
          body: Stack(
            children: [
              Offstage(child: RecyclerCardsPage()),
              Align(
                alignment: .topLeft,
                child: ValueListenableBuilder<Widget>(valueListenable: content, builder: (context, child, _) => child),
              ),
            ],
          ),
        ),
      );
      final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView, skipOffstage: false));
      final adapter = list.getAdapter()!;
      final positions = [
        for (var position = 0; position < adapter.getItemCount(); position++)
          if (adapter.getItemViewType(position) == type) position,
      ].take(33).toList();
      expect(positions, hasLength(33));
      final holder = adapter.createViewHolder(list, type);
      adapter.bindViewHolder(holder, positions.first);
      content.value = RepaintBoundary(child: SizedBox(width: 360, child: holder.itemView));
      await tester.pumpAndSettle();
      await _loadImages(tester, holder);
      final before = _CardTree.capture(holder);
      final firstTitle = _text(tester, holder, 'cards-title');
      var previous = _elements(holder);
      var added = 0;
      var removed = 0;
      final timings = <int>[];
      final ids = <int>{holder.getItemId()};
      final builds = _BuildCapture(previous);
      try {
        for (final position in positions.skip(1)) {
          final clock = Stopwatch()..start();
          adapter.bindViewHolder(holder, position);
          await tester.pump(Duration(milliseconds: 8));
          clock.stop();
          timings.add(clock.elapsedMicroseconds);
          ids.add(holder.getItemId());
          final current = _elements(holder);
          added += current.difference(previous).length;
          removed += previous.difference(current).length;
          previous = current;
          _CardTree.capture(holder).expectSameFixedTree(before);
        }
      } finally {
        builds.dispose();
      }
      expect(ids, hasLength(33), reason: '不能把相同数据重复绑定伪装成换行复用');
      expect(_text(tester, holder, 'cards-title'), isNot(firstTitle));
      expect(holder.getItemId(), adapter.getItemId(positions.last));
      expect(added, 0);
      expect(removed, 0);
      expect(builds.countAll(before.fixedWidgets.keys), 0);
      expect(tester.takeException(), isNull);
      final sorted = [...timings]..sort();
      double percentile(double q) => sorted[((sorted.length - 1) * q).floor()] / 1000;
      debugPrint(
        'RECYCLER_CARD_BIND_PERF ${jsonEncode({'view_type': type, 'binds': timings.length, 'different_data_ids': ids.length, 'initial_elements': before.elements.length, 'added_elements': added, 'removed_elements': removed, 'static_builds': builds.countAll(before.fixedWidgets.keys), 'pump_p50_ms': percentile(.5), 'pump_p95_ms': percentile(.95), 'pump_max_ms': percentile(1), 'environment': 'flutter_test/debug; host pump wall time, not device FrameTiming/FPS'})}',
      );
      await tester.pumpWidget(SizedBox());
      content.dispose();
    });
  }
}

Future<void> _open(
  WidgetTester tester,
  Widget page, {
  double width = 390,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

rv.RecyclerView _list(WidgetTester tester) => tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));

Future<void> _choose(WidgetTester tester, String action) async {
  await tester.tap(find.byKey(ValueKey('cards-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('cards-$action')));
  await tester.pumpAndSettle();
}

Set<rv.ViewHolder> _visible(rv.RecyclerView list) {
  final layout = list.getLayoutManager()! as rv.LinearLayoutManager;
  return {
    for (var index = layout.findFirstVisibleItemPosition(); index <= layout.findLastVisibleItemPosition(); index++)
      ?list.findViewHolderForAdapterPosition(index),
  };
}

Finder _inside(rv.ViewHolder holder, Finder matching) =>
    find.descendant(of: find.byWidget(holder.itemView, skipOffstage: false), matching: matching, matchRoot: true);

String _text(WidgetTester tester, rv.ViewHolder holder, String key) =>
    tester.widget<Text>(_inside(holder, find.byKey(ValueKey(key)))).data!;

String _textInside(WidgetTester tester, Finder root, String key) =>
    tester.widget<Text>(find.descendant(of: root, matching: find.byKey(ValueKey(key)))).data!;

bool _selected(rv.ViewHolder holder) => _inside(holder, find.byType(Semantics))
    .evaluate()
    .map((element) => (element.widget as Semantics).properties.selected)
    .firstWhere((selected) => selected != null)!;

Set<Element> _elements(rv.ViewHolder holder) {
  final result = <Element>{};
  void visit(Element element) {
    result.add(element);
    element.visitChildren(visit);
  }

  visit(find.byWidget(holder.itemView, skipOffstage: false).evaluate().single);
  return result;
}

Future<void> _loadImages(WidgetTester tester, rv.ViewHolder holder) async {
  final images = _inside(holder, find.byType(Image)).evaluate().toList();
  await tester.runAsync(() async {
    await Future.wait([for (final element in images) precacheImage((element.widget as Image).image, element)]);
  });
  await tester.pumpAndSettle();
}

class _CardTree {
  _CardTree(this.elements, this.fixedWidgets, this.fixedRenderObjects);

  factory _CardTree.capture(rv.ViewHolder holder) {
    final elements = _elements(holder);
    final fixed = <Element, Widget>{
      for (final element in elements)
        if (element.widget is Image ||
            (element.widget is Icon &&
                (element.widget as Icon).icon != Icons.add_circle_outline_rounded &&
                (element.widget as Icon).icon != Icons.check_circle_rounded) ||
            element.widget is Row ||
            element.widget is Column ||
            element.widget is Wrap ||
            (element.widget is Text && _staticLabels.contains((element.widget as Text).data)))
          element: element.widget,
    };
    return _CardTree(elements, fixed, {for (final element in fixed.keys) element: element.renderObject});
  }

  final Set<Element> elements;
  final Map<Element, Widget> fixedWidgets;
  final Map<Element, RenderObject?> fixedRenderObjects;

  void expectSameFixedTree(_CardTree previous) {
    expect(fixedWidgets.keys.toSet(), previous.fixedWidgets.keys.toSet());
    for (final entry in previous.fixedWidgets.entries) {
      expect(fixedWidgets[entry.key], same(entry.value), reason: '固定图片、图标与排版描述应保留原实例');
      expect(fixedRenderObjects[entry.key], same(previous.fixedRenderObjects[entry.key]));
    }
  }
}

final _staticLabels = {'FIELD NOTES', '林间夜行者', '枝头守望者', '4.9', '鸟类调查', '栖息地记录', '离线可用', '观察次数', '记录完整度', '样区海拔'};

class _BuildCapture {
  _BuildCapture(this.initialElements) : previous = debugOnRebuildDirtyWidget {
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      // 先前已经挂载的 Element 才计入，避免依赖调试打印开关影响的 builtOnce 标记。
      if (initialElements.contains(element)) counts.update(element, (count) => count + 1, ifAbsent: () => 1);
    };
  }

  final Set<Element> initialElements;
  final RebuildDirtyWidgetCallback? previous;
  final counts = <Element, int>{};

  int count(Element element) => counts[element] ?? 0;
  int countAll(Iterable<Element> elements) => elements.fold(0, (sum, element) => sum + count(element));
  void dispose() => debugOnRebuildDirtyWidget = previous;
}
