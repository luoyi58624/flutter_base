import 'dart:convert';

import 'package:example/src/pages/examples/recycler_view/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_base/src/flutter/views/recycler_view/work_probe.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElRenderView, TextEngine;
import 'package:flutter_test/flutter_test.dart';

const _warmup = 4;
const _measured = 24;

void main() {
  testWidgets('真实纯文本行分离描述创建、完整挂载和保留文本引擎更新', (tester) async {
    final warmContent = ValueNotifier<Widget>(SizedBox());
    final coldContent = ValueNotifier<Widget>(SizedBox());
    final list = await _sourceHost(tester, warmContent: warmContent, coldContent: coldContent);
    final adapter = list.getAdapter()!;
    final warm = adapter.createViewHolder(list, 0);
    adapter.bindViewHolder(warm, 990);
    warmContent.value = warm.itemView;
    await tester.pumpAndSettle();
    final initial = _Tree.capture(warm);
    expect(initial.views, hasLength(1));
    expect(initial.engines, hasLength(1));
    expect(initial.painters, hasLength(1));
    expect(initial.paragraphs, isEmpty, reason: '当前 ElView 使用自持 TextPainter，并没有 RenderParagraph 子树');
    final idle = <int>[];
    for (var index = 0; index < 12; index++) {
      final beforeLayouts = initial.layoutCount;
      final clock = Stopwatch()..start();
      await tester.pump(Duration(milliseconds: 8));
      clock.stop();
      final after = _Tree.capture(warm);
      after.expectRetained(initial);
      expect(after.layoutCount, beforeLayouts);
      idle.add(clock.elapsedMicroseconds);
    }
    final samples = <Map<String, int>>[];
    final positions = <int>{};
    var mounted = 0, unmounted = 0;
    _Tree? previousCold;

    Future<void> update(int position, Map<String, int> sample) async {
      final before = _Tree.capture(warm);
      final builds = _BuildCapture(before.elements);
      final clock = Stopwatch()..start();
      final bindClock = Stopwatch()..start();
      adapter.bindViewHolder(warm, position);
      bindClock.stop();
      await tester.pump(Duration(milliseconds: 8));
      clock.stop();
      builds.dispose();
      final after = _Tree.capture(warm);
      after.expectRetained(initial);
      expect(_text(warm), 'Item - $position');
      expect(after.painters.single.text!.toPlainText(), 'Item - $position');
      expect(warm.getBindingAdapterPosition(), position);
      expect(after.painters.single.debugDisposed, isFalse);
      sample.addAll({
        'update_bind_callback_us': bindClock.elapsedMicroseconds,
        'update_bind_and_pump_us': clock.elapsedMicroseconds,
        'update_row_builds': builds.rowBuilds,
        'update_view_dirty_rebuild_callbacks': builds.viewBuilds,
        'update_retained_element_descriptor_changes': after.changedDescriptions(before),
        'update_view_layouts': after.layoutCount - before.layoutCount,
        'update_elements_added': after.elements.difference(initial.elements).length,
        'update_elements_removed': initial.elements.difference(after.elements).length,
        'update_render_objects_added': after.renders.difference(initial.renders).length,
        'update_render_objects_removed': initial.renders.difference(after.renders).length,
        'update_text_engines_added': after.engines.difference(initial.engines).length,
        'update_text_painters_added': after.painters.difference(initial.painters).length,
      });
    }

    Future<void> create(int position, Map<String, int> sample) async {
      final clock = Stopwatch()..start();
      final factoryClock = Stopwatch()..start();
      final holder = adapter.createViewHolder(list, 0);
      factoryClock.stop();
      final bindClock = Stopwatch()..start();
      adapter.bindViewHolder(holder, position);
      bindClock.stop();
      coldContent.value = holder.itemView;
      await tester.pump(Duration(milliseconds: 8));
      clock.stop();
      final tree = _Tree.capture(holder);
      expect(_text(holder), 'Item - $position');
      expect(tree.painters.single.text!.toPlainText(), 'Item - $position');
      expect(tree.elements.intersection(initial.elements), isEmpty);
      expect(tree.renders.intersection(initial.renders), isEmpty);
      expect(tree.engines.intersection(initial.engines), isEmpty);
      expect(tree.painters.intersection(initial.painters), isEmpty);
      final previous = previousCold;
      if (previous != null) {
        expect(tree.elements.intersection(previous.elements), isEmpty);
        expect(tree.renders.intersection(previous.renders), isEmpty);
        expect(tree.engines.intersection(previous.engines), isEmpty);
        expect(tree.painters.intersection(previous.painters), isEmpty);
      }
      sample.addAll({
        'create_description_callback_us': factoryClock.elapsedMicroseconds,
        'create_initial_bind_callback_us': bindClock.elapsedMicroseconds,
        'create_bind_mount_and_pump_us': clock.elapsedMicroseconds,
        'created_elements': tree.elements.length,
        'created_states': tree.states.length,
        'created_render_objects': tree.renders.length,
        'created_text_engines': tree.engines.length,
        'created_text_painters': tree.painters.length,
      });
      mounted++;
      final unmountClock = Stopwatch()..start();
      coldContent.value = SizedBox();
      await tester.pump(Duration(milliseconds: 8));
      unmountClock.stop();
      expect(tree.elements.every((element) => !element.mounted), isTrue);
      expect(tree.states.every((state) => !state.mounted), isTrue);
      expect(tree.renders.every((render) => render.debugDisposed == true), isTrue);
      expect(tree.painters.every((painter) => painter.debugDisposed), isTrue);
      sample['unmount_and_pump_us'] = unmountClock.elapsedMicroseconds;
      unmounted++;
      previousCold = tree;
    }

    // 跨过999/1000让文本实际改变长度，同时交替先后顺序，避免固定享受后一半预热。
    for (var index = 0; index < _warmup + _measured; index++) {
      final position = 994 + index;
      final sample = <String, int>{'position': position, 'create_first': index.isOdd ? 1 : 0};
      if (index.isOdd) {
        await create(position, sample);
        await update(position, sample);
      } else {
        await update(position, sample);
        await create(position, sample);
      }
      if (index >= _warmup) {
        samples.add(sample);
        positions.add(position);
      }
    }
    expect(positions, hasLength(_measured));
    expect(positions, containsAll([999, 1000]));
    expect(mounted, unmounted);
    expect(tester.takeException(), isNull);
    _emit('actual_holder_create_vs_update', {
      'source': 'actual RecyclerTextPage Adapter/ViewHolder/itemView; two visible isolated slots',
      'tree': initial.counts,
      'warmup_operations': _warmup,
      'measured_operations': _measured,
      'different_measured_positions': positions.toList(),
      'idle_pump': _timings(idle),
      'timings': {
        for (final field in [
          'create_description_callback_us',
          'create_initial_bind_callback_us',
          'create_bind_mount_and_pump_us',
          'update_bind_callback_us',
          'update_bind_and_pump_us',
          'unmount_and_pump_us',
        ])
          field: _timings(samples.map((sample) => sample[field]!).toList()),
      },
      'total_cold_mounts': mounted,
      'total_cold_unmounts': unmounted,
      'raw_samples_us': samples,
    });
    await tester.pumpWidget(SizedBox());
    expect(initial.painters.every((painter) => painter.debugDisposed), isTrue);
    warmContent.dispose();
    coldContent.dispose();
  });

  testWidgets('真实文本配置的 TextPainter 单独比较新建排版与保留实例换文排版', (tester) async {
    final warmContent = ValueNotifier<Widget>(SizedBox());
    final coldContent = ValueNotifier<Widget>(SizedBox());
    final list = await _sourceHost(tester, warmContent: warmContent, coldContent: coldContent);
    final adapter = list.getAdapter()!;
    final holder = adapter.createViewHolder(list, 0);
    adapter.bindViewHolder(holder, 990);
    warmContent.value = holder.itemView;
    await tester.pumpAndSettle();
    final source = _Tree.capture(holder).painters.single;
    final style = source.text!.style;
    TextPainter newPainter(int position) => TextPainter(
      text: TextSpan(text: 'Item - $position', style: style),
      textAlign: source.textAlign,
      textDirection: source.textDirection,
      textScaler: source.textScaler,
      locale: source.locale,
      maxLines: source.maxLines,
      ellipsis: source.ellipsis,
      strutStyle: source.strutStyle,
      textWidthBasis: source.textWidthBasis,
      textHeightBehavior: source.textHeightBehavior,
    );
    final retained = newPainter(990)..layout(maxWidth: 390);
    final samples = <Map<String, int>>[];
    for (var index = 0; index < _warmup + _measured; index++) {
      final position = 994 + index;
      final sample = <String, int>{'position': position, 'create_first': index.isOdd ? 1 : 0};
      void update() {
        final clock = Stopwatch()..start();
        retained.text = TextSpan(text: 'Item - $position', style: style);
        retained.layout(maxWidth: 390);
        clock.stop();
        sample['retained_painter_set_text_and_layout_us'] = clock.elapsedMicroseconds;
        expect(retained.text!.toPlainText(), 'Item - $position');
        expect(retained.debugDisposed, isFalse);
      }

      void create() {
        final clock = Stopwatch()..start();
        final painter = newPainter(position)..layout(maxWidth: 390);
        clock.stop();
        sample['new_painter_and_layout_us'] = clock.elapsedMicroseconds;
        expect(painter.text!.toPlainText(), 'Item - $position');
        expect(painter.size, retained.size);
        painter.dispose();
        expect(painter.debugDisposed, isTrue);
      }

      if (index.isOdd) {
        // 尺寸只依赖同一文本与配置；更新后再比较两者，避免上一字符串跨位数时的差异。
        final clock = Stopwatch()..start();
        final painter = newPainter(position)..layout(maxWidth: 390);
        clock.stop();
        sample['new_painter_and_layout_us'] = clock.elapsedMicroseconds;
        update();
        expect(painter.size, retained.size);
        painter.dispose();
        expect(painter.debugDisposed, isTrue);
      } else {
        update();
        create();
      }
      if (index >= _warmup) samples.add(sample);
    }
    _emit('text_painter_same_configuration_control', {
      'source': 'separate TextPainter instances configured from the actual ElView painter',
      'scope': 'set text + layout only; no Widget/Element/RenderObject pipeline or pump',
      'font_family': style?.fontFamily,
      'font_size': style?.fontSize,
      'text_direction': source.textDirection.toString(),
      'width_constraint': 390,
      'warmup_operations': _warmup,
      'measured_operations': _measured,
      'timings': {
        for (final field in ['new_painter_and_layout_us', 'retained_painter_set_text_and_layout_us'])
          field: _timings(samples.map((sample) => sample[field]!).toList()),
      },
      'raw_samples_us': samples,
    });
    retained.dispose();
    await tester.pumpWidget(SizedBox());
    warmContent.dispose();
    coldContent.dispose();
  });

  for (final smallShift in [false, true]) {
    for (final prefetchEnabled in [false, true]) {
      testWidgets('真实万条文本${prefetchEnabled ? '默认缓存预取' : '关闭缓存预取'}${smallShift ? '每帧3px小幅平移' : '快速跨屏'}记录工作量与结构保留', (
        tester,
      ) async {
        final content = ValueNotifier<Widget>(SizedBox());
        await _open(
          tester,
          Scaffold(
            body: Stack(
              children: [
                Offstage(child: RecyclerTextPage()),
                Align(
                  alignment: .topLeft,
                  child: ValueListenableBuilder(valueListenable: content, builder: (_, child, _) => child),
                ),
              ],
            ),
          ),
        );
        final source = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView, skipOffstage: false));
        final counted = _CountingAdapter(source.getAdapter()!);
        final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(prefetchEnabled);
        final list = rv.RecyclerView()
          ..setAdapter(counted)
          ..setLayoutManager(layout)
          ..setItemViewCacheSize(prefetchEnabled ? 2 : 0);
        // 挂载前完成配置；避免测试计数器安装过程触发无关的运行时换适配器生命周期。
        content.value = SizedBox(width: 390, height: 600, child: list);
        await tester.pumpAndSettle();
        list.scrollToPosition(1000);
        await tester.pumpAndSettle();
        final extent = tester.getSize(find.byWidget(_visible(list).first.itemView)).height;
        expect(extent, greaterThan(0));
        final distance = smallShift ? 3.0 : extent * (layout.getChildCount() + 4);
        for (var index = 0; index < _warmup; index++) {
          list.scrollBy(0, distance);
          await tester.pump(Duration(milliseconds: 8));
        }
        final beforeMeasured = _mountedTrees(counted);
        final beforeCreated = counted.created.length;
        final initialVisiblePositions = _visible(list).map((holder) => holder.getBindingAdapterPosition()).toSet();
        final newlyVisiblePositions = <int>{};
        final initial = {for (final entry in beforeMeasured.entries) entry.key: entry.value};
        final samples = <Map<String, int>>[];
        final dataPositions = <rv.ViewHolder, Set<int>>{};
        var totalCrossRecord = 0;
        for (var index = 0; index < _measured; index++) {
          final before = _mountedTrees(counted);
          final positionsBefore = {for (final holder in before.keys) holder: holder.getBindingAdapterPosition()};
          final hostsBefore = {for (final holder in before.keys) holder: _hostWidget(holder)};
          final firstBefore = layout.findFirstVisibleItemPosition();
          final lastBefore = layout.findLastVisibleItemPosition();
          final beforeBinds = counted.bindings.length;
          final beforeCreates = counted.created.length;
          final elements = {for (final tree in before.values) ...tree.elements};
          final builds = _BuildCapture(elements);
          final coreBefore = _coreWork();
          final clock = Stopwatch()..start();
          list.scrollBy(0, index < _measured ~/ 2 ? distance : -distance);
          await tester.pump(Duration(milliseconds: 8));
          clock.stop();
          final coreAfter = _coreWork();
          builds.dispose();
          final after = _mountedTrees(counted);
          final visibleAfter = _visible(list);
          var additions = 0, removals = 0, layouts = 0, rebindings = 0;
          var changedDescriptions = 0, disposedPainters = 0, hostChanges = 0;
          for (final entry in before.entries) {
            final holder = entry.key;
            final next = after[holder];
            if (next == null) {
              disposedPainters += entry.value.painters.where((painter) => painter.debugDisposed).length;
              removals += entry.value.elements.length;
              continue;
            }
            next.expectRetained(entry.value);
            if (!identical(_hostWidget(holder), hostsBefore[holder])) hostChanges++;
            additions += next.elements.difference(entry.value.elements).length;
            removals += entry.value.elements.difference(next.elements).length;
            layouts += next.layoutCount - entry.value.layoutCount;
            changedDescriptions += next.changedDescriptions(entry.value);
            final position = holder.getBindingAdapterPosition();
            if (position != rv.RecyclerView.NO_POSITION && position != positionsBefore[holder]) {
              rebindings++;
              dataPositions.putIfAbsent(holder, () => {}).add(position);
              expect(_text(holder), 'Item - $position');
              expect(next.painters.single.text!.toPlainText(), 'Item - $position');
            }
          }
          totalCrossRecord += rebindings;
          expect(additions, 0);
          expect(removals, 0);
          expect(disposedPainters, 0);
          final sample = {
            'frame': index,
            'full_scroll_and_pump_us': clock.elapsedMicroseconds,
            'bind_callbacks': counted.bindings.length - beforeBinds,
            'new_holders': counted.created.length - beforeCreates,
            'same_holder_cross_record_updates': rebindings,
            'elements_added': additions,
            'elements_removed': removals,
            'text_painters_disposed': disposedPainters,
            'view_layouts': layouts,
            'row_builds': builds.rowBuilds,
            'view_dirty_rebuild_callbacks': builds.viewBuilds,
            'retained_element_descriptor_changes': changedDescriptions,
            'host_wrapper_descriptor_changes': hostChanges,
            'visible_first_before': firstBefore,
            'visible_last_before': lastBefore,
            'visible_first_after': layout.findFirstVisibleItemPosition(),
            'visible_last_after': layout.findLastVisibleItemPosition(),
            'visible_holders': layout.getChildCount(),
            'mounted_holders': after.length,
            'hidden_bound_holders': counted.holders
                .where((holder) => holder.getBindingAdapterPosition() >= 0 && !visibleAfter.contains(holder))
                .length,
            for (final entry in coreAfter.entries) 'core_${entry.key}': entry.value - coreBefore[entry.key]!,
          };
          samples.add(sample);
          for (final holder in visibleAfter) {
            final position = holder.getBindingAdapterPosition();
            if (!initialVisiblePositions.contains(position)) newlyVisiblePositions.add(position);
            expect(_text(holder), 'Item - $position');
          }
          expect(tester.takeException(), isNull);
        }
        if (smallShift) {
          // 默认缓存可能完全命中已有绑定；进入新记录并不等于必须再次触发 bind。
          expect(newlyVisiblePositions, isNotEmpty);
        } else {
          expect(totalCrossRecord, greaterThan(_measured));
        }
        final finalTrees = _mountedTrees(counted);
        for (final entry in initial.entries) {
          finalTrees[entry.key]!.expectRetained(entry.value);
        }
        _emit('actual_text_page_scroll', {
          'source': 'actual RecyclerTextPage Adapter/ViewHolder/row; forwarding counters in a fresh viewport without AppBar/scrollbar',
          'items': counted.getItemCount(),
          'scroll_kind': smallShift ? 'small_3px' : 'fast_full_window',
          'step_per_frame': distance,
          'cache_items': prefetchEnabled ? 2 : 0,
          'prefetch': prefetchEnabled,
          'prefetch_item_count': layout.getInitialPrefetchItemCount(),
          'prefetch_budget': 'unchanged production clock path; flutter_test virtual frame timestamps may select conservative 1ms fallback',
          'warmup_scroll_frames': _warmup,
          'measured_scroll_frames': _measured,
          'row_height': extent,
          'scroll_distance_per_frame': distance,
          'mounted_holders_before_measuring': initial.length,
          'new_holders_during_measurement': counted.created.length - beforeCreated,
          'cross_record_updates': totalCrossRecord,
          'newly_visible_positions': newlyVisiblePositions.toList()..sort(),
          'different_positions_per_holder': dataPositions.values.map((positions) => positions.length).toList(),
          'row_tree': initial.values.first.counts,
          'scroll_and_pump': _timings(samples.map((sample) => sample['full_scroll_and_pump_us']!).toList()),
          'synchronous_recycler_layout': _timings(
            samples.map((sample) => sample['core_layout_microseconds']!).toList(),
          ),
          'total_work': {
            for (final field in [
              'bind_callbacks',
              'new_holders',
              'same_holder_cross_record_updates',
              'elements_added',
              'elements_removed',
              'text_painters_disposed',
              'view_layouts',
              'row_builds',
              'view_dirty_rebuild_callbacks',
              'retained_element_descriptor_changes',
              'host_wrapper_descriptor_changes',
              'core_full_layouts',
              'core_translated_layouts',
              'core_item_layout_visits',
              'core_prefix_queries',
              'core_layout_microseconds',
            ])
              field: samples.fold(0, (sum, sample) => sum + sample[field]!),
          },
          'raw_samples_us': samples,
        });
        await tester.pumpWidget(SizedBox());
        expect(initial.values.expand((tree) => tree.painters).every((painter) => painter.debugDisposed), isTrue);
        content.dispose();
      });
    }
  }
}

