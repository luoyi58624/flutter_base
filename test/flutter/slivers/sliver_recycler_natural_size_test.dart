import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

ScrollController _configure(WidgetTester tester, {Size? size}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size ?? Size(320, 240);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  return controller;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(Duration(milliseconds: 16), EnginePhase.sendSemanticsUpdate, Duration(seconds: 2));
}

class _NaturalLog {
  int mounts = 0;
  int disposals = 0;
  final live = <_NaturalItemState>{};
  final taps = <int>[];
}

class _NaturalItem extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _NaturalItem({required this.index, required this.extents, required this.axis, required this.type, required this.log});

  final ValueListenable<int> index;
  final ValueListenable<List<double>> extents;
  final Axis axis;
  final int type;
  final _NaturalLog log;

  @override
  State<_NaturalItem> createState() => _NaturalItemState();
}

class _NaturalItemState extends State<_NaturalItem> {
  late final int originalType;

  @override
  void initState() {
    super.initState();
    originalType = widget.type;
    widget.log.mounts++;
    widget.log.live.add(this);
  }

  @override
  void dispose() {
    widget.log.live.remove(this);
    widget.log.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: widget.index,
    builder: (_, index, _) => ValueListenableBuilder<List<double>>(
      valueListenable: widget.extents,
      builder: (_, extents, _) {
        final extent = extents[index];
        return SizedBox(
          width: widget.axis == Axis.horizontal ? extent : null,
          height: widget.axis == Axis.vertical ? extent : null,
          child: extent == 0
              ? null
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.log.taps.add(widget.index.value),
                  child: Align(alignment: Alignment.topLeft, child: Text('自然 $index')),
                ),
        );
      },
    ),
  );
}

class _Fixture {
  _Fixture(this.tester, List<double> sizes, {this.axis = Axis.vertical, this.reverse = false, this.itemType})
    : controller = _configure(tester),
      extents = ValueNotifier(sizes) {
    addTearDown(extents.dispose);
  }

  final WidgetTester tester;
  final Axis axis;
  final bool reverse;
  final int Function(int)? itemType;
  final ScrollController controller;
  final ValueNotifier<List<double>> extents;
  final log = _NaturalLog();

  int typeFor(int index) => itemType?.call(index) ?? 0;

  Widget page({int? count, List<Widget>? before, List<Widget>? after}) => MaterialApp(
    home: CustomScrollView(
      controller: controller,
      scrollDirection: axis,
      reverse: reverse,
      physics: ClampingScrollPhysics(),
      scrollCacheExtent: ScrollCacheExtent.pixels(0),
      slivers: [
        ...?before,
        ElSliverList.recycler(
          itemCount: count ?? extents.value.length,
          itemType: typeFor,
          maxRecycledItems: 4,
          itemBuilder: (_, index) =>
              _NaturalItem(index: index, extents: extents, axis: axis, type: typeFor(index.value), log: log),
        ),
        ...?after,
      ],
    ),
  );

  Future<void> mount({List<Widget>? before, List<Widget>? after}) async {
    await tester.pumpWidget(page(before: before, after: after));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  }

  List<_NaturalItemState> get active => tester.stateList<_NaturalItemState>(find.byType(_NaturalItem)).toList();

  _NaturalItemState stateAt(int index) => active.singleWhere((state) => state.widget.index.value == index);

  Rect rectOf(_NaturalItemState state) => tester.getRect(find.byWidget(state.widget));

  Rect rectAt(int index) => rectOf(stateAt(index));

  List<_NaturalItemState> get visible {
    final viewport = tester.getRect(find.byType(CustomScrollView));
    return active.where((state) => rectOf(state).overlaps(viewport)).toList()
      ..sort((a, b) => a.widget.index.value.compareTo(b.widget.index.value));
  }

  void resize(int index, double extent) {
    final next = List<double>.of(extents.value);
    next[index] = extent;
    extents.value = next;
  }

  Future<void> jump(double offset) async {
    controller.jumpTo(offset);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  }

