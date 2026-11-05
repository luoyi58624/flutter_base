import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = _FrameBudgetBinding();
  testWidgets('一万条不同数据复用后复选状态归属于数据身份', (tester) async {
    final adapter = _Rows(10000);
    final list = _list(adapter)..setItemViewCacheSize(0);
    await _pump(tester, list);
    expect(adapter.holders.length, lessThan(12));

    await tester.tap(find.byKey(ValueKey('checkbox-1')));
    await tester.pumpAndSettle();
    expect(adapter.selected, {1});

    list.scrollToPosition(9000);
    await tester.pump();
    await tester.pump();
    expect(find.text('数据 9000：内容不同'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byKey(ValueKey('checkbox-9001'))).value, isFalse);
    await tester.tap(find.byKey(ValueKey('checkbox-9001')));
    await tester.pumpAndSettle();
    expect(adapter.selected, {1, 9001});
    expect(adapter.bindings.values.any((ids) => ids.toSet().length > 1), isTrue);

    list.scrollToPosition(0);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byKey(ValueKey('checkbox-1'))).value, isTrue);
    expect(tester.widget<Checkbox>(find.byKey(ValueKey('checkbox-2'))).value, isFalse);
    expect(adapter.selected, {1, 9001});
    expect(adapter.holders.length, lessThan(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('稳定小幅平移不重建测量或绘制已有正文', (tester) async {
    final adapter = _Rows(1000);
    final list = _list(adapter)..setItemViewCacheSize(0);
    await _pump(tester, list);
    final holders = [
      for (final index in [1, 2, 3]) list.findViewHolderForAdapterPosition(index)! as _Holder,
    ];
    final before = {for (final holder in holders) holder.serial: adapter.work.snapshot(holder.serial)};
    final positions = {
      for (final holder in holders) holder.serial: tester.getTopLeft(find.byWidget(holder.itemView)).dy,
    };

    for (var frame = 1; frame <= 6; frame++) {
      list.scrollBy(0, 3.25);
      await tester.pump(Duration(milliseconds: 8));
      for (final holder in holders) {
        expect(adapter.work.snapshot(holder.serial), before[holder.serial]);
        expect(
          tester.getTopLeft(find.byWidget(holder.itemView)).dy,
          closeTo(positions[holder.serial]! - frame * 3.25, 1e-6),
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('连续滚动复用同一裁剪合成层且卸载后释放', (tester) async {
    final list = _list(_Rows(100, cheap: true));
    await _pump(tester, list);
    final clips = tester.layers.whereType<ClipRectLayer>().where(
      (layer) => layer.clipRect == Rect.fromLTWH(0, 0, 320, 240),
    );
    expect(clips, hasLength(1));
    final clip = clips.single;
    for (var frame = 0; frame < 4; frame++) {
      list.scrollBy(0, 9.25);
      await tester.pump();
      final current = tester.layers.whereType<ClipRectLayer>().where(
        (layer) => layer.clipRect == Rect.fromLTWH(0, 0, 320, 240),
      );
      expect(current, hasLength(1));
      expect(current.single, same(clip));
      expect(clip.debugDisposed, isFalse);
    }
    await tester.pumpWidget(SizedBox());
    expect(clip.debugDisposed, isTrue, reason: '视口释放后不应再持有旧裁剪层');
    expect(tester.takeException(), isNull);
  });

  testWidgets('缓存包装后正文自行变脏仍重建并传播展开尺寸和异步文本', (tester) async {
    final adapter = _Rows(100);
    final list = _list(adapter);
    await _pump(tester, list);
    final first = list.findViewHolderForAdapterPosition(1)! as _Holder;
    final second = list.findViewHolderForAdapterPosition(2)!;
    final secondTop = tester.getTopLeft(find.byWidget(second.itemView)).dy;
    final beforeBuilds = adapter.work.builds[first.serial]!;

    first.model.value = first.model.value.copy(extent: 125, title: '已经展开的正文');
    await tester.pump();
    expect(find.text('已经展开的正文'), findsOneWidget);
    expect(adapter.work.builds[first.serial], greaterThan(beforeBuilds));
    expect(tester.getSize(find.byWidget(first.itemView)).height, 125);
    expect(tester.getTopLeft(find.byWidget(second.itemView)).dy, closeTo(secondTop + 75, .001));

    unawaited(
      Future<void>.delayed(Duration(milliseconds: 12), () {
        first.model.value = first.model.value.copy(title: '异步正文已就绪');
      }),
    );
    await tester.pump(Duration(milliseconds: 12));
    await tester.pump();
    expect(find.text('异步正文已就绪'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('一万条数据的局部通知只读取变更范围类型且保持可见锚点', (tester) async {
    final adapter = _Rows(10000);
    final list = _list(adapter);
    await _pump(tester, list);
    final target = list.findViewHolderForAdapterPosition(1)!;
    final top = tester.getTopLeft(find.byWidget(target.itemView)).dy;
    adapter.typeQueries.clear();

    for (var index = 8000; index < 8003; index++) {
      adapter.items[index] = adapter.items[index].copy(type: 1, extent: 73);
    }
    adapter.notifyItemRangeChanged(8000, 3, 'content');
    expect(adapter.typeQueries, orderedEquals([8000, 8001, 8002]));
    await tester.pump();
    expect(adapter.typeQueries.length, lessThan(32), reason: '局部更新不能重新扫描一万条记录');
    expect(tester.getTopLeft(find.byWidget(target.itemView)).dy, closeTo(top, 1e-6));

    adapter.items[1] = adapter.items[1].copy(type: 1, title: '替换为另一种结构');
    adapter.notifyItemChanged(1, 'type');
    await tester.pump();
    expect(list.findViewHolderForAdapterPosition(1)!.getItemViewType(), 1);
    expect(find.text('替换为另一种结构'), findsOneWidget);
    expect(adapter.wrongTypes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('插入移动删除后仍遵守依赖位置的结构类型', (tester) async {
    final adapter = _Rows(200, positionTypes: true)..setHasStableIds(true);
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = _list(adapter, layout: layout);
    await _pump(tester, list);
    list.scrollToPosition(30);
    await tester.pumpAndSettle();

    void verify() {
      for (var index = layout.findFirstVisibleItemPosition(); index <= layout.findLastVisibleItemPosition(); index++) {
        final holder = list.findViewHolderForAdapterPosition(index);
        if (holder == null) continue;
        expect(holder.getItemViewType(), index % 3);
        expect(holder.getItemId(), adapter.items[index].id);
      }
      expect(adapter.wrongTypes, isEmpty);
      expect(tester.takeException(), isNull);
    }

    adapter.items.insert(0, _Data(50000));
    adapter.notifyItemInserted(0);
    await tester.pumpAndSettle();
    verify();
    adapter.items.insert(2, adapter.items.removeAt(1));
    adapter.notifyItemMoved(1, 2);
    await tester.pumpAndSettle();
    verify();
    adapter.items.removeAt(0);
    adapter.notifyItemRemoved(0);
    await tester.pumpAndSettle();
    verify();
  });

  testWidgets('远距离跳转后向上首次测量异高前项不挪动已显示内容', (tester) async {
    final adapter = _Rows(1000);
    // 前一项此前没有测量，且与同类型默认高度差别很大。
    adapter.items[499] = adapter.items[499].copy(extent: 173.25);
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = _list(adapter, layout: layout)..setItemViewCacheSize(0);
    await _pump(tester, list);
    layout.scrollToPositionWithOffset(500, 0);
    await tester.pumpAndSettle();
    final holder = list.findViewHolderForAdapterPosition(500)!;
    final before = tester.getTopLeft(find.byWidget(holder.itemView)).dy;
    list.scrollBy(0, -12.75);
    await tester.pump();
    expect(list.findViewHolderForAdapterPosition(500), same(holder));
    expect(tester.getTopLeft(find.byWidget(holder.itemView)).dy, closeTo(before + 12.75, 1e-5));
    expect(list.findViewHolderForAdapterPosition(499), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('小数高度和内边距不会让稳定惯性因浮点修正反复重启', (tester) async {
    final adapter = _Rows(1000, extent: 47.3, cheap: true);
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = _list(adapter, layout: layout)..setPadding(7.1, 13.7, 9.3, 17.9);
    await _pump(tester, list);
    layout.scrollToPositionWithOffset(100, .37);
    await tester.pumpAndSettle();
    final position = _position(tester, list);
    expect(list.fling(0, 1900), isTrue);
    await tester.pump();
    // 活动身份用于检测同一段惯性是否被无意义的尺寸修正打断。
    // ignore: invalid_use_of_protected_member
    final activity = position.activity;
    expect(activity, isA<BallisticScrollActivity>());
    var pixels = position.pixels;
    for (var frame = 0; frame < 18; frame++) {
      await tester.pump(Duration(milliseconds: 8));
      // ignore: invalid_use_of_protected_member
      expect(position.activity, same(activity), reason: '小数尺寸第 $frame 帧不应重启惯性');
      expect(position.pixels, greaterThan(pixels));
      pixels = position.pixels;
    }
    list.stopScroll();
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('预取的下一项不会被本帧刚退场的缓存项挤掉重绑', (tester) async {
    binding.useMonotonicFrameClock = true;
    addTearDown(() => binding.useMonotonicFrameClock = false);
    final adapter = _Rows(100, cheap: true, extent: 48);
    final layout = rv.LinearLayoutManager()..setInitialPrefetchItemCount(2);
    final list = _list(adapter, layout: layout)..setItemViewCacheSize(1);
    await _pump(tester, list, height: 190);
    final next = layout.findLastVisibleItemPosition() + 1;
    for (var frame = 0; frame < 10 && !adapter.bindings.values.any((ids) => ids.contains(next)); frame++) {
      // 首帧挂载可能耗完预取预算，再给稳定布局一次准备机会。
      list.scrollBy(0, .001);
      await tester.pump();
    }
    final prepared = adapter.holders.where((holder) => holder.getBindingAdapterPosition() == next).toList();
    expect(prepared, hasLength(1), reason: '轻量下一项应已在可见区外完成预取');
    expect(list.findViewHolderForAdapterPosition(next), isNull);
    final holder = prepared.single;
    final bindingCount = adapter.bindings[holder.serial]!.where((id) => id == next).length;

    list.scrollBy(0, 48);
    await tester.pump();
    expect(list.findViewHolderForAdapterPosition(next), same(holder));
    expect(adapter.bindings[holder.serial]!.where((id) => id == next).length, bindingCount);

    // 宽度变化后，下一个已经预取的 LayoutBuilder 也必须在合法布局阶段重新测量。
    await tester.pump();
    final following = next + 1;
    final followingHolder = adapter.holders.singleWhere(
      (candidate) => candidate.getBindingAdapterPosition() == following,
    );
    final followingBindings = adapter.bindings[followingHolder.serial]!.where((id) => id == following).length;
    await _pump(tester, list, width: 200, height: 190);
    list.scrollBy(0, 48);
    await tester.pump();
    expect(list.findViewHolderForAdapterPosition(following), same(followingHolder));
    expect(tester.getSize(find.byWidget(followingHolder.itemView)).width, 200);
    expect(adapter.bindings[followingHolder.serial]!.where((id) => id == following).length, followingBindings);

    layout.setItemPrefetchEnabled(false);
    await tester.pump();
    final hiddenBound = adapter.holders.where((candidate) {
      final position = candidate.getBindingAdapterPosition();
      return position >= 0 && list.findViewHolderForAdapterPosition(position) == null;
    });
    expect(hiddenBound.length, lessThanOrEqualTo(1), reason: '关闭预取后额外保留容量必须退回用户配置');
    list.setItemViewCacheSize(0);
    await tester.pump();
    expect(hiddenBound, isEmpty, reason: '缓存改为零应释放全部位置绑定缓存');
    expect(tester.takeException(), isNull);
  });

  testWidgets('缓存设为零时不偷偷保留预取绑定，退出项仍进入类型池', (tester) async {
    final adapter = _Rows(100, cheap: true);
    final layout = rv.LinearLayoutManager()..setInitialPrefetchItemCount(4);
    final list = _list(adapter, layout: layout)..setItemViewCacheSize(0);
    await _pump(tester, list);
    expect(
      adapter.holders.every((holder) => holder.getBindingAdapterPosition() <= layout.findLastVisibleItemPosition()),
      isTrue,
    );
    final original = list.findViewHolderForAdapterPosition(0)!;
    list.scrollBy(0, 250);
    await tester.pump();
    expect(list.findViewHolderForAdapterPosition(0), isNull);
    expect(original.getBindingAdapterPosition(), isNot(0));
    expect(adapter.holders.length, lessThan(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('可见集合不变时无障碍坐标也跟随滚动，隐藏池不暴露语义', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final adapter = _Rows(100, cheap: true);
      final list = _list(adapter)..setItemViewCacheSize(0);
      await _pump(tester, list);
      final finder = find.byKey(ValueKey('semantic-2'));
      final before = _semanticsRect(tester.getSemantics(finder));
      list.scrollBy(0, 11.25);
      await tester.pump();
      final after = _semanticsRect(tester.getSemantics(finder));
      // 语义根还包含逻辑像素到设备像素的变换。
      expect(after.top, closeTo(before.top - 11.25 * tester.view.devicePixelRatio, 1e-5));
      expect(after.width, before.width);
      expect(after.height, before.height);
      await tester.tap(find.text('数据 2：内容不同'));
      expect(adapter.lastTapped, 2);

      list.scrollBy(0, 300);
      await tester.pump();
      expect(find.bySemanticsLabel('row-semantic-0'), findsNothing);
      expect(find.text('数据 0：内容不同').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('非空列表移除可见数据后旧语义和点击目标立即消失', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final adapter = _Rows(100, cheap: true)..setHasStableIds(true);
      final list = _list(adapter)..setItemViewCacheSize(0);
      await _pump(tester, list);
      expect(find.bySemanticsLabel('row-semantic-1'), findsOneWidget);
      adapter.items.removeAt(1);
      adapter.notifyItemRemoved(1);
      await tester.pump();
      expect(find.bySemanticsLabel('row-semantic-1'), findsNothing);
      expect(find.text('数据 1：内容不同').hitTestable(), findsNothing);
      expect(list.findViewHolderForItemId(1), isNull);
      expect(list.findViewHolderForAdapterPosition(1)!.getItemId(), 2);
      await tester.tap(find.text('数据 2：内容不同'));
      expect(adapter.lastTapped, 2);
      list.scrollBy(0, 50);
      await tester.pump();
      expect(find.bySemanticsLabel('row-semantic-1'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('主题与宽度变化后驻留子树仍更新且返回顶部不会显示旧环境', (tester) async {
    final adapter = _Rows(300, responsive: true);
    final list = _list(adapter)..setItemViewCacheSize(0);
    await _pump(tester, list);
    list.scrollToPosition(30);
    await tester.pumpAndSettle();
    await _pump(tester, list, width: 200, brightness: Brightness.dark);
    await tester.pumpAndSettle();
    final target = list.findViewHolderForAdapterPosition(30)!;
    expect(tester.getSize(find.byWidget(target.itemView)), Size(200, 68));
    expect(tester.widget<Text>(find.text('数据 30：内容不同')).style!.color, Colors.white);
    list.scrollToPosition(0);
    await tester.pumpAndSettle();
    final first = list.findViewHolderForAdapterPosition(0)!;
    expect(tester.getSize(find.byWidget(first.itemView)), Size(200, 68));
    expect(tester.widget<Text>(find.text('数据 0：内容不同')).style!.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('环境物理能够接管惯性且程序 fling 遵循真实最小最大速度', (tester) async {
    final velocities = <double>[];
    final adapter = _Rows(1000, cheap: true);
    final list = _list(adapter);
    await _pump(tester, list, behavior: _Behavior(velocities));
    expect(_position(tester, list).physics, isA<_Physics>());
    list.scrollToPosition(100);
    await tester.pumpAndSettle();
    velocities.clear();
    expect(list.fling(0, 100), isFalse, reason: '环境最小速度为 250');
    expect(velocities, isEmpty);
    expect(list.fling(0, 5000), isTrue);
    expect(velocities, isNotEmpty);
    expect(velocities.last, 900, reason: '环境最大速度为 900');
    await tester.pump(Duration(milliseconds: 16));
    list.stopScroll();
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('环境弹性物理允许真实拖出边界并在松手后回弹', (tester) async {
    final adapter = _Rows(100, cheap: true);
    final list = _list(adapter);
    await _pump(tester, list, behavior: _BounceBehavior());
    final position = _position(tester, list);
    final first = list.findViewHolderForAdapterPosition(0)!;
    final viewport = tester.getRect(find.byWidget(list));
    final gesture = await tester.startGesture(viewport.center);
    await gesture.moveBy(Offset(0, 80));
    await tester.pump();
    // 第一次移动可能只赢得拖拽手势，第二次移动才保证有真实的滚动位移。
    await gesture.moveBy(Offset(0, 40));
    await tester.pump();
    expect(position.pixels, lessThan(0), reason: '布局不能把环境允许的弹性越界强行夹回零');
    expect(tester.getTopLeft(find.byWidget(first.itemView)).dy, closeTo(viewport.top - position.pixels, .001));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(0, .01));
    expect(tester.getTopLeft(find.byWidget(first.itemView)).dy, closeTo(viewport.top, .01));
    expect(tester.takeException(), isNull);
  });
}

class _FrameBudgetBinding extends AutomatedTestWidgetsFlutterBinding {
  // 自动测试使用固定日期；此处仅为预取缓存测试对齐单调时钟，避免退化成宿主速度相关的 1ms 预算。
  bool useMonotonicFrameClock = false;
  int? _monotonicFrameStart;

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    _monotonicFrameStart = developer.Timeline.now;
    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  Duration get currentSystemFrameTimeStamp =>
      useMonotonicFrameClock ? Duration(microseconds: _monotonicFrameStart!) : super.currentSystemFrameTimeStamp;
}

rv.RecyclerView _list(_Rows adapter, {rv.LinearLayoutManager? layout}) => rv.RecyclerView()
  ..setLayoutManager(layout ?? (rv.LinearLayoutManager()..setItemPrefetchEnabled(false)))
  ..setAdapter(adapter);

Future<void> _pump(
  WidgetTester tester,
  rv.RecyclerView list, {
  double width = 320,
  double height = 240,
  Brightness brightness = Brightness.light,
  ScrollBehavior? behavior,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      scrollBehavior: behavior,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: list),
        ),
      ),
    ),
  );
  await tester.pump();
}

ScrollPosition _position(WidgetTester tester, rv.RecyclerView list) => tester
    .state<ScrollableState>(find.descendant(of: find.byWidget(list), matching: find.byType(Scrollable)).first)
    .position;

Rect _semanticsRect(SemanticsNode node) {
  var rect = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    if (current.transform case final transform?) rect = MatrixUtils.transformRect(transform, rect);
    current = current.parent;
  }
  return rect;
}

class _Data {
  _Data(this.id, {String? title, this.extent = 50, this.type = 0, this.selected = false})
    : title = title ?? '数据 $id：内容不同';

  final int id;
  final String title;
  final double extent;
  final int type;
  final bool selected;

  _Data copy({String? title, double? extent, int? type, bool? selected}) => _Data(
    id,
    title: title ?? this.title,
    extent: extent ?? this.extent,
    type: type ?? this.type,
    selected: selected ?? this.selected,
  );
}

class _Work {
  final builds = <int, int>{};
  final layouts = <int, int>{};
  final paints = <int, int>{};

  (int, int, int) snapshot(int serial) => (builds[serial] ?? 0, layouts[serial] ?? 0, paints[serial] ?? 0);
}

class _Holder extends rv.ViewHolder {
  _Holder(this.serial, this.model, Widget view) : super(view);
  final int serial;
  final ValueNotifier<_Data> model;
}

class _Rows extends rv.Adapter<_Holder> {
  _Rows(int count, {double extent = 50, this.positionTypes = false, this.cheap = false, this.responsive = false})
    : items = List.generate(count, (index) => _Data(index, extent: extent));

  final List<_Data> items;
  final bool positionTypes;
  final bool cheap;
  final bool responsive;
  final work = _Work();
  final holders = <_Holder>[];
  final typeQueries = <int>[];
  final bindings = <int, List<int>>{};
  final wrongTypes = <int>[];
  int? lastTapped;

  Set<int> get selected => {
    for (final item in items)
      if (item.selected) item.id,
  };

  @override
  int getItemCount() => items.length;

  @override
  int getItemId(int position) => items[position].id;

  @override
  int getItemViewType(int position) {
    typeQueries.add(position);
    return positionTypes ? position % 3 : items[position].type;
  }

  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final serial = holders.length;
    final model = ValueNotifier(_Data(-1, type: viewType));
    final view = Builder(
      builder: (context) {
        final color = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
        return ValueListenableBuilder<_Data>(
          valueListenable: model,
          builder: (context, data, _) => LayoutBuilder(
            builder: (context, constraints) {
              work.builds.update(serial, (count) => count + 1, ifAbsent: () => 1);
              final height = data.extent + (responsive && constraints.maxWidth < 250 ? 18 : 0);
              final text = Text(data.title, style: TextStyle(color: color), maxLines: 1);
              return _MeasureProbe(
                work: work,
                serial: serial,
                child: SizedBox(
                  height: height,
                  child: Semantics(
                    key: ValueKey('semantic-${data.id}'),
                    label: 'row-semantic-${data.id}',
                    container: true,
                    explicitChildNodes: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => lastTapped = data.id,
                      child: cheap
                          ? Align(alignment: Alignment.centerLeft, child: text)
                          : Row(
                              children: [
                                Checkbox(
                                  key: ValueKey('checkbox-${data.id}'),
                                  value: data.selected,
                                  onChanged: (value) {
                                    final position = items.indexWhere((item) => item.id == data.id);
                                    items[position] = items[position].copy(selected: value);
                                    notifyItemChanged(position, 'selected');
                                  },
                                ),
                                Expanded(child: text),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    final holder = _Holder(serial, model, view);
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) {
    final expectedType = positionTypes ? position % 3 : items[position].type;
    if (holder.getItemViewType() != expectedType) wrongTypes.add(position);
    bindings.putIfAbsent(holder.serial, () => []).add(items[position].id);
    holder.model.value = items[position];
  }
}

class _MeasureProbe extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MeasureProbe({required this.work, required this.serial, required super.child});
  final _Work work;
  final int serial;

  @override
  RenderObject createRenderObject(BuildContext context) => _MeasureBox(work, serial);
}

class _MeasureBox extends RenderProxyBox {
  _MeasureBox(this.work, this.serial);
  final _Work work;
  final int serial;

  @override
  void performLayout() {
    work.layouts.update(serial, (count) => count + 1, ifAbsent: () => 1);
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    work.paints.update(serial, (count) => count + 1, ifAbsent: () => 1);
    super.paint(context, offset);
  }
}

class _Behavior extends MaterialScrollBehavior {
  // ignore: prefer_const_constructors_in_immutables
  _Behavior(this.velocities);
  final List<double> velocities;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => _Physics(velocities);
}

class _Physics extends ClampingScrollPhysics {
  // ignore: prefer_const_constructors_in_immutables
  _Physics(this.velocities, {super.parent});
  final List<double> velocities;

  @override
  _Physics applyTo(ScrollPhysics? ancestor) => _Physics(velocities, parent: buildParent(ancestor));

  @override
  double get minFlingVelocity => 250;

  @override
  double get maxFlingVelocity => 900;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    velocities.add(velocity);
    return super.createBallisticSimulation(position, velocity);
  }
}

class _BounceBehavior extends MaterialScrollBehavior {
  // ignore: prefer_const_constructors_in_immutables
  _BounceBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