Future<rv.RecyclerView> _sourceHost(
  WidgetTester tester, {
  required ValueNotifier<Widget> warmContent,
  required ValueNotifier<Widget> coldContent,
}) async {
  await _open(
    tester,
    Scaffold(
      body: Stack(
        children: [
          Offstage(child: RecyclerTextPage()),
          Align(
            alignment: .topLeft,
            child: Column(children: [_slot(warmContent), _slot(coldContent)]),
          ),
        ],
      ),
    ),
  );
  final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView, skipOffstage: false));
  list.setItemViewCacheSize(0);
  (list.getLayoutManager()! as rv.LinearLayoutManager).setItemPrefetchEnabled(false);
  await tester.pumpAndSettle();
  return list;
}

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _slot(ValueNotifier<Widget> content) => SizedBox(
  width: 390,
  height: 48,
  child: Align(
    alignment: .topLeft,
    child: RepaintBoundary(
      child: SizedBox(
        width: 390,
        child: ValueListenableBuilder(valueListenable: content, builder: (_, child, _) => child),
      ),
    ),
  ),
);

Set<rv.ViewHolder> _visible(rv.RecyclerView list) {
  final layout = list.getLayoutManager()! as rv.LinearLayoutManager;
  return {
    for (var index = layout.findFirstVisibleItemPosition(); index <= layout.findLastVisibleItemPosition(); index++)
      ?list.findViewHolderForAdapterPosition(index),
  };
}

