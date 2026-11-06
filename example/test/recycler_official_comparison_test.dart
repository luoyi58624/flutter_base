import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:example/src/pages/examples/recycler_view/cards.dart';
import 'package:example/src/pages/examples/recycler_view/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_base/src/flutter/views/recycler_view/work_probe.dart';
import 'package:flutter_test/flutter_test.dart';

part 'recycler_comparison_profile.dart';

const _warmup = 8;
const _samplesPerLeg = 24;
const _width = 390.0;
const _height = 600.0;
const _detail = bool.fromEnvironment('RECYCLER_COMPARE_DETAIL');
const _semantics = !bool.fromEnvironment('RECYCLER_COMPARE_DISABLE_SEMANTICS');
const _order = String.fromEnvironment('RECYCLER_COMPARE_ORDER', defaultValue: 'LRRL');

void main() {
  for (final cards in [false, true]) {
    for (final motion in ['small', 'row', 'fast']) {
      final content = cards ? 'cards' : 'text';
      testWidgets('官方 ListView 与 RecyclerView 同条件 $content/$motion', (tester) async {
        expect(_order, isIn(['LRRL', 'RLLR']), reason: '只接受两种平衡的 ABBA 顺序');
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(_width, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        expect(tester.binding.semanticsEnabled, _semantics, reason: '测试标签必须与实际语义管线状态一致');
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        _ComparisonProfile? profile;
        try {
          if (_profile) profile = await _ComparisonProfile.open(tester);
          final fixture = await _Fixture.open(tester, cards: cards);
          final legs = <Map<String, Object?>>[];
          List<_VisibleFrame>? reference;
          double? referenceExtent;
          double? referenceStep;
          for (var leg = 0; leg < _order.length; leg++) {
            final recycler = _order[leg] == 'R';
            final work = _Work();
            final controller = ScrollController(keepScrollOffset: false);
            rv.RecyclerView? list;
            final Widget scroller;
            if (recycler) {
              list = rv.RecyclerView(controller: controller)
                ..setAdapter(_Adapter(fixture.adapter, work))
                ..setLayoutManager(rv.LinearLayoutManager()..setItemPrefetchEnabled(false))
                ..setItemViewCacheSize(0);
              scroller = list;
            } else {
              scroller = ListView.builder(
                controller: controller,
                padding: .zero,
                scrollCacheExtent: ScrollCacheExtent.pixels(0),
                itemCount: fixture.count,
                // 官方复杂卡片原本声明了 itemExtent；不移除它，也不替 RV 增加等价捷径。
                itemExtent: fixture.itemExtent,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemBuilder: (context, position) {
                  work.created++;
                  var child = fixture.builder(context, position)!;
                  // 实际卡片的 builder 自带边界；两边只保留滚动容器提供的那一个边界。
                  if (child is RepaintBoundary) child = child.child!;
                  return _RowProbe(_RowLife(work, position), child: child);
                },
              );
            }
            final viewport = GlobalKey();
            fixture.measured.value = ScrollConfiguration(
              behavior: _Behavior(),
              child: SizedBox(key: viewport, width: _width, height: _height, child: scroller),
            );
            await tester.pumpAndSettle();
            final viewportBox = viewport.currentContext!.findRenderObject()! as RenderBox;
            final first = _visible(work, list, viewportBox).rows.first;
            final extent = first.height;
            expect(extent, greaterThan(0));
            if (referenceExtent != null) expect(extent, closeTo(referenceExtent, .001));
            referenceExtent ??= extent;
            final step = switch (motion) {
              'small' => 3.0,
              'row' => extent,
              _ => _height * 1.5,
            };
            if (referenceStep != null) expect(step, closeTo(referenceStep, .001));
            referenceStep ??= step;
            final base = extent * 100;
            for (var frame = 0; frame < _warmup; frame++) {
              controller.jumpTo(base + step * (frame + 1));
              await tester.pump(Duration(microseconds: 8333));
            }
            // 在计时前完成初次挂载留下的保守几何失效，不把夹具初始化算成滚动成本。
            await tester.pump();
            final idle = <int>[];
            for (var frame = 0; frame < 4; frame++) {
              final clock = Stopwatch()..start();
              await tester.pump(Duration(microseconds: 8333));
              clock.stop();
              idle.add(clock.elapsedMicroseconds);
            }
            final captures = <_VisibleFrame>[];
            final samples = <Map<String, Object?>>[];
            final builds = _BuildEvents();
            final initialCreated = work.created;
            final initialBinds = work.binds;
            final initialDisposed = work.disposed;
            final start = base + step * _warmup;
            if (profile != null) await profile.startLeg(leg);
            try {
              for (var frame = 0; frame < _samplesPerLeg; frame++) {
                final before = work.snapshot();
                final coreBefore = _coreWork();
                final forward = frame < _samplesPerLeg ~/ 2;
                final delta = forward ? frame + 1 : _samplesPerLeg - frame - 1;
                final target = start + step * delta;
                builds.begin();
                final trace = profile?.beginFrame(leg, frame);
                final clock = Stopwatch()..start();
                try {
                  controller.jumpTo(target);
                  await tester.pump(Duration(microseconds: 8333));
                } finally {
                  clock.stop();
                  trace?.finish();
                }
                builds.finish(work, viewport.currentContext! as Element);
                final coreAfter = _coreWork();
                final after = work.snapshot();
                // 真实内容、几何扫描和断言都在完整帧的计时区间之外。
                final visible = _visible(work, list, viewportBox);
                captures.add(visible);
                expect(controller.offset, closeTo(target, .001), reason: '两边必须执行完全相同的像素轨迹');
                expect(visible.rows, isNotEmpty);
                _expectContent(visible, cards: cards);
                if (reference != null) visible.expectSame(reference[frame]);
                final workload = {for (final key in after.keys) key: after[key]! - before[key]!};
                samples.add({
                  'frame': frame,
                  'direction': forward ? 'forward' : 'backward',
                  'target_pixels': target,
                  'actual_pixels': controller.offset,
                  'scroll_and_full_pump_us': clock.elapsedMicroseconds,
                  'work': workload,
                  if (recycler)
                    'recycler_core_work': {for (final key in coreAfter.keys) key: coreAfter[key]! - coreBefore[key]!},
                  'mounted_probe_rows': work.boxes.length,
                  'visible': visible.toJson(),
                  'matched_reference': reference != null,
                });
              }
            } finally {
              builds.dispose();
            }
            final timeline = profile == null ? null : await profile.finishLeg(leg);
            reference ??= captures;
            final allPositions = {for (final frame in captures) ...frame.rows.map((row) => row.position)};
            expect(allPositions.length, greaterThan(1));
            if (motion != 'small') {
              expect(
                work.created - initialCreated + work.binds - initialBinds,
                greaterThan(0),
                reason: '较大位移必须实际填充新记录',
              );
            }
            expect(tester.takeException(), isNull);
            legs.add({
              'leg': leg,
              'mode': recycler ? 'RecyclerView' : 'ListView',
              'sample_count': samples.length,
              'measured_unique_visible_positions': allPositions.length,
              'timings': _timings(samples.map((sample) => sample['scroll_and_full_pump_us']! as int).toList()),
              'idle_full_pump': _timings(idle),
              'measured_work': _totalWork(samples),
              'measured_created_rows': work.created - initialCreated,
              'measured_disposed_rows': work.disposed - initialDisposed,
              'raw_samples': samples,
              'timeline_profile': ?timeline,
            });
            fixture.measured.value = SizedBox();
            await tester.pumpAndSettle();
            expect(work.boxes, isEmpty, reason: '离开测量通道必须释放本通道所有探针和真实行');
            controller.dispose();
          }
          final modes = <String, Object?>{};
          for (final mode in ['ListView', 'RecyclerView']) {
            final modeLegs = legs.where((leg) => leg['mode'] == mode);
            final raw = <Map<String, Object?>>[
              for (final leg in modeLegs) ...(leg['raw_samples']! as List<Map<String, Object?>>),
            ];
            expect(raw.length, 48);
            modes[mode] = {
              'sample_count': raw.length,
              'timings': _timings(raw.map((sample) => sample['scroll_and_full_pump_us']! as int).toList()),
              'work': _totalWork(raw),
            };
          }
          debugPrint(
            'RECYCLER_OFFICIAL_COMPARISON ${jsonEncode({
              'label': const String.fromEnvironment('RECYCLER_COMPARE_LABEL', defaultValue: 'current'),
              'scenario': content,
              'motion': motion,
              'order': _order,
              'environment': 'headless flutter_test / Debug JIT / test font Ahem; host wall time, not device FrameTiming/FPS',
              'timing_scope': 'controller.jumpTo + one complete pump including semantics; no finder/assert/tree scan in timer; idle is reported without subtraction',
              'probe_scope': 'one identical non-boundary RenderProxyBox per row; row layout/paint callbacks, not global pipeline phases',
              'creation_counter_scope': 'ListView actual itemBuilder calls; RecyclerView actual holder factory calls; not equal allocation counts',
              'build_counter_scope': _detail ? 'actual _TextRow/_ObservationRow body callbacks; official text directly returns ElView and has no body Widget wrapper' : 'disabled; RECYCLER_COMPARE_DETAIL=true enables the global build callback and detailed timers in a separate diagnostic run',
              'detail_timers_enabled': _detail,
              'timeline_profiling_enabled': _profile,
              'render_timeline_profiling_enabled': _profile && _profileRender,
              'item_count': fixture.count,
              'viewport': {'width': _width, 'height': _height, 'device_pixel_ratio': 1},
              'text_scale': 1,
              'semantics_enabled': _semantics,
              'shadows_enabled': !debugDisableShadows,
              'images_predecoded': fixture.imagesPredecoded,
              'official_item_extent': fixture.itemExtent,
              'recycler_fixed_item_extent': null,
              'cache': {'official_cache_extent': 0, 'recycler_item_cache_size': 0, 'recycler_prefetch': false},
              'keep_alive': false,
              'per_item_repaint_boundaries': 1,
              'physics': 'ClampingScrollPhysics; programmatic identical absolute offsets',
              'padding': 0,
              'step_per_frame': referenceStep,
              'warmup_per_leg': _warmup,
              'measured_samples_per_leg': _samplesPerLeg,
              'geometry_and_actual_content_matched_across_legs': true,
              'modes': modes,
              'legs': legs,
            })}',
          );
          await tester.pumpWidget(SizedBox());
          fixture.dispose();
          expect(tester.takeException(), isNull);
        } finally {
          try {
            if (profile != null) await profile.close();
          } finally {
            debugDisableShadows = previousShadows;
          }
        }
      }, semanticsEnabled: _semantics);
    }
  }
}

