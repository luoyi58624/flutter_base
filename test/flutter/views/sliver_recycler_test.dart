import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  ScrollController controller,
  List<Widget> slivers, {
  Axis axis = Axis.vertical,
  bool reverse = false,
  double cache = 0,
}) => MaterialApp(
  home: CustomScrollView(
    controller: controller,
    scrollDirection: axis,
    reverse: reverse,
    scrollCacheExtent: ScrollCacheExtent.pixels(cache),
    slivers: slivers,
  ),
);

ScrollController _setup(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(320, 240);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  return controller;
}

class _RecycledItem extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _RecycledItem(this.index);

  final ValueListenable<int> index;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ValueListenableBuilder<int>(valueListenable: index, builder: (_, value, _) => Text('条目 $value')),
  );
}

class _ReuseLog {
  int mounts = 0;
  int disposals = 0;
  final live = <_StatefulItemState>{};
  final taps = <(int, int)>[];
}

class _StatefulItem extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _StatefulItem({required this.index, required this.log, this.type = 0, this.prefix = '状态'});

  final ValueListenable<int> index;
  final _ReuseLog log;
  final int type;
  final String prefix;

  @override
  State<_StatefulItem> createState() => _StatefulItemState();
}

class _StatefulItemState extends State<_StatefulItem> {
  late final int identity;
  late final int originalType;
  final bindings = <int>[];

  void _recordBinding() => bindings.add(widget.index.value);

  @override
  void initState() {
    super.initState();
    identity = widget.log.mounts++;
    originalType = widget.type;
    widget.log.live.add(this);
    widget.index.addListener(_recordBinding);
    _recordBinding();
  }

  @override
  void didUpdateWidget(_StatefulItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.index, widget.index)) {
      oldWidget.index.removeListener(_recordBinding);
      widget.index.addListener(_recordBinding);
      _recordBinding();
    }
  }

  @override
  void dispose() {
    widget.index.removeListener(_recordBinding);
    widget.log.live.remove(this);
    widget.log.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ValueListenableBuilder<int>(
      valueListenable: widget.index,
      builder: (_, value, _) => GestureDetector(
        behavior: .opaque,
        onTap: () => widget.log.taps.add((identity, widget.index.value)),
        child: Text('${widget.prefix} $value'),
      ),
    ),
  );
}

Future<void> _unmountAndCheck(WidgetTester tester, _ReuseLog log) async {
  await tester.pumpWidget(SizedBox.shrink());
  expect(log.live, isEmpty);
  expect(log.disposals, log.mounts);
  expect(tester.takeException(), isNull);
}

class _LifecycleLog {
  int mounts = 0;
  int disposals = 0;
  final live = <_LifecycleItemState>{};
  final taps = <int>[];
}

class _LifecycleItem extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _LifecycleItem({required this.index, required this.log, this.animate = false});

  final ValueListenable<int> index;
  final _LifecycleLog log;
  final bool animate;

  @override
  State<_LifecycleItem> createState() => _LifecycleItemState();
}

class _LifecycleItemState extends State<_LifecycleItem> with SingleTickerProviderStateMixin {
  final focus = FocusNode();
  AnimationController? animation;
  int ticks = 0;

  void _tick() => ticks++;

  @override
  void initState() {
    super.initState();
    widget.log.mounts++;
    widget.log.live.add(this);
    if (widget.animate) {
      animation = AnimationController(vsync: this, duration: Duration(seconds: 5))
        ..addListener(_tick)
        ..forward();
    }
  }

  @override
  void dispose() {
    animation?.removeListener(_tick);
    animation?.dispose();
    focus.dispose();
    widget.log.live.remove(this);
    widget.log.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 240,
    child: Focus(
      focusNode: focus,
      child: ValueListenableBuilder<int>(
        valueListenable: widget.index,
        builder: (_, value, _) => Semantics(
          label: '生命周期 $value',
          button: true,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: .opaque,
            onTap: () => widget.log.taps.add(widget.index.value),
            child: Text('生命周期 $value'),
          ),
        ),
      ),
    ),
  );
}

Set<String> _semanticsLabels(WidgetTester tester) {
  final labels = <String>{};
  void collect(SemanticsNode node) {
    labels.add(node.getSemanticsData().label);
    node.visitChildren((child) {
      collect(child);
      return true;
    });
  }

  collect(tester.getSemantics(find.byType(CustomScrollView)));
  return labels;
}

