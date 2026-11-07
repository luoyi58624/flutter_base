import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final poolLimit in [5, 0, 64]) {
    testWidgets('大步往返滚动保留整屏结构且不受长期池容量 $poolLimit 限制', (tester) async {
      final rows = _Rows(types: 3);
      final controller = ScrollController();
      final list = _list(rows, controller: controller)..setItemViewCacheSize(0);
      for (var type = 0; type < 3; type++) {
        list.getRecycledViewPool().setMaxRecycledViews(type, poolLimit);
      }
      await _pump(tester, list);
      controller.jumpTo(16000);
      await tester.pump();
      final created = rows.holders.length;
      final initialized = rows.initialized;
      final disposed = rows.disposed;
      final visibilityChanges = rows.visibilityChanges;

      for (final delta in [240.0, 960.0, 960.0, -960.0, -960.0, -240.0]) {
        controller.jumpTo(controller.offset + delta);
        await tester.pump(Duration(milliseconds: 16));
        final first = (controller.offset / 16).round();
        expect(find.text('Item - $first').hitTestable(), findsOneWidget);
        expect(find.text('Item - ${first + 29}').hitTestable(), findsOneWidget);
        expect(list.getLayoutManager()!.getChildCount(), 30);
        expect(rows.wrongTypes, isEmpty);
      }

      expect(rows.holders.length, created, reason: '本轮退出的同类型条目应直接供本轮进入行复用');
      expect(rows.initialized, initialized, reason: '跨记录换绑应保留已挂载的 State');
      expect(rows.disposed, disposed, reason: '不能先因池满卸载，再为新进入行重新挂载');
      expect(rows.visibilityChanges, visibilityChanges, reason: '同帧直接复用不应先隐藏再显示');
      expect(rows.holders.length, 30);
      for (var type = 0; type < 3; type++) {
        expect(list.getRecycledViewPool().getRecycledViewCount(type), lessThanOrEqualTo(poolLimit));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
      expect(rows.disposed, rows.initialized);
      controller.dispose();
    });
  }

  testWidgets('剩余离屏条目遵守池容量且停止 ticker 和焦点参与', (tester) async {
    final rows = _Rows(blockTypes: true, ticking: true);
    final controller = ScrollController();
    final list = _list(rows, controller: controller)..setItemViewCacheSize(0);
    await _pump(tester, list);
    final old = rows.holders.toList();
    list.scrollToPosition(6000);
    await tester.pump(Duration(milliseconds: 16));
    await tester.pump();
    expect(find.text('Item - 6000').hitTestable(), findsOneWidget);
    expect(list.getRecycledViewPool().getRecycledViewCount(0), 5);
    expect(rows.disposed, 25);
    final surviving = old.where((holder) => !holder.disposed).toList();
    expect(surviving, hasLength(5));
    final ticks = {for (final holder in surviving) holder: holder.ticks};
    for (final holder in surviving) {
      expect(holder.focus.canRequestFocus, isFalse);
      expect(holder.visible, isFalse);
    }
    await tester.pump(Duration(milliseconds: 50));
    for (final holder in surviving) {
      expect(holder.ticks, ticks[holder], reason: '真正留在池中的行必须停表');
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    expect(rows.disposed, rows.initialized);
    controller.dispose();
  });

  testWidgets('带焦点的行离屏复用后不会把键盘焦点交给另一条记录', (tester) async {
    final rows = _Rows();
    final controller = ScrollController();
    final list = _list(rows, controller: controller)..setItemViewCacheSize(0);
    await _pump(tester, list);
    final focused = list.findViewHolderForAdapterPosition(3)! as _Holder;
    focused.focus.requestFocus();
    await tester.pump();
    expect(focused.focus.hasPrimaryFocus, isTrue);
    controller.jumpTo(960);
    await tester.pump();
    await tester.pump();
    expect(focused.disposed, isFalse);
    expect(focused.focus.hasFocus, isFalse);
    expect(focused.getBindingAdapterPosition(), inInclusiveRange(60, 89));
    expect(find.text('Item - 60').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    controller.dispose();
  });
}

rv.RecyclerView _list(_Rows rows, {required ScrollController controller}) => rv.RecyclerView(controller: controller)
  ..setLayoutManager(rv.LinearLayoutManager()..setItemPrefetchEnabled(false))
  ..setAdapter(rows);

Future<void> _pump(WidgetTester tester, rv.RecyclerView list) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: .topLeft,
          child: SizedBox(width: 400, height: 480, child: list),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _Rows extends rv.Adapter<_Holder> {
  _Rows({this.types = 1, this.blockTypes = false, this.ticking = false});
  final int types;
  final bool blockTypes;
  final bool ticking;
  final holders = <_Holder>[];
  final wrongTypes = <int>[];
  int initialized = 0;
  int disposed = 0;
  int visibilityChanges = 0;

  @override
  int getItemCount() => 10000;

  @override
  int getItemViewType(int position) => blockTypes ? position ~/ 5000 : position % types;

  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final holder = _Holder(this);
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) {
    if (holder.getItemViewType() != getItemViewType(position)) wrongTypes.add(position);
    holder.position.value = position;
  }
}

class _Holder extends rv.ViewHolder {
  _Holder(_Rows rows) : this._(_RowData(rows));
  _Holder._(this.data) : super(_Row(data));
  final _RowData data;
  ValueNotifier<int> get position => data.position;
  FocusNode get focus => data.focus;
  bool get disposed => data.disposed;
  bool get visible => data.visible;
  int get ticks => data.ticks;
}

class _RowData {
  _RowData(this.rows);
  final _Rows rows;
  final position = ValueNotifier(-1);
  final focus = FocusNode();
  bool visible = true;
  bool disposed = false;
  int ticks = 0;
}

class _Row extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Row(this.data);
  final _RowData data;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> with SingleTickerProviderStateMixin {
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    widget.data.rows.initialized++;
    if (widget.data.rows.ticking) _ticker = createTicker((_) => widget.data.ticks++)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (widget.data.visible != visible) widget.data.rows.visibilityChanges++;
    widget.data.visible = visible;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    widget.data.focus.dispose();
    widget.data.position.dispose();
    widget.data.disposed = true;
    widget.data.rows.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: widget.data.focus,
    child: ValueListenableBuilder<int>(
      valueListenable: widget.data.position,
      builder: (context, position, child) => SizedBox(height: 16, child: Text('Item - $position')),
    ),
  );
}