  void expectVisibleChain({bool fillsViewport = false}) {
    final rows = visible;
    expect(rows, isNotEmpty);
    double leading(Rect rect) => switch ((axis, reverse)) {
      (Axis.vertical, false) => rect.top,
      (Axis.vertical, true) => -rect.bottom,
      (Axis.horizontal, false) => rect.left,
      (Axis.horizontal, true) => -rect.right,
    };
    double trailing(Rect rect) => switch ((axis, reverse)) {
      (Axis.vertical, false) => rect.bottom,
      (Axis.vertical, true) => -rect.top,
      (Axis.horizontal, false) => rect.right,
      (Axis.horizontal, true) => -rect.left,
    };

    for (var position = 0; position < rows.length; position++) {
      final state = rows[position];
      final index = state.widget.index.value;
      final rect = rectOf(state);
      expect(axis == Axis.vertical ? rect.height : rect.width, closeTo(extents.value[index], .01));
      expect(state.originalType, typeFor(index), reason: '不同结构类型不能共用同一 State。');
      if (position > 0) {
        final previous = rows[position - 1];
        expect(index, previous.widget.index.value + 1);
        expect(leading(rect), closeTo(trailing(rectOf(previous)), .01), reason: '实测条目之间不能留下间隙或重叠。');
      }
    }
    if (fillsViewport) {
      final viewport = tester.getRect(find.byType(CustomScrollView));
      expect(leading(rectOf(rows.first)), lessThanOrEqualTo(leading(viewport) + .01));
      expect(trailing(rectOf(rows.last)), greaterThanOrEqualTo(trailing(viewport) - .01));
    }
    expect(log.live.length, lessThanOrEqualTo(active.length + 4));
  }