Map<rv.ViewHolder, _Tree> _mountedTrees(_CountingAdapter adapter) => {
  for (final holder in adapter.holders)
    if (find.byWidget(holder.itemView, skipOffstage: false).evaluate().isNotEmpty) holder: _Tree.capture(holder),
};

Widget _hostWidget(rv.ViewHolder holder) => find
    .ancestor(
      of: find.byWidget(holder.itemView, skipOffstage: false),
      matching: find.byType(TickerMode, skipOffstage: false),
    )
    .evaluate()
    .first
    .widget;

Map<String, int> _coreWork() {
  // 示例包的白盒测试只读取 assert 探针，不把内部计数器变成业务 API。
  // ignore: invalid_use_of_internal_member
  return RecyclerWorkProbe.snapshot();
}

String _text(rv.ViewHolder holder) =>
    (find
                    .descendant(
                      of: find.byWidget(holder.itemView, skipOffstage: false),
                      matching: find.byType(ElView, skipOffstage: false),
                      matchRoot: true,
                    )
                    .evaluate()
                    .single
                    .widget
                as ElView)
            .child
        as String;

Map<String, num> _timings(List<int> samples) {
  final sorted = [...samples]..sort();
  num p(double value) => sorted[(sorted.length * value).ceil() - 1] / 1000;
  return {'p50_ms': p(.5), 'p95_ms': p(.95), 'max_ms': p(1)};
}

