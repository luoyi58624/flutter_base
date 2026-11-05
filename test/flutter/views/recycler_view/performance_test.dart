import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('一万条不同数据的有界复用与局部通知性能记录', (tester) async {
    final counters = _Counters();
    final adapter = _BenchAdapter(counters);
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = rv.RecyclerView()
      ..setLayoutManager(layout)
      ..setItemViewCacheSize(0)
      ..setAdapter(adapter);

    final initialClock = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: .topLeft,
            child: SizedBox(width: 360, height: 480, child: list),
          ),
        ),
      ),
    );
    await tester.pump();
    initialClock.stop();
    final initialCreated = adapter.holders.length;
    expect(initialCreated, lessThan(20), reason: '一万条业务数据不能变成一万棵挂载子树');

    final stable = [for (var position = 1; position <= 4; position++) list.findViewHolderForAdapterPosition(position)!];
    final initialBuilds = counters.builds;
    final initialLayouts = counters.layouts;
    final initialPaints = counters.paints;
    var hostChanges = 0;
    final stableFrameUs = <int>[];
    for (var frame = 0; frame < 24; frame++) {
      final before = [for (final holder in stable) _hostWidget(holder)];
      final clock = Stopwatch()..start();
      list.scrollBy(0, .1);
      await tester.pump(Duration(milliseconds: 8));
      clock.stop();
      stableFrameUs.add(clock.elapsedMicroseconds);
      for (var index = 0; index < stable.length; index++) {
        if (!identical(before[index], _hostWidget(stable[index]))) hostChanges++;
      }
    }
    final stableBuilds = counters.builds - initialBuilds;
    final stableLayouts = counters.layouts - initialLayouts;
    final stablePaints = counters.paints - initialPaints;
    expect(stableBuilds, 0);
    expect(stableLayouts, 0);
    expect(stablePaints, 0);

    final movingFrameUs = <int>[];
    for (final distance in [...List<double>.filled(40, 88), ...List<double>.filled(40, -88)]) {
      final clock = Stopwatch()..start();
      list.scrollBy(0, distance);
      await tester.pump(Duration(milliseconds: 8));
      clock.stop();
      movingFrameUs.add(clock.elapsedMicroseconds);
    }
    expect(adapter.positionsPerHolder.values.any((positions) => positions.length > 2), isTrue);
    expect(adapter.holders.length, lessThan(40));
    expect(counters.initializations, adapter.holders.length, reason: '复用应保留 State，而不是反复挂载');
    expect(counters.disposals, 0);
    final reboundPositions = adapter.positionsPerHolder.values.fold<int>(
      0,
      (count, positions) => count + positions.length,
    );

    adapter.typeQueries = 0;
    final notifyClock = Stopwatch()..start();
    for (var revision = 1; revision <= 16; revision++) {
      adapter.revisions[7000] = revision;
      adapter.notifyItemRangeChanged(7000, 4, 'content');
    }
    notifyClock.stop();
    final notificationQueries = adapter.typeQueries;
    await tester.pump();

    // 远跳后必须真的显示该位置的数据，不能靠重复静态内容获得复用数字。
    list.scrollToPosition(9000);
    await tester.pump();
    await tester.pump();
    expect(find.text('项目 9000 · 版本 0').hitTestable(), findsOneWidget);
    expect(list.findViewHolderForAdapterPosition(9000)?.getItemId(), 9000);
    expect(tester.takeException(), isNull);

    debugPrint(
      'RECYCLER_PERF ${jsonEncode({'label': const String.fromEnvironment('RECYCLER_BENCH_LABEL', defaultValue: 'current'), 'environment': 'flutter_test/debug; host wall time, not device frame timing', 'items': 10000, 'initial_mount_us': initialClock.elapsedMicroseconds, 'initial_holders': initialCreated, 'stable_frames': stableFrameUs.length, 'stable_body_builds': stableBuilds, 'stable_body_layouts': stableLayouts, 'stable_body_paints': stablePaints, 'stable_observed_host_changes': hostChanges, 'stable_pump': _timings(stableFrameUs), 'moving_frames': movingFrameUs.length, 'moving_pump': _timings(movingFrameUs), 'holders_after_scroll': adapter.holders.length, 'distinct_holder_position_bindings': reboundPositions, 'bind_calls': adapter.bindCalls, 'content_notifications': 16, 'affected_items_per_notification': 4, 'notification_type_queries': notificationQueries, 'notification_total_us': notifyClock.elapsedMicroseconds})}',
    );
    await tester.pumpWidget(SizedBox());
    expect(counters.disposals, counters.initializations);
    for (final holder in adapter.holders) {
      holder.model.dispose();
    }
  });
}

