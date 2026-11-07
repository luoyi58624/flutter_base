import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_base/src/flutter/views/recycler_view/work_probe.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Record = ({int id, double extent});

class _Cells extends rv.Adapter<_Cell> {
  _Cells(List<double> extents, {this.horizontal = false, this.typeFor})
    : records = [for (var index = 0; index < extents.length; index++) (id: index, extent: extents[index])] {
    setHasStableIds(true);
  }
  final List<_Record> records;
  final bool horizontal;
  final int Function(int)? typeFor;
  final holders = <_Cell>[];
  @override
  int getItemCount() => records.length;
  @override
  int getItemId(int position) => records[position].id;
  @override
  int getItemViewType(int position) => typeFor?.call(position) ?? 0;
  @override
  _Cell onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final holder = _Cell(horizontal);
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_Cell holder, int position, [List<Object> payloads = const []]) =>
      holder.record.value = records[position];
  void dispose() {
    for (final holder in holders) {
      holder.record.dispose();
    }
  }
}

class _Cell extends rv.ViewHolder {
  _Cell(bool horizontal) : this._(ValueNotifier<_Record>((id: -1, extent: 0)), horizontal);
  _Cell._(this.record, bool horizontal)
    : super(
        ValueListenableBuilder<_Record>(
          valueListenable: record,
          builder: (context, value, _) => SizedBox(
            width: horizontal ? value.extent : null,
            height: horizontal ? null : value.extent,
            child: Text('Item ${value.id}'),
          ),
        ),
      );
  final ValueNotifier<_Record> record;
}

class _Spans extends rv.SpanSizeLookup {
  _Spans(this.sizes);
  final List<int> sizes;
  @override
  int getSpanSize(int position) => sizes[position];
}

class _HeaderSpans extends rv.SpanSizeLookup {
  @override
  int getSpanSize(int position) => position == 0 ? 2 : 1;
}