void _emit(String scenario, Map<String, Object?> values) => debugPrint(
  'RECYCLER_TEXT_COST ${jsonEncode({'label': const String.fromEnvironment('RECYCLER_TEXT_LABEL', defaultValue: 'unlabelled'), 'scenario': scenario, 'environment': 'headless flutter_test / Debug JIT / Ahem; host wall time, not device FrameTiming/FPS', 'timing_scope': 'pump timings include the test/framework build-layout-paint pipeline; separate TextPainter control excludes that pipeline; do not subtract idle pump to claim net cost', 'text_backend': 'ElView.TextEngine owns a TextPainter; this row has no RenderParagraph', ...values})}',
);

class _Tree {
  _Tree(
    this.elements,
    this.states,
    this.renders,
    this.views,
    this.engines,
    this.painters,
    this.layoutCount,
    this.widgets,
  );

  factory _Tree.capture(rv.ViewHolder holder) {
    final elements = <Element>{};
    void visitElement(Element element) {
      elements.add(element);
      element.visitChildren(visitElement);
    }

    final root = find.byWidget(holder.itemView, skipOffstage: false).evaluate().single;
    visitElement(root);
    final renders = <RenderObject>{};
    void visitRender(RenderObject render) {
      if (!renders.add(render)) return;
      render.visitChildren(visitRender);
    }

    visitRender(root.renderObject!);
    final views = renders.whereType<ElRenderView>().toSet();
    final engines = {for (final view in views) ?view.textEngineForTest};
    final painters = {for (final engine in engines) engine.painterForTest};
    return _Tree(
      elements,
      elements.whereType<StatefulElement>().map((element) => element.state).toSet(),
      renders,
      views,
      engines,
      painters,
      views.fold(0, (sum, view) => sum + view.debugLayoutCount),
      {for (final element in elements) element: element.widget},
    );
  }

