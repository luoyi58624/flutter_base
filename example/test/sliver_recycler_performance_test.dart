import 'dart:convert';

import 'package:example/src/pages/examples/sliver_recycler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('SLIVER_RECYCLER_PERFORMANCE');
const _width = 390.0;
const _height = 745.0;
const _cacheExtent = 250.0;
const _itemCount = 10000;
const _frame = Duration(microseconds: 8333);
const _step = 64.0;
const _warmupFrames = 10;
const _framesPerDirection = 20;

enum _Sliver { recycler, list }

typedef _Frame = ({int micros, int mounts, int disposals, int rebinds, int factoryCalls});

void main() {
  // 默认跳过；启用 SLIVER_RECYCLER_PERFORMANCE 后可用 --plain-name 选择单个负载。
  for (final content in ElSliverRecyclerExampleContent.values) {
    testWidgets('Sliver 性能对照：${content.name}', skip: !_enabled, (tester) async {
      await _setup(tester, content);
      debugPrintSynchronously(
        'SLIVER_RECYCLER_CONFIG ${jsonEncode({
          'scope': 'flutter_tester debug pump wall time, excludes device raster and presentation',
          'lifecycle_scope': 'outer item probe; inner subtree builds are not counted',
          'content': content.name,
          'item_sizing': 'natural',
          'viewport': [_width, _height],
          'device_pixel_ratio': 1,
          'cache_px': _cacheExtent,
          'item_count': _itemCount,
          'step_px': _step,
          'simulated_frame_interval_us': _frame.inMicroseconds,
          'warmup_frames': _warmupFrames,
          'frames_per_direction': _framesPerDirection,
          'passes_per_sliver': 2,
        })}',
      );

      final slivers = _Sliver.values;
      final order = List.generate(slivers.length, (index) => slivers[(index + content.index) % slivers.length]);
      final runs = {for (final sliver in order) sliver: <List<_Frame>>[]};
      // 每轮旋转顺序，第二次反向执行，平摊热身和执行顺序造成的偏差。
      for (final sliver in [...order, ...order.reversed]) {
        runs[sliver]!.add(await _measure(tester, content, sliver));
      }
      for (final entry in runs.entries) {
        final frames = entry.value.expand((run) => run).toList();
        debugPrintSynchronously(
          'SLIVER_RECYCLER_RESULT ${jsonEncode({'content': content.name, 'sliver': entry.key.name, 'item_sizing': 'natural', 'all': _summary(frames), 'passes': entry.value.map(_summary).toList(), 'mount_frames': _summary(frames.where((frame) => frame.mounts > 0)), 'rebind_only_frames': _summary(frames.where((frame) => frame.rebinds > 0 && frame.mounts == 0)), 'unchanged_frames': _summary(frames.where((frame) => frame.mounts == 0 && frame.rebinds == 0))})}',
        );
      }
    });
  }
}

Future<void> _setup(WidgetTester tester, ElSliverRecyclerExampleContent content) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(_width, _height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  if (content == .rectangles || content == .text) return;

  final probe = GlobalKey();
  await tester.pumpWidget(_app(SizedBox(key: probe)));
  final context = probe.currentContext!;
  final images = [
    AssetImage('assets/recycler_cards/bili_home.webp'),
    ResizeImage.resizeIfNeeded(960, null, AssetImage('assets/recycler_cards/owl.jpg')),
    ResizeImage.resizeIfNeeded(960, null, AssetImage('assets/recycler_cards/owl-2.jpg')),
  ];
  Object? imageError;
  await tester.runAsync(
    () => Future.wait([
      for (final image in images) precacheImage(image, context, onError: (error, _) => imageError = error),
    ]).timeout(Duration(seconds: 10)),
  );
  expect(imageError, isNull);
  await tester.pumpAndSettle();
}

Widget _app(Widget body) => MaterialApp(
  theme: ThemeData(platform: .android),
  home: ElComponentProvider(
    components: el.mobileComponents,
    child: Scaffold(body: body),
  ),
);

