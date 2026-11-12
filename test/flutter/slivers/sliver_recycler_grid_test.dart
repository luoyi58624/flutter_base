import 'package:flutter/foundation.dart' show Listenable, ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Builder = Widget Function(BuildContext, ValueListenable<int>);

ScrollController _setup(WidgetTester tester, {Size size = const Size(320, 240)}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  return controller;
}

Widget _app(
  ScrollController controller,
  Widget sliver, {
  Axis axis = Axis.vertical,
  bool reverse = false,
  TextDirection direction = TextDirection.ltr,
  double cache = 0,
  List<Widget> before = const [],
  List<Widget> after = const [],
}) => MaterialApp(
  home: Directionality(
    textDirection: direction,
    child: CustomScrollView(
      controller: controller,
      scrollDirection: axis,
      reverse: reverse,
      scrollCacheExtent: ScrollCacheExtent.pixels(cache),
      slivers: [...before, sliver, ...after],
    ),
  ),
);

Widget _matrix(
  bool masonry, {
  required int count,
  required _Builder builder,
  int columns = 2,
  double mainSpacing = 0,
  double crossSpacing = 0,
  Object? Function(int)? type,
  int poolSize = 32,
}) => masonry
    ? ElSliverMasonry.recycler(
        itemCount: count,
        itemBuilder: builder,
        crossAxisCount: columns,
        mainAxisSpacing: mainSpacing,
        crossAxisSpacing: crossSpacing,
        itemType: type,
        maxRecycledItems: poolSize,
      )
    : ElSliverGrid.recycler(
        itemCount: count,
        itemBuilder: builder,
        crossAxisCount: columns,
        mainAxisSpacing: mainSpacing,
        crossAxisSpacing: crossSpacing,
        itemType: type,
        maxRecycledItems: poolSize,
      );

Widget _cell(int index, double extent, {Axis axis = Axis.vertical, ValueChanged<int>? onTap}) => SizedBox(
  key: ValueKey('cell $index'),
  height: axis == Axis.vertical ? extent : null,
  width: axis == Axis.horizontal ? extent : null,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap == null ? null : () => onTap(index),
    child: Center(child: Text('cell $index')),
  ),
);

_Builder _cells(double Function(int) extent, {Axis axis = Axis.vertical, ValueChanged<int>? onTap}) =>
    (_, index) => ValueListenableBuilder<int>(
      valueListenable: index,
      builder: (_, value, _) => _cell(value, extent(value), axis: axis, onTap: onTap),
    );

Rect _rect(WidgetTester tester, int index) => tester.getRect(find.byKey(ValueKey('cell $index')));

Future<void> _settle(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(milliseconds: 16), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));

class _Log {
  int factories = 0;
  int mounts = 0;
  int builds = 0;
  int disposals = 0;
  final live = <_ProbeState>{};
}

class _Probe extends StatefulWidget {
  const _Probe({required this.index, required this.log, required this.height});

  final ValueListenable<int> index;
  final _Log log;
  final double height;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.log.mounts++;
    widget.log.live.add(this);
  }

  @override
  Widget build(BuildContext context) {
    widget.log.builds++;
    return SizedBox(
      height: widget.height,
      child: ValueListenableBuilder<int>(valueListenable: widget.index, builder: (_, value, _) => Text('probe $value')),
    );
  }

  @override
  void dispose() {
    widget.log.live.remove(this);
    widget.log.disposals++;
    super.dispose();
  }
}

Map<_ProbeState, (Widget, Element, RenderObject)> _snapshot(WidgetTester tester) => {
  for (final state in tester.stateList<_ProbeState>(find.byType(_Probe)))
    state: (state.widget, state.context as Element, state.context.findRenderObject()!),
};