  final Set<Element> elements;
  final Set<State> states;
  final Set<RenderObject> renders;
  final Set<ElRenderView> views;
  final Set<TextEngine> engines;
  final Set<TextPainter> painters;
  final int layoutCount;
  final Map<Element, Widget> widgets;
  Set<RenderParagraph> get paragraphs => renders.whereType<RenderParagraph>().toSet();

  Map<String, int> get counts => {
    'elements': elements.length,
    'states': states.length,
    'render_objects': renders.length,
    'el_render_views': views.length,
    'text_engines': engines.length,
    'text_painters': painters.length,
    'render_paragraphs': paragraphs.length,
  };

  int changedDescriptions(_Tree previous) => elements
      .intersection(previous.elements)
      .where((element) => !identical(widgets[element], previous.widgets[element]))
      .length;

  void expectRetained(_Tree previous) {
    expect(elements, previous.elements);
    expect(states, previous.states);
    expect(renders, previous.renders);
    expect(views, previous.views);
    expect(engines, previous.engines);
    expect(painters, previous.painters);
  }
}

class _CountingAdapter extends rv.Adapter<rv.ViewHolder> {
  _CountingAdapter(this.source) {
    setHasStableIds(source.hasStableIds());
  }
  final rv.Adapter source;
  final holders = <rv.ViewHolder>{};
  final created = <rv.ViewHolder>[];
  final bindings = <int>[];

