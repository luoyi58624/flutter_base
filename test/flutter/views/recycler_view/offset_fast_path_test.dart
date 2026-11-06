import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_base/src/flutter/views/recycler_view/test_clock.dart';
import 'package:flutter_base/src/flutter/views/recycler_view/work_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    RecyclerWorkProbe.reset();
    RecyclerTestClock.reset();
  });
  for (final axis in [rv.RecyclerView.VERTICAL, rv.RecyclerView.HORIZONTAL]) {
    for (final reversed in [false, true]) {
      testWidgets('窗口不变仅平移，方向$axis reverse$reversed不重新访问条目或索引', (tester) async {
        final rows = _Rows();
        final controller = ScrollController();
        final list = rv.RecyclerView(controller: controller)
          ..setAdapter(rows)
          ..setLayoutManager(rv.LinearLayoutManager(null, axis, reversed)..setItemPrefetchEnabled(false))
          ..setItemViewCacheSize(0)
          ..setPadding(12, 16, 8, 4);
        await _open(tester, list);
        // 首次子树挂载可能使几何代次失效，先完成一次保守重算再统计纯平移。
        controller.jumpTo(.1);
        await tester.pump();
        final holder = list.findViewHolderForAdapterPosition(1)!;
        final before = tester.getTopLeft(find.byWidget(holder.itemView));
        RecyclerWorkProbe.reset();
        for (var step = 1; step <= 6; step++) {
          final committed = tester.getTopLeft(find.byWidget(holder.itemView));
          controller.jumpTo(.1 + step);
          expect(tester.getTopLeft(find.byWidget(holder.itemView)), committed, reason: '输入先于下一帧布局到达时，命中与变换仍须对应已绘制的位置');
          await tester.pump(Duration(milliseconds: 8));
        }
        final work = RecyclerWorkProbe.snapshot();
        debugPrint('RECYCLER_OFFSET_WORK ${jsonEncode({'axis': axis, 'reverse': reversed, ...work})}');
        expect(work['translated_layouts'], 6);
        expect(work['full_layouts'], 0);
        expect(work['item_layout_visits'], 0);
        expect(work['prefix_queries'], 0);
        final after = tester.getTopLeft(find.byWidget(holder.itemView));
        final delta = reversed ? 6.0 : -6.0;
        expect(axis == rv.RecyclerView.VERTICAL ? after.dy - before.dy : after.dx - before.dx, closeTo(delta, .001));
        expect(list.findViewHolderForAdapterPosition(1), same(holder));
        expect(find.text('行 1').hitTestable(), findsOneWidget);
        await tester.pumpWidget(SizedBox());
        controller.dispose();
        rows.dispose();
      });
    }
  }

  testWidgets('跨过窗口边界与程序定位回到完整布局', (tester) async {
    final rows = _Rows();
    final controller = ScrollController();
    final list = _list(rows, controller);
    await _open(tester, list);
    RecyclerWorkProbe.reset();
    controller.jumpTo(60);
    await tester.pump();
    expect(RecyclerWorkProbe.fullLayouts, greaterThan(0));
    expect(list.findViewHolderForAdapterPosition(0), isNull);
    expect(find.text('行 5').hitTestable(), findsOneWidget);
    RecyclerWorkProbe.reset();
    list.scrollToPosition(1000);
    await tester.pump();
    expect(RecyclerWorkProbe.fullLayouts, greaterThan(0));
    expect(find.text('行 1000').hitTestable(), findsOneWidget);
    await tester.pumpWidget(SizedBox());
    controller.dispose();
    rows.dispose();
  });

  testWidgets('相同估高命中的新窗口连续累计位置，不逐项重复查询前缀和', (tester) async {
    final rows = _Rows();
    final controller = ScrollController();
    final list = _list(rows, controller);
    await _open(tester, list);
    list.scrollToPosition(1000);
    await tester.pump();
    RecyclerWorkProbe.reset();
    controller.jumpTo(controller.offset + 250);
    await tester.pump();
    final work = RecyclerWorkProbe.snapshot();
    debugPrint('RECYCLER_FILL_WORK ${jsonEncode(work)}');
    expect(work['full_layouts'], 1);
    expect(work['prefix_queries'], lessThanOrEqualTo(6));
    expect(find.text('行 1005').hitTestable(), findsOneWidget);
    expect(find.text('行 1009').hitTestable(), findsOneWidget);
    await tester.pumpWidget(SizedBox());
    controller.dispose();
    rows.dispose();
  });

  testWidgets('同帧滚动不能覆盖可见子项变高或数据通知的完整布局需求', (tester) async {
    final rows = _Rows();
    final controller = ScrollController();
    final list = _list(rows, controller);
    await _open(tester, list);
    final holder = list.findViewHolderForAdapterPosition(1)! as _Holder;
    rows.extents[1] = 120;
    holder.data.value = (position: 1, extent: 120.0);
    RecyclerWorkProbe.reset();
    controller.jumpTo(1);
    await tester.pump();
    expect(RecyclerWorkProbe.fullLayouts, greaterThan(0));
    expect(tester.getSize(find.byWidget(holder.itemView)).height, 120);
    RecyclerWorkProbe.reset();
    rows.notifyItemChanged(1);
    controller.jumpTo(2);
    await tester.pump();
    expect(RecyclerWorkProbe.fullLayouts, greaterThan(0));
    await tester.pumpWidget(SizedBox());
    controller.dispose();
    rows.dispose();
  });

  testWidgets('主轴和交叉轴尺寸变化不能使用旧几何平移', (tester) async {
    final rows = _Rows();
    final controller = ScrollController();
    final list = _list(rows, controller);
    await _open(tester, list);
    RecyclerWorkProbe.reset();
    await _open(tester, list, width: 200, height: 320);
    expect(RecyclerWorkProbe.fullLayouts, greaterThan(0));
    final holder = list.findViewHolderForAdapterPosition(0)!;
    expect(tester.getSize(find.byWidget(holder.itemView)).width, 200);
    expect(list.getLayoutManager()!.getChildCount(), 7);
    await tester.pumpWidget(SizedBox());
    controller.dispose();
    rows.dispose();
  });

  testWidgets('平移路径的预取绑定仍禁止在计算布局期间发送数据通知', (tester) async {
    var remainingBudget = 0;
    RecyclerTestClock.remainingBudgetMicroseconds = (_) => remainingBudget;
    final rows = _Rows();
    final controller = ScrollController();
    final layout = rv.LinearLayoutManager()..setInitialPrefetchItemCount(2);
    final list = rv.RecyclerView(controller: controller)
      ..setAdapter(rows)
      ..setLayoutManager(layout)
      ..setItemViewCacheSize(1);
    await _open(tester, list);
    controller.jumpTo(.1);
    await tester.pump();
    final target = layout.findLastVisibleItemPosition() + 1;
    var attempted = false;
    Object? notificationError;
    rows.onBind = (_, position) {
      if (attempted || position != target) return;
      attempted = true;
      try {
        rows.notifyItemChanged(0, 'illegal-during-prefetch');
      } catch (error) {
        notificationError = error;
      }
    };
    remainingBudget = 1000000;
    RecyclerWorkProbe.reset();
    controller.jumpTo(.2);
    await tester.pump();
    expect(RecyclerWorkProbe.translatedLayouts, greaterThan(0), reason: '必须真正覆盖平移后的预取分支');
    expect(attempted, isTrue, reason: '必须实际执行目标记录的预取绑定');
    expect(notificationError, isA<StateError>());
    expect(notificationError.toString(), contains('计算布局'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    controller.dispose();
    rows.dispose();
  });

  testWidgets('完整布局尾部 attach 发出的宿主失效不能被结束时覆盖成有效几何', (tester) async {
    final rows = _Rows();
    final controller = ScrollController();
    final list = _list(rows, controller);
    await _open(tester, list);
    controller.jumpTo(.1);
    await tester.pump();
    final earlier = list.findViewHolderForAdapterPosition(1)! as _Holder;
    final earlierBox = tester.renderObject<RenderConstrainedBox>(find.byWidget(earlier.itemView));
    var changed = false;
    rows.onAttach = (holder) {
      if (changed || holder.getBindingAdapterPosition() != 5) return;
      changed = true;
      // 模拟晚到的宿主失效，不在完成测量后直接改变子节点约束破坏同帧语义阶段。
      RenderAbstractViewport.of(earlierBox).markNeedsLayout();
    };
    controller.jumpTo(60);
    await tester.pump();
    expect(changed, isTrue, reason: '后进入的第5项必须在早期第1项完成测量后触发 attach');
    RecyclerWorkProbe.reset();
    controller.jumpTo(60.1);
    await tester.pump();
    expect(RecyclerWorkProbe.fullLayouts, greaterThan(0), reason: '布局期间的晚到失效必须保留至下一帧');
    expect(tester.getSize(find.byWidget(earlier.itemView)).height, 50);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    controller.dispose();
    rows.dispose();
  });

  testWidgets('连续平移后尺寸调整物理收到最近一帧像素快照', (tester) async {
    final rows = _Rows();
    final controller = ScrollController();
    final dimensions = <({double oldPixels, double newPixels})>[];
    final list = _list(rows, controller);
    await _open(tester, list, behavior: _DimensionsBehavior(dimensions));
    controller.jumpTo(.1);
    await tester.pump();
    RecyclerWorkProbe.reset();
    for (final offset in [1.0, 2.0, 3.0]) {
      controller.jumpTo(offset);
      await tester.pump();
    }
    expect(RecyclerWorkProbe.translatedLayouts, 3);
    dimensions.clear();
    final changed = list.findViewHolderForAdapterPosition(2)! as _Holder;
    rows.extents[2] = 80;
    changed.data.value = (position: 2, extent: 80.0);
    await tester.pump();
    expect(dimensions, isNotEmpty, reason: '真实内容总高度变化应进入 adjustPositionForNewDimensions');
    expect(dimensions.first.oldPixels, closeTo(3, .001), reason: '平移也必须同步 ScrollPosition 的最近指标快照');
    expect(dimensions.first.newPixels, closeTo(3, .001));
    expect(controller.offset, closeTo(3, .001));
    expect(tester.getSize(find.byWidget(changed.itemView)).height, 80);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    controller.dispose();
    rows.dispose();
  });
}

rv.RecyclerView _list(_Rows rows, ScrollController controller) => rv.RecyclerView(controller: controller)
  ..setAdapter(rows)
  ..setLayoutManager(rv.LinearLayoutManager()..setItemPrefetchEnabled(false))
  ..setItemViewCacheSize(0);

Future<void> _open(
  WidgetTester tester,
  rv.RecyclerView list, {
  double width = 240,
  double height = 240,
  ScrollBehavior? behavior,
}) => tester.pumpWidget(
  MaterialApp(
    home: Align(
      child: SizedBox(
        width: width,
        height: height,
        child: behavior == null ? list : ScrollConfiguration(behavior: behavior, child: list),
      ),
    ),
  ),
);

class _Rows extends rv.Adapter<_Holder> {
  final holders = <_Holder>[];
  final extents = <int, double>{};
  void Function(_Holder holder, int position)? onBind;
  void Function(_Holder holder)? onAttach;
  @override
  int getItemCount() => 10000;
  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final holder = _Holder();
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) {
    holder.data.value = (position: position, extent: extents[position] ?? 50.0);
    onBind?.call(holder, position);
  }

  @override
  void onViewAttachedToWindow(_Holder holder) => onAttach?.call(holder);

  void dispose() {
    for (final holder in holders) {
      holder.data.dispose();
    }
  }
}

class _Holder extends rv.ViewHolder {
  _Holder() : this._(ValueNotifier((position: -1, extent: 50.0)));
  _Holder._(this.data)
    : super(
        ValueListenableBuilder(
          valueListenable: data,
          builder: (_, value, _) =>
              SizedBox(width: value.extent, height: value.extent, child: Text('行 ${value.position}')),
        ),
      );
  final ValueNotifier<({int position, double extent})> data;
}

class _DimensionsBehavior extends MaterialScrollBehavior {
  const _DimensionsBehavior(this.records);

  final List<({double oldPixels, double newPixels})> records;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => _DimensionsPhysics(records);
}

class _DimensionsPhysics extends ClampingScrollPhysics {
  const _DimensionsPhysics(this.records, {super.parent});

  final List<({double oldPixels, double newPixels})> records;

  @override
  _DimensionsPhysics applyTo(ScrollPhysics? ancestor) => _DimensionsPhysics(records, parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    records.add((oldPixels: oldPosition.pixels, newPixels: newPosition.pixels));
    return newPosition.pixels;
  }
}