class _Fixture {
  _Fixture(this.adapter, this.builder, this.itemExtent, this.measured, this.hideSource, this.imagesPredecoded);

  final rv.Adapter adapter;
  final NullableIndexedWidgetBuilder builder;
  final double? itemExtent;
  final ValueNotifier<Widget> measured;
  final ValueNotifier<bool> hideSource;
  final int imagesPredecoded;
  int get count => adapter.getItemCount();

  static Future<_Fixture> open(WidgetTester tester, {required bool cards}) async {
    final measured = ValueNotifier<Widget>(SizedBox());
    final hideSource = ValueNotifier(false);
    final page = cards ? RecyclerCardsPage() : RecyclerTextPage();
    final sourceKey = GlobalKey();
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: child!,
          ),
          home: Scaffold(
            body: Stack(
              children: [
                ValueListenableBuilder(
                  valueListenable: hideSource,
                  child: SizedBox(key: sourceKey, child: page),
                  builder: (_, hidden, child) => Offstage(offstage: hidden, child: child),
                ),
                Align(
                  alignment: .topLeft,
                  child: ValueListenableBuilder(valueListenable: measured, builder: (_, child, _) => child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final original = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
    final adapter = original.getAdapter()!;
    expect(adapter.getItemCount(), 10000);
    final prefix = cards ? 'cards' : 'text';
    await tester.tap(find.byKey(ValueKey('$prefix-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('$prefix-mode-listView')));
    await tester.pumpAndSettle();
    final official = tester.widget<ListView>(find.byKey(ValueKey('official-$prefix-list')));
    final builder = (official.childrenDelegate as SliverChildBuilderDelegate).builder;
    var imageCount = 0;
    if (cards) {
      final images = find.descendant(of: find.byKey(sourceKey), matching: find.byType(Image)).evaluate().toList();
      expect(images.length, greaterThanOrEqualTo(2), reason: '两种真实卡片照片都必须在计时前预解码');
      await tester.runAsync(() async {
        await Future.wait([for (final element in images) precacheImage((element.widget as Image).image, element)]);
      });
      imageCount = images.length;
      await tester.pumpAndSettle();
    }
    // 仅保留实际页面对业务记录和模型的所有权，不在测量通道复制一份卡片实现。
    hideSource.value = true;
    await tester.pumpAndSettle();
    return _Fixture(adapter, builder, official.itemExtent, measured, hideSource, imageCount);
  }

  void dispose() {
    measured.dispose();
    hideSource.dispose();
  }
}

class _Adapter extends rv.Adapter<_Holder> {
  _Adapter(this.source, this.work) {
    setHasStableIds(source.hasStableIds());
  }

  final rv.Adapter source;
  final _Work work;

  @override
  int getItemCount() => source.getItemCount();
  @override
  int getItemId(int position) => source.getItemId(position);
  @override
  int getItemViewType(int position) => source.getItemViewType(position);
  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    work.created++;
    return _Holder(source.onCreateViewHolder(parent, viewType), _RowLife(work, -1));
  }

  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) {
    work.binds++;
    holder.life.position = position;
    // 身份由外层真实 RecyclerView 管理，只转发原适配器绑定，避免重复执行绑定簿记。
    source.onBindViewHolder(holder.source, position, payloads);
  }

  @override
  void onViewRecycled(_Holder holder) => source.onViewRecycled(holder.source);
  @override
  bool onFailedToRecycleView(_Holder holder) => source.onFailedToRecycleView(holder.source);
  @override
  void onViewAttachedToWindow(_Holder holder) => source.onViewAttachedToWindow(holder.source);
  @override
  void onViewDetachedFromWindow(_Holder holder) => source.onViewDetachedFromWindow(holder.source);
}

class _Holder extends rv.ViewHolder {
  _Holder(this.source, this.life) : super(_RowProbe(life, child: source.itemView));
  final rv.ViewHolder source;
  final _RowLife life;
}

class _RowLife {
  _RowLife(this.work, this.position);
  final _Work work;
  int position;
  Element? element;
  _RenderRowProbe? box;
}

class _RowProbe extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _RowProbe(this.life, {required super.child});
  final _RowLife life;

  @override
  _RenderRowProbe createRenderObject(BuildContext context) {
    life.element = context as Element;
    return life.box = _RenderRowProbe(life);
  }
}

class _RenderRowProbe extends RenderProxyBox {
  _RenderRowProbe(this.life) {
    life.work.boxes.add(this);
    life.work.mounted++;
  }

  final _RowLife life;

  @override
  void performLayout() {
    life.work.layouts++;
    final clock = _detail ? (Stopwatch()..start()) : null;
    super.performLayout();
    if (clock != null) life.work.layoutUs += (clock..stop()).elapsedMicroseconds;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    life.work.paints++;
    final clock = _detail ? (Stopwatch()..start()) : null;
    super.paint(context, offset);
    if (clock != null) life.work.paintUs += (clock..stop()).elapsedMicroseconds;
  }

  @override
  void dispose() {
    life.work.boxes.remove(this);
    life.work.disposed++;
    life.box = null;
    life.element = null;
    super.dispose();
  }
}

class _Work {
  final boxes = <_RenderRowProbe>{};
  int created = 0, binds = 0, mounted = 0, disposed = 0;
  int layouts = 0, paints = 0, layoutUs = 0, paintUs = 0;
  int bodies = 0, officialShells = 0, leaves = 0, elViews = 0;

  Map<String, int> snapshot() => {
    'row_descriptions_created': created,
    'recycler_bind_callbacks': binds,
    'probe_render_objects_created': mounted,
    'probe_render_objects_disposed': disposed,
    'row_layout_callbacks': layouts,
    'row_paint_callbacks': paints,
    if (_detail) 'business_body_build_callbacks': bodies,
    if (_detail) 'official_card_shell_build_callbacks': officialShells,
    if (_detail) 'listenable_leaf_build_callbacks': leaves,
    if (_detail) 'el_view_dirty_rebuild_callbacks': elViews,
    if (_detail) 'row_layout_subtree_us': layoutUs,
    if (_detail) 'row_paint_subtree_us': paintUs,
  };
}

class _BuildEvents {
  _BuildEvents() : previous = debugOnRebuildDirtyWidget {
    if (!_detail) return;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (!active) return;
      final widget = element.widget;
      final type = widget.runtimeType.toString();
      if (widget is ElView ||
          type == '_TextRow' ||
          type == '_ObservationRow' ||
          type == '_OfficialObservationRow' ||
          type.startsWith('ValueListenableBuilder<')) {
        pending.update(element, (count) => count + 1, ifAbsent: () => 1);
      }
    };
  }

  final RebuildDirtyWidgetCallback? previous;
  final pending = <Element, int>{};
  bool active = false;

  void begin() {
    if (!_detail) return;
    pending.clear();
    active = true;
  }

  void finish(_Work work, Element root) {
    if (!_detail) return;
    active = false;
    for (final entry in pending.entries) {
      final element = entry.key;
      if (!element.mounted) continue;
      var belongs = identical(element, root);
      element.visitAncestorElements((parent) {
        if (identical(parent, root)) {
          belongs = true;
          return false;
        }
        return true;
      });
      if (!belongs) continue;
      final widget = element.widget;
      final type = widget.runtimeType.toString();
      if (type == '_TextRow' || type == '_ObservationRow') work.bodies += entry.value;
      if (type == '_OfficialObservationRow') work.officialShells += entry.value;
      if (type.startsWith('ValueListenableBuilder<')) work.leaves += entry.value;
      if (widget is ElView) work.elViews += entry.value;
    }
    pending.clear();
  }

  void dispose() {
    if (_detail) debugOnRebuildDirtyWidget = previous;
  }
}

_VisibleFrame _visible(_Work work, rv.RecyclerView? list, RenderBox viewport) {
  final Iterable<_RenderRowProbe> boxes;
  if (list == null) {
    boxes = work.boxes;
  } else {
    final layout = list.getLayoutManager()! as rv.LinearLayoutManager;
    final first = layout.findFirstVisibleItemPosition();
    final last = layout.findLastVisibleItemPosition();
    boxes = [
      for (var index = first; index <= last; index++)
        if (list.findViewHolderForAdapterPosition(index) case final _Holder holder) holder.life.box!,
    ];
  }
  final rows = <_VisibleRow>[];
  for (final box in boxes) {
    if (!box.attached || !box.hasSize || box.size.isEmpty) continue;
    final origin = box.localToGlobal(Offset.zero, ancestor: viewport);
    if (origin.dy + box.size.height <= .0001 || origin.dy >= _height - .0001) continue;
    final texts = <String>[];
    final images = <String>[];
    var icons = 0;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is ElView && widget.child is String) texts.add(widget.child! as String);
      if (widget is Text && widget.data != null) texts.add(widget.data!);
      if (widget is Image) images.add(_image(widget.image));
      if (widget is Icon) icons++;
      element.visitChildren(visit);
    }

    visit(box.life.element!);
    rows.add(_VisibleRow(box.life.position, origin.dy, box.size.height, texts, images, icons));
  }
  rows.sort((a, b) => a.position.compareTo(b.position));
  return _VisibleFrame(rows);
}

String _image(ImageProvider image) => switch (image) {
  ResizeImage() => '${image.width}x${image.height}/${_image(image.imageProvider)}',
  AssetImage() => 'asset:${image.assetName}',
  _ => image.runtimeType.toString(),
};

void _expectContent(_VisibleFrame frame, {required bool cards}) {
  for (final row in frame.rows) {
    expect(row.height, greaterThan(0));
    if (cards) {
      final title = '观测 #${(row.position + 1).toString().padLeft(5, '0')}';
      expect(row.texts.where((text) => text.contains(title)), hasLength(1));
      expect(row.images, hasLength(1));
      expect(row.images.single, contains(row.position.isEven ? 'owl.jpg' : 'owl-2.jpg'));
      expect(row.icons, greaterThan(5));
    } else {
      expect(row.texts, ['Item - ${row.position}']);
      expect(row.images, isEmpty);
    }
  }
}

class _VisibleFrame {
  _VisibleFrame(this.rows);
  final List<_VisibleRow> rows;