Widget _hostWidget(rv.ViewHolder holder) =>
    find.ancestor(of: find.byWidget(holder.itemView), matching: find.byType(TickerMode)).evaluate().first.widget;

Map<String, num> _timings(List<int> values) {
  final sorted = [...values]..sort();
  double percentile(double q) => sorted[((sorted.length - 1) * q).floor()] / 1000;
  return {'p50_ms': percentile(.5), 'p95_ms': percentile(.95), 'max_ms': percentile(1)};
}

class _Counters {
  int builds = 0;
  int layouts = 0;
  int paints = 0;
  int initializations = 0;
  int disposals = 0;
}

class _BenchAdapter extends rv.Adapter<_BenchHolder> {
  _BenchAdapter(this.counters) {
    setHasStableIds(true);
  }

  final _Counters counters;
  final holders = <_BenchHolder>[];
  final positionsPerHolder = <_BenchHolder, Set<int>>{};
  final revisions = <int, int>{};
  int typeQueries = 0;
  int bindCalls = 0;

  @override
  int getItemCount() => 10000;

  @override
  int getItemId(int position) => position;

  @override
  int getItemViewType(int position) {
    typeQueries++;
    return position % 4;
  }

  @override
  _BenchHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final model = ValueNotifier((position: -1, revision: 0));
    final holder = _BenchHolder(model, _BenchRow(model, counters, viewType));
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_BenchHolder holder, int position, [List<Object> payloads = const []]) {
    bindCalls++;
    positionsPerHolder.putIfAbsent(holder, () => {}).add(position);
    holder.model.value = (position: position, revision: revisions[position] ?? 0);
  }
}

class _BenchHolder extends rv.ViewHolder {
  _BenchHolder(this.model, super.itemView);

  final ValueNotifier<({int position, int revision})> model;
}

class _BenchRow extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _BenchRow(this.model, this.counters, this.type);

  final ValueNotifier<({int position, int revision})> model;
  final _Counters counters;
  final int type;

  @override
  State<_BenchRow> createState() => _BenchRowState();
}

class _BenchRowState extends State<_BenchRow> {
  @override
  void initState() {
    super.initState();
    widget.counters.initializations++;
  }

  @override
  void dispose() {
    widget.counters.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.model,
    builder: (context, item, _) {
      widget.counters.builds++;
      return _WorkProbe(
        counters: widget.counters,
        child: SizedBox(
          height: 64 + widget.type * 4,
          child: Row(
            children: [
              Checkbox(value: item.position.isEven, onChanged: (_) {}),
              Expanded(
                child: Column(
                  mainAxisAlignment: .center,
                  crossAxisAlignment: .start,
                  children: [
                    Text('项目 ${item.position} · 版本 ${item.revision}'),
                    Text('独立数据 ${item.position * 17}，类型 ${widget.type}', maxLines: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _WorkProbe extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _WorkProbe({required this.counters, required super.child});

  final _Counters counters;

  @override
  RenderObject createRenderObject(BuildContext context) => _WorkRenderBox(counters);
}

class _WorkRenderBox extends RenderProxyBox {
  _WorkRenderBox(this.counters);

  final _Counters counters;

  @override
  void performLayout() {
    counters.layouts++;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    counters.paints++;
    super.paint(context, offset);
  }
}