  Future<void> unmount() async {
    await tester.pumpWidget(SizedBox.shrink());
    expect(log.live, isEmpty);
    expect(log.disposals, log.mounts);
    // 卸载后再次通知尺寸源，不应再触发已释放条目的回调。
    extents.value = List<double>.of(extents.value);
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  testWidgets('不同类型的自然高度与前后 Sliver 连续布局并正确命中', (tester) async {
    final sizes = List<double>.generate(12, (index) => 40 + (index % 3) * 20.0);
    final fixture = _Fixture(tester, sizes, itemType: (index) => index % 2);
    await fixture.mount(
      before: [SliverToBoxAdapter(child: SizedBox(height: 60, child: Text('自然列表前')))],
      after: [
        SliverToBoxAdapter(
          child: SizedBox(key: ValueKey('自然列表后'), height: 80, child: Text('自然列表后')),
        ),
      ],
    );

    expect(fixture.rectAt(0), Rect.fromLTWH(0, 60, 320, 40));
    expect(fixture.rectAt(1), Rect.fromLTWH(0, 100, 320, 60));
    expect(fixture.rectAt(2), Rect.fromLTWH(0, 160, 320, 80));
    await fixture.jump(60);
    expect(fixture.rectAt(0).top, closeTo(0, .01));
    expect(fixture.rectAt(3).top, closeTo(180, .01));

    // 逐段经过整张短列表，使尾部断言使用已经实测的总长度。
    for (final offset in [180.0, 300.0, 420.0, 540.0, 620.0]) {
      await fixture.jump(offset);
      fixture.expectVisibleChain();
    }
    await fixture.jump(fixture.controller.position.maxScrollExtent);
    expect(fixture.controller.position.maxScrollExtent, closeTo(60 + 720 + 80 - 240, .01));
    expect(tester.getRect(find.byKey(ValueKey('自然列表后'))), Rect.fromLTWH(0, 160, 320, 80));
    expect(fixture.rectAt(11).bottom, closeTo(160, .01));
    await tester.tap(find.text('自然 11'));
    expect(fixture.log.taps, [11]);
    await fixture.unmount();
  });

  testWidgets('未知高度远跳和回退只挂载窗口附近，恢复首项几何和最新绑定', (tester) async {
    final sizes = List<double>.generate(10000, (index) => 40 + (index % 3) * 20.0);
    final fixture = _Fixture(tester, sizes, itemType: (index) => index % 2);
    await fixture.mount();
    expect(fixture.log.mounts, lessThan(16));

    for (final offset in [120000.0, 300000.0, 60000.0, 180000.0]) {
      await fixture.jump(offset);
      fixture.expectVisibleChain(fillsViewport: true);
      expect(fixture.visible.first.widget.index.value, greaterThan(200));
      expect(fixture.log.mounts, lessThan(40), reason: '远跳不能逐项创建前面的未知高度内容。');
      final state = fixture.visible.firstWhere(
        (state) => tester.getRect(find.byType(CustomScrollView)).contains(fixture.rectOf(state).center),
      );
      await tester.tapAt(fixture.rectOf(state).center);
      expect(fixture.log.taps.last, state.widget.index.value);
      final position = fixture.controller.position;
      expect(position.pixels, inInclusiveRange(position.minScrollExtent, position.maxScrollExtent));
    }

    await fixture.jump(0);
    expect(fixture.controller.offset, 0);
    expect(fixture.rectAt(0), Rect.fromLTWH(0, 0, 320, 40));
    expect(fixture.rectAt(1).top, closeTo(40, .01));
    expect(fixture.rectAt(2).top, closeTo(100, .01));
    fixture.expectVisibleChain(fillsViewport: true);
    await fixture.unmount();
  });

  testWidgets('子项动态变高和同帧滚动重新测量，收缩后仍沿用相同 State', (tester) async {
    final fixture = _Fixture(tester, List<double>.filled(8, 40));
    await fixture.mount();
    final first = fixture.stateAt(0);
    final second = fixture.stateAt(1);
    final firstElement = tester.element(find.byWidget(first.widget));
    final firstRender = firstElement.renderObject;

    fixture.resize(0, 100);
    await tester.pump();
    expect(fixture.stateAt(0), same(first));
    expect(fixture.stateAt(1), same(second));
    expect(tester.element(find.byWidget(first.widget)), same(firstElement));
    expect(firstElement.renderObject, same(firstRender));
    expect(fixture.rectAt(0).height, 100);
    expect(fixture.rectAt(1).top, 100);
    expect(fixture.rectAt(2).top, 140);

    fixture.resize(1, 120);
    fixture.controller.jumpTo(1);
    await tester.pump();
    expect(fixture.controller.offset, 1);
    expect(fixture.rectAt(0).top, -1);
    expect(fixture.rectAt(1), Rect.fromLTWH(0, 99, 320, 120));
    expect(fixture.rectAt(2).top, 219);

    fixture.resize(0, 20);
    fixture.resize(1, 40);
    fixture.controller.jumpTo(0);
    await tester.pump();
    expect(fixture.stateAt(0), same(first));
    expect(fixture.stateAt(1), same(second));
    expect(fixture.rectAt(0).height, 20);
    expect(fixture.rectAt(1).top, 20);
    expect(fixture.rectAt(2).top, 60);

    // 单项自然高度可以超过视口，滚到该项中间时仍保留完整实测尺寸。
    fixture.resize(0, 500);
    await tester.pump();
    expect(fixture.rectAt(0).height, 500);
    await fixture.jump(250);
    expect(fixture.rectAt(0), Rect.fromLTWH(0, -250, 320, 500));
    fixture.expectVisibleChain(fillsViewport: true);
    await fixture.unmount();
  });

  testWidgets('连续零高度条目之后仍能测量正常条目并到达后续 Sliver', (tester) async {
    final fixture = _Fixture(tester, [0, 0, 0, 40, 60, 0, 80, 100], itemType: (index) => index % 3);
    await fixture.mount(
      after: [
        SliverToBoxAdapter(
          child: SizedBox(key: ValueKey('零高之后'), height: 80, child: Text('零高之后')),
        ),
      ],
    );

    expect(fixture.rectAt(3), Rect.fromLTWH(0, 0, 320, 40));
    expect(fixture.rectAt(4), Rect.fromLTWH(0, 40, 320, 60));
    expect(fixture.rectAt(6), Rect.fromLTWH(0, 100, 320, 80));
    expect(fixture.rectAt(7).top, 180);
    expect(fixture.controller.position.maxScrollExtent, closeTo(120, .01));
    await tester.tap(find.text('自然 3'));
    await tester.tap(find.text('自然 6'));
    expect(fixture.log.taps, [3, 6]);

    await fixture.jump(fixture.controller.position.maxScrollExtent);
    expect(fixture.rectAt(7).bottom, closeTo(160, .01));
    expect(tester.getRect(find.byKey(ValueKey('零高之后'))), Rect.fromLTWH(0, 160, 320, 80));
    await fixture.jump(0);
    expect(fixture.rectAt(3).top, 0);
    await fixture.unmount();
  });

  testWidgets('全部零高和空列表不占据范围，恢复正常数据后重新测量', (tester) async {
    final fixture = _Fixture(tester, List<double>.filled(16, 0));
    final before = [SliverToBoxAdapter(child: SizedBox(height: 60))];
    final after = [
      SliverToBoxAdapter(
        child: SizedBox(key: ValueKey('空列表后'), height: 80, child: Text('空列表后')),
      ),
    ];
    await fixture.mount(before: before, after: after);
    expect(fixture.controller.position.maxScrollExtent, 0);
    expect(tester.getRect(find.byKey(ValueKey('空列表后'))), Rect.fromLTWH(0, 60, 320, 80));

    await tester.pumpWidget(fixture.page(count: 0, before: before, after: after));
    await _settle(tester);
    expect(find.byType(_NaturalItem), findsNothing);
    expect(fixture.log.live, isEmpty);
    expect(fixture.log.disposals, fixture.log.mounts);
    expect(fixture.controller.position.maxScrollExtent, 0);
    expect(tester.getRect(find.byKey(ValueKey('空列表后'))).top, 60);

    fixture.extents.value = [40, 60, 80];
    await tester.pumpWidget(fixture.page(before: before, after: after));
    await _settle(tester);
    expect(fixture.rectAt(0), Rect.fromLTWH(0, 60, 320, 40));
    expect(fixture.rectAt(1).top, 100);
    expect(fixture.rectAt(2).top, 160);
    expect(fixture.controller.position.maxScrollExtent, closeTo(80, .01));
    await fixture.unmount();
  });

  testWidgets('共享 Obs 已标脏时同帧缩短数据和数量，不构建越界的活跃项或池项', (tester) async {
    final controller = _configure(tester);
    final data = Obs(List<double>.generate(1000, (index) => 40 + (index % 3) * 20.0));
    addTearDown(data.dispose);
    final builtIndices = <int>[];
    int typeFor(int index) => index ~/ 20;
    Widget builder(BuildContext context, ValueListenable<int> index) => ObsBuilder(
      listenables: [index],
      builder: (_) {
        final value = index.value;
        builtIndices.add(value);
        return SizedBox(height: data.value[value], child: Text('共享 $value'));
      },
    );
    Widget page() => MaterialApp(
      home: CustomScrollView(
        controller: controller,
        physics: ClampingScrollPhysics(),
        scrollCacheExtent: ScrollCacheExtent.pixels(0),
        slivers: [
          ElSliverList.recycler(
            itemCount: data.rawValue.length,
            itemType: typeFor,
            maxRecycledItems: 4,
            itemBuilder: builder,
          ),
        ],
      ),
    );
    Set<int> indices({bool includePool = false}) => tester
        .widgetList<Text>(find.textContaining(RegExp(r'^共享 \d+$'), skipOffstage: !includePool))
        .map((text) => int.parse(text.data!.split(' ').last))
        .toSet();

    await tester.pumpWidget(page());
    await _settle(tester);
    for (final offset in [12000.0, 24000.0]) {
      controller.jumpTo(offset);
      await _settle(tester);
    }
    final active = indices();
    final pooled = indices(includePool: true).difference(active);
    expect(active, isNotEmpty);
    expect(active, everyElement(greaterThan(3)));
    expect(pooled, isNotEmpty, reason: '必须同时覆盖已经标脏的离屏池项。');
    expect(pooled.any((index) => index >= 3), isTrue, reason: '池中必须存在缩减后越界的旧绑定。');
    builtIndices.clear();

    // 先让共享数据的订阅者进入脏队列，再在同一帧更新数量。
    data.rawValue.removeRange(3, data.rawValue.length);
    data.notify();
    await tester.pumpWidget(page());
    expect(tester.takeException(), isNull);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(builtIndices, isNotEmpty);
    expect(builtIndices, everyElement(inInclusiveRange(0, 2)));
    expect(indices(includePool: true), unorderedEquals([0, 1, 2]));
    expect(find.text('共享 0').hitTestable(), findsOneWidget);
    expect(find.text('共享 2').hitTestable(), findsOneWidget);
    expect(controller.offset, 0);
    expect(controller.position.maxScrollExtent, 0);

    await tester.pumpWidget(SizedBox.shrink());
    data.notify();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final layout in ['List', 'Grid', 'Masonry']) {
    testWidgets('$layout 共享 Obs 已标脏时同帧改变结构类型，不构建旧类型绑定', (tester) async {
      final controller = _configure(tester);
      final data = Obs<List<Object>>(['原文字', 1]);
      addTearDown(data.dispose);
      Object typeFor(int index) => data.rawValue[index].runtimeType;
      Widget builder(BuildContext context, ValueListenable<int> index) {
        final type = typeFor(index.value);
        return ObsBuilder(
          listenables: [index],
          builder: (_) {
            final value = data.value[index.value];
            return SizedBox(height: 40, child: Text(type == String ? value as String : '数字 ${value as int}'));
          },
        );
      }

      Widget page() => MaterialApp(
        home: CustomScrollView(
          controller: controller,
          scrollCacheExtent: ScrollCacheExtent.pixels(0),
          slivers: [
            switch (layout) {
              'Grid' => ElSliverGrid.recycler(
                itemCount: data.rawValue.length,
                itemType: typeFor,
                maxRecycledItems: 4,
                itemBuilder: builder,
                crossAxisCount: 2,
              ),
              'Masonry' => ElSliverMasonry.recycler(
                itemCount: data.rawValue.length,
                itemType: typeFor,
                maxRecycledItems: 4,
                itemBuilder: builder,
                crossAxisCount: 2,
              ),
              _ => ElSliverList.recycler(
                itemCount: data.rawValue.length,
                itemType: typeFor,
                maxRecycledItems: 4,
                itemBuilder: builder,
              ),
            },
          ],
        ),
      );

      await tester.pumpWidget(page());
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('原文字').hitTestable(), findsOneWidget);
      expect(find.text('数字 1').hitTestable(), findsOneWidget);

      // 旧类型子树已进入脏队列；数量不变，但两个位置的数据结构互换。
      data.rawValue[0] = 2;
      data.rawValue[1] = '新文字';
      data.notify();
      await tester.pumpWidget(page());
      expect(tester.takeException(), isNull);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('数字 2').hitTestable(), findsOneWidget);
      expect(find.text('新文字').hitTestable(), findsOneWidget);
      expect(find.text('原文字', skipOffstage: false), findsNothing);
      expect(find.text('数字 1', skipOffstage: false), findsNothing);

      await tester.pumpWidget(SizedBox.shrink());
      data.notify();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  for (final reverse in [false, true]) {
    testWidgets('横向自然宽度 reverse=$reverse 连续排布、命中和回退', (tester) async {
      final sizes = List<double>.generate(9, (index) => 40 + (index % 3) * 20.0);
      final fixture = _Fixture(tester, sizes, axis: Axis.horizontal, reverse: reverse, itemType: (index) => index % 2);
      await fixture.mount(
        before: [SliverToBoxAdapter(child: SizedBox(width: 20))],
        after: [
          SliverToBoxAdapter(
            child: SizedBox(key: ValueKey('横向列表后'), width: 60, child: Text('横向列表后')),
          ),
        ],
      );

      final first = fixture.rectAt(0);
      final second = fixture.rectAt(1);
      expect(first.width, 40);
      expect(second.width, 60);
      expect(reverse ? first.right : first.left, reverse ? 300 : 20);
      expect(reverse ? second.right : second.left, reverse ? 260 : 60);
      fixture.expectVisibleChain();
      await tester.tapAt(first.center);

      await fixture.jump(200);
      final fourth = fixture.rectAt(3);
      expect(reverse ? fourth.right : fourth.left, reverse ? 320 : 0);
      fixture.expectVisibleChain();
      await tester.tapAt(fourth.center);
      expect(fixture.log.taps, [0, 3]);

      await fixture.jump(fixture.controller.position.maxScrollExtent);
      expect(fixture.controller.position.maxScrollExtent, closeTo(300, .01));
      final footer = tester.getRect(find.byKey(ValueKey('横向列表后')));
      expect(footer, reverse ? Rect.fromLTWH(0, 0, 60, 240) : Rect.fromLTWH(260, 0, 60, 240));
      await fixture.jump(0);
      expect(fixture.rectAt(0), first);
      await fixture.unmount();
    });
  }

  testWidgets('初始大缓存的前方补测改变估值后，继续补齐可见尾端', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(320, 500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ScrollController(initialScrollOffset: 1100);
    addTearDown(controller.dispose);
    final sizes = <double>[100, 500, 100, 100, 100, 100, 500, 500, 500, 500];
    final taps = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          physics: ClampingScrollPhysics(),
          scrollCacheExtent: ScrollCacheExtent.pixels(500),
          slivers: [
            ElSliverList.recycler(
              itemCount: sizes.length,
              itemType: (index) => index == 0 ? 'A' : 'B',
              itemBuilder: (_, index) => ValueListenableBuilder<int>(
                valueListenable: index,
                builder: (_, value, _) => SizedBox(
                  key: ValueKey('回填 $value'),
                  height: sizes[value],
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps.add(index.value),
                    child: Align(alignment: Alignment.topLeft, child: Text('回填 $value')),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 5000, child: Text('后续长 Sliver'))),
          ],
        ),
      ),
    );

    // 首帧前方补测将第 6 项移到 [1000, 1500)，同一轮还须继续补入第 7 项。
    expect(tester.takeException(), isNull);
    expect(controller.offset, 1100);
    final sixth = tester.getRect(find.byKey(ValueKey('回填 6')));
    final seventh = tester.getRect(find.byKey(ValueKey('回填 7')));
    expect(sixth, Rect.fromLTWH(0, -100, 320, 500));
    expect(seventh.top, closeTo(sixth.bottom, .01));
    expect(seventh.top, 400);
    expect(seventh.height, 500);
    await tester.tapAt(Offset(160, 450));
    expect(taps, [7], reason: '视口底部的 100 像素必须属于第 7 项，不能留下未挂载的空白。');

    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('没有主轴尺寸的文本按换行自然测量，视口变窄后重新排布', (tester) async {
    final controller = _configure(tester, size: Size(320, 400));
    final texts = ['short', List.filled(4, 'natural layout').join(' '), 'tail'];
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          scrollCacheExtent: ScrollCacheExtent.pixels(0),
          slivers: [
            ElSliverList.recycler(
              itemCount: texts.length,
              itemBuilder: (_, index) => ValueListenableBuilder<int>(
                valueListenable: index,
                builder: (_, value, _) => Padding(
                  key: ValueKey('文本 $value'),
                  padding: EdgeInsets.all(8),
                  child: Text(texts[value], style: TextStyle(fontSize: 16, height: 1.25)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await _settle(tester);
    Rect row(int index) => tester.getRect(find.byKey(ValueKey('文本 $index')));
    final firstHeight = row(0).height;
    final longHeight = row(1).height;
    final lastTop = row(2).top;
    expect(longHeight, greaterThan(firstHeight));
    expect(row(1).top, closeTo(row(0).bottom, .01));
    expect(row(2).top, closeTo(row(1).bottom, .01));

    tester.view.physicalSize = Size(160, 400);
    await _settle(tester);
    expect(row(0).height, firstHeight);
    expect(row(1).width, 160);
    expect(row(1).height, greaterThan(longHeight));
    expect(row(1).top, closeTo(row(0).bottom, .01));
    expect(row(2).top, closeTo(row(1).bottom, .01));
    expect(row(2).top, greaterThan(lastTop));
    expect(controller.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
