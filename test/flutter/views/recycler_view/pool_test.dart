import 'package:flutter/widgets.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('回收池按类型隔离并后进先出，每类默认最多保留五个', () {
    final pool = rv.RecycledViewPool();
    final adapter = _PoolAdapter();
    final parent = rv.RecyclerView();
    final first = adapter.createViewHolder(parent, 7);
    final second = adapter.createViewHolder(parent, 7);
    final other = adapter.createViewHolder(parent, 9);

    pool.putRecycledView(first);
    pool.putRecycledView(second);
    pool.putRecycledView(other);

    expect(pool.getRecycledViewCount(7), 2);
    expect(pool.getRecycledView(7), same(second));
    expect(pool.getRecycledView(9), same(other));
    expect(pool.getRecycledView(7), same(first));
    expect(pool.getRecycledView(7), isNull);

    for (var i = 0; i < 8; i++) {
      pool.putRecycledView(adapter.createViewHolder(parent, 7));
    }
    expect(pool.getRecycledViewCount(7), 5);
    expect(pool.getRecycledViewCount(9), 0);
  });

  test('调整池上限会收缩已有内容，clear 保留每种类型的上限', () {
    final pool = rv.RecycledViewPool();
    final adapter = _PoolAdapter();
    final parent = rv.RecyclerView();
    for (var i = 0; i < 5; i++) {
      pool.putRecycledView(adapter.createViewHolder(parent, 0));
    }
    pool.setMaxRecycledViews(0, 2);
    expect(pool.getRecycledViewCount(0), 2);

    pool.clear();
    expect(pool.getRecycledViewCount(0), 0);
    for (var i = 0; i < 4; i++) {
      pool.putRecycledView(adapter.createViewHolder(parent, 0));
    }
    expect(pool.getRecycledViewCount(0), 2);

    pool.setMaxRecycledViews(0, 0);
    expect(pool.getRecycledViewCount(0), 0);
    pool.putRecycledView(adapter.createViewHolder(parent, 0));
    expect(pool.getRecycledViewCount(0), 0);
  });

  test('不可回收状态按引用计数配对恢复', () {
    final holder = _PoolHolder(SizedBox());
    expect(holder.isRecyclable(), isTrue);
    holder.setIsRecyclable(false);
    holder.setIsRecyclable(false);
    expect(holder.isRecyclable(), isFalse);
    holder.setIsRecyclable(true);
    expect(holder.isRecyclable(), isFalse);
    holder.setIsRecyclable(true);
    expect(holder.isRecyclable(), isTrue);
  });

  test('Adapter 创建与绑定维护官方 holder 身份', () {
    final adapter = _PoolAdapter()..setHasStableIds(true);
    final holder = adapter.createViewHolder(rv.RecyclerView(), 4);
    expect(holder.getItemViewType(), 4);
    expect(holder.getBindingAdapterPosition(), rv.RecyclerView.NO_POSITION);

    adapter.bindViewHolder(holder, 3);
    expect(holder.getItemId(), 103);
    expect(holder.getBindingAdapterPosition(), 3);
    expect(holder.getAbsoluteAdapterPosition(), 3);
    expect(adapter.bindings, [3]);
  });

  test('单项与范围通知使用官方观察者回调，注销后不再接收', () {
    final adapter = _PoolAdapter();
    final observer = _Observer();
    adapter.registerAdapterDataObserver(observer);
    expect(adapter.hasObservers(), isTrue);
    expect(() => adapter.setHasStableIds(true), throwsStateError);

    adapter.notifyItemChanged(2, 'title');
    adapter.notifyItemRangeChanged(3, 2);
    adapter.notifyItemInserted(1);
    adapter.notifyItemRangeInserted(2, 3);
    adapter.notifyItemRemoved(4);
    adapter.notifyItemRangeRemoved(5, 2);
    adapter.notifyItemMoved(7, 1);
    adapter.notifyDataSetChanged();
    expect(observer.events, [
      ['changed', 2, 1, 'title'],
      ['changed', 3, 2, null],
      ['inserted', 1, 1],
      ['inserted', 2, 3],
      ['removed', 4, 1],
      ['removed', 5, 2],
      ['moved', 7, 1, 1],
      ['all'],
    ]);

    adapter.unregisterAdapterDataObserver(observer);
    expect(adapter.hasObservers(), isFalse);
    adapter.notifyDataSetChanged();
    expect(observer.events, hasLength(8));
  });
}

class _PoolHolder extends rv.ViewHolder {
  _PoolHolder(super.itemView);
}

class _PoolAdapter extends rv.Adapter<_PoolHolder> {
  final bindings = <int>[];

  @override
  int getItemCount() => 10;

  @override
  int getItemId(int position) => position + 100;

  @override
  _PoolHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _PoolHolder(SizedBox());

  @override
  void onBindViewHolder(_PoolHolder holder, int position, [List<Object> payloads = const []]) {
    bindings.add(position);
  }
}

class _Observer extends rv.AdapterDataObserver {
  final events = <List<Object?>>[];

  @override
  void onChanged() => events.add(['all']);

  @override
  void onItemRangeChanged(int positionStart, int itemCount, [Object? payload]) =>
      events.add(['changed', positionStart, itemCount, payload]);

  @override
  void onItemRangeInserted(int positionStart, int itemCount) => events.add(['inserted', positionStart, itemCount]);

  @override
  void onItemRangeRemoved(int positionStart, int itemCount) => events.add(['removed', positionStart, itemCount]);

  @override
  void onItemRangeMoved(int fromPosition, int toPosition, int itemCount) =>
      events.add(['moved', fromPosition, toPosition, itemCount]);
}