Future<List<_Frame>> _measure(WidgetTester tester, ElSliverRecyclerExampleContent content, _Sliver sliver) async {
  final controller = ScrollController(keepScrollOffset: false);
  final counts = _Counts();

  Widget buildItem(BuildContext context, ValueListenable<int> index) {
    counts.factoryCalls++;
    return _Probe(index: index, counts: counts, child: content.buildItem(context, index));
  }

  final delegate = SliverChildBuilderDelegate(
    (context, index) => buildItem(context, AlwaysStoppedAnimation(index)),
    childCount: _itemCount,
    addAutomaticKeepAlives: false,
  );

  try {
    await tester.pumpWidget(
      _app(
        CustomScrollView(
          controller: controller,
          primary: false,
          physics: ClampingScrollPhysics(),
          semanticChildCount: _itemCount,
          scrollCacheExtent: ScrollCacheExtent.pixels(_cacheExtent),
          slivers: [
            switch (sliver) {
              .recycler => ElSliverRecycler(itemCount: _itemCount, itemBuilder: buildItem),
              .list => SliverList(delegate: delegate),
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.position.viewportDimension, _height);
    final initialMounts = counts.mounts;

    final start = _warmupFrames * _step;
    final end = start + _framesPerDirection * _step;
    await _sweep(tester, controller, start, _warmupFrames, counts);
    final forward = await _sweep(tester, controller, end, _framesPerDirection, counts);
    final backward = await _sweep(tester, controller, start, _framesPerDirection, counts);
    final frames = [...forward, ...backward];
    if (sliver == .recycler) {
      expect(frames.any((frame) => frame.rebinds > 0), isTrue, reason: '测量区间必须实际发生换绑。');
      // 以实际首屏挂载量给当前负载留出异高和缓存窗口变化的余量，不预设条目高度。
      final creationLimit = initialMounts * 2 + 4;
      expect(counts.factoryCalls, lessThanOrEqualTo(creationLimit), reason: '单类型条目的创建量应受实际窗口规模约束。');
      expect(counts.mounts, lessThanOrEqualTo(creationLimit), reason: '持续滚动不应持续挂载新的条目 State。');
    }
    expect(tester.takeException(), isNull);
    return frames;
  } finally {
    await tester.pumpWidget(SizedBox.shrink());
    controller.dispose();
    expect(counts.disposals, counts.mounts, reason: '退出列表后，可见区和回收池中的条目都应释放。');
  }
}

Future<List<_Frame>> _sweep(
  WidgetTester tester,
  ScrollController controller,
  double target,
  int samples,
  _Counts counts,
) async {
  final origin = controller.offset;
  final animation = controller.animateTo(target, duration: _frame * samples, curve: Curves.linear);
  await tester.pump();
  final result = <_Frame>[];
  final watch = Stopwatch();
  for (var i = 1; i <= samples; i++) {
    final before = counts.snapshot;
    watch
      ..reset()
      ..start();
    await tester.pump(_frame);
    watch.stop();
    result.add((
      micros: watch.elapsedMicroseconds,
      mounts: counts.mounts - before.mounts,
      disposals: counts.disposals - before.disposals,
      rebinds: counts.rebinds - before.rebinds,
      factoryCalls: counts.factoryCalls - before.factoryCalls,
    ));
    expect(controller.offset, closeTo(origin + (target - origin) * i / samples, .01));
  }
  await tester.pump(_frame);
  await animation;
  return result;
}

Map<String, num> _summary(Iterable<_Frame> frames) {
  final times = frames.map((frame) => frame.micros).toList()..sort();
  if (times.isEmpty) return {'frames': 0};

  double percentile(double p) => times[(times.length * p).ceil() - 1] / 1000;
  return {
    'frames': times.length,
    'mean_ms': times.fold(0, (sum, time) => sum + time) / times.length / 1000,
    'p50_ms': percentile(.5),
    'p95_ms': percentile(.95),
    'p99_ms': percentile(.99),
    'max_ms': times.last / 1000,
    'over_8_33ms': times.where((time) => time > _frame.inMicroseconds).length,
    'factory_calls': frames.fold(0, (sum, frame) => sum + frame.factoryCalls),
    'mounts': frames.fold(0, (sum, frame) => sum + frame.mounts),
    'disposals': frames.fold(0, (sum, frame) => sum + frame.disposals),
    'rebinds': frames.fold(0, (sum, frame) => sum + frame.rebinds),
  };
}

class _Counts {
  int factoryCalls = 0;
  int mounts = 0;
  int disposals = 0;
  int rebinds = 0;

  ({int factoryCalls, int mounts, int disposals, int rebinds}) get snapshot =>
      (factoryCalls: factoryCalls, mounts: mounts, disposals: disposals, rebinds: rebinds);
}

class _Probe extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Probe({required this.index, required this.counts, required this.child});

  final ValueListenable<int> index;
  final _Counts counts;
  final Widget child;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  void _recordRebind() => widget.counts.rebinds++;

  @override
  void initState() {
    super.initState();
    widget.counts.mounts++;
    widget.index.addListener(_recordRebind);
  }

  @override
  void didUpdateWidget(_Probe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      oldWidget.index.removeListener(_recordRebind);
      widget.index.addListener(_recordRebind);
    }
  }

  @override
  void dispose() {
    widget.index.removeListener(_recordRebind);
    widget.counts.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