Future<void> _unmountLifecycle(WidgetTester tester, _LifecycleLog log) async {
  await tester.pumpWidget(SizedBox.shrink());
  expect(log.live, isEmpty);
  expect(log.disposals, log.mounts);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('跨窗口按类型复用相同 Element 和 RenderObject', (tester) async {
    final controller = _setup(tester);
    var creations = 0;
    await tester.pumpWidget(
      _app(controller, [
        ElSliverRecycler(
          itemCount: 10000,
          itemType: (index) => index % 2,
          itemBuilder: (_, index) {
            creations++;
            return _RecycledItem(index);
          },
        ),
      ]),
    );

    Map<Element, (int, RenderObject)> visibleItems() => {
      for (final element in find.byType(_RecycledItem).evaluate())
        element: ((element.widget as _RecycledItem).index.value, element.renderObject!),
    };

    final before = visibleItems();
    final initialCreations = creations;
    expect(before.length, inInclusiveRange(6, 7));
    expect(controller.position.maxScrollExtent, 10000 * 40 - 240);

    controller.jumpTo(4000);
    await tester.pump();
    final after = visibleItems();
    expect(find.text('条目 100').hitTestable(), findsOneWidget);
    expect(after.keys, unorderedEquals(before.keys));
    expect(creations, initialCreations);
    for (final entry in after.entries) {
      final (oldIndex, oldRender) = before[entry.key]!;
      expect(entry.value.$1, isNot(oldIndex));
      expect(entry.value.$1 % 2, oldIndex % 2);
      expect(entry.value.$2, same(oldRender));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('与前后 Sliver 共用位置，缓存条目保留正确的命中坐标', (tester) async {
    final controller = _setup(tester);
    final taps = <int>[];
    await tester.pumpWidget(
      _app(controller, cache: 80, [
        SliverToBoxAdapter(child: SizedBox(height: 60, child: Text('列表上方'))),
        ElSliverRecycler(
          itemCount: 20,
          itemBuilder: (_, index) => ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (_, value, _) => SizedBox(
              height: 40,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps.add(value),
                child: Text('条目 $value'),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 80, child: Text('列表下方'))),
      ]),
    );

    expect(controller.position.maxScrollExtent, 60 + 20 * 40 + 80 - 240);
    expect(find.text('条目 6').hitTestable(), findsNothing);
    controller.jumpTo(60 + 40 * 10);
    await tester.pump();
    expect(tester.getTopLeft(find.text('条目 10')).dy, closeTo(0, .01));
    await tester.tap(find.text('条目 10'));
    expect(taps, [10]);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('列表下方').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('横向反向视口按正确方向排布并响应点击', (tester) async {
    final controller = _setup(tester);
    final taps = <int>[];
    await tester.pumpWidget(
      _app(controller, axis: Axis.horizontal, reverse: true, [
        ElSliverRecycler(
          itemCount: 200,
          itemBuilder: (_, index) => ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (_, value, _) => SizedBox(
              width: 80,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps.add(value),
                child: Center(child: Text('横向 $value')),
              ),
            ),
          ),
        ),
      ]),
    );
    expect(tester.getCenter(find.text('横向 0')).dx, closeTo(280, .01));
    expect(tester.getCenter(find.text('横向 1')).dx, closeTo(200, .01));
    controller.jumpTo(80 * 10);
    await tester.pump();
    await tester.tap(find.text('横向 10'));
    expect(taps, [10]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('替换构建器及改变尺寸、数量后更新条目和总范围', (tester) async {
    final controller = _setup(tester);
    Widget page(int count, double extent, String prefix) => _app(controller, [
      ElSliverRecycler(
        itemCount: count,
        itemBuilder: (_, index) => SizedBox(
          height: extent,
          child: ValueListenableBuilder<int>(valueListenable: index, builder: (_, value, _) => Text('$prefix $value')),
        ),
      ),
    ]);

    await tester.pumpWidget(page(100, 40, '旧数据'));
    controller.jumpTo(800);
    await tester.pump();
    expect(find.text('旧数据 20').hitTestable(), findsOneWidget);
    await tester.pumpWidget(page(3, 60, '新数据'));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(controller.position.maxScrollExtent, 0);
    expect(find.text('新数据 0').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(find.text('新数据 1')).dy, 60);
    expect(find.text('旧数据 20'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('State 跨序号保留，监听和交互使用最新绑定', (tester) async {
    final controller = _setup(tester);
    final log = _ReuseLog();
    await tester.pumpWidget(
      _app(controller, [
        ElSliverRecycler(
          itemCount: 10000,
          itemBuilder: (_, index) => _StatefulItem(index: index, log: log),
        ),
      ]),
    );

    final before = {
      for (final state in tester.stateList<_StatefulItemState>(find.byType(_StatefulItem)))
        state: state.widget.index.value,
    };
    final first = before.keys.singleWhere((state) => state.widget.index.value == 0);
    await tester.tap(find.text('状态 0'));
    expect(log.taps, [(first.identity, 0)]);

    controller.jumpTo(4000);
    await tester.pump();

    final after = tester.stateList<_StatefulItemState>(find.byType(_StatefulItem)).toSet();
    expect(after, unorderedEquals(before.keys));
    expect(log.mounts, before.length);
    expect(log.disposals, 0);
    for (final state in after) {
      expect(state.widget.index.value, isNot(before[state]));
      expect(state.bindings.last, state.widget.index.value);
      expect(state.bindings.length, greaterThan(1));
    }

    final reboundIndex = first.widget.index.value;
    expect(reboundIndex, greaterThanOrEqualTo(100));
    await tester.tap(find.text('状态 $reboundIndex').hitTestable());
    expect(log.taps, [(first.identity, 0), (first.identity, reboundIndex)]);
    await _unmountAndCheck(tester, log);
  });

  testWidgets('零空闲池仍同轮复用，持续滚到新索引不重复挂载', (tester) async {
    final controller = _setup(tester);
    final log = _ReuseLog();
    await tester.pumpWidget(
      _app(controller, cache: 80, [
        ElSliverRecycler(
          itemCount: 10000,
          maxRecycledItems: 0,
          itemBuilder: (_, index) => _StatefulItem(index: index, log: log),
        ),
      ]),
    );

    // 先进入完整缓存窗口，再遍历新索引，避免仅靠按序号缓存也能通过往返检查。
    controller.jumpTo(4000);
    await tester.pump();
    final warmMounts = log.mounts;
    final warmLive = log.live.length;
    expect(warmLive, inInclusiveRange(10, 12));

    for (var step = 0; step < 18; step++) {
      final index = step.isEven ? 1000 + step * 200 : 100 + step * 37;
      controller.jumpTo(index * 40.0);
      await tester.pump();
      expect(find.text('状态 $index').hitTestable(), findsOneWidget);
      expect(log.mounts, warmMounts);
      expect(log.live.length, warmLive);
    }

    await _unmountAndCheck(tester, log);
  });

  testWidgets('不同类型共用空闲池上限，淘汰和整体卸载释放 State', (tester) async {
    final controller = _setup(tester);
    final log = _ReuseLog();
    int typeFor(int index) => index ~/ 20;
    await tester.pumpWidget(
      _app(controller, [
        ElSliverRecycler(
          itemCount: 1000,
          maxRecycledItems: 4,
          itemType: typeFor,
          itemBuilder: (_, index) => _StatefulItem(index: index, log: log, type: typeFor(index.value)),
        ),
      ]),
    );
    final activeCapacity = log.live.length;
    expect(activeCapacity, inInclusiveRange(6, 7));

    for (var type = 1; type <= 12; type++) {
      controller.jumpTo(type * 20 * 40.0);
      await tester.pump();
      expect(log.live.length, lessThanOrEqualTo(activeCapacity + 4));
      final visible = tester.stateList<_StatefulItemState>(find.byType(_StatefulItem).hitTestable()).toList();
      expect(visible, isNotEmpty);
      for (final state in visible) {
        expect(state.originalType, type);
        expect(state.originalType, typeFor(state.widget.index.value));
      }
    }

    expect(log.disposals, greaterThan(0));
    await _unmountAndCheck(tester, log);
  });

  testWidgets('同一类型闭包的分布变化后重新匹配槽位', (tester) async {
    final controller = _setup(tester);
    final log = _ReuseLog();
    var phase = 0;
    int typeFor(int index) => (index ~/ 2 + phase) % 2;
    Widget builder(BuildContext context, ValueListenable<int> index) =>
        _StatefulItem(index: index, log: log, type: typeFor(index.value));
    Widget page() => _app(controller, [
      ElSliverRecycler(itemCount: 100, maxRecycledItems: 4, itemType: typeFor, itemBuilder: builder),
    ]);

    await tester.pumpWidget(page());
    final visibleCount = find.byType(_StatefulItem).hitTestable().evaluate().length;
    for (final nextPhase in [1, 0]) {
      phase = nextPhase;
      await tester.pumpWidget(page());
      final visible = tester.stateList<_StatefulItemState>(find.byType(_StatefulItem).hitTestable()).toList();
      expect(visible.length, visibleCount);
      for (final state in visible) {
        expect(state.originalType, typeFor(state.widget.index.value));
      }
      expect(find.text('状态 0').hitTestable(), findsOneWidget);
    }

    await _unmountAndCheck(tester, log);
  });

  testWidgets('同一构建器支持空列表、扩容、深处缩减和清空', (tester) async {
    final controller = _setup(tester);
    final log = _ReuseLog();
    Widget builder(BuildContext context, ValueListenable<int> index) => _StatefulItem(index: index, log: log);
    Widget page(int count) => _app(controller, [ElSliverRecycler(itemCount: count, itemBuilder: builder)]);

    await tester.pumpWidget(page(0));
    expect(controller.position.maxScrollExtent, 0);
    expect(log.mounts, 0);
    expect(find.byType(_StatefulItem), findsNothing);

    await tester.pumpWidget(page(100));
    final initialStates = tester.stateList<_StatefulItemState>(find.byType(_StatefulItem)).toSet();
    expect(controller.position.maxScrollExtent, 100 * 40 - 240);
    await tester.pumpWidget(page(200));
    expect(tester.stateList<_StatefulItemState>(find.byType(_StatefulItem)), unorderedEquals(initialStates));
    expect(controller.position.maxScrollExtent, 200 * 40 - 240);

    controller.jumpTo(150 * 40);
    await tester.pump();
    expect(find.text('状态 150').hitTestable(), findsOneWidget);
    await tester.pumpWidget(page(3));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(controller.position.maxScrollExtent, 0);
    expect(find.byType(_StatefulItem).hitTestable(), findsNWidgets(3));
    expect(find.text('状态 0').hitTestable(), findsOneWidget);
    expect(find.text('状态 150').hitTestable(), findsNothing);

    await tester.pumpWidget(page(0));
    await tester.pumpAndSettle();
    expect(controller.position.maxScrollExtent, 0);
    expect(find.byType(_StatefulItem), findsNothing);
    expect(log.live, isEmpty);
    expect(log.disposals, log.mounts);

    await tester.pumpWidget(page(4));
    expect(find.byType(_StatefulItem).hitTestable(), findsNWidgets(4));
    expect(find.text('状态 3').hitTestable(), findsOneWidget);
    await _unmountAndCheck(tester, log);
  });

  testWidgets('仅替换构建器更新现有内容并保持滚动位置', (tester) async {
    final controller = _setup(tester);
    final log = _ReuseLog();
    Widget oldBuilder(BuildContext context, ValueListenable<int> index) =>
        _StatefulItem(index: index, log: log, prefix: '旧');
    Widget newBuilder(BuildContext context, ValueListenable<int> index) =>
        _StatefulItem(index: index, log: log, prefix: '新');
    Widget page(Widget Function(BuildContext, ValueListenable<int>) builder) =>
        _app(controller, [ElSliverRecycler(itemCount: 100, itemBuilder: builder)]);

    await tester.pumpWidget(page(oldBuilder));
    controller.jumpTo(800);
    await tester.pump();
    expect(find.text('旧 20').hitTestable(), findsOneWidget);

    await tester.pumpWidget(page(newBuilder));
    await tester.pumpAndSettle();
    expect(controller.offset, 800);
    expect(find.text('旧 20').hitTestable(), findsNothing);
    expect(find.text('新 20').hitTestable(), findsOneWidget);
    final first = tester
        .stateList<_StatefulItemState>(find.byType(_StatefulItem).hitTestable())
        .singleWhere((state) => state.widget.index.value == 20);
    await tester.tap(find.text('新 20'));
    expect(log.taps, [(first.identity, 20)]);
    await _unmountAndCheck(tester, log);
  });

  testWidgets('窗口不变时后代 setState 和外部信号仍在下一帧刷新', (tester) async {
    final controller = _setup(tester);
    final signal = ValueNotifier(0);
    addTearDown(signal.dispose);
    late StateSetter updateLocal;
    var local = 0;
    var factoryCalls = 0;
    await tester.pumpWidget(
      _app(controller, [
        ElSliverRecycler(
          itemCount: 1,
          itemBuilder: (_, _) {
            factoryCalls++;
            return StatefulBuilder(
              builder: (_, setState) {
                updateLocal = setState;
                return ValueListenableBuilder<int>(
                  valueListenable: signal,
                  builder: (_, value, _) => SizedBox(height: 40, child: Text('局部 $local · 信号 $value')),
                );
              },
            );
          },
        ),
      ]),
    );
    final initialCalls = factoryCalls;

    updateLocal(() => local++);
    await tester.pump();
    expect(find.text('局部 1 · 信号 0'), findsOneWidget);
    signal.value++;
    await tester.pump();
    expect(find.text('局部 1 · 信号 1'), findsOneWidget);
    expect(controller.offset, 0);
    expect(factoryCalls, initialCalls);
    await tester.pumpWidget(SizedBox.shrink());
    signal.value++;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('同帧换绑清除旧焦点，池项不命中也不保留旧语义', (tester) async {
    final controller = _setup(tester);
    final log = _LifecycleLog();
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _app(controller, [
          ElSliverRecycler(
            itemCount: 20,
            maxRecycledItems: 2,
            itemType: (index) => index ~/ 2,
            itemBuilder: (_, index) => _LifecycleItem(index: index, log: log),
          ),
        ]),
      );
      final first = log.live.single;
      first.focus.requestFocus();
      await tester.pump();
      expect(first.focus.hasFocus, isTrue);
      expect(_semanticsLabels(tester), contains('生命周期 0'));

      controller.jumpTo(240);
      await tester.pump();
      expect(log.live.single, same(first));
      expect(first.widget.index.value, 1);
      expect(first.focus.hasFocus, isFalse);
      expect(_semanticsLabels(tester), contains('生命周期 1'));
      expect(_semanticsLabels(tester), isNot(contains('生命周期 0')));

      first.focus.requestFocus();
      await tester.pump();
      expect(first.focus.hasFocus, isTrue);
      controller.jumpTo(480);
      await tester.pump();
      expect(log.live.length, 2);
      expect(first.mounted, isTrue);
      expect(first.focus.hasFocus, isFalse);
      expect(find.text('生命周期 1', skipOffstage: false), findsOneWidget);
      final labels = _semanticsLabels(tester);
      expect(labels, contains('生命周期 2'));
      expect(labels, isNot(contains('生命周期 1')));
      await tester.tapAt(Offset(160, 120));
      expect(log.taps, [2]);

      first.focus.requestFocus();
      await tester.pump();
      expect(first.focus.hasFocus, isFalse);
      await _unmountLifecycle(tester, log);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('留池期间暂停 ticker，再激活恢复且卸载释放所有回调', (tester) async {
    final controller = _setup(tester);
    final log = _LifecycleLog();
    await tester.pumpWidget(
      _app(controller, [
        ElSliverRecycler(
          itemCount: 20,
          maxRecycledItems: 2,
          itemType: (index) => index % 2,
          itemBuilder: (_, index) => _LifecycleItem(index: index, log: log, animate: true),
        ),
      ]),
    );
    final first = log.live.single;
    await tester.pump(Duration(milliseconds: 20));
    await tester.pump(Duration(milliseconds: 20));
    expect(first.ticks, greaterThan(0));

    controller.jumpTo(240);
    await tester.pump();
    expect(log.live.length, 2);
    expect(first.mounted, isTrue);
    final pausedTicks = first.ticks;
    await tester.pump(Duration(milliseconds: 100));
    await tester.pump(Duration(milliseconds: 100));
    expect(first.ticks, pausedTicks);

    controller.jumpTo(480);
    await tester.pump();
    expect(first.widget.index.value, 2);
    await tester.pump(Duration(milliseconds: 20));
    expect(first.ticks, greaterThan(pausedTicks));

    final states = log.live.toList();
    await _unmountLifecycle(tester, log);
    final finalTicks = [for (final state in states) state.ticks];
    await tester.pump(Duration(seconds: 1));
    expect([for (final state in states) state.ticks], finalTicks);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
