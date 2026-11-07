import 'dart:convert';

import 'package:example/src/pages/examples/bibi/feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart'
    show ElScrollViewStateTesting, ElVirtualScrollDebugCounters;
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('BIBI_GRID_ISOLATION');
const _width = 390.0;
const _height = 745.0;
const _side = 8.0;
const _columnGap = 8.0;
const _cardWidth = (_width - _side * 2 - _columnGap) / 2;
const _frame = Duration(microseconds: 8333);
const _step = 40.0;
const _samples = 72;
const _atlas = 'assets/recycler_cards/bili_home.webp';

enum _Layout { rows, grid, measuredGrid, scopedMeasuredGrid }

enum _Cards { original, tinyAtlas, plain }

typedef _CardCounts = ({int built, int mounted, int unmounted});
typedef _FrameSample = ({int elapsed, _CardCounts cards});

void main() {
  // flutter test test/bibi_grid_isolation_test.dart --dart-define=BIBI_GRID_ISOLATION=true
  testWidgets('同一裸滚动宿主对照虚拟 Grid 与双卡片行', skip: !_enabled, (tester) async {
    final cardHeight = await _setup(tester);
    final rowExtent = (cardHeight + 9).ceilToDouble();
    final tinyBundle = _TinyAtlasBundle();
    final runs = <Map<String, Object?>>[];

    // 每组执行双向采样，交替先跑两种布局，减少预热和先后顺序偏差。
    for (final cards in _Cards.values) {
      final bundle = cards == .tinyAtlas ? tinyBundle : rootBundle;
      if (cards == .tinyAtlas) {
        await tester.pumpWidget(_app(SizedBox(key: ValueKey('tiny-atlas')), bundle: bundle));
        await _warmAtlas(tester, find.byKey(ValueKey('tiny-atlas')));
      }
      final layouts = [_Layout.rows, _Layout.grid];
      for (final layout in cards == .tinyAtlas ? layouts.reversed : layouts) {
        runs.add(await _measure(tester, cards, layout, bundle, cardHeight, rowExtent));
      }
    }

    debugPrint(
      'BIBI_GRID_ISOLATION ${jsonEncode({
        'scope': 'headless pump wall time with linear animateTo, no platform input or raster/presentation timing',
        'viewport': [_width, _height],
        'row_extent': rowExtent,
        'step_px': _step,
        'frame_interval_us': _frame.inMicroseconds,
        'runs': runs,
      })}',
    );
  });

  testWidgets('同一 Grid 对照测量包裹', skip: !_enabled, (tester) async {
    final cardHeight = await _setup(tester);
    final rowExtent = (cardHeight + 9).ceilToDouble();
    final runs = [
      for (final layout in [_Layout.grid, _Layout.measuredGrid, _Layout.scopedMeasuredGrid])
        await _measure(tester, .original, layout, rootBundle, cardHeight, rowExtent),
    ];
    expect(runs.last['scroll_measurement_builds'], 0);
    expect(runs.last['counters'], runs.first['counters']);
    debugPrint('BIBI_GRID_MEASURE_WRAPPER ${jsonEncode(runs)}');
  });
}

