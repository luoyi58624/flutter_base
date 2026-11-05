import 'package:flutter/material.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_base/src/flutter/views/recycler_view/test_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(RecyclerTestClock.reset);

  testWidgets('预算足够时准备屏外条目，进入可见区复用绑定结果', (tester) async {
    final clock = _BudgetClock(remaining: 3000)..install();
    final rows = _BudgetRows(clock, createUs: 200, bindUs: 300);
    final layout = rv.LinearLayoutManager()..setInitialPrefetchItemCount(2);
    final list = _list(rows, layout);
    await _pump(tester, list);
    final next = layout.findLastVisibleItemPosition() + 1;
    final prepared = rows.boundTo(next);
    expect(prepared, isNotNull);
    expect(rows.boundTo(next + 1), isNotNull);
    expect(list.findViewHolderForAdapterPosition(next), isNull);
    expect(rows.attached.contains(next), isFalse);
    final boundBefore = rows.bindings.where((position) => position == next).length;

    // 限制为零阻止这一帧再准备其他条目，检查的只是已完成结果的复用。
    clock.remaining = 0;
    list.scrollBy(0, 50);
    await tester.pump();
    expect(list.findViewHolderForAdapterPosition(next), same(prepared));
    expect(rows.bindings.where((position) => position == next).length, boundBefore);
    expect(rows.attached.contains(next), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('预算耗尽或为负时跳过准备，后续有预算的布局补齐', (tester) async {
    final clock = _BudgetClock(remaining: 0)..install();
    final rows = _BudgetRows(clock, createUs: 200, bindUs: 300);
    final layout = rv.LinearLayoutManager()..setInitialPrefetchItemCount(2);
    final list = _list(rows, layout);
    await _pump(tester, list);
    final next = layout.findLastVisibleItemPosition() + 1;
    final createdBefore = rows.holders.length;
    expect(rows.boundTo(next), isNull);

    clock.remaining = -100;
    list.scrollBy(0, .01);
    await tester.pump();
    expect(rows.holders.length, createdBefore);
    expect(rows.boundTo(next), isNull);

    clock.remaining = 3000;
    list.scrollBy(0, .01);
    await tester.pump();
    expect(rows.boundTo(next), isNotNull);
    expect(rows.boundTo(next + 1), isNotNull);
    expect(list.findViewHolderForAdapterPosition(next), isNull);
    expect(tester.takeException(), isNull);
  });

  for (final cost in [
    (name: '创建', create: 4000, bind: 100, mount: 0, insufficient: 3000, enough: 4500),
    (name: '绑定', create: 100, bind: 4000, mount: 0, insufficient: 3000, enough: 4500),
    (name: '创建与绑定合计', create: 1400, bind: 1400, mount: 0, insufficient: 2000, enough: 3000),
    (name: '真实子树挂载', create: 0, bind: 100, mount: 4000, insufficient: 3000, enough: 4500),
  ]) {
    testWidgets('学习${cost.name}耗时后不在不足预算里重复尝试', (tester) async {
      final clock = _BudgetClock(remaining: 0)..install();
      final rows = _BudgetRows(clock, createUs: cost.create, bindUs: cost.bind, mountUs: cost.mount);
      final layout = rv.LinearLayoutManager()..setInitialPrefetchItemCount(2);
      final list = _list(rows, layout);
      await _pump(tester, list);
      final next = layout.findLastVisibleItemPosition() + 1;
      final createdBefore = rows.holders.length;
      final bindingsBefore = rows.bindings.length;

      clock.remaining = cost.insufficient;
      list.scrollBy(0, .01);
      await tester.pump();
      expect(rows.holders.length, createdBefore, reason: '应依据屏内已学习的准备成本避免开始必定超预算的工作');
      expect(rows.bindings.length, bindingsBefore);
      expect(rows.boundTo(next), isNull);

      clock.remaining = cost.enough;
      list.scrollBy(0, .01);
      await tester.pump();
      expect(rows.boundTo(next), isNotNull);
      expect(rows.boundTo(next + 1), isNull, reason: '第一项耗掉预算后，本帧不得再开始下一次重准备');
      expect(rows.holders.length, createdBefore + 1);
      expect(rows.bindings.length, bindingsBefore + 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('预取关闭或缓存为零时预算足够也不准备隐藏绑定', (tester) async {
    final clock = _BudgetClock(remaining: 100000)..install();
    final rows = _BudgetRows(clock);
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = _list(rows, layout);
    await _pump(tester, list);
    final next = layout.findLastVisibleItemPosition() + 1;
    expect(rows.boundTo(next), isNull);
    list.setItemViewCacheSize(0);
    layout.setItemPrefetchEnabled(true);
    await tester.pump();
    expect(rows.boundTo(next), isNull);
    expect(rows.holders.length, layout.getChildCount());
  });
}

class _BudgetClock {
  _BudgetClock({required this.remaining});
  int now = 0;
  int remaining;

  void install() {
    RecyclerTestClock.nowMicroseconds = () => now;
    RecyclerTestClock.remainingBudgetMicroseconds = (_) => remaining;
  }
}

class _BudgetHolder extends rv.ViewHolder {
  _BudgetHolder(this.value, Widget view) : super(view);
  final ValueNotifier<int> value;
}

class _BudgetRows extends rv.Adapter<_BudgetHolder> {
  _BudgetRows(this.clock, {this.createUs = 0, this.bindUs = 0, this.mountUs = 0});
  final _BudgetClock clock;
  final int createUs;
  final int bindUs;
  final int mountUs;
  final holders = <_BudgetHolder>[];
  final bindings = <int>[];
  final attached = <int>[];

  _BudgetHolder? boundTo(int position) {
    for (final holder in holders) {
      if (holder.getBindingAdapterPosition() == position) return holder;
    }
    return null;
  }

  @override
  int getItemCount() => 100;

  @override
  _BudgetHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    clock.now += createUs;
    final value = ValueNotifier(-1);
    final holder = _BudgetHolder(
      value,
      Builder(
        builder: (context) {
          // 用真实挂载时发生的工作，验证预算不是只统计创建回调自身。
          clock.now += mountUs;
          return SizedBox(
            height: 50,
            child: ValueListenableBuilder(
              valueListenable: value,
              builder: (context, position, _) => Text('条目 $position'),
            ),
          );
        },
      ),
    );
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_BudgetHolder holder, int position, [List<Object> payloads = const []]) {
    clock.now += bindUs;
    bindings.add(position);
    holder.value.value = position;
  }

  @override
  void onViewAttachedToWindow(_BudgetHolder holder) => attached.add(holder.getBindingAdapterPosition());
}

rv.RecyclerView _list(_BudgetRows rows, rv.LinearLayoutManager layout) => rv.RecyclerView()
  ..setLayoutManager(layout)
  ..setAdapter(rows)
  ..setItemViewCacheSize(1);

Future<void> _pump(WidgetTester tester, rv.RecyclerView list) => tester.pumpWidget(
  MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 320, height: 190, child: list),
    ),
  ),
);