  @override
  int getItemCount() => source.getItemCount();
  @override
  int getItemId(int position) => source.getItemId(position);
  @override
  int getItemViewType(int position) => source.getItemViewType(position);
  @override
  rv.ViewHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final holder = source.onCreateViewHolder(parent, viewType);
    holders.add(holder);
    created.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(rv.ViewHolder holder, int position, [List<Object> payloads = const []]) {
    // swapAdapter 可沿用原适配器已经创建的池项，也必须纳入全部身份跟踪。
    holders.add(holder);
    bindings.add(position);
    source.onBindViewHolder(holder, position, payloads);
  }

  @override
  void onViewRecycled(rv.ViewHolder holder) => source.onViewRecycled(holder);
  @override
  void onViewAttachedToWindow(rv.ViewHolder holder) => source.onViewAttachedToWindow(holder);
  @override
  void onViewDetachedFromWindow(rv.ViewHolder holder) => source.onViewDetachedFromWindow(holder);
}

class _BuildCapture {
  _BuildCapture(this.elements) : previous = debugOnRebuildDirtyWidget {
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (!elements.contains(element)) return;
      if (element.widget.runtimeType.toString() == '_TextRow') rowBuilds++;
      if (element.widget is ElView) viewBuilds++;
    };
  }

  final Set<Element> elements;
  final RebuildDirtyWidgetCallback? previous;
  int rowBuilds = 0;
  int viewBuilds = 0;
  void dispose() => debugOnRebuildDirtyWidget = previous;
}
