import 'package:flutter/material.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('初始仅创建视口附近内容，长列表不会全量挂载', (tester) async {
    final adapter = _RowsAdapter(count: 1000);
    final list = _list(adapter);
    await _pump(tester, list);

    expect(list.findViewHolderForAdapterPosition(0), isNotNull);
    expect(list.findViewHolderForAdapterPosition(3), isNotNull);
    expect(list.findViewHolderForAdapterPosition(999), isNull);
    expect(adapter.holders.length, lessThan(20));
    expect(adapter.tracker.initializations.length, adapter.holders.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨条目复用保留已挂载 State，不会重新 initState', (tester) async {
    final adapter = _RowsAdapter(count: 1000);
    final list = _list(adapter)..setItemViewCacheSize(0);
    await _pump(tester, list);

    for (var i = 0; i < 15; i++) {
      list.scrollBy(0, 96);
      await tester.pump();
    }

    expect(adapter.positionsByHolder.values.any((positions) => positions.length > 2), isTrue);
    expect(adapter.holders.length, lessThan(25));
    for (final holder in adapter.holders) {
      expect(adapter.tracker.initializations[holder.serial], 1, reason: '复用 holder 必须保留整棵已挂载子树');
    }
    expect(adapter.tracker.disposals, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('每项独立重绘边界让稳定内容在滚动平移时复用已有绘制', (tester) async {
    final adapter = _RowsAdapter(count: 100, paintProbe: true);
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = _list(adapter, layout: layout)..setItemViewCacheSize(0);
    await _pump(tester, list);

    final boundaries = <Element>{};
    for (final holder in adapter.holders) {
      final item = find.byWidget(holder.itemView, skipOffstage: false);
      final boundary = find
          .ancestor(of: item, matching: find.byType(RepaintBoundary, skipOffstage: false))
          .evaluate()
          .first;
      expect(boundaries.add(boundary), isTrue, reason: '每个 holder 应有自己的最近重绘边界');
    }
    final stableHolders = {
      for (final position in [1, 2, 3]) position: list.findViewHolderForAdapterPosition(position)!,
    };
    final paintCounts = {for (final position in stableHolders.keys) position: adapter.tracker.paintCounts[position]!};
    final tops = {
      for (final entry in stableHolders.entries) entry.key: tester.getTopLeft(find.byWidget(entry.value.itemView)).dy,
    };
    expect(paintCounts.values.every((count) => count > 0), isTrue);
    expect(adapter.tracker.paintCounts[5] ?? 0, 0);

    for (var frame = 1; frame <= 3; frame++) {
      list.scrollBy(0, 24);
      await tester.pump();
      for (final entry in stableHolders.entries) {
        expect(list.findViewHolderForAdapterPosition(entry.key), same(entry.value));
        expect(tester.getTopLeft(find.byWidget(entry.value.itemView)).dy, closeTo(tops[entry.key]! - frame * 24, .01));
        expect(adapter.tracker.paintCounts[entry.key], paintCounts[entry.key], reason: '仅平移的稳定条目无需重新 paint');
      }
    }
    expect(adapter.tracker.paintCounts[5], greaterThan(0), reason: '新进入视口的条目仍必须实际绘制');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('不同 viewType 不会相互复用', (tester) async {
    final adapter = _RowsAdapter(count: 150, types: 3);
    final list = _list(adapter)..setItemViewCacheSize(0);
    await _pump(tester, list);
    for (var i = 0; i < 8; i++) {
      list.scrollBy(0, 144);
      await tester.pump();
    }

    expect(adapter.wrongTypeBindings, isEmpty);
    expect(adapter.positionsByHolder.values.any((positions) => positions.length > 1), isTrue);
    expect(adapter.holders.length, lessThan(35));
  });

  testWidgets('插入通知立即映射 adapter 位置，布局位置到下一次布局才更新', (tester) async {
    final adapter = _RowsAdapter(count: 30);
    final list = _list(adapter);
    await _pump(tester, list);
    final holder = list.findViewHolderForAdapterPosition(1)!;

    adapter.items.insert(0, _Item(5000));
    adapter.notifyItemInserted(0);
    expect(holder.getBindingAdapterPosition(), 2);
    expect(holder.getLayoutPosition(), 1);
    await tester.pump();

    expect(holder.getLayoutPosition(), 2);
    expect(holder.getBindingAdapterPosition(), 2);
    expect(list.findViewHolderForAdapterPosition(2), same(holder));
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除和移动通知不会把 holder 身份交给错误的数据', (tester) async {
    final adapter = _RowsAdapter(count: 30)..setHasStableIds(true);
    final list = _list(adapter);
    await _pump(tester, list);
    final moved = list.findViewHolderForAdapterPosition(1)!;
    final removed = list.findViewHolderForAdapterPosition(3)!;

    final item = adapter.items.removeAt(1);
    adapter.items.insert(2, item);
    adapter.notifyItemMoved(1, 2);
    expect(moved.getBindingAdapterPosition(), 2);
    await tester.pump();
    expect(list.findViewHolderForAdapterPosition(2), same(moved));
    expect(moved.getItemId(), item.id);

    adapter.items.removeAt(3);
    adapter.notifyItemRemoved(3);
    expect(removed.getBindingAdapterPosition(), rv.RecyclerView.NO_POSITION);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('局部 payload 合并后只重绑受影响条目', (tester) async {
    final adapter = _RowsAdapter(count: 30);
    final list = _list(adapter);
    await _pump(tester, list);
    adapter.bindings.clear();

    adapter.items[1] = _Item(1, title: '更新内容');
    adapter.notifyItemChanged(1, 'title');
    adapter.notifyItemChanged(1, 'color');
    await tester.pump();

    final changes = adapter.bindings.where((binding) => binding.position == 1).toList();
    expect(changes, hasLength(1));
    expect(changes.single.payloads, ['title', 'color']);
    expect(adapter.bindings.where((binding) => binding.position != 1), isEmpty);
    expect(find.text('更新内容').hitTestable(), findsOneWidget);
  });

  testWidgets('完整更新清除之前和之后累积的局部 payload', (tester) async {
    final adapter = _RowsAdapter(count: 30);
    final list = _list(adapter);
    await _pump(tester, list);
    adapter.bindings.clear();

    adapter.notifyItemChanged(1, 'before');
    adapter.notifyItemChanged(1);
    adapter.notifyItemChanged(1, 'after');
    await tester.pump();

    final changes = adapter.bindings.where((binding) => binding.position == 1).toList();
    expect(changes, hasLength(1));
    expect(changes.single.payloads, isEmpty);
  });

  testWidgets('notifyDataSetChanged 到下一次布局前位置无效，稳定 ID 在重排后重新关联', (tester) async {
    final adapter = _RowsAdapter(count: 20)..setHasStableIds(true);
    final list = _list(adapter);
    await _pump(tester, list);
    final holder = list.findViewHolderForAdapterPosition(1)!;
    final id = holder.getItemId();

    final first = adapter.items[1];
    adapter.items[1] = adapter.items[2];
    adapter.items[2] = first;
    adapter.notifyDataSetChanged();
    expect(holder.getBindingAdapterPosition(), rv.RecyclerView.NO_POSITION);
    await tester.pump();

    final rebound = list.findViewHolderForAdapterPosition(2)!;
    expect(rebound.getItemId(), id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远距离定位未知高度条目，无需创建前面的所有条目', (tester) async {
    final adapter = _RowsAdapter(count: 1000, varyingExtent: true);
    final layout = rv.LinearLayoutManager();
    final list = _list(adapter, layout: layout);
    await _pump(tester, list);

    list.scrollToPosition(500);
    await tester.pump();
    await tester.pump();

    expect(list.findViewHolderForAdapterPosition(500), isNotNull);
    expect(layout.findFirstVisibleItemPosition(), inInclusiveRange(495, 500));
    expect(adapter.holders.length, lessThan(50));
    expect(find.text('row 500').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未知高度短列表定位较短末项后保持可见且不越过滚动边界', (tester) async {
    final adapter = _RowsAdapter(count: 12, types: 12, varyingExtent: true);
    final layout = rv.LinearLayoutManager();
    final list = _list(adapter, layout: layout);
    await _pump(tester, list);

    list.scrollToPosition(11);
    await tester.pumpAndSettle();

    expect(list.findViewHolderForAdapterPosition(11), isNotNull);
    expect(layout.findLastVisibleItemPosition(), 11);
    expect(find.text('row 11').hitTestable(), findsOneWidget);
    final scrollable = find.descendant(of: find.byWidget(list), matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, inInclusiveRange(position.minScrollExtent, position.maxScrollExtent));
    expect(tester.takeException(), isNull);
  });

  testWidgets('未知高度列表在首个可见条目前插入数据时保持锚点', (tester) async {
    final adapter = _RowsAdapter(count: 100, varyingExtent: true)..setHasStableIds(true);
    final layout = rv.LinearLayoutManager();
    final list = _list(adapter, layout: layout);
    await _pump(tester, list);
    layout.scrollToPositionWithOffset(30, 0);
    await tester.pump();
    await tester.pump();
    final target = find.text('row 30').hitTestable();
    final before = tester.getTopLeft(target).dy;

    adapter.items.insert(0, _Item(5000, extent: 180));
    adapter.notifyItemInserted(0);
    await tester.pump();

    expect(tester.getTopLeft(target).dy, closeTo(before, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('横向和反向布局仍可按 adapter 位置定位', (tester) async {
    for (final orientation in [rv.RecyclerView.VERTICAL, rv.RecyclerView.HORIZONTAL]) {
      final adapter = _RowsAdapter(count: 80, horizontal: orientation == rv.RecyclerView.HORIZONTAL);
      final layout = rv.LinearLayoutManager(null, orientation, true);
      final list = _list(adapter, layout: layout);
      await _pump(tester, list);
      expect(list.findViewHolderForAdapterPosition(0), isNotNull);

      list.scrollToPosition(20);
      await tester.pump();
      await tester.pump();
      expect(list.findViewHolderForAdapterPosition(20), isNotNull);
      expect(find.text('row 20').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    }
  });

  testWidgets('替换 Adapter 后释放旧子树并显示新的数据', (tester) async {
    final first = _RowsAdapter(count: 30);
    final second = _RowsAdapter(count: 30, firstId: 1000);
    final list = _list(first);
    await _pump(tester, list);

    list.setAdapter(second);
    await tester.pump();
    await tester.pump();

    expect(find.text('row 1000').hitTestable(), findsOneWidget);
    expect(first.tracker.disposals.length, first.tracker.initializations.length);
    expect(first.detachedFromRecyclerView, 1);
    expect(second.attachedToRecyclerView, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('共享回收池跨宿主复用已挂载子树，不重新初始化 State', (tester) async {
    final pool = rv.RecycledViewPool();
    final adapter = _RowsAdapter(count: 100);
    final firstLayout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final secondLayout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final first = _list(adapter, layout: firstLayout)
      ..setItemViewCacheSize(0)
      ..setRecycledViewPool(pool);
    final second = _list(adapter, layout: secondLayout)
      ..setItemViewCacheSize(0)
      ..setRecycledViewPool(pool);

    Widget host({required double firstHeight, bool showSecond = false}) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(width: 320, height: firstHeight, child: first),
            if (showSecond) SizedBox(width: 320, height: 240, child: second),
          ],
        ),
      ),
    );

    await tester.pumpWidget(host(firstHeight: 240));
    await tester.pumpWidget(host(firstHeight: 48));
    expect(pool.getRecycledViewCount(0), greaterThan(0));
    final before = adapter.holders.length;

    await tester.pumpWidget(host(firstHeight: 48, showSecond: true));
    await tester.pump();

    expect(adapter.holders.length, lessThan(before + 5));
    expect(second.findViewHolderForAdapterPosition(0), isNotNull);
    for (final count in adapter.tracker.initializations.values) {
      expect(count, 1);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('池中条目不参与绘制命中和无障碍语义，清池会释放子树', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final pool = rv.RecycledViewPool();
      final adapter = _RowsAdapter(count: 100);
      final list = _list(adapter)
        ..setItemViewCacheSize(0)
        ..setRecycledViewPool(pool);
      await _pump(tester, list);
      final firstLabel = RegExp(r'^item 0(?:\n|$)');
      expect(find.bySemanticsLabel(firstLabel), findsOneWidget);

      list.scrollBy(0, 144);
      await tester.pump();
      expect(find.text('row 0').hitTestable(), findsNothing);
      expect(find.bySemanticsLabel(firstLabel), findsNothing);

      pool.clear();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
      expect(adapter.tracker.disposals.length, adapter.tracker.initializations.length);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('删除全部数据后旧条目退出可见布局和语义树', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final adapter = _RowsAdapter(count: 20);
      final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
      final list = _list(adapter, layout: layout);
      await _pump(tester, list);
      final oldHolder = list.findViewHolderForAdapterPosition(0)!;
      expect(find.text('row 0').hitTestable(), findsOneWidget);

      final oldCount = adapter.items.length;
      adapter.items.clear();
      adapter.notifyItemRangeRemoved(0, oldCount);
      await tester.pump();

      expect(list.findViewHolderForAdapterPosition(0), isNull);
      expect(list.findViewHolderForLayoutPosition(0), isNull);
      expect(oldHolder.getBindingAdapterPosition(), rv.RecyclerView.NO_POSITION);
      expect(layout.getChildCount(), 0);
      expect(find.text('row 0').hitTestable(), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^item \d+(?:\n|$)')), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('兼容替换为短列表后旧内容消失，离屏 ticker 停止且受保护条目最终释放', (tester) async {
    final first = _RowsAdapter(count: 30, ticking: true);
    final second = _RowsAdapter(count: 1, firstId: 1000, ticking: true);
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = _list(first, layout: layout)..setItemViewCacheSize(0);
    await _pump(tester, list);
    final protected = list.findViewHolderForAdapterPosition(3)!..setIsRecyclable(false);
    await tester.pump(Duration(milliseconds: 16));

    list.swapAdapter(second, false);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 16));
    expect(find.text('row 1000').hitTestable(), findsOneWidget);
    expect(find.text('row 3').hitTestable(), findsNothing);
    expect(layout.getChildCount(), 1);
    expect(list.findViewHolderForAdapterPosition(1), isNull);
    final active = list.findViewHolderForAdapterPosition(0);
    final ticksBefore = Map<int, int>.of(first.tracker.ticks);

    await tester.pump(Duration(milliseconds: 250));
    for (final oldHolder in first.holders) {
      if (!identical(oldHolder, active)) {
        expect(first.tracker.ticks[oldHolder.serial], ticksBefore[oldHolder.serial]);
      }
    }

    protected.setIsRecyclable(true);
    await tester.pumpWidget(SizedBox());
    expect(first.tracker.disposals.length, first.tracker.initializations.length);
    expect(second.tracker.disposals.length, second.tracker.initializations.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stackFromEnd 在初次布局显示长列表末尾', (tester) async {
    final adapter = _RowsAdapter(count: 1000);
    final layout = rv.LinearLayoutManager()
      ..setStackFromEnd(true)
      ..setItemPrefetchEnabled(false);
    final list = _list(adapter, layout: layout)..setPadding(8, 12, 10, 20);
    await _pump(tester, list);

    expect(layout.findLastVisibleItemPosition(), 999);
    final last = list.findViewHolderForAdapterPosition(999)!;
    final viewport = tester.getRect(find.byWidget(list));
    expect(tester.getRect(find.byWidget(last.itemView)).bottom, closeTo(viewport.bottom - 20, 0.01));
    expect(adapter.holders.length, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stackFromEnd 的短内容贴住内边距末端', (tester) async {
    final adapter = _RowsAdapter(count: 2);
    final layout = rv.LinearLayoutManager()
      ..setStackFromEnd(true)
      ..setItemPrefetchEnabled(false);
    final list = _list(adapter, layout: layout)..setPadding(8, 12, 10, 20);
    await _pump(tester, list);

    final first = list.findViewHolderForAdapterPosition(0)!;
    final last = list.findViewHolderForAdapterPosition(1)!;
    final viewport = tester.getRect(find.byWidget(list));
    final firstRect = tester.getRect(find.byWidget(first.itemView));
    final lastRect = tester.getRect(find.byWidget(last.itemView));
    expect(firstRect.top, closeTo(viewport.bottom - 20 - 96, 0.01));
    expect(lastRect.bottom, closeTo(viewport.bottom - 20, 0.01));
    expect(firstRect.top, greaterThan(viewport.top + 12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL 横向布局与 reverseLayout 组合遵循实际起始边缘', (tester) async {
    for (final reverse in [false, true]) {
      final adapter = _RowsAdapter(count: 40, horizontal: true);
      final layout = rv.LinearLayoutManager(null, rv.RecyclerView.HORIZONTAL, reverse)..setItemPrefetchEnabled(false);
      final list = _list(adapter, layout: layout)..setPadding(10, 0, 20, 0);
      await _pump(tester, list, textDirection: TextDirection.rtl);
      final viewport = tester.getRect(find.byWidget(list));
      final first = list.findViewHolderForAdapterPosition(0)!;
      final next = list.findViewHolderForAdapterPosition(1)!;
      final firstRect = tester.getRect(find.byWidget(first.itemView));
      final nextRect = tester.getRect(find.byWidget(next.itemView));

      if (reverse) {
        expect(firstRect.left, closeTo(viewport.left + 10, 0.01));
        expect(nextRect.left, closeTo(firstRect.right, 0.01));
      } else {
        expect(firstRect.right, closeTo(viewport.right - 20, 0.01));
        expect(nextRect.right, closeTo(firstRect.left, 0.01));
      }

      layout.scrollToPositionWithOffset(20, 0);
      await tester.pump();
      final target = list.findViewHolderForAdapterPosition(20)!;
      final targetRect = tester.getRect(find.byWidget(target.itemView));
      expect(
        reverse ? targetRect.left : targetRect.right,
        closeTo(reverse ? viewport.left + 10 : viewport.right - 20, 0.01),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    }
  });

  testWidgets('尺寸稳定的连续布局不会每帧重新创建惯性滚动活动', (tester) async {
    final adapter = _RowsAdapter(count: 1000);
    final layout = rv.LinearLayoutManager();
    final list = _list(adapter, layout: layout);
    await _pump(tester, list);
    list.scrollToPosition(100);
    await tester.pumpAndSettle();
    layout.setItemPrefetchEnabled(false);
    await tester.pumpAndSettle();

    final scrollable = find.descendant(of: find.byWidget(list), matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    final viewport = position.viewportDimension;
    final maxExtent = position.maxScrollExtent;
    ScrollActivity? currentActivity() {
      // 活动对象身份用于识别布局是否错误地重启同一段惯性滚动。
      // ignore: invalid_use_of_protected_member
      return position.activity;
    }

    expect(list.fling(0, 3000), isTrue);
    await tester.pump();
    final activity = currentActivity();
    expect(activity, isA<BallisticScrollActivity>());
    var previousPixels = position.pixels;
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(Duration(milliseconds: 16));
      expect(position.viewportDimension, viewport);
      expect(position.maxScrollExtent, maxExtent);
      expect(currentActivity(), same(activity), reason: '第 $frame 帧尺寸稳定时应继续同一个惯性活动');
      expect(position.pixels, greaterThan(previousPixels));
      previousPixels = position.pixels;
    }
    list.stopScroll();
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('stopScroll 取消平滑定位后不会延迟跳回旧目标', (tester) async {
    final adapter = _RowsAdapter(count: 1000);
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = _list(adapter, layout: layout);
    await _pump(tester, list);

    list.smoothScrollToPosition(900);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 30));
    final stoppedPosition = layout.findFirstVisibleItemPosition();
    expect(stoppedPosition, greaterThan(0));
    expect(stoppedPosition, lessThan(900));

    list.stopScroll();
    await tester.pump();
    await tester.pump(Duration(milliseconds: 500));
    await tester.pump();

    expect(layout.findFirstVisibleItemPosition(), stoppedPosition);
    expect(list.findViewHolderForAdapterPosition(900), isNull);
    expect(list.getScrollState(), rv.RecyclerView.SCROLL_STATE_IDLE);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手指接管平滑定位后不会延迟跳回旧目标', (tester) async {
    final adapter = _RowsAdapter(count: 1000);
    final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
    final list = _list(adapter, layout: layout);
    await _pump(tester, list);

    list.smoothScrollToPosition(900);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 30));
    final beforeDrag = layout.findFirstVisibleItemPosition();
    expect(beforeDrag, greaterThan(0));
    expect(beforeDrag, lessThan(900));

    final gesture = await tester.startGesture(tester.getCenter(find.byWidget(list)));
    await tester.pump();
    await gesture.moveBy(Offset(0, 96));
    await tester.pump();
    final draggedPosition = layout.findFirstVisibleItemPosition();
    expect(draggedPosition, lessThanOrEqualTo(beforeDrag));
    await tester.pump(Duration(milliseconds: 400));
    expect(layout.findFirstVisibleItemPosition(), draggedPosition);

    await gesture.up();
    await tester.pump();
    await tester.pump(Duration(milliseconds: 500));
    await tester.pump();
    expect(layout.findFirstVisibleItemPosition(), lessThan(beforeDrag + 20));
    expect(list.findViewHolderForAdapterPosition(900), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('父级 build 替换整个 RecyclerView 配置时安全提交新适配器', (tester) async {
    final first = _RowsAdapter(count: 20);
    final second = _RowsAdapter(count: 20, firstId: 1000);
    final selected = ValueNotifier(false);
    final createdWidgets = <rv.RecyclerView>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: selected,
            builder: (context, useSecond, child) {
              final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
              final list = _list(useSecond ? second : first, layout: layout);
              createdWidgets.add(list);
              return SizedBox(width: 320, height: 240, child: list);
            },
          ),
        ),
      ),
    );
    expect(find.text('row 0').hitTestable(), findsOneWidget);
    final oldWidget = createdWidgets.single;

    selected.value = true;
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump();

    expect(createdWidgets, hasLength(2));
    expect(oldWidget.findViewHolderForAdapterPosition(0), isNull);
    expect(createdWidgets.last.findViewHolderForAdapterPosition(0), isNotNull);
    expect(find.text('row 1000').hitTestable(), findsOneWidget);
    expect(find.text('row 0').hitTestable(), findsNothing);
    expect(first.hasObservers(), isFalse);
    expect(second.hasObservers(), isTrue);
    expect(first.tracker.disposals.length, first.tracker.initializations.length);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(SizedBox());
    selected.dispose();
  });

  for (final clearAll in [true, false]) {
    testWidgets(clearAll ? 'clear 实际卸载池内已挂载 State' : '缩小回收池上限实际卸载超额 State', (tester) async {
      final pool = rv.RecycledViewPool();
      final adapter = _RowsAdapter(count: 40);
      final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
      final list = _list(adapter, layout: layout)
        ..setItemViewCacheSize(0)
        ..setRecycledViewPool(pool);

      Widget host(double height) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 320, height: height, child: list),
          ),
        ),
      );

      await tester.pumpWidget(host(240));
      await tester.pumpWidget(host(48));
      final pooled = _inspectPool(pool);
      expect(pooled.length, greaterThan(1));
      expect(adapter.tracker.disposals, isEmpty);

      if (clearAll) {
        pool.clear();
      } else {
        pool.setMaxRecycledViews(0, 1);
      }
      await tester.pump();
      final remaining = _inspectPool(pool);
      expect(remaining.length, clearAll ? 0 : 1);
      for (final holder in pooled) {
        expect(adapter.tracker.disposals.contains(holder.serial), !remaining.contains(holder));
      }
      final active = list.findViewHolderForAdapterPosition(0)! as _RowHolder;
      expect(adapter.tracker.disposals.contains(active.serial), isFalse);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(SizedBox());
      expect(adapter.tracker.disposals.length, adapter.tracker.initializations.length);
    });
  }
}

rv.RecyclerView _list(_RowsAdapter adapter, {rv.LinearLayoutManager? layout}) => rv.RecyclerView()
  ..setLayoutManager(layout ?? rv.LinearLayoutManager())
  ..setAdapter(adapter);

Future<void> _pump(WidgetTester tester, rv.RecyclerView list, {TextDirection textDirection = TextDirection.ltr}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: textDirection,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 320, height: 240, child: list),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

List<_RowHolder> _inspectPool(rv.RecycledViewPool pool) {
  final holders = <_RowHolder>[];
  while (pool.getRecycledViewCount(0) > 0) {
    holders.add(pool.getRecycledView(0)! as _RowHolder);
  }
  for (final holder in holders) {
    pool.putRecycledView(holder);
  }
  return holders;
}

class _Item {
  _Item(this.id, {this.type = 0, this.extent = 48, String? title}) : title = title ?? 'row $id';

  final int id;
  final int type;
  final double extent;
  final String title;
}

class _Binding {
  _Binding(this.position, List<Object> payloads) : payloads = List.of(payloads);

  final int position;
  final List<Object> payloads;
}

class _Tracker {
  final initializations = <int, int>{};
  final disposals = <int>{};
  final ticks = <int, int>{};
  final paintCounts = <int, int>{};
}

class _RowHolder extends rv.ViewHolder {
  _RowHolder(this.serial, this.type, this.model, Widget itemView) : super(itemView);

  final int serial;
  final int type;
  final ValueNotifier<_Item> model;
}

class _RowsAdapter extends rv.Adapter<_RowHolder> {
  _RowsAdapter({
    required int count,
    int types = 1,
    int firstId = 0,
    bool varyingExtent = false,
    this.horizontal = false,
    this.ticking = false,
    this.paintProbe = false,
  }) : items = List.generate(
         count,
         (index) => _Item(firstId + index, type: index % types, extent: varyingExtent ? 40 + (index % 3) * 20.0 : 48),
       );

  final List<_Item> items;
  final bool horizontal;
  final bool ticking;
  final bool paintProbe;
  final tracker = _Tracker();
  final holders = <_RowHolder>[];
  final positionsByHolder = <int, Set<int>>{};
  final wrongTypeBindings = <int>[];
  final bindings = <_Binding>[];
  int attachedToRecyclerView = 0;
  int detachedFromRecyclerView = 0;

  @override
  int getItemCount() => items.length;

  @override
  int getItemViewType(int position) => items[position].type;

  @override
  int getItemId(int position) => items[position].id;

  @override
  _RowHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final serial = holders.length;
    final model = ValueNotifier(_Item(-1));
    final holder = _RowHolder(
      serial,
      viewType,
      model,
      _RowProbe(
        serial: serial,
        model: model,
        tracker: tracker,
        horizontal: horizontal,
        ticking: ticking,
        paintProbe: paintProbe,
      ),
    );
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_RowHolder holder, int position, [List<Object> payloads = const []]) {
    final item = items[position];
    if (holder.type != item.type) wrongTypeBindings.add(position);
    positionsByHolder.putIfAbsent(holder.serial, () => <int>{}).add(position);
    bindings.add(_Binding(position, payloads));
    holder.model.value = item;
  }

  @override
  void onAttachedToRecyclerView(rv.RecyclerView recyclerView) {
    attachedToRecyclerView++;
  }

  @override
  void onDetachedFromRecyclerView(rv.RecyclerView recyclerView) {
    detachedFromRecyclerView++;
  }
}

class _RowProbe extends StatefulWidget {
  // 测试按仓库规则保留普通构造，避免 const 改变挂载身份。
  // ignore: prefer_const_constructors_in_immutables
  _RowProbe({
    required this.serial,
    required this.model,
    required this.tracker,
    required this.horizontal,
    this.ticking = false,
    this.paintProbe = false,
  });

  final int serial;
  final ValueNotifier<_Item> model;
  final _Tracker tracker;
  final bool horizontal;
  final bool ticking;
  final bool paintProbe;

  @override
  State<_RowProbe> createState() => _RowProbeState();
}

class _RowProbeState extends State<_RowProbe> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    widget.tracker.initializations.update(widget.serial, (value) => value + 1, ifAbsent: () => 1);
    if (widget.ticking) {
      _controller = AnimationController(vsync: this, duration: Duration(seconds: 1))
        ..addListener(() => widget.tracker.ticks.update(widget.serial, (count) => count + 1, ifAbsent: () => 1))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    widget.tracker.disposals.add(widget.serial);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<_Item>(
    valueListenable: widget.model,
    builder: (context, item, child) {
      final content = Semantics(
        label: 'item ${item.id}',
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}, child: Text(item.title)),
      );
      return SizedBox(
        width: widget.horizontal ? item.extent : null,
        height: widget.horizontal ? null : item.extent,
        child: widget.paintProbe
            ? CustomPaint(painter: _CountingPainter(item.id, widget.tracker), child: content)
            : content,
      );
    },
  );
}

class _CountingPainter extends CustomPainter {
  _CountingPainter(this.itemId, this.tracker);

  final int itemId;
  final _Tracker tracker;

  @override
  void paint(Canvas canvas, Size size) {
    tracker.paintCounts.update(itemId, (count) => count + 1, ifAbsent: () => 1);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(covariant _CountingPainter oldDelegate) => itemId != oldDelegate.itemId;
}