void main() {
  testWidgets('Grid 按同行最大自然高度推进，列间距和行间距独立', (tester) async {
    final controller = _setup(tester, size: const Size(320, 160));
    final heights = <double>[40, 70, 50, 20, 60, 40];
    await tester.pumpWidget(
      _app(
        controller,
        _matrix(
          false,
          count: heights.length,
          builder: _cells((index) => heights[index]),
          mainSpacing: 8,
          crossSpacing: 10,
        ),
      ),
    );
    await _settle(tester);

    expect(_rect(tester, 0).left, 0);
    expect(_rect(tester, 0).width, 155);
    expect(_rect(tester, 1), const Rect.fromLTWH(165, 0, 155, 70));
    expect(_rect(tester, 2).top, 78);
    expect(_rect(tester, 3).top, 78);
    expect(_rect(tester, 4).top, 136);
    expect(_rect(tester, 5).top, 136);
    expect(controller.position.maxScrollExtent, closeTo(196 - 160, .01));
    expect(tester.takeException(), isNull);
  });

  for (final cache in [0.0, 80.0]) {
    testWidgets('Grid 缓存前缘位于行间距时停止调度，间距不扩大命中范围（cache=$cache）', (tester) async {
      final controller = _setup(tester);
      final tapped = <int>[];
      await tester.pumpWidget(
        _app(
          controller,
          _matrix(false, count: 40, mainSpacing: 20, builder: _cells((_) => 100, onTap: tapped.add)),
          cache: cache,
        ),
      );
      await _settle(tester);

      final pixels = 110 + cache;
      controller.jumpTo(pixels);
      await _settle(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(controller.offset, pixels);
      expect(controller.position.maxScrollExtent, 20 * 100 + 19 * 20 - 240);
      expect(_rect(tester, 0).bottom, 100 - pixels);
      expect(_rect(tester, 2).top, 120 - pixels);
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(Duration(milliseconds: 16));
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(controller.offset, pixels);
        expect(_rect(tester, 2).top, 120 - pixels);
      }

      // 无缓存时点首行下方空隙，有缓存时点下一行下方的可见空隙。
      await tester.tapAt(Offset(40, cache == 0 ? 5 : 40));
      await _settle(tester);
      expect(tapped, isEmpty);
      final visibleCell = cache == 0 ? 2 : 4;
      await tester.tap(find.byKey(ValueKey('cell $visibleCell')));
      await _settle(tester);
      expect(tapped, [visibleCell]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Masonry 根据实测自然高度依次填入最短列', (tester) async {
    final controller = _setup(tester, size: const Size(320, 160));
    final heights = <double>[100, 40, 30, 80, 20, 50];
    await tester.pumpWidget(
      _app(
        controller,
        _matrix(
          true,
          count: heights.length,
          builder: _cells((index) => heights[index]),
          mainSpacing: 8,
          crossSpacing: 10,
        ),
      ),
    );
    await _settle(tester);

    expect(_rect(tester, 0), const Rect.fromLTWH(0, 0, 155, 100));
    expect(_rect(tester, 1), const Rect.fromLTWH(165, 0, 155, 40));
    expect(_rect(tester, 2), const Rect.fromLTWH(165, 48, 155, 30));
    expect(_rect(tester, 3), const Rect.fromLTWH(165, 86, 155, 80));
    expect(_rect(tester, 4), const Rect.fromLTWH(0, 108, 155, 20));
    expect(_rect(tester, 5), const Rect.fromLTWH(0, 136, 155, 50));
    expect(controller.position.maxScrollExtent, closeTo(186 - 160, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Masonry 极高条目与远处短列同时可见，挂载数量不跟索引跨度增长', (tester) async {
    final controller = _setup(tester);
    final log = _Log();
    await tester.pumpWidget(
      _app(
        controller,
        _matrix(
          true,
          count: 10000,
          poolSize: 0,
          type: (index) => index == 0 ? 'tall' : 'short',
          builder: (_, index) {
            log.factories++;
            return _Probe(index: index, log: log, height: index.value == 0 ? 2000 : 40);
          },
        ),
      ),
    );
    await _settle(tester);
    controller.jumpTo(1200);
    await _settle(tester);

    final active = tester.stateList<_ProbeState>(find.byType(_Probe)).toList();
    final indices = active.map((state) => state.widget.index.value).toSet();
    expect(indices, contains(0));
    expect(indices, contains(31));
    expect(indices, isNot(contains(1)));
    expect(indices.length, inInclusiveRange(7, 9));
    expect(log.mounts, lessThanOrEqualTo(12));
    expect(log.live.length, lessThanOrEqualTo(9));
    expect(controller.offset, closeTo(1200, .01));
    final tall = active.singleWhere((state) => state.widget.index.value == 0);
    expect(tester.getRect(find.byWidget(tall.widget)), const Rect.fromLTWH(0, -1200, 160, 2000));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(log.live, isEmpty);
    expect(log.disposals, log.mounts);
  });

  testWidgets('Grid 前导零高行仅靠子项监听展开并推移后续行', (tester) async {
    final controller = _setup(tester);
    final heights = ValueNotifier(<double>[0, 0, 40, 40]);
    addTearDown(heights.dispose);
    var factories = 0;
    final grid = _matrix(
      false,
      count: 4,
      builder: (_, index) {
        factories++;
        return ListenableBuilder(
          listenable: Listenable.merge([index, heights]),
          builder: (_, _) => _cell(index.value, heights.value[index.value]),
        );
      },
    );
    await tester.pumpWidget(
      _app(
        controller,
        grid,
        after: const [
          SliverToBoxAdapter(
            child: SizedBox(key: ValueKey('after-leading-zero'), height: 30, child: Text('后续内容')),
          ),
        ],
      ),
    );
    await _settle(tester);
    final initialFactories = factories;
    expect(_rect(tester, 2).top, 0);
    expect(tester.getTopLeft(find.byKey(const ValueKey('after-leading-zero'))).dy, 40);

    // 后一行始终有高度，前导零高行仍需保留自己的局部更新入口。
    heights.value = [60, 0, 40, 40];
    await _settle(tester);
    expect(_rect(tester, 0).height, 60);
    expect(find.byKey(const ValueKey('cell 0')).hitTestable(), findsOneWidget);
    expect(_rect(tester, 2).top, 60);
    expect(_rect(tester, 3).top, 60);
    expect(tester.getTopLeft(find.byKey(const ValueKey('after-leading-zero'))).dy, 100);
    expect(
      tester.widget<ElSliverGrid>(
        find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry),
      ),
      same(grid),
    );
    expect(factories, initialFactories);
    expect(tester.takeException(), isNull);
  });

  for (final masonry in [false, true]) {
    final name = masonry ? 'Masonry' : 'Grid';

    testWidgets('$name 跨窗口复用固定 Widget、Element、State 和 RenderObject', (tester) async {
      final controller = _setup(tester);
      final log = _Log();
      await tester.pumpWidget(
        _app(
          controller,
          _matrix(
            masonry,
            count: 10000,
            poolSize: 0,
            builder: (_, index) {
              log.factories++;
              return _Probe(index: index, log: log, height: 40);
            },
          ),
        ),
      );
      await _settle(tester);
      controller.jumpTo(4000);
      await _settle(tester);
      final before = _snapshot(tester);
      final factories = log.factories;
      final builds = log.builds;
      final mounts = log.mounts;
      expect(before.length, inInclusiveRange(12, 14));

      for (final offset in <double>[8000, 12000, 20000, 6000]) {
        controller.jumpTo(offset);
        await _settle(tester);
        final after = _snapshot(tester);
        expect(after.keys, unorderedEquals(before.keys));
        for (final state in before.keys) {
          expect(after[state]!.$1, same(before[state]!.$1));
          expect(after[state]!.$2, same(before[state]!.$2));
          expect(after[state]!.$3, same(before[state]!.$3));
        }
        expect(log.factories, factories);
        expect(log.builds, builds);
        expect(log.mounts, mounts);
        final firstIndex = (offset / 40).round() * 2;
        expect(find.text('probe $firstIndex').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      expect(log.live, isEmpty);
      expect(log.disposals, log.mounts);
    });

    testWidgets('$name 深处缩量、清空与恢复会清理缓存和池中的旧数据绑定', (tester) async {
      final controller = _setup(tester);
      final records = ValueNotifier(List.generate(200, (index) => 'record $index'));
      addTearDown(records.dispose);
      await tester.pumpWidget(
        _app(
          controller,
          ValueListenableBuilder<List<String>>(
            valueListenable: records,
            builder: (_, values, _) => _matrix(
              masonry,
              count: values.length,
              poolSize: 8,
              builder: (_, index) => ListenableBuilder(
                listenable: Listenable.merge([index, records]),
                builder: (_, _) => SizedBox(
                  key: ValueKey('cell ${index.value}'),
                  height: 40,
                  // 直接访问真实数据，失效槽位若抢先重建就会暴露越界。
                  child: Text(records.value[index.value]),
                ),
              ),
            ),
          ),
          cache: 80,
        ),
      );
      await _settle(tester);
      controller.jumpTo(2400);
      await _settle(tester);
      expect(find.text('record 120').hitTestable(), findsOneWidget);
      controller.jumpTo(controller.position.maxScrollExtent);
      await _settle(tester);
      expect(find.text('record 199').hitTestable(), findsOneWidget);
      // 尾部窗口更小，确认缩量前同时存在缓存条目和空闲槽位。
      expect(
        find.textContaining('record ', skipOffstage: false).evaluate().length,
        greaterThan(find.textContaining('record ').evaluate().length),
      );
      expect(tester.takeException(), isNull);

      records.value = List.generate(18, (index) => 'short $index');
      await _settle(tester);
      expect(controller.position.maxScrollExtent, closeTo(120, .01));
      expect(controller.offset, closeTo(120, .01));
      expect(find.text('short 17').hitTestable(), findsOneWidget);
      expect(_rect(tester, 17).bottom, closeTo(240, .01));
      expect(find.textContaining('record ', skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);

      records.value = [];
      await _settle(tester);
      expect(controller.position.maxScrollExtent, 0);
      expect(controller.offset, 0);
      expect(find.textContaining('short ', skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);

      records.value = List.generate(60, (index) => 'restored $index');
      await _settle(tester);
      expect(controller.position.maxScrollExtent, closeTo(960, .01));
      expect(controller.offset, 0);
      expect(find.text('restored 0').hitTestable(), findsOneWidget);
      controller.jumpTo(controller.position.maxScrollExtent);
      await _settle(tester);
      expect(find.text('restored 59').hitTestable(), findsOneWidget);
      expect(_rect(tester, 59).bottom, closeTo(240, .01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name 缓存内前方条目局部变高后保持可见锚点', (tester) async {
      final controller = _setup(tester);
      final heights = ValueNotifier(List<double>.filled(100, 40));
      addTearDown(heights.dispose);
      var factories = 0;
      await tester.pumpWidget(
        _app(
          controller,
          cache: 80,
          _matrix(
            masonry,
            count: heights.value.length,
            builder: (_, index) {
              factories++;
              return ListenableBuilder(
                listenable: Listenable.merge([index, heights]),
                builder: (_, _) => _cell(index.value, heights.value[index.value]),
              );
            },
          ),
        ),
      );
      await _settle(tester);
      controller.jumpTo(120);
      await _settle(tester);
      final top = _rect(tester, 6).top;
      final warmFactories = factories;
      expect(top, closeTo(0, .01));
      expect(find.byKey(const ValueKey('cell 2')), findsOneWidget);

      heights.value = [...heights.value]..[2] = 100;
      await _settle(tester);

      expect(_rect(tester, 6).top, closeTo(top, .01));
      expect(controller.offset, closeTo(180, .01));
      expect(factories, lessThanOrEqualTo(warmFactories + 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name 宽度与列数变化重新测量自然换行高度', (tester) async {
      final controller = _setup(tester, size: const Size(320, 800));
      final columns = ValueNotifier(2);
      addTearDown(columns.dispose);
      final text = List.filled(6, 'natural width layout').join(' ');
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: columns,
            builder: (_, count, _) => CustomScrollView(
              controller: controller,
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              slivers: [
                _matrix(
                  masonry,
                  columns: count,
                  count: 3,
                  builder: (_, index) => ValueListenableBuilder<int>(
                    valueListenable: index,
                    builder: (_, value, _) => Padding(
                      key: ValueKey('cell $value'),
                      padding: const EdgeInsets.all(8),
                      child: Text(text, style: const TextStyle(fontSize: 16, height: 1.25)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      final initialHeight = _rect(tester, 0).height;
      expect(_rect(tester, 0).width, 160);

      tester.view.physicalSize = const Size(240, 800);
      await _settle(tester);
      expect(_rect(tester, 0).width, 120);
      expect(_rect(tester, 0).height, greaterThan(initialHeight));
      expect(_rect(tester, 2).top, closeTo(_rect(tester, 0).bottom, .01));

      columns.value = 3;
      await _settle(tester);
      for (var index = 0; index < 3; index++) {
        expect(_rect(tester, index).width, 80);
        expect(_rect(tester, index).left, index * 80);
        expect(_rect(tester, index).top, 0);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name 正确处理零高项和全零列表', (tester) async {
      final controller = _setup(tester);
      final heights = <double>[0, 40, 0, 60];
      Widget page() =>
          _app(controller, _matrix(masonry, count: heights.length, builder: _cells((index) => heights[index])));
      await tester.pumpWidget(page());
      await _settle(tester);
      expect(_rect(tester, 1).height, 40);
      expect(_rect(tester, 3).height, 60);
      expect(_rect(tester, 3).top, masonry ? 0 : 40);
      expect(controller.position.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);

      heights.fillRange(0, heights.length, 0);
      await tester.pumpWidget(page());
      await _settle(tester);
      expect(controller.position.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name 全零条目仅靠子项监听也能展开、收起后再次展开', (tester) async {
      final controller = _setup(tester);
      final heights = ValueNotifier(List<double>.filled(4, 0));
      addTearDown(heights.dispose);
      var factories = 0;
      final grid = _matrix(
        masonry,
        count: 4,
        builder: (_, index) {
          factories++;
          return ListenableBuilder(
            listenable: Listenable.merge([index, heights]),
            builder: (_, _) => _cell(index.value, heights.value[index.value]),
          );
        },
      );
      await tester.pumpWidget(
        _app(
          controller,
          grid,
          after: const [
            SliverToBoxAdapter(
              child: SizedBox(key: ValueKey('after-zero'), height: 30, child: Text('后续内容')),
            ),
          ],
        ),
      );
      await _settle(tester);
      final initialFactories = factories;
      expect(tester.getTopLeft(find.byKey(const ValueKey('after-zero'))).dy, 0);

      // 只通知子项；不替换父级 Grid，也不依靠重新执行行工厂唤醒零高内容。
      for (final height in <double>[80, 0, 120]) {
        heights.value = [0, 0, 0, height];
        await _settle(tester);
        // 零高 Sliver 会被 Viewport 标为离屏；仍须检查其保留节点的真实布局尺寸。
        final cell = find.byKey(const ValueKey('cell 3'), skipOffstage: false);
        expect(tester.getRect(cell).height, height);
        expect(tester.getRect(cell).top, 0);
        expect(tester.getTopLeft(find.byKey(const ValueKey('after-zero'))).dy, closeTo(height, .01));
        if (height > 0) {
          expect(find.byKey(const ValueKey('cell 3')).hitTestable(), findsOneWidget);
        }
        expect(
          tester.widget<ElSliverGrid>(
            find.byWidgetPredicate(
              (widget) => widget is ElSliverGrid || widget is ElSliverMasonry,
              skipOffstage: false,
            ),
          ),
          same(grid),
        );
        expect(factories, initialFactories);
        expect(controller.position.maxScrollExtent, 0);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('$name 与前后 Sliver 共用滚动范围和命中坐标', (tester) async {
      final controller = _setup(tester);
      final taps = <int>[];
      await tester.pumpWidget(
        _app(
          controller,
          _matrix(masonry, count: 10, builder: _cells((_) => 40, onTap: taps.add)),
          before: const [SliverToBoxAdapter(child: SizedBox(height: 50, child: Text('header')))],
          after: const [SliverToBoxAdapter(child: SizedBox(height: 70, child: Text('footer')))],
        ),
      );
      await _settle(tester);
      expect(_rect(tester, 0).top, 50);
      expect(controller.position.maxScrollExtent, closeTo(50 + 200 + 70 - 240, .01));
      controller.jumpTo(controller.position.maxScrollExtent);
      await _settle(tester);
      expect(find.text('footer').hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cell 8')));
      expect(taps, [8]);
      expect(tester.takeException(), isNull);
    });
  }

  final directions = [
    (name: 'Grid RTL', masonry: false, axis: Axis.vertical, reverse: false, rtl: true),
    (name: 'Masonry 垂直反向', masonry: true, axis: Axis.vertical, reverse: true, rtl: false),
    (name: 'Grid 水平反向', masonry: false, axis: Axis.horizontal, reverse: true, rtl: false),
  ];
  for (final scenario in directions) {
    testWidgets('${scenario.name} 的二维位置与点击一致', (tester) async {
      final controller = _setup(tester);
      final taps = <int>[];
      await tester.pumpWidget(
        _app(
          controller,
          _matrix(
            scenario.masonry,
            count: 200,
            builder: _cells((_) => 40, axis: scenario.axis, onTap: taps.add),
            crossSpacing: 8,
          ),
          axis: scenario.axis,
          reverse: scenario.reverse,
          direction: scenario.rtl ? TextDirection.rtl : TextDirection.ltr,
        ),
      );
      await _settle(tester);
      if (scenario.axis == Axis.horizontal) {
        expect(_rect(tester, 0), const Rect.fromLTWH(280, 0, 40, 116));
        expect(_rect(tester, 1), const Rect.fromLTWH(280, 124, 40, 116));
      } else if (scenario.rtl) {
        expect(_rect(tester, 0), const Rect.fromLTWH(164, 0, 156, 40));
        expect(_rect(tester, 1), const Rect.fromLTWH(0, 0, 156, 40));
      } else {
        expect(_rect(tester, 0), const Rect.fromLTWH(0, 200, 156, 40));
        expect(_rect(tester, 1), const Rect.fromLTWH(164, 200, 156, 40));
      }
      await tester.tap(find.byKey(const ValueKey('cell 1')));
      expect(taps, [1]);
      controller.jumpTo(80);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('cell 4')));
      expect(taps, [1, 4]);
      expect(tester.takeException(), isNull);
    });
  }
}
