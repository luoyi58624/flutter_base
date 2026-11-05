import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('一万条变高记录从末项实测向前填满，首屏没有猜测窗口的多余挂载', (tester) async {
    final rows = _Rows(10000);
    final layout = _layout();
    final list = _list(rows, layout)..setPadding(8, 12, 10, 20);
    await _open(tester, list);

    final expected = _expectedTail(rows, 360 - 12 - 20);
    expect(layout.findFirstVisibleItemPosition(), expected.last);
    expect(layout.findLastVisibleItemPosition(), 9999);
    expect(rows.boundPositions, expected, reason: '首入只应从最后一项向前绑定实际需要的尾缀');
    expect(rows.created, expected.length);
    expect(rows.builds, {for (final position in expected) position: 1});
    expect(rows.layouts, {for (final position in expected) position: 1});
    _expectLastAtEdge(tester, list, reverse: false, horizontal: false, padding: EdgeInsets.fromLTRB(8, 12, 10, 20));
    debugPrint(
      'RECYCLER_TAIL_ENTRY ${jsonEncode({'items': rows.getItemCount(), 'bound_positions': rows.boundPositions, 'created_holders': rows.created, 'row_builds': rows.builds.length, 'body_layouts': rows.layouts.length, 'type_queries': rows.typeQueries})}',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('末项高于视口时首入只创建末项，不提前挂载其上方记录', (tester) async {
    final rows = _Rows(10000, lastExtent: 700);
    final layout = _layout();
    final list = _list(rows, layout)..setPadding(8, 12, 10, 20);
    await _open(tester, list);

    expect(rows.boundPositions, [9999]);
    expect(rows.created, 1);
    expect(rows.layouts, {9999: 1});
    expect(layout.findFirstVisibleItemPosition(), 9999);
    _expectLastAtEdge(tester, list, reverse: false, horizontal: false, padding: EdgeInsets.fromLTRB(8, 12, 10, 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('末尾实测填充兼容纵横方向、反向、RTL 与不对称内边距', (tester) async {
    for (final horizontal in [false, true]) {
      for (final reverse in [false, true]) {
        for (final rtl in horizontal ? [false, true] : [false]) {
          final rows = _Rows(10000, horizontal: horizontal);
          final layout = _layout(horizontal: horizontal, reverse: reverse);
          final list = _list(rows, layout)..setPadding(8, 12, 10, 20);
          await _open(tester, list, rtl: rtl);
          final available = horizontal ? 320 - 8 - 10 : 360 - 12 - 20;
          expect(rows.boundPositions, _expectedTail(rows, available.toDouble()));
          _expectLastAtEdge(
            tester,
            list,
            reverse: reverse,
            horizontal: horizontal,
            rtl: rtl,
            padding: EdgeInsets.fromLTRB(8, 12, 10, 20),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(SizedBox());
        }
      }
    }
  });

  testWidgets('短内容全部实测后仍贴住物理末端，内边距不参与内容尺寸', (tester) async {
    for (final horizontal in [false, true]) {
      for (final reverse in [false, true]) {
        final rows = _Rows(2, horizontal: horizontal);
        final layout = _layout(horizontal: horizontal, reverse: reverse);
        final list = _list(rows, layout)..setPadding(8, 12, 10, 20);
        await _open(tester, list);
        expect(rows.boundPositions, [1, 0]);
        expect(layout.getChildCount(), 2);
        _expectLastAtEdge(
          tester,
          list,
          reverse: reverse,
          horizontal: horizontal,
          padding: EdgeInsets.fromLTRB(8, 12, 10, 20),
        );
        final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
        expect(position.pixels, 0);
        expect(position.maxScrollExtent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(SizedBox());
      }
    }
  });

  testWidgets('显式初始定位优先于 stackFromEnd，不强制创建末尾条目', (tester) async {
    final rows = _Rows(10000);
    final layout = _layout();
    final list = _list(rows, layout)..scrollToPosition(4000);
    await _open(tester, list);
    expect(list.findViewHolderForAdapterPosition(4000), isNotNull);
    expect(rows.boundPositions, isNot(contains(9999)));
    expect(layout.findLastVisibleItemPosition(), lessThan(4020));
    expect(tester.takeException(), isNull);
  });
}

rv.LinearLayoutManager _layout({bool horizontal = false, bool reverse = false}) =>
    rv.LinearLayoutManager(null, horizontal ? rv.RecyclerView.HORIZONTAL : rv.RecyclerView.VERTICAL, reverse)
      ..setStackFromEnd(true)
      ..setItemPrefetchEnabled(false);

rv.RecyclerView _list(_Rows rows, rv.LinearLayoutManager layout) => rv.RecyclerView()
  ..setLayoutManager(layout)
  ..setItemViewCacheSize(0)
  ..setAdapter(rows);

Future<void> _open(WidgetTester tester, rv.RecyclerView list, {bool rtl = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: rtl ? .rtl : .ltr,
          child: Align(
            alignment: .topLeft,
            child: SizedBox(width: 320, height: 360, child: list),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<int> _expectedTail(_Rows rows, double available) {
  final result = <int>[];
  var filled = 0.0;
  for (var position = rows.getItemCount() - 1; position >= 0; position--) {
    result.add(position);
    filled += rows.extentAt(position);
    if (filled >= available) break;
  }
  return result;
}

void _expectLastAtEdge(
  WidgetTester tester,
  rv.RecyclerView list, {
  required bool reverse,
  required bool horizontal,
  bool rtl = false,
  required EdgeInsets padding,
}) {
  final last = list.findViewHolderForAdapterPosition(list.getAdapter()!.getItemCount() - 1)!;
  final viewport = tester.getRect(find.byWidget(list));
  final rect = tester.getRect(find.byWidget(last.itemView));
  final reversed = horizontal ? reverse != rtl : reverse;
  if (horizontal) {
    expect(
      reversed ? rect.left : rect.right,
      closeTo(reversed ? viewport.left + padding.left : viewport.right - padding.right, .01),
    );
  } else {
    expect(
      reversed ? rect.top : rect.bottom,
      closeTo(reversed ? viewport.top + padding.top : viewport.bottom - padding.bottom, .01),
    );
  }
}

class _Rows extends rv.Adapter<_Holder> {
  _Rows(this.count, {this.horizontal = false, this.lastExtent}) {
    setHasStableIds(true);
  }

  final int count;
  final bool horizontal;
  final double? lastExtent;
  final boundPositions = <int>[];
  final builds = <int, int>{};
  final layouts = <int, int>{};
  int created = 0;
  int typeQueries = 0;

  double extentAt(int position) {
    if (position == count - 1 && lastExtent != null) return lastExtent!;
    return [48.0, 168.0, 78.0, 126.0, 54.0][position % 5];
  }

  @override
  int getItemCount() => count;
  @override
  int getItemId(int position) => position;
  @override
  int getItemViewType(int position) {
    typeQueries++;
    return position % 2;
  }

  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    created++;
    return _Holder(this);
  }

  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) {
    boundPositions.add(position);
    holder.model.value = (position: position, extent: extentAt(position));
  }
}

class _Holder extends rv.ViewHolder {
  _Holder(_Rows rows) : this._(rows, ValueNotifier((position: -1, extent: 0.0)));
  _Holder._(_Rows rows, this.model)
    : super(
        ValueListenableBuilder<({int position, double extent})>(
          valueListenable: model,
          builder: (context, value, child) {
            rows.builds.update(value.position, (count) => count + 1, ifAbsent: () => 1);
            return _LayoutProbe(rows, value.position, value.extent);
          },
        ),
      );

  final ValueNotifier<({int position, double extent})> model;
}

class _LayoutProbe extends LeafRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _LayoutProbe(this.rows, this.position, this.extent);
  final _Rows rows;
  final int position;
  final double extent;

  @override
  RenderObject createRenderObject(BuildContext context) => _ProbeRenderBox(rows, position, extent);
  @override
  void updateRenderObject(BuildContext context, _ProbeRenderBox renderObject) {
    renderObject
      ..position = position
      ..extent = extent
      ..markNeedsLayout();
  }
}

class _ProbeRenderBox extends RenderBox {
  _ProbeRenderBox(this.rows, this.position, this.extent);
  final _Rows rows;
  int position;
  double extent;

  @override
  void performLayout() {
    rows.layouts.update(position, (count) => count + 1, ifAbsent: () => 1);
    size = constraints.constrain(
      rows.horizontal ? Size(extent, constraints.maxHeight) : Size(constraints.maxWidth, extent),
    );
  }
}
