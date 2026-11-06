import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/flutter_base.dart' show ElCardView, ElStyle;
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

const _extent = 336.0;
const _warmup = 4;
const _samples = 24;

void main() {
  testWidgets('复杂卡片同 Element 更新与强制销毁重建的创建耗时正对照', (tester) async {
    final work = _Work();
    final content = ValueNotifier<Widget>(SizedBox());
    await tester.pumpWidget(_host(ValueListenableBuilder(valueListenable: content, builder: (_, child, _) => child)));
    var model = ValueNotifier(_Data(0));
    var row = _description(model, work, 0);
    final firstMount = Stopwatch()..start();
    content.value = RepaintBoundary(child: row);
    await tester.pump();
    firstMount.stop();
    final initialTree = _Tree.capture(row);
    expect(initialTree.elements.length, greaterThan(100), reason: '夹具必须是有多层排版、图标、装饰和动态字段的复杂行');
    final updates = <Map<String, Object?>>[];
    final remounts = <Map<String, Object?>>[];
    final idle = <Map<String, Object?>>[];

    // 先运行真实数据更新，再记录无业务工作的测试框架基线；它不能机械地从更新耗时中扣除。
    for (var warmup = 0; warmup < _warmup; warmup++) {
      model.value = _Data(100000 + warmup);
      await tester.pump(Duration(milliseconds: 8));
    }
    for (var frame = 0; frame < 12; frame++) {
      final beforeTree = _Tree.capture(row);
      final beforeWork = work.snapshot();
      final clock = Stopwatch()..start();
      await tester.pump(Duration(milliseconds: 8));
      clock.stop();
      final afterTree = _Tree.capture(row);
      final sample = _measurement(beforeTree, afterTree, beforeWork, work, clock);
      expect(work.snapshot(), beforeWork, reason: '未改模型时不能产生新的构建、布局、绘制或创建销毁工作');
      expect(afterTree.elements, beforeTree.elements);
      expect(afterTree.states, beforeTree.states);
      expect(afterTree.renders, beforeTree.renders);
      expect(sample['widget_descriptions_changed'], 0);
      idle.add(sample);
    }

    for (var iteration = 0; iteration < _warmup + _samples; iteration++) {
      final beforeUpdateTree = _Tree.capture(row);
      final beforeUpdateWork = work.snapshot();
      final updateClock = Stopwatch()..start();
      model.value = _Data(iteration * 2 + 1);
      await tester.pump(Duration(milliseconds: 8));
      updateClock.stop();
      final afterUpdateTree = _Tree.capture(row);
      final update = _measurement(beforeUpdateTree, afterUpdateTree, beforeUpdateWork, work, updateClock);
      expect(update['elements_added'], 0);
      expect(update['elements_removed'], 0);
      expect(update['states_added'], 0);
      expect(update['states_removed'], 0);
      expect(update['render_objects_added'], 0);
      expect(update['render_objects_removed'], 0);
      expect(update['row_initializations'], 0);
      expect(update['row_disposals'], 0);
      expect(update['probe_creations'], 0);
      expect(update['probe_disposals'], 0);
      expect(update['dynamic_leaf_probe_creations'], 0);
      expect(update['dynamic_leaf_probe_disposals'], 0);
      expect(update['root_widget_descriptions_created'], 0);
      expect(update['row_builds'], 0, reason: '固定结构不订阅整条记录，数据只更新最小消费点');
      expect(update['leaf_builds'], 9);
      expect(update['widget_descriptions_changed'] as int, greaterThan(0), reason: '不可变 Widget 描述更新不等于 Element 销毁');
      expect(find.text(_title(model.value.id)), findsOneWidget);

      final beforeMountTree = afterUpdateTree;
      final beforeMountWork = work.snapshot();
      final nextModel = ValueNotifier(_Data(iteration * 2 + 2));
      final factoryClock = Stopwatch()..start();
      final nextRow = _description(nextModel, work, 0);
      factoryClock.stop();
      final mountClock = Stopwatch()..start();
      content.value = RepaintBoundary(child: nextRow);
      await tester.pump(Duration(milliseconds: 8));
      mountClock.stop();
      final afterMountTree = _Tree.capture(nextRow);
      final mount = _measurement(beforeMountTree, afterMountTree, beforeMountWork, work, mountClock)
        ..['widget_description_factory_us'] = factoryClock.elapsedMicroseconds;
      expect(mount['elements_added'], afterMountTree.elements.length);
      expect(mount['elements_removed'], beforeMountTree.elements.length);
      expect(mount['states_retained'], 0);
      expect(mount['render_objects_retained'], 0);
      expect(mount['row_initializations'], 1);
      expect(mount['row_disposals'], 1);
      expect(mount['probe_creations'], 1);
      expect(mount['probe_disposals'], 1);
      expect(mount['dynamic_leaf_probe_creations'], 9);
      expect(mount['dynamic_leaf_probe_disposals'], 9);
      expect(mount['root_widget_descriptions_created'], 1);
      model.dispose();
      model = nextModel;
      row = nextRow;
      if (iteration >= _warmup) {
        updates.add(update);
        remounts.add(mount);
      }
    }

    _emit('isolated_update_vs_forced_remount', {
      'row_elements': initialTree.elements.length,
      'row_stateful_elements': initialTree.states.length,
      'row_render_objects': initialTree.renders.length,
      'first_mount_pump_us_unwarmed': firstMount.elapsedMicroseconds,
      'idle_calibration': {
        'warmup_model_updates': _warmup,
        'unchanged_model_pumps': idle.length,
        'interpretation': 'Diagnostic tester/framework baseline only; do not subtract it from update or mount timings to claim net cost.',
        'summary': _summary(idle),
      },
      'idle_calibration_samples': idle,
      'update': _summary(updates),
      'forced_remount': _summary(remounts),
      'update_samples': updates,
      'forced_remount_samples': remounts,
    });
    await tester.pumpWidget(SizedBox());
    expect(work.rowDisposals, work.rowInitializations);
    expect(work.probeDisposals, work.probeCreations);
    expect(work.leafProbeDisposals, work.leafProbeCreations);
    model.dispose();
    content.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('真实 RecyclerView 快速整屏跨记录换绑复杂卡片不继续创建或销毁子树', (tester) async {
    final work = _Work();
    final adapter = _Cards(work);
    final manager = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = rv.RecyclerView()
      ..setAdapter(adapter)
      ..setLayoutManager(manager)
      ..setItemViewCacheSize(0);
    for (var type = 0; type < 2; type++) {
      list.getRecycledViewPool().setMaxRecycledViews(type, 1);
    }
    final firstFrameClock = Stopwatch()..start();
    await tester.pumpWidget(_host(SizedBox(width: 400, height: _extent * 2, child: list)));
    firstFrameClock.stop();
    expect(manager.getChildCount(), 2);
    final firstScreenHolders = adapter.holders.length;
    final firstScreenInitializations = work.rowInitializations;
    expect(firstScreenHolders, 2);
    final firstTrees = {for (final holder in adapter.holders) holder: _Tree.capture(holder.itemView)};
    expect(firstTrees.values.every((tree) => tree.elements.length > 100), isTrue);
    final measured = <Map<String, Object?>>[];
    var newHoldersAfterFirstScreen = 0;
    var destroyedStatesAfterFirstScreen = 0;

    for (var frame = 0; frame < _warmup + _samples; frame++) {
      final beforeWork = work.snapshot();
      final beforeTrees = {for (final holder in adapter.holders) holder: _Tree.capture(holder.itemView)};
      final beforePositions = {for (final holder in adapter.holders) holder: holder.getItemId()};
      final beforeCreated = adapter.holders.length;
      final forward = frame < _warmup + _samples ~/ 2;
      final clock = Stopwatch()..start();
      list.scrollBy(0, (forward ? 1 : -1) * _extent * 6);
      await tester.pump(Duration(milliseconds: 8));
      clock.stop();
      final afterWork = work.snapshot();
      newHoldersAfterFirstScreen += adapter.holders.length - beforeCreated;
      destroyedStatesAfterFirstScreen += afterWork['row_disposals']! - beforeWork['row_disposals']!;
      final afterTrees = {for (final holder in adapter.holders) holder: _Tree.capture(holder.itemView)};
      expect(adapter.holders.length, firstScreenHolders, reason: '快滚后不能把新数据退化为新的 holder');
      expect(work.rowInitializations, firstScreenInitializations);
      expect(work.rowDisposals, 0);
      expect(work.probeCreations, firstScreenHolders);
      expect(work.probeDisposals, 0);
      expect(work.rootWidgetDescriptions, firstScreenHolders);
      expect(work.leafProbeCreations, firstScreenHolders * 9);
      expect(work.leafProbeDisposals, 0);
      expect(manager.getChildCount(), 2);
      var additions = 0, removals = 0, retainedRenders = 0, changedDescriptions = 0;
      for (final holder in adapter.holders) {
        final before = beforeTrees[holder]!;
        final after = afterTrees[holder]!;
        additions += after.elements.difference(before.elements).length;
        removals += before.elements.difference(after.elements).length;
        retainedRenders += after.renders.intersection(before.renders).length;
        changedDescriptions += after.changedDescriptions(before);
        expect(after.elements, firstTrees[holder]!.elements);
        expect(after.states, firstTrees[holder]!.states);
        expect(after.renders, firstTrees[holder]!.renders);
        expect(holder.getItemId(), isNot(beforePositions[holder]));
        expect(holder.template, holder.getBindingAdapterPosition() % 2);
        expect(find.text(_title(holder.model.value.id)).hitTestable(), findsOneWidget);
      }
      final sample = {
        'full_pump_us': clock.elapsedMicroseconds,
        'elements_added': additions,
        'elements_removed': removals,
        'render_objects_retained': retainedRenders,
        'widget_descriptions_changed': changedDescriptions,
        for (final entry in afterWork.entries) entry.key: entry.value - beforeWork[entry.key]!,
      };
      if (frame >= _warmup) measured.add(sample);
    }

    expect(newHoldersAfterFirstScreen, 0);
    expect(destroyedStatesAfterFirstScreen, 0);
    expect(adapter.boundIds.values.every((ids) => ids.length > 10), isTrue);
    _emit('actual_recycler_fast_full_screen', {
      'items': adapter.getItemCount(),
      'view_types': 2,
      'cache_size': 0,
      'prefetch_enabled': false,
      'pool_capacity_per_type': 1,
      'first_screen_holders': firstScreenHolders,
      'new_holders_after_first_screen': newHoldersAfterFirstScreen,
      'row_disposals_after_first_screen': destroyedStatesAfterFirstScreen,
      'initial_description_factory_us': adapter.factoryUs,
      'first_screen_pump_us_unwarmed': firstFrameClock.elapsedMicroseconds,
      'row_elements_per_holder': firstTrees.values.map((tree) => tree.elements.length).toList(),
      'distinct_data_ids_per_holder': adapter.boundIds.values.map((ids) => ids.length).toList(),
      'moving': _summary(measured),
      'samples': measured,
    });
    await tester.pumpWidget(SizedBox());
    expect(work.rowDisposals, work.rowInitializations);
    expect(work.probeDisposals, work.probeCreations);
    expect(work.leafProbeDisposals, work.leafProbeCreations);
    for (final holder in adapter.holders) {
      holder.model.dispose();
    }
    expect(tester.takeException(), isNull);
  });
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: .topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);

_ComplexCard _description(ValueNotifier<_Data> model, _Work work, int template) {
  // 仅统计 Adapter 创建的根描述，后代的不可变描述变化另按已保留 Element 的 widget 身份记录。
  work.rootWidgetDescriptions++;
  return _ComplexCard(key: UniqueKey(), model: model, work: work, template: template);
}

String _title(int id) => '项目 #${id.toString().padLeft(5, '0')}';

void _emit(String scenario, Map<String, Object?> data) => debugPrint(
  'COMPLEX_WIDGET_COST ${jsonEncode({'scenario': scenario, 'environment': 'flutter_test / Debug JIT; host wall time, CPU layout and paint recording; not device FrameTiming or GPU raster', 'warmup_operations': _warmup, 'measured_operations': _samples, 'factory_note': 'Only constructs the root Widget description. Descendant Widget creation, Element mounting, build/layout/paint and teardown are included in full_pump_us.', 'instrumentation_note': 'row_root and dynamic_leaf_root measure their own probe callbacks, not every relayout/repaint boundary below them. Zero root callbacks do not mean zero subtree work. Root and leaf durations can overlap and must not be summed.', 'identity_note': 'root_widget_descriptions_created counts explicit root factories only. widget_descriptions_changed counts replaced immutable descriptions on retained Elements; it does not count Element mounting or total descendant Widget constructors.', ...data})}',
);

Map<String, Object?> _summary(List<Map<String, Object?>> samples) {
  Map<String, num> distribution(String field) {
    final values = [for (final sample in samples) sample[field]! as int]..sort();
    double p(double q) => values[((values.length - 1) * q).floor()] / 1000;
    return {'p50_ms': p(.5), 'p95_ms': p(.95), 'max_ms': p(1)};
  }

  return {
    'full_pump': distribution('full_pump_us'),
    'row_build': distribution('row_build_us'),
    'leaf_build': distribution('leaf_build_us'),
    'row_root_layout': distribution('row_root_layout_us'),
    'dynamic_leaf_root_layout': distribution('dynamic_leaf_root_layout_us'),
    'row_root_paint_recording': distribution('row_root_paint_us'),
    'dynamic_leaf_root_paint_recording': distribution('dynamic_leaf_root_paint_us'),
    if (samples.first.containsKey('widget_description_factory_us'))
      'widget_description_factory': distribution('widget_description_factory_us'),
  };
}

Map<String, Object?> _measurement(_Tree before, _Tree after, Map<String, int> previous, _Work work, Stopwatch clock) =>
    {
      'full_pump_us': clock.elapsedMicroseconds,
      'elements_added': after.elements.difference(before.elements).length,
      'elements_removed': before.elements.difference(after.elements).length,
      'states_added': after.states.difference(before.states).length,
      'states_removed': before.states.difference(after.states).length,
      'states_retained': after.states.intersection(before.states).length,
      'render_objects_added': after.renders.difference(before.renders).length,
      'render_objects_removed': before.renders.difference(after.renders).length,
      'render_objects_retained': after.renders.intersection(before.renders).length,
      'render_paragraphs_retained': after.paragraphs.intersection(before.paragraphs).length,
      'widget_descriptions_changed': after.changedDescriptions(before),
      for (final entry in work.snapshot().entries) entry.key: entry.value - previous[entry.key]!,
    };

class _Tree {
  _Tree(this.elements, this.states, this.renders, this.paragraphs, this.widgets);

  factory _Tree.capture(Widget row) {
    final elements = <Element>{};
    void visit(Element element) {
      elements.add(element);
      element.visitChildren(visit);
    }

    visit(find.byWidget(row, skipOffstage: false).evaluate().single);
    final renders = elements.whereType<RenderObjectElement>().map((element) => element.renderObject).toSet();
    return _Tree(
      elements,
      elements.whereType<StatefulElement>().map((element) => element.state).toSet(),
      renders,
      renders.whereType<RenderParagraph>().toSet(),
      {for (final element in elements) element: element.widget},
    );
  }

  final Set<Element> elements;
  final Set<State> states;
  final Set<RenderObject> renders;
  final Set<RenderParagraph> paragraphs;
  final Map<Element, Widget> widgets;

  int changedDescriptions(_Tree before) => elements
      .where((element) => before.elements.contains(element) && !identical(widgets[element], before.widgets[element]))
      .length;
}

class _Data {
  _Data(this.id);
  final int id;
  bool get active => id.isOdd;
  double get progress => (id % 91 + 1) / 100;
}

class _Cards extends rv.Adapter<_Holder> {
  _Cards(this.work) {
    setHasStableIds(true);
  }
  final _Work work;
  final holders = <_Holder>[];
  final factoryUs = <int>[];
  final boundIds = <_Holder, Set<int>>{};

  @override
  int getItemCount() => 10000;
  @override
  int getItemId(int position) => position;
  @override
  int getItemViewType(int position) => position % 2;
  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final model = ValueNotifier(_Data(-1));
    final clock = Stopwatch()..start();
    final row = _description(model, work, viewType);
    clock.stop();
    factoryUs.add(clock.elapsedMicroseconds);
    final holder = _Holder(model, viewType, row);
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) {
    expect(holder.template, position % 2);
    boundIds.putIfAbsent(holder, () => {}).add(position);
    holder.model.value = _Data(position);
  }
}

class _Holder extends rv.ViewHolder {
  _Holder(this.model, this.template, super.itemView);
  final ValueNotifier<_Data> model;
  final int template;
}

class _Work {
  int rootWidgetDescriptions = 0;
  int rowInitializations = 0, rowDisposals = 0, rowBuilds = 0, rowBuildUs = 0;
  int leafBuilds = 0, leafBuildUs = 0, layouts = 0, layoutUs = 0, paints = 0, paintUs = 0;
  int probeCreations = 0, probeDisposals = 0;
  int leafLayouts = 0, leafLayoutUs = 0, leafPaints = 0, leafPaintUs = 0;
  int leafProbeCreations = 0, leafProbeDisposals = 0;

  Map<String, int> snapshot() => {
    'root_widget_descriptions_created': rootWidgetDescriptions,
    'row_initializations': rowInitializations,
    'row_disposals': rowDisposals,
    'row_builds': rowBuilds,
    'row_build_us': rowBuildUs,
    'leaf_builds': leafBuilds,
    'leaf_build_us': leafBuildUs,
    'row_root_layout_calls': layouts,
    'row_root_layout_us': layoutUs,
    'row_root_paint_calls': paints,
    'row_root_paint_us': paintUs,
    'dynamic_leaf_root_layout_calls': leafLayouts,
    'dynamic_leaf_root_layout_us': leafLayoutUs,
    'dynamic_leaf_root_paint_calls': leafPaints,
    'dynamic_leaf_root_paint_us': leafPaintUs,
    'probe_creations': probeCreations,
    'probe_disposals': probeDisposals,
    'dynamic_leaf_probe_creations': leafProbeCreations,
    'dynamic_leaf_probe_disposals': leafProbeDisposals,
  };
}

class _ComplexCard extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ComplexCard({super.key, required this.model, required this.work, required this.template});
  final ValueNotifier<_Data> model;
  final _Work work;
  final int template;
  @override
  State<_ComplexCard> createState() => _ComplexCardState();
}

