import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable, debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph, RenderProxyBox, ScrollCacheExtent;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Data = Obs<List<Map<String, String>>>;

class _Log {
  int factories = 0;
  int cardWidgets = 0;
  int cardBuilds = 0;
  int cardUpdates = 0;
  int cardMounts = 0;
  int cardUnmounts = 0;
  int frameCreates = 0;
  int frameUpdates = 0;
  int frameDisposes = 0;
  int titleBuilds = 0;
  final traces = <_Trace>[];
  final taps = <int>[];

  Map<String, int> get counts => {
    'item_factory': factories,
    'card_widget_create': cardWidgets,
    'card_build': cardBuilds,
    'card_element_update': cardUpdates,
    'card_mount': cardMounts,
    'card_unmount': cardUnmounts,
    'outer_render_create': frameCreates,
    'outer_render_update': frameUpdates,
    'outer_render_dispose': frameDisposes,
    'title_builder': titleBuilds,
  };

  Map<String, int> delta(Map<String, int> before) => {
    for (final entry in counts.entries) entry.key: entry.value - before[entry.key]!,
  };
}

class _Trace {
  _Trace(this.index, this.log);

  final ValueListenable<int> index;
  final _Log log;
  // 键属于槽位，换绑业务序号时保持不变。
  final cardKey = UniqueKey();
  final titleScopeKey = UniqueKey();
  final titleKey = UniqueKey();
  final tapKey = UniqueKey();
}

class _Card extends StatelessWidget {
  _Card({required this.trace, required this.data, required this.localTitle}) : super(key: trace.cardKey) {
    trace.log.cardWidgets++;
  }

  final _Trace trace;
  final _Data data;
  final bool localTitle;

  @override
  StatelessElement createElement() => _CardElement(this);

  Widget _title() {
    trace.log.titleBuilds++;
    return Text('${data.value[trace.index.value]['title']}', key: trace.titleKey, maxLines: 1, overflow: .ellipsis);
  }

