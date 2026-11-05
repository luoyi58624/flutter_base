import 'dart:convert';

import 'package:example/src/pages/examples/recycler_view/cards.dart';
import 'package:example/src/pages/examples/recycler_view/chat.dart';
import 'package:example/src/pages/examples/recycler_view/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mine in [false, true]) {
    testWidgets('真实聊天${mine ? '发出' : '收到'}换绑仅构建正文与时间消费点各一次', (tester) async {
      final content = ValueNotifier<Widget>(SizedBox());
      await _sourceHost(tester, RecyclerChatPage(), content);
      final sourceList = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView, skipOffstage: false));
      final adapter = sourceList.getAdapter()!;
      final first = mine ? 0 : 1;
      final next = mine ? 3 : 2;
      expect(adapter.getItemViewType(first), adapter.getItemViewType(next));
      final holder = adapter.createViewHolder(sourceList, adapter.getItemViewType(first));
      adapter.bindViewHolder(holder, first);
      content.value = SizedBox(width: 360, child: holder.itemView);
      await tester.pumpAndSettle();
      final root = find.byWidget(holder.itemView).evaluate().single;
      final elements = _elements(root);
      final consumers = elements.where((element) => element.widget is ValueListenableBuilder).toSet();
      expect(consumers, hasLength(2), reason: '真实气泡以同一消息模型驱动正文和时间两个最小消费点');
      final beforeText = {for (final consumer in consumers) consumer: _textBelow(consumer)};
      expect(beforeText.values.where((text) => text.startsWith('消息 #')), hasLength(1));
      expect(beforeText.values.where((text) => RegExp(r'^\d\d:\d\d$').hasMatch(text)), hasLength(1));
      final fixed = elements.where((element) {
        final widget = element.widget;
        return identical(element, root) ||
            widget is LayoutBuilder ||
            widget is Align ||
            widget is ConstrainedBox ||
            widget is ElCardView ||
            widget is Column ||
            widget is Text && (widget.data == '我' || widget.data == '小林');
      }).toSet();
      final fixedWidgets = {for (final element in fixed) element: element.widget};
      final capture = _BuildCapture({...consumers, ...fixed});
      try {
        adapter.bindViewHolder(holder, next);
        await tester.pump(Duration(milliseconds: 8));
      } finally {
        capture.dispose();
      }
      expect(holder.getItemId(), adapter.getItemId(next));
      expect([for (final consumer in consumers) capture.count(consumer)], everyElement(1));
      expect([for (final element in fixed) capture.count(element)], everyElement(0));
      for (final consumer in consumers) {
        expect(_textBelow(consumer), isNot(beforeText[consumer]), reason: '正文和时间必须实际换成另一条消息');
      }
      for (final element in fixed) {
        expect(element.widget, same(fixedWidgets[element]));
      }
      expect(_elements(root), elements, reason: '数据换绑保留整棵已有 Element');
      debugPrint(
        'RECYCLER_CHAT_LEAVES ${jsonEncode({'direction': mine ? 'outgoing' : 'incoming', 'changed_consumers': consumers.length, 'consumer_builds': consumers.fold(0, (sum, element) => sum + capture.count(element)), 'fixed_nodes': fixed.length, 'fixed_builds': fixed.fold(0, (sum, element) => sum + capture.count(element)), 'element_additions': _elements(root).difference(elements).length})}',
      );
      await tester.pumpWidget(SizedBox());
      content.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  for (final cards in [false, true]) {
    testWidgets('真实${cards ? '卡片' : '复选'}适配器关闭预取后首屏只绑定最终可见条目', (tester) async {
      final content = ValueNotifier<Widget>(SizedBox());
      await _sourceHost(tester, cards ? RecyclerCardsPage() : RecyclerSelectionPage(), content);
      final sourceList = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView, skipOffstage: false));
      final counted = _CountingAdapter(sourceList.getAdapter()!);
      final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
      final measuredList = rv.RecyclerView()
        ..setLayoutManager(layout)
        ..setAdapter(counted)
        ..setItemViewCacheSize(0);
      // 页面维持业务模型生命周期，新视口在挂载之前就关闭预取；旧页面工作不进入计数。
      content.value = SizedBox(width: 390, height: 600, child: measuredList);
      await tester.pump();
      final visible = layout.getChildCount();
      expect(visible, greaterThan(0));
      expect(layout.findFirstVisibleItemPosition(), 0);
      expect(counted.positions.length, visible);
      expect(counted.positions.toSet().length, visible);
      expect(counted.positions, orderedEquals(List.generate(visible, (index) => index)));
      expect(counted.created, visible);
      await tester.pumpAndSettle();
      expect(counted.positions.length, visible, reason: '异步图片或样式收尾也不能导致重复绑定');
      debugPrint(
        'RECYCLER_FIRST_VISIBLE ${jsonEncode({'page': cards ? 'cards' : 'selection', 'source': 'actual page Adapter and row; separate fresh viewport', 'prefetch': false, 'cache': 0, 'visible': visible, 'bindings': counted.positions.length, 'created': counted.created})}',
      );
      await tester.pumpWidget(SizedBox());
      content.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('普通按钮与 toggle 记录固定结构和模型监听器成本并保留交互', (tester) async {
    final ordinaryKey = GlobalKey();
    final toggleKey = GlobalKey();
    final selected = ValueNotifier(false);
    var activations = 0;
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ElButton(key: ordinaryKey, child: '操作', onPressed: () => activations++),
                ElButton.toggle(key: toggleKey, modelValue: selected, child: '操作'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ordinary = _buttonMetrics(ordinaryKey.currentContext! as Element);
    final toggle = _buttonMetrics(toggleKey.currentContext! as Element);
    expect(ordinary['elements'], greaterThan(0));
    expect(toggle['elements'], greaterThan(0));
    expect(ordinary['direct_model_builders'], 1, reason: '测量当前普通按钮仍持有的 ElModelValue 构建器成本');
    expect(toggle['direct_model_builders'], 1);
    debugPrint(
      'RECYCLER_BUTTON_STRUCTURE ${jsonEncode({'ordinary': ordinary, 'toggle': toggle, 'measurement': 'mounted Element and StatefulElement counts; no timing or memory inference'})}',
    );
    await tester.tap(find.byKey(ordinaryKey));
    await tester.pumpAndSettle();
    expect(activations, 1);
    expect(selected.value, isFalse);
    await tester.tap(find.byKey(toggleKey));
    await tester.pumpAndSettle();
    expect(selected.value, isTrue);
    expect(activations, 1);
    await tester.pumpWidget(SizedBox());
    selected.dispose();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _sourceHost(WidgetTester tester, Widget page, ValueNotifier<Widget> content) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Offstage(child: page),
              Align(
                alignment: Alignment.topLeft,
                child: ValueListenableBuilder(valueListenable: content, builder: (_, content, _) => content),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Set<Element> _elements(Element root) {
  final elements = <Element>{};
  void visit(Element element) {
    elements.add(element);
    element.visitChildren(visit);
  }

  visit(root);
  return elements;
}

String _textBelow(Element root) =>
    _elements(root)
        .map((element) => element.widget)
        .whereType<Text>()
        .map((text) => text.data)
        .whereType<String>()
        .single;

Map<String, int> _buttonMetrics(Element root) {
  final elements = _elements(root);
  final direct = <Element>[];
  root.visitChildren(direct.add);
  return {
    'elements': elements.length,
    'stateful_elements': elements.whereType<StatefulElement>().length,
    'direct_model_builders': direct.where((element) => element.widget is ListenableBuilder).length,
    'all_listenable_builders': elements.where((element) => element.widget is ListenableBuilder).length,
    'obs_builders': elements.where((element) => element.widget is ObsBuilder).length,
  };
}

class _CountingAdapter extends rv.Adapter<rv.ViewHolder> {
  _CountingAdapter(this.source) {
    setHasStableIds(source.hasStableIds());
  }
  final rv.Adapter source;
  final positions = <int>[];
  int created = 0;

  @override
  int getItemCount() => source.getItemCount();

  @override
  int getItemId(int position) => source.getItemId(position);

  @override
  int getItemViewType(int position) => source.getItemViewType(position);

  @override
  rv.ViewHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    created++;
    return source.onCreateViewHolder(parent, viewType);
  }

  @override
  void onBindViewHolder(rv.ViewHolder holder, int position, [List<Object> payloads = const []]) {
    positions.add(position);
    source.onBindViewHolder(holder, position, payloads);
  }

  @override
  void onViewAttachedToWindow(rv.ViewHolder holder) => source.onViewAttachedToWindow(holder);

  @override
  void onViewDetachedFromWindow(rv.ViewHolder holder) => source.onViewDetachedFromWindow(holder);

  @override
  void onViewRecycled(rv.ViewHolder holder) => source.onViewRecycled(holder);
}

class _BuildCapture {
  _BuildCapture(this.observed) : previous = debugOnRebuildDirtyWidget {
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (observed.contains(element)) counts.update(element, (count) => count + 1, ifAbsent: () => 1);
    };
  }
  final Set<Element> observed;
  final RebuildDirtyWidgetCallback? previous;
  final counts = <Element, int>{};
  int count(Element element) => counts[element] ?? 0;
  void dispose() => debugOnRebuildDirtyWidget = previous;
}
