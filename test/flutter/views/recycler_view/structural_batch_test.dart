import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('结构通知合并扫描且类型允许依赖位置和总数量', (tester) async {
    final adapter = _Rows();
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = rv.RecyclerView()
      ..setLayoutManager(layout)
      ..setItemViewCacheSize(0)
      ..setAdapter(adapter);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Align(child: SizedBox(width: 320, height: 300, child: list)),
      ),
    );
    adapter.queries = 0;
    for (var operation = 0; operation < 10; operation++) {
      adapter.ids.insert(0, -operation - 1);
      adapter.notifyItemInserted(0);
      final moved = adapter.ids.removeAt(20);
      adapter.ids.insert(30, moved);
      adapter.notifyItemMoved(20, 30);
      adapter.ids.removeLast();
      adapter.notifyItemRemoved(adapter.ids.length);
    }
    await tester.pump();
    print(
      'STRUCTURAL_PERF ${jsonEncode({'items': adapter.ids.length, 'notifications': 30, 'type_queries': adapter.queries})}',
    );
    expect(adapter.queries, adapter.ids.length);
    for (
      var position = layout.findFirstVisibleItemPosition();
      position <= layout.findLastVisibleItemPosition();
      position++
    ) {
      final holder = list.findViewHolderForAdapterPosition(position)!;
      expect(holder.getItemId(), adapter.ids[position]);
      expect(holder.getItemViewType(), adapter.type(position));
      expect(find.text('${adapter.ids[position]} / ${adapter.type(position)}').hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('结构通知后立即读取远跳几何使用最新类型且局部通知仍只扫描目标区间', (tester) async {
    final adapter = _Rows();
    final list = rv.RecyclerView()
      ..setLayoutManager(rv.LinearLayoutManager()..setItemPrefetchEnabled(false))
      ..setAdapter(adapter);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: SizedBox(width: 320, height: 300, child: list),
      ),
    );
    adapter.ids.insert(0, -1);
    adapter.notifyItemInserted(0);
    adapter.notifyItemRangeChanged(9000, 3);
    list.scrollToPosition(9000);
    await tester.pump();
    final holder = list.findViewHolderForAdapterPosition(9000)!;
    expect(holder.getItemId(), adapter.ids[9000]);
    expect(holder.getItemViewType(), adapter.type(9000));
    adapter.queries = 0;
    adapter.notifyItemRangeChanged(8000, 3);
    expect(adapter.queries, 3);
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });
}

class _Rows extends rv.Adapter<_Holder> {
  _Rows() {
    setHasStableIds(true);
  }

  final ids = List.generate(10000, (index) => index);
  int queries = 0;
  int type(int position) => (position + ids.length) % 3;

  @override
  int getItemCount() => ids.length;
  @override
  int getItemId(int position) => ids[position];
  @override
  int getItemViewType(int position) {
    queries++;
    return type(position);
  }

  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _Holder();
  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) {
    holder.text.value = '${ids[position]} / ${type(position)}';
  }
}

class _Holder extends rv.ViewHolder {
  _Holder() : this._(ValueNotifier(''));
  _Holder._(this.text)
    : super(
        ValueListenableBuilder(
          valueListenable: text,
          builder: (context, value, _) => SizedBox(height: 50, child: Text(value)),
        ),
      );

  final ValueNotifier<String> text;
}