  @override
  Widget build(BuildContext context) {
    trace.log.cardBuilds++;
    // 每次 build 都真实创建配置，不用 const 或手动缓存掩盖额外重建。
    return _FrameProbe(
      log: trace.log,
      child: ElCardView(
        style: ElStyle(
          padding: .all(12),
          backgroundColor: Color(0xfff5f7fa),
          borderRadius: .circular(12),
          border: .all(borderWidth: 1, borderColor: Color(0xffd8dfe8)),
        ),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              children: [
                Icon(Icons.article_outlined, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('固定卡片头')),
                Text('已核验'),
              ],
            ),
            SizedBox(height: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  if (localTitle)
                    ObsBuilder(key: trace.titleScopeKey, listenables: [trace.index], builder: (_) => _title())
                  else
                    _title(),
                  SizedBox(height: 8),
                  Text('固定正文：这部分不依赖条目序号。'),
                ],
              ),
            ),
            Row(
              children: [
                Icon(Icons.label_outline, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('固定分类')),
                GestureDetector(
                  key: trace.tapKey,
                  behavior: .opaque,
                  onTap: () => trace.log.taps.add(trace.index.value),
                  child: Padding(padding: .all(8), child: Text('查看记录')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardElement extends StatelessElement {
  _CardElement(_Card super.widget);

  _Log get _log => (widget as _Card).trace.log;

  @override
  void mount(Element? parent, Object? newSlot) {
    _log.cardMounts++;
    super.mount(parent, newSlot);
  }

  @override
  void update(covariant _Card newWidget) {
    _log.cardUpdates++;
    super.update(newWidget);
  }

  @override
  void unmount() {
    _log.cardUnmounts++;
    super.unmount();
  }
}

class _FrameProbe extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _FrameProbe({required this.log, required super.child});

  final _Log log;

  @override
  RenderProxyBox createRenderObject(BuildContext context) {
    log.frameCreates++;
    return _FrameRender(log);
  }

  @override
  void updateRenderObject(BuildContext context, RenderProxyBox renderObject) {
    log.frameUpdates++;
  }
}

class _FrameRender extends RenderProxyBox {
  _FrameRender(this.log);

  final _Log log;

  @override
  void dispose() {
    log.frameDisposes++;
    super.dispose();
  }
}

class _TreeSnapshot {
  _TreeSnapshot(Element root, {Set<Key> excluded = const {}}) {
    void visit(Element element) {
      if (excluded.contains(element.widget.key)) return;
      widgets[element] = element.widget;
      if (element is RenderObjectElement) renders[element] = element.renderObject;
      if (element is StatefulElement) states[element] = element.state;
      element.visitChildren(visit);
    }

    visit(root);
  }

  final widgets = <Element, Widget>{};
  final renders = <RenderObjectElement, RenderObject>{};
  final states = <StatefulElement, State>{};

  void expectSameNodes(_TreeSnapshot after) {
    expect(after.widgets.keys, unorderedEquals(widgets.keys), reason: 'Element 集合不能被替换。');
    expect(after.renders.keys, unorderedEquals(renders.keys));
    expect(after.states.keys, unorderedEquals(states.keys));
    for (final entry in renders.entries) {
      expect(after.renders[entry.key], same(entry.value), reason: 'RenderObject 必须是原实例。');
    }
    for (final entry in states.entries) {
      expect(after.states[entry.key], same(entry.value), reason: 'State 必须是原实例。');
    }
    for (final element in widgets.keys) {
      expect(element.mounted, isTrue);
    }
  }

  void expectSameWidgets(_TreeSnapshot after) {
    expectSameNodes(after);
    for (final entry in widgets.entries) {
      expect(after.widgets[entry.key], same(entry.value), reason: '静态 ${entry.value.runtimeType} 不能生成新配置。');
    }
  }

  int changedWidgets(_TreeSnapshot after) =>
      widgets.entries.where((entry) => !identical(entry.value, after.widgets[entry.key])).length;
}

class _Fixture {
  _Fixture(this.tester, {this.localTitle = true});

  final WidgetTester tester;
  final bool localTitle;
  final controller = ScrollController();
  final log = _Log();
  final _Data data = Obs(List.generate(1000, (index) => {'title': '标题 $index'}));
  final rebuilt = <Element>[];
  RebuildDirtyWidgetCallback? _previousHook;

  Future<void> mount() async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(400, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(controller.dispose);
    addTearDown(data.dispose);
    _previousHook = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      rebuilt.add(element);
      _previousHook?.call(element, builtOnce);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = _previousHook);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            physics: ClampingScrollPhysics(),
            scrollCacheExtent: ScrollCacheExtent.pixels(0),
            slivers: [
              ElSliverRecycler(
                itemCount: data.rawValue.length,
                maxRecycledItems: 0,
                itemBuilder: (_, index) {
                  log.factories++;
                  final trace = _Trace(index, log);
                  log.traces.add(trace);
                  if (localTitle) {
                    return SizedBox(
                      height: 240,
                      child: _Card(trace: trace, data: data, localTitle: true),
                    );
                  }
                  // 对照保留同一回收池，仅把监听范围扩大到整张卡片。
                  return SizedBox(
                    height: 240,
                    child: ObsBuilder(
                      listenables: [index],
                      builder: (_) => _Card(trace: trace, data: data, localTitle: false),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(log.factories, 2);
    expect(log.traces.map((trace) => trace.index.value), unorderedEquals([0, 1]));
    expect(tester.takeException(), isNull);
  }

  _TreeSnapshot staticTree(_Trace trace) =>
      _TreeSnapshot(tester.element(find.byKey(trace.cardKey)), excluded: {trace.titleScopeKey, trace.titleKey});

  _TreeSnapshot titleTree(_Trace trace) => _TreeSnapshot(tester.element(find.byKey(trace.titleKey)));

  Text titleWidget(_Trace trace) => tester.widget<Text>(find.byKey(trace.titleKey));

  RenderParagraph paragraph(_Trace trace) {
    final richText = find.descendant(of: find.byKey(trace.titleKey), matching: find.byType(RichText));
    expect(richText, findsOneWidget);
    return tester.renderObject<RenderParagraph>(richText);
  }

  Future<void> jump(int firstIndex) async {
    rebuilt.clear();
    controller.jumpTo(firstIndex * 240);
    await tester.pump();
    expect(log.traces.map((trace) => trace.index.value), unorderedEquals([firstIndex, firstIndex + 1]));
    expect(tester.takeException(), isNull);
  }

  Future<void> unmount() async {
    await tester.pumpWidget(SizedBox.shrink());
    expect(log.cardUnmounts, log.cardMounts);
    expect(log.frameDisposes, log.frameCreates);
    expect(data.obsBuilders, isEmpty);
    expect(tester.takeException(), isNull);
    debugOnRebuildDirtyWidget = _previousHook;
  }
}

void _expectStaticCountersUnchanged(_Log log, Map<String, int> before) {
  final delta = log.delta(before)..remove('title_builder');
  expect(delta.values, everyElement(0), reason: '外层不能新增 Widget、build、update、挂载或释放。');
}

void main() {
  testWidgets('Obs 标题换绑时静态整棵子树完全复用，标题节点只更新配置', (tester) async {
    final fixture = _Fixture(tester);
    await fixture.mount();
    final log = fixture.log;
    final before = log.counts;
    final staticBefore = {for (final trace in log.traces) trace: fixture.staticTree(trace)};
    var titleBefore = {for (final trace in log.traces) trace: fixture.titleTree(trace)};
    final paragraphs = {for (final trace in log.traces) trace: fixture.paragraph(trace)};
    final callbacks = {
      for (final trace in log.traces) trace: tester.widget<GestureDetector>(find.byKey(trace.tapKey)).onTap,
    };
    var staticRebuilds = 0;

    for (var step = 1; step <= 20; step++) {
      await fixture.jump(step * 20);
      for (final trace in log.traces) {
        final staticAfter = fixture.staticTree(trace);
        staticBefore[trace]!.expectSameWidgets(staticAfter);
        staticRebuilds += fixture.rebuilt.where(staticBefore[trace]!.widgets.containsKey).length;
        expect(fixture.rebuilt.where(staticBefore[trace]!.widgets.containsKey), isEmpty);
        final titleAfter = fixture.titleTree(trace);
        titleBefore[trace]!.expectSameNodes(titleAfter);
        expect(titleBefore[trace]!.changedWidgets(titleAfter), greaterThan(0));
        expect(fixture.paragraph(trace), same(paragraphs[trace]));
        expect(fixture.paragraph(trace).text.toPlainText(), '标题 ${trace.index.value}');
        expect(fixture.titleWidget(trace).data, '标题 ${trace.index.value}');
        expect(tester.widget<GestureDetector>(find.byKey(trace.tapKey)).onTap, same(callbacks[trace]));
      }
      titleBefore = {for (final trace in log.traces) trace: fixture.titleTree(trace)};
      _expectStaticCountersUnchanged(log, before);
      expect(log.titleBuilds - before['title_builder']!, step * 2);
    }

    final delta = log.delta(before);
    debugPrintSynchronously(
      'SLIVER_STATIC_REUSE ${jsonEncode({'scenario': '20_rebind_windows', 'slots': log.traces.length, 'static_elements': staticBefore.values.fold(0, (sum, tree) => sum + tree.widgets.length), 'static_render_objects': staticBefore.values.fold(0, (sum, tree) => sum + tree.renders.length), 'static_element_rebuilds': staticRebuilds, 'static_widget_replacements': 0, 'title_element_replacements': 0, 'title_render_replacements': 0, ...delta})}',
    );
    await tester.tap(find.byKey(log.traces.first.tapKey));
    expect(log.taps, [log.traces.first.index.value], reason: '同一事件闭包必须读取换绑后的序号。');
    await fixture.unmount();
  });

  testWidgets('共享 listData 通知只更新标题区域，外层仍完整保留', (tester) async {
    final fixture = _Fixture(tester);
    await fixture.mount();
    final log = fixture.log;
    final before = log.counts;
    final staticBefore = {for (final trace in log.traces) trace: fixture.staticTree(trace)};
    final titleBefore = {for (final trace in log.traces) trace: fixture.titleTree(trace)};
    final paragraphs = {for (final trace in log.traces) trace: fixture.paragraph(trace)};
    fixture.rebuilt.clear();
    fixture.data.rawValue[0]['title'] = '已修改的标题';
    fixture.data.notify();
    await tester.pump();

    for (final trace in log.traces) {
      staticBefore[trace]!.expectSameWidgets(fixture.staticTree(trace));
      expect(fixture.rebuilt.where(staticBefore[trace]!.widgets.containsKey), isEmpty);
      titleBefore[trace]!.expectSameNodes(fixture.titleTree(trace));
      expect(titleBefore[trace]!.changedWidgets(fixture.titleTree(trace)), greaterThan(0));
      expect(fixture.paragraph(trace), same(paragraphs[trace]));
      final expected = trace.index.value == 0 ? '已修改的标题' : '标题 1';
      expect(fixture.paragraph(trace).text.toPlainText(), expected);
    }
    _expectStaticCountersUnchanged(log, before);
    // 共享一个 Obs 时两个标题都订阅它，不能误报为逐条目或字段去重。
    expect(log.titleBuilds - before['title_builder']!, 2);
    debugPrintSynchronously(
      'SLIVER_STATIC_REUSE ${jsonEncode({'scenario': 'shared_obs_one_record_change', ...log.delta(before)})}',
    );
    await fixture.unmount();
  });

  testWidgets('整卡监听对照会更新静态配置，证明身份与构建探针能识别差异', (tester) async {
    final fixture = _Fixture(tester, localTitle: false);
    await fixture.mount();
    final log = fixture.log;
    final before = log.counts;
    final staticBefore = {for (final trace in log.traces) trace: fixture.staticTree(trace)};
    final titleBefore = {for (final trace in log.traces) trace: fixture.titleTree(trace)};
    var replacedWidgets = 0;
    var staticRebuilds = 0;
    await fixture.jump(20);

    for (final trace in log.traces) {
      final staticAfter = fixture.staticTree(trace);
      staticBefore[trace]!.expectSameNodes(staticAfter);
      replacedWidgets += staticBefore[trace]!.changedWidgets(staticAfter);
      staticRebuilds += fixture.rebuilt.where(staticBefore[trace]!.widgets.containsKey).length;
      titleBefore[trace]!.expectSameNodes(fixture.titleTree(trace));
      expect(fixture.paragraph(trace).text.toPlainText(), '标题 ${trace.index.value}');
    }
    expect(replacedWidgets, greaterThan(0));
    expect(staticRebuilds, greaterThan(0));
    expect(log.cardWidgets - before['card_widget_create']!, 2);
    expect(log.cardBuilds - before['card_build']!, 2);
    expect(log.cardUpdates - before['card_element_update']!, 2);
    expect(log.frameUpdates - before['outer_render_update']!, 2);
    expect(log.factories - before['item_factory']!, 0);
    expect(log.cardUnmounts - before['card_unmount']!, 0);
    expect(log.frameCreates - before['outer_render_create']!, 0);
    debugPrintSynchronously(
      'SLIVER_STATIC_REUSE ${jsonEncode({'scenario': 'whole_card_observer_control', 'static_widget_replacements': replacedWidgets, 'static_element_rebuilds': staticRebuilds, ...log.delta(before)})}',
    );
    await fixture.unmount();
  });
}