Future<double> _setup(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(_width, _height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final probeKey = ValueKey('card-probe');
  await tester.pumpWidget(_app(SizedBox(key: probeKey)));
  await _warmAtlas(tester, find.byKey(probeKey));
  await tester.pumpWidget(
    _app(
      Align(
        alignment: .topLeft,
        child: SizedBox(key: probeKey, width: _cardWidth, child: buildBibiVideoCard(0, 0)),
      ),
    ),
  );
  return tester.getSize(find.byKey(probeKey)).height;
}

Widget _app(Widget body, {AssetBundle? bundle}) => MaterialApp(
  theme: ThemeData(platform: .android),
  home: ElComponentProvider(
    components: el.mobileComponents,
    child: Scaffold(
      body: DefaultAssetBundle(bundle: bundle ?? rootBundle, child: body),
    ),
  ),
);

Future<void> _warmAtlas(WidgetTester tester, Finder finder) async {
  final context = tester.element(finder);
  Object? failure;
  await tester.runAsync(
    () => precacheImage(
      AssetImage(_atlas),
      context,
      onError: (error, _) => failure = error,
    ).timeout(Duration(seconds: 5)),
  );
  expect(failure, isNull);
  await tester.pumpAndSettle();
}

Future<Map<String, Object?>> _measure(
  WidgetTester tester,
  _Cards cards,
  _Layout layout,
  AssetBundle bundle,
  double cardHeight,
  double rowExtent,
) async {
  final controller = ElScrollController(keepScrollOffset: false);
  final host = GlobalKey<ElScrollViewState>();
  var built = 0;
  var mounted = 0;
  var unmounted = 0;
  var measurementBuilds = 0;
  _CardCounts cardCounts() => (built: built, mounted: mounted, unmounted: unmounted);
  void mount() => mounted++;
  void unmount() => unmounted++;
  Widget cell(int index) {
    built++;
    return SizedBox(
      key: ValueKey(index),
      height: cardHeight,
      child: _MountProbe(
        onMount: mount,
        onUnmount: unmount,
        child: cards == .plain ? ColoredBox(color: Colors.blueGrey) : buildBibiVideoCard(index, 0),
      ),
    );
  }

  Widget viewport(double extent) {
    final rowGap = rowExtent - extent;
    return ElScrollView(
      key: host,
      controller: controller,
      padding: .symmetric(horizontal: _side),
      cacheExtent: 250,
      physics: ClampingScrollPhysics(),
      scrollbar: ElNoScrollBar(),
      children: [
        if (layout != .rows)
          ElGridView.builder(
            crossAxisCount: 2,
            columnGap: _columnGap,
            rowGap: rowGap,
            mainAxisExtent: extent,
            itemCount: bibiVideoCount,
            itemBuilder: (_, index) => cell(index),
          )
        else
          ElListView.builder(
            fixedSize: true,
            itemCount: bibiVideoRowCount,
            itemBuilder: (_, index) => Padding(
              padding: .only(bottom: rowGap),
              child: Row(
                spacing: _columnGap,
                crossAxisAlignment: .start,
                children: [
                  Expanded(child: cell(index * 2)),
                  Expanded(child: cell(index * 2 + 1)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  final body = layout == .measuredGrid || layout == .scopedMeasuredGrid
      ? ElChildSizeBuilder(
          constraints: BoxConstraints.tightFor(width: _cardWidth),
          child: buildBibiVideoCard(0, 0),
          builder: (size, _) {
            measurementBuilds++;
            return SizedBox.expand(
              child: layout == .scopedMeasuredGrid
                  ? LayoutBuilder(builder: (_, _) => viewport(size.height))
                  : viewport(size.height),
            );
          },
        )
      : SizedBox.expand(child: viewport(cardHeight));
  await tester.pumpWidget(_app(body, bundle: bundle));
  await tester.pumpAndSettle();
  expect(controller.position.viewportDimension, _height);
  final first = tester.getRect(find.byKey(ValueKey(0)));
  final second = tester.getRect(find.byKey(ValueKey(1)));
  final next = tester.getRect(find.byKey(ValueKey(2)));
  expect(first.size, Size(_cardWidth, cardHeight));
  expect(second.left - first.right, _columnGap);
  expect(next.top - first.top, closeTo(rowExtent, .01));
  if (cards != .plain) {
    final image = tester.widgetList<RawImage>(find.byType(RawImage)).first.image;
    expect(image?.width, cards == .tinyAtlas ? 1 : 1536);
  }

  final start = rowExtent * 16;
  final end = start + _samples * _step;
  controller.jumpTo(start - 16 * _step);
  await tester.pumpAndSettle();
  await _sweep(tester, controller, start, 16, cardCounts);

  final counters = host.currentState!.debugCounters;
  final before = _counts(counters);
  final initialMeasurementBuilds = measurementBuilds;
  final forward = await _sweep(tester, controller, end, _samples, cardCounts);
  final reverse = await _sweep(tester, controller, start, _samples, cardCounts);
  final after = _counts(counters);
  final frames = [...forward, ...reverse];
  final result = <String, Object?>{
    'cards': cards.name,
    'layout': layout.name,
    'initial_measurement_builds': initialMeasurementBuilds,
    'scroll_measurement_builds': measurementBuilds - initialMeasurementBuilds,
    'all': _summary(frames),
    'mount_frames': _summary(frames.where((frame) => frame.cards.mounted > 0)),
    'steady_frames': _summary(frames.where((frame) => frame.cards.mounted == 0 && frame.cards.unmounted == 0)),
    'counters': {for (final key in before.keys) key: after[key]! - before[key]!},
  };
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(SizedBox.shrink());
  controller.dispose();
  return result;
}

Future<List<_FrameSample>> _sweep(
  WidgetTester tester,
  ScrollController controller,
  double target,
  int samples,
  _CardCounts Function() cardCounts,
) async {
  final origin = controller.offset;
  final animation = controller.animateTo(target, duration: _frame * samples, curve: Curves.linear);
  await tester.pump();
  final results = <_FrameSample>[];
  final watch = Stopwatch();
  for (var i = 1; i <= samples; i++) {
    final before = cardCounts();
    watch
      ..reset()
      ..start();
    await tester.pump(_frame);
    watch.stop();
    final after = cardCounts();
    results.add((
      elapsed: watch.elapsedMicroseconds,
      cards: (
        built: after.built - before.built,
        mounted: after.mounted - before.mounted,
        unmounted: after.unmounted - before.unmounted,
      ),
    ));
    expect(controller.offset, closeTo(origin + (target - origin) * i / samples, .01));
  }
  await tester.pump(_frame);
  await animation;
  return results;
}

Map<String, int> _counts(ElVirtualScrollDebugCounters counters) => {
  'reconcile': counters.debugContentReconcileCount,
  'incremental_reconcile': counters.debugContentIncrementalReconcileCount,
  'layout_item_visits': counters.debugLayoutChildVisitCount,
  'paint_candidate_visits': counters.debugPaintCandidateVisitCount,
  'host_builds': counters.debugBuildCount,
};

Map<String, num> _summary(Iterable<_FrameSample> frames) {
  final ordered = frames.map((frame) => frame.elapsed).toList()..sort();
  if (ordered.isEmpty) return {'frames': 0};
  return {
    'frames': ordered.length,
    'cards_built': frames.fold(0, (sum, frame) => sum + frame.cards.built),
    'cards_mounted': frames.fold(0, (sum, frame) => sum + frame.cards.mounted),
    'cards_unmounted': frames.fold(0, (sum, frame) => sum + frame.cards.unmounted),
    'mean_ms': ordered.fold(0, (sum, elapsed) => sum + elapsed) / ordered.length / 1000,
    'p95_ms': ordered[(ordered.length * .95).ceil() - 1] / 1000,
  };
}

class _TinyAtlasBundle extends CachingAssetBundle {
  final _pixel = ByteData.sublistView(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAANSURBVBhXY2BgYGAAAAAFAAGKM+MAAAAAAElFTkSuQmCC',
    ),
  );

  @override
  Future<ByteData> load(String key) async => key == _atlas ? _pixel : rootBundle.load(key);
}

class _MountProbe extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MountProbe({required this.onMount, required this.onUnmount, required this.child});

  final VoidCallback onMount;
  final VoidCallback onUnmount;
  final Widget child;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onUnmount();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