  void expectSame(_VisibleFrame reference) {
    expect(rows.map((row) => row.position).toList(), reference.rows.map((row) => row.position).toList());
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index], other = reference.rows[index];
      expect(row.top, closeTo(other.top, .001));
      expect(row.height, closeTo(other.height, .001));
      expect(row.texts, other.texts);
      expect(row.images, other.images);
      expect(row.icons, other.icons);
    }
  }

  List<Map<String, Object?>> toJson() => [for (final row in rows) row.toJson()];
}

class _VisibleRow {
  _VisibleRow(this.position, this.top, this.height, this.texts, this.images, this.icons);
  final int position;
  final double top, height;
  final List<String> texts, images;
  final int icons;

  Map<String, Object?> toJson() => {
    'position': position,
    'top': top,
    'height': height,
    'texts': texts,
    if (images.isNotEmpty) 'images': images,
    if (icons > 0) 'icons': icons,
  };
}

Map<String, int> _coreWork() {
  // 白盒测试只读取 assert 探针，不把计数器加入业务公开入口。
  // ignore: invalid_use_of_internal_member
  return RecyclerWorkProbe.snapshot();
}

Map<String, num> _timings(List<int> samples) {
  final sorted = [...samples]..sort();
  double percentile(double value) => sorted[math.max(0, (sorted.length * value).ceil() - 1)] / 1000;
  return {
    'mean_ms': samples.fold(0, (sum, sample) => sum + sample) / samples.length / 1000,
    'p50_ms': percentile(.5),
    'p95_ms': percentile(.95),
    'max_ms': percentile(1),
  };
}

Map<String, int> _totalWork(List<Map<String, Object?>> samples) {
  final result = <String, int>{};
  for (final sample in samples) {
    for (final entry in (sample['work']! as Map<String, int>).entries) {
      result.update(entry.key, (count) => count + entry.value, ifAbsent: () => entry.value);
    }
  }
  return result;
}

class _Behavior extends MaterialScrollBehavior {
  // ignore: prefer_const_constructors_in_immutables
  _Behavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => ClampingScrollPhysics();
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