Future<rv.RecyclerView> _open(
  WidgetTester tester,
  _Cells adapter,
  rv.LayoutManager manager, {
  bool rtl = false,
  Size? size,
  bool scrollbar = false,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size ?? Size(300, 260);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(adapter.dispose);
  manager.setItemPrefetchEnabled(false);
  final list = rv.RecyclerView(controller: ScrollController(keepScrollOffset: false))
    ..setLayoutManager(manager)
    ..setAdapter(adapter)
    ..setPadding(padding.left, padding.top, padding.right, padding.bottom);
  addTearDown(list.controller!.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: rtl ? .rtl : .ltr,
        child: ScrollConfiguration(
          behavior: ScrollBehavior().copyWith(scrollbars: false),
          child: scrollbar ? CupertinoScrollbar(controller: list.controller, thumbVisibility: true, child: list) : list,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return list;
}

Finder _cell(int id) => find.ancestor(of: find.text('Item $id'), matching: find.byType(SizedBox)).first;
Rect _rect(WidgetTester tester, int id) => tester.getRect(_cell(id));

void main() {
  test('跨度查询与参数沿用 AndroidX 分组规则', () {
    final manager = rv.GridLayoutManager(null, 3);
    final spans = _Spans([3, 1, 2, 2, 2, 1]);
    manager.setSpanSizeLookup(spans);
    expect([for (var i = 0; i < 6; i++) spans.getSpanIndex(i, 3)], [0, 0, 1, 0, 0, 2]);
    expect([for (var i = 0; i < 6; i++) spans.getSpanGroupIndex(i, 3)], [0, 1, 1, 2, 3, 3]);
    expect(() => manager.setSpanCount(0), throwsArgumentError);
    expect(() => manager.setStackFromEnd(true), throwsUnsupportedError);
    expect(() => rv.StaggeredGridLayoutManager(0, rv.RecyclerView.VERTICAL), throwsArgumentError);
  });

  testWidgets('Grid 同行等高、逐行推进，每个格子拥有独立 holder', (tester) async {
    final adapter = _Cells([80, 40, 60, 120, 40, 90]);
    final list = await _open(tester, adapter, rv.GridLayoutManager(null, 2));
    expect(_rect(tester, 0), Rect.fromLTWH(0, 0, 150, 80));
    expect(_rect(tester, 1), Rect.fromLTWH(150, 0, 150, 80));
    expect(_rect(tester, 2), Rect.fromLTWH(0, 80, 150, 120));
    expect(_rect(tester, 3), Rect.fromLTWH(150, 80, 150, 120));
    expect(_rect(tester, 4).top, 200);
    expect(list.findViewHolderForItemId(0), isNot(same(list.findViewHolderForItemId(1))));
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('Grid 跨列条目先分组再以组内最大高度推进', (tester) async {
    final manager = rv.GridLayoutManager(null, 3)..setSpanSizeLookup(_Spans([3, 1, 2, 2, 1]));
    await _open(tester, _Cells([50, 70, 40, 60, 80]), manager);
    expect(_rect(tester, 0), Rect.fromLTWH(0, 0, 300, 50));
    expect(_rect(tester, 1), Rect.fromLTWH(0, 50, 100, 70));
    expect(_rect(tester, 2), Rect.fromLTWH(100, 50, 200, 70));
    expect(_rect(tester, 3), Rect.fromLTWH(0, 120, 200, 80));
    expect(_rect(tester, 4), Rect.fromLTWH(200, 120, 100, 80));
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('Grid 垂直 RTL 镜像跨度，反向布局保留正确命中坐标', (tester) async {
    final manager = rv.GridLayoutManager(null, 2, rv.RecyclerView.VERTICAL, true);
    await _open(tester, _Cells(List.filled(20, 50)), manager, rtl: true);
    expect(_rect(tester, 0), Rect.fromLTWH(150, 210, 150, 50));
    expect(_rect(tester, 1), Rect.fromLTWH(0, 210, 150, 50));
    expect(tester.getTopLeft(_cell(2)).dy, 160);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('水平 Grid 跨度表示行数，RTL 反转主轴', (tester) async {
    await _open(
      tester,
      _Cells(List.filled(20, 80), horizontal: true),
      rv.GridLayoutManager(null, 2, rv.RecyclerView.HORIZONTAL),
      rtl: true,
    );
    expect(_rect(tester, 0), Rect.fromLTWH(220, 0, 80, 130));
    expect(_rect(tester, 1), Rect.fromLTWH(220, 130, 80, 130));
    expect(_rect(tester, 2).left, 140);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('Grid 万项远跳仍按需挂载并复用现有子树，跨度变化重排', (tester) async {
    final adapter = _Cells(List.filled(10000, 100));
    final manager = rv.GridLayoutManager(null, 2);
    final list = await _open(tester, adapter, manager)
      ..setItemViewCacheSize(0);
    final holder = list.findViewHolderForItemId(0)!;
    final element = find.byWidget(holder.itemView).evaluate().single;
    final render = element.renderObject;
    list.scrollToPosition(9000);
    await tester.pumpAndSettle();
    expect(find.text('Item 9000'), findsOneWidget);
    expect(holder.getItemId(), isNot(0));
    expect(find.byWidget(holder.itemView).evaluate().single, same(element));
    expect(element.renderObject, same(render));
    expect(adapter.holders.length, lessThan(20));
    manager.setSpanCount(3);
    await tester.pumpAndSettle();
    expect(_rect(tester, manager.findFirstVisibleItemPosition()).width, closeTo(100, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  for (final staggered in [false, true]) {
    testWidgets('${staggered ? '瀑布流' : 'Grid'}连续跨行滚动不会因锚点 holder 被复用而跳底', (tester) async {
      final adapter = _Cells(List.filled(10000, 100));
      final manager = staggered
          ? rv.StaggeredGridLayoutManager(2, rv.RecyclerView.VERTICAL)
          : rv.GridLayoutManager(null, 2);
      final list = (await _open(tester, adapter, manager))..setItemViewCacheSize(0);
      for (final offset in [150.0, 300.0, 450.0, 600.0, 450.0, 250.0, 100.0]) {
        list.controller!.jumpTo(offset);
        await tester.pump(Duration(milliseconds: 16));
        expect(list.controller!.offset, closeTo(offset, .01), reason: '布局不能将一次滚动放大为额外位移');
        expect(tester.takeException(), isNull);
      }
      expect(adapter.holders.length, lessThan(20));
      await tester.pumpWidget(SizedBox());
    });
  }

  testWidgets('Grid 跨列横幅不污染普通行的总高度和远距离定位', (tester) async {
    final manager = rv.GridLayoutManager(null, 2)..setSpanSizeLookup(_HeaderSpans());
    final adapter = _Cells([120, ...List.filled(10000, 80)]);
    final list = await _open(tester, adapter, manager);
    final position = list.controller!.position;
    final maximum = 120 + 5000 * 80 - position.viewportDimension;
    expect(position.maxScrollExtent, closeTo(maximum, .01));
    for (final ratio in [.25, .5, .75, 1.0, .5, 0.0]) {
      position.jumpTo(maximum * ratio);
      await tester.pump(Duration(milliseconds: 16));
      expect(position.pixels, closeTo(maximum * ratio, .01));
      expect(position.maxScrollExtent, closeTo(maximum, .01));
      if (ratio == 1) expect(_rect(tester, 10000).bottom, closeTo(position.viewportDimension, .01));
    }
    expect(adapter.holders.length, lessThan(20));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('Grid 实际鼠标拖拽 Cupertino 滚动条按轨道比例定位，往返拖拽不会提前到底', (tester) async {
    final manager = rv.GridLayoutManager(null, 2)..setSpanSizeLookup(_HeaderSpans());
    final adapter = _Cells([120, ...List.filled(10000, 80)]);
    final list = await _open(tester, adapter, manager, scrollbar: true);
    final position = list.controller!.position;
    final maximum = position.maxScrollExtent;
    final geometryBuilds = RecyclerWorkProbe.gridGeometryBuilds;
    // Cupertino 默认最短滑块 36px，上下各留 3px，鼠标从滑块中心按住。
    final scrollbar = tester.state<RawScrollbarState<CupertinoScrollbar>>(find.byType(CupertinoScrollbar));
    // ignore: invalid_use_of_protected_member
    final painter = scrollbar.scrollbarPainter;
    expect(painter.hitTestOnlyThumbInteractive(Offset(295, 21), PointerDeviceKind.mouse), isTrue);
    final gesture = await tester.startGesture(Offset(295, 21), kind: PointerDeviceKind.mouse);
    await tester.pump(Duration(milliseconds: 150));
    for (final ratio in [.25, .5, .75, 1.0, .5, 0.0]) {
      await gesture.moveTo(Offset(295, 21 + (260 - 6 - 36) * ratio));
      await tester.pump(Duration(milliseconds: 16));
      expect(position.pixels / maximum, closeTo(ratio, .015));
      expect(position.maxScrollExtent, closeTo(maximum, .01));
      if (ratio > 0 && ratio < 1) {
        final expected = ((position.pixels - 120) / 80).floor() * 2 + 1;
        expect(manager.findFirstVisibleItemPosition(), expected);
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(adapter.holders.length, lessThan(20));
    expect(RecyclerWorkProbe.gridGeometryBuilds, geometryBuilds, reason: '拖拽只查行高索引，不能反复全表分组');
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('Grid 同跨度不同类型分别估高，首屏全为横幅时补测普通行后范围稳定', (tester) async {
    final adapter = _Cells([350, ...List.filled(10000, 80)]);
    final list = await _open(tester, adapter, rv.GridLayoutManager(null, 2)..setSpanSizeLookup(_HeaderSpans()));
    list.controller!.jumpTo(350);
    await tester.pumpAndSettle();
    expect(list.controller!.position.maxScrollExtent, 350 + 5000 * 80 - 260);
    expect(list.controller!.position.pixels, 350);
    await tester.pumpWidget(SizedBox());

    final typed = _Cells([120, 120, ...List.filled(10000, 80)], typeFor: (position) => position < 2 ? 1 : 0);
    final typedList = await _open(tester, typed, rv.GridLayoutManager(null, 2));
    expect(typedList.controller!.position.maxScrollExtent, 120 + 5000 * 80 - 260);
    typedList.controller!.jumpTo(200000);
    await tester.pumpAndSettle();
    expect(typedList.controller!.position.maxScrollExtent, 120 + 5000 * 80 - 260);
    expect(typedList.controller!.position.pixels, 200000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('Grid 插入、删除、更新行高后保留锚点与稳定身份', (tester) async {
    final adapter = _Cells(List.filled(100, 50));
    final manager = rv.GridLayoutManager(null, 2);
    final list = await _open(tester, adapter, manager);
    list.scrollToPosition(20);
    await tester.pumpAndSettle();
    final before = _rect(tester, 20).top;
    adapter.records.insertAll(0, [(id: 100, extent: 90), (id: 101, extent: 90)]);
    adapter.notifyItemRangeInserted(0, 2);
    await tester.pumpAndSettle();
    expect(_rect(tester, 20).top, closeTo(before, .01));
    adapter.records.removeRange(0, 2);
    adapter.notifyItemRangeRemoved(0, 2);
    await tester.pumpAndSettle();
    expect(_rect(tester, 20).top, closeTo(before, .01));
    adapter.records[20] = (id: 20, extent: 130);
    adapter.notifyItemChanged(20);
    await tester.pumpAndSettle();
    expect(_rect(tester, 21).height, 130);
    expect(_rect(tester, 22).top, closeTo(before + 130, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('瀑布流按最短列填充，长短项不会按整行对齐', (tester) async {
    final manager = rv.StaggeredGridLayoutManager(2, rv.RecyclerView.VERTICAL);
    await _open(tester, _Cells([100, 40, 50, 120, 60, 70]), manager);
    expect(_rect(tester, 0), Rect.fromLTWH(0, 0, 150, 100));
    expect(_rect(tester, 1), Rect.fromLTWH(150, 0, 150, 40));
    expect(_rect(tester, 2), Rect.fromLTWH(150, 40, 150, 50));
    expect(_rect(tester, 3), Rect.fromLTWH(150, 90, 150, 120));
    expect(_rect(tester, 4), Rect.fromLTWH(0, 100, 150, 60));
    expect(_rect(tester, 5), Rect.fromLTWH(0, 160, 150, 70));
    expect(manager.findFirstVisibleItemPositions(), [0, 1]);
    expect(manager.findLastVisibleItemPositions(), [5, 3]);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('瀑布流极高首项与短列并存时填满窗口，按列找可见项', (tester) async {
    final manager = rv.StaggeredGridLayoutManager(2, rv.RecyclerView.VERTICAL);
    final adapter = _Cells([1000, ...List.filled(1000, 25)]);
    final list = await _open(tester, adapter, manager);
    expect(_rect(tester, 11).top, 250);
    list.controller!.jumpTo(500);
    await tester.pumpAndSettle();
    expect(manager.findFirstVisibleItemPositions(), [0, 21]);
    expect(_rect(tester, 0).top, -500);
    expect(manager.getChildCount(), lessThan(20));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('瀑布流滑块往返跳过未测量条目时，布局保留拖拽给出的像素位置', (tester) async {
    final manager = rv.StaggeredGridLayoutManager(2, rv.RecyclerView.VERTICAL);
    final adapter = _Cells(List.generate(10000, (index) => index.isEven ? 100.0 : 50.0));
    final list = await _open(tester, adapter, manager, scrollbar: true);
    final position = list.controller!.position;
    final gesture = await tester.startGesture(Offset(295, 21));
    await tester.pump(Duration(milliseconds: 150));
    for (final y in [180.0, 80.0, 150.0, 50.0]) {
      final before = position.pixels;
      await gesture.moveTo(Offset(295, y));
      final requested = position.pixels;
      expect((requested - before).abs(), greaterThan(position.viewportDimension));
      await tester.pump(Duration(milliseconds: 16));
      expect(position.pixels, closeTo(requested, .01));
      expect(manager.findFirstVisibleItemPositions(), everyElement(greaterThanOrEqualTo(0)));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('精确瀑布流远跳和重叠回拖保留两列坐标，尺寸变化时只重建一次几何', (tester) async {
    final extents = List<double>.generate(10000, (index) => 45.0 + index % 9 * 18);
    final widths = <double>{};
    var calculations = 0;
    final manager = rv.StaggeredGridLayoutManager(2, rv.RecyclerView.VERTICAL)
      ..setItemExtentBuilder((index, width) {
        calculations++;
        widths.add(width);
        return extents[index] + width / 5;
      });
    final adapter = _Cells(List.filled(extents.length, 14));
    final list = await _open(tester, adapter, manager, padding: EdgeInsets.fromLTRB(12, 6, 8, 4));
    final position = list.controller!.position;

    List<Rect> reference(double width) {
      final lines = [6.0, 6.0];
      final rects = <Rect>[];
      for (final extent in extents) {
        final lane = lines[1] < lines[0] ? 1 : 0;
        final height = extent + width / 5;
        rects.add(Rect.fromLTWH(12 + lane * width, lines[lane], width, height));
        lines[lane] += height;
      }
      return rects;
    }

    void expectGeometry(List<Rect> rects) {
      final pixels = position.pixels;
      final expectedMax = rects.fold(0.0, (max, rect) => rect.bottom > max ? rect.bottom : max) + 4 - 260;
      expect(position.maxScrollExtent, closeTo(expectedMax, .01));
      final firstInEachLane = manager.findFirstVisibleItemPositions();
      expect(firstInEachLane, everyElement(greaterThanOrEqualTo(0)));
      for (final index in firstInEachLane) {
        final expected = rects[index].shift(Offset(0, -pixels));
        final actual = _rect(tester, index);
        expect(actual.left, closeTo(expected.left, .01));
        expect(actual.top, closeTo(expected.top, .01));
        expect(actual.height, closeTo(expected.height, .01));
      }
    }

    expect(calculations, extents.length);
    expect(widths, {140.0});
    final initial = reference(140);
    final far = position.maxScrollExtent * .82;
    final back = position.maxScrollExtent * .25;
    for (final target in [far, far - 83, back, back + 105, back - 17, 0.0]) {
      position.jumpTo(target);
      await tester.pump();
      expect(position.pixels, closeTo(target, .01));
      expectGeometry(initial);
    }
    expect(calculations, extents.length);
    expect(adapter.holders.length, lessThan(20));

    extents[0] += 90;
    adapter.notifyItemChanged(0);
    await tester.pump();
    expect(calculations, 2 * extents.length);
    expectGeometry(reference(140));

    tester.view.physicalSize = Size(340, 260);
    await tester.pumpAndSettle();
    expect(calculations, 3 * extents.length);
    expect(widths, {140.0, 160.0});
    expectGeometry(reference(160));

    manager.setItemExtentBuilder(null);
    await tester.pumpAndSettle();
    expect(_rect(tester, 0).height, 14);
    expect(calculations, 3 * extents.length);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('瀑布流补测前面的条目时保留已呈现条目的列', (tester) async {
    final manager = rv.StaggeredGridLayoutManager(2, rv.RecyclerView.VERTICAL);
    final adapter = _Cells(List.generate(1000, (index) => 50.0 + index % 5 * 20));
    final list = await _open(tester, adapter, manager);
    list.scrollToPosition(100);
    await tester.pumpAndSettle();
    for (final delta in [40, 70]) {
      list.controller!.jumpTo(list.controller!.offset - delta);
      await tester.pumpAndSettle();
    }
    expect(manager.findViewByPosition(96), isNotNull);
    final column = _rect(tester, 96).left;
    list.controller!.jumpTo(list.controller!.offset - 120);
    await tester.pumpAndSettle();
    expect(manager.findViewByPosition(96), isNotNull);
    expect(_rect(tester, 96).left, column);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('瀑布流远跳、反向、改列数和全量清空均保持有效布局', (tester) async {
    final adapter = _Cells(List.generate(10000, (index) => 50.0 + index % 5 * 20));
    final manager = rv.StaggeredGridLayoutManager(3, rv.RecyclerView.VERTICAL);
    final list = await _open(tester, adapter, manager);
    list.scrollToPosition(8000);
    await tester.pumpAndSettle();
    expect(find.text('Item 8000'), findsOneWidget);
    expect(adapter.holders.length, lessThan(50));
    list.scrollToPosition(0);
    await tester.pumpAndSettle();
    expect(find.text('Item 0'), findsOneWidget);
    manager.setSpanCount(2);
    manager.setReverseLayout(true);
    await tester.pumpAndSettle();
    expect(_rect(tester, 0).width, 150);
    adapter.records.clear();
    adapter.notifyDataSetChanged();
    await tester.pumpAndSettle();
    expect(manager.getChildCount(), 0);
    expect(list.controller!.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