class _ComplexCardState extends State<_ComplexCard> {
  @override
  void initState() {
    super.initState();
    widget.work.rowInitializations++;
  }

  @override
  void dispose() {
    widget.work.rowDisposals++;
    super.dispose();
  }

  Widget _leaf(Widget Function(_Data data) builder) => ValueListenableBuilder(
    valueListenable: widget.model,
    builder: (context, data, child) {
      final clock = Stopwatch()..start();
      final result = _WorkProbe(work: widget.work, leaf: true, child: builder(data));
      clock.stop();
      widget.work.leafBuilds++;
      widget.work.leafBuildUs += clock.elapsedMicroseconds;
      return result;
    },
  );

  @override
  Widget build(BuildContext context) {
    final clock = Stopwatch()..start();
    widget.work.rowBuilds++;
    final color = widget.template == 0 ? Color(0xff466eaa) : Color(0xff4b856f);
    final result = _WorkProbe(
      work: widget.work,
      child: SizedBox(
        height: _extent,
        child: ElCardView(
          style: ElStyle(
            padding: EdgeInsets.all(12),
            backgroundColor: Color(0xfff7f8fb),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                children: [
                  ClipOval(
                    child: ColoredBox(
                      color: color,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.landscape_outlined, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        _leaf((data) => Text(_title(data.id), style: TextStyle(fontSize: 14, fontWeight: .w600))),
                        _leaf((data) => Text('工作面板 · 修订 ${data.id * 7}', style: TextStyle(fontSize: 10), maxLines: 1)),
                      ],
                    ),
                  ),
                  Icon(Icons.more_horiz, size: 20),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  for (final text in ['协作空间', '数据分析', '已同步'])
                    Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xffe6ebf4), borderRadius: BorderRadius.circular(4)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          child: Text(text, style: TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '固定说明：这张卡片包含图标、标记、阴影、统计与进度。换绑时固定结构应始终保留。',
                style: TextStyle(fontSize: 11, height: 1.2),
                maxLines: 2,
                overflow: .ellipsis,
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  for (var metric = 0; metric < 4; metric++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: Column(
                              children: [
                                Icon(
                                  [
                                    Icons.insights,
                                    Icons.people_outline,
                                    Icons.cloud_outlined,
                                    Icons.check_circle_outline,
                                  ][metric],
                                  size: 18,
                                  color: color,
                                ),
                                Text(['访问', '成员', '文件', '完成'][metric], style: TextStyle(fontSize: 9)),
                                _leaf(
                                  (data) => Text(
                                    '${data.id * (metric + 3) + metric}',
                                    style: TextStyle(fontSize: 12, fontWeight: .w600),
                                    maxLines: 1,
                                    overflow: .ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8),
              _leaf(
                (data) => Text(
                  '记录 ${data.id}：正文随数据身份更新，标题、统计、状态与进度均读取当前记录。',
                  style: TextStyle(fontSize: 11, height: 1.2),
                  maxLines: 2,
                  overflow: .ellipsis,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.stacked_line_chart, size: 18, color: color),
                  SizedBox(width: 8),
                  Expanded(
                    child: _leaf(
                      (data) => CustomPaint(size: Size(240, 8), painter: _ProgressPainter(data.progress, color)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16),
                  SizedBox(width: 4),
                  Text('刚刚更新', style: TextStyle(fontSize: 10)),
                  Spacer(),
                  Icon(Icons.shield_outlined, size: 16),
                  SizedBox(width: 4),
                  _leaf((data) => Text(data.active ? '运行中' : '待处理', style: TextStyle(fontSize: 10, color: color))),
                  SizedBox(width: 8),
                  Icon(Icons.bookmark_border, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    clock.stop();
    widget.work.rowBuildUs += clock.elapsedMicroseconds;
    return result;
  }
}

class _WorkProbe extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _WorkProbe({required this.work, this.leaf = false, required super.child});
  final _Work work;
  final bool leaf;
  @override
  RenderObject createRenderObject(BuildContext context) => _WorkRenderBox(work, leaf);
}

class _WorkRenderBox extends RenderProxyBox {
  _WorkRenderBox(this.work, this.leaf) {
    if (leaf) {
      work.leafProbeCreations++;
    } else {
      work.probeCreations++;
    }
  }
  final _Work work;
  final bool leaf;
  @override
  void performLayout() {
    final clock = Stopwatch()..start();
    if (leaf) {
      work.leafLayouts++;
    } else {
      work.layouts++;
    }
    super.performLayout();
    clock.stop();
    if (leaf) {
      work.leafLayoutUs += clock.elapsedMicroseconds;
    } else {
      work.layoutUs += clock.elapsedMicroseconds;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final clock = Stopwatch()..start();
    if (leaf) {
      work.leafPaints++;
    } else {
      work.paints++;
    }
    super.paint(context, offset);
    clock.stop();
    if (leaf) {
      work.leafPaintUs += clock.elapsedMicroseconds;
    } else {
      work.paintUs += clock.elapsedMicroseconds;
    }
  }

  @override
  void dispose() {
    if (leaf) {
      work.leafProbeDisposals++;
    } else {
      work.probeDisposals++;
    }
    super.dispose();
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.value, this.color);
  final double value;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(4)),
      Paint()..color = Color(0xffdce3ee),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width * value, size.height), Radius.circular(4)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) => value != oldDelegate.value || color != oldDelegate.color;
}
