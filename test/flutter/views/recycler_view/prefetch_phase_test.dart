import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_base/src/flutter/views/recycler_view/test_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(RecyclerTestClock.reset);

  testWidgets('屏外预取完成绑定与正文布局但不绘制，入屏复用同一个 holder', (tester) async {
    final fixture = _Fixture();
    await fixture.open(tester);
    final next = fixture.layout.findLastVisibleItemPosition() + 1;
    final prepared = fixture.rows.boundTo(next)!;
    final before = prepared.work.snapshot();
    final beforeElement = find.byWidget(prepared.itemView, skipOffstage: false).evaluate().single;
    final beforeRoot = beforeElement.renderObject;
    expect(before['mounts'], 1);
    expect(before['data_builds'], greaterThan(0));
    expect(before['root_layouts'], greaterThan(0));
    expect(before['body_layouts'], greaterThan(0));
    expect(before['paragraph_layouts'], greaterThan(0));
    expect(before['root_paints'], 0);
    expect(before['body_paints'], 0);
    expect(before['paragraph_paints'], 0);
    expect(fixture.list.findViewHolderForAdapterPosition(next), isNull);
    expect(fixture.rows.attached, isNot(contains(next)));
    final bindingsBefore = fixture.rows.bindings.where((position) => position == next).length;

    fixture.remainingBudget = 0;
    fixture.rows.stage = 'enter';
    fixture.list.scrollBy(0, 100);
    await tester.pump(Duration(milliseconds: 16));
    final visible = fixture.list.findViewHolderForAdapterPosition(next)! as _Holder;
    expect(visible, same(prepared));
    final afterElement = find.byWidget(prepared.itemView).evaluate().single;
    expect(afterElement, same(beforeElement));
    expect(afterElement.renderObject, same(beforeRoot));
    expect(fixture.rows.bindings.where((position) => position == next).length, bindingsBefore);
    expect(prepared.work.disposals, 0);
    expect(prepared.work.bodyPaints, greaterThan(0));
    expect(_text(next).hitTestable(), findsOneWidget);
    _print('prepared_then_visible', {
      'position': next,
      'prefetched': before,
      'after_entry': prepared.work.snapshot(),
      'entry_delta': _delta(before, prepared.work.snapshot()),
      'holder_preserved': identical(prepared, visible),
      'element_preserved': identical(beforeElement, afterElement),
      'render_preserved': identical(beforeRoot, afterElement.renderObject),
      'binds_during_entry': fixture.rows.bindings.where((position) => position == next).length - bindingsBefore,
      'events': prepared.work.events,
    });
    await fixture.close(tester);
  });

  for (final prefetchEnabled in [false, true]) {
    testWidgets('${prefetchEnabled ? '零预算' : '关闭预取'}时未准备的新记录在进入帧换绑和绘制', (tester) async {
      final fixture = _Fixture(prefetchEnabled: prefetchEnabled, remainingBudget: 0);
      await fixture.open(tester);
      final next = fixture.layout.findLastVisibleItemPosition() + 1;
      expect(fixture.rows.boundTo(next), isNull);
      fixture.rows.stage = 'enter';
      fixture.list.scrollBy(0, 100);
      await tester.pump(Duration(milliseconds: 16));
      final entered = fixture.list.findViewHolderForAdapterPosition(next)! as _Holder;
      final events = entered.work.events.where((event) => event['position'] == next).toList();
      expect(events.any((event) => event['event'] == 'bind' && event['stage'] == 'enter'), isTrue);
      expect(events.any((event) => event['event'] == 'body_paint' && event['stage'] == 'enter'), isTrue);
      expect(_text(next).hitTestable(), findsOneWidget);
      _print(prefetchEnabled ? 'zero_budget' : 'prefetch_disabled', {
        'position': next,
        'new_record_prepared_before_entry': false,
        'holder_mounts': entered.work.mounts,
        'holder_disposals': entered.work.disposals,
        'entry_frame_root_layouts': events.where((event) => event['event'] == 'root_layout').length,
        'entry_frame_body_layouts': events.where((event) => event['event'] == 'body_layout').length,
        'entry_frame_paragraph_layouts': events.where((event) => event['event'] == 'paragraph_layout').length,
        'entry_frame_paragraph_paints': events.where((event) => event['event'] == 'paragraph_paint').length,
        'events_for_entered_record': events,
      });
      await fixture.close(tester);
    });
  }

  testWidgets('快速跨越两项预取范围后，新窗口仍需在进入帧绑定布局和绘制', (tester) async {
    final fixture = _Fixture();
    await fixture.open(tester);
    final preparedPositions = fixture.rows.holders.map((holder) => holder.getBindingAdapterPosition()).toSet();
    final createdBefore = fixture.rows.holders.length;
    fixture.remainingBudget = 0;
    fixture.rows.stage = 'jump_beyond_prefetch';
    fixture.list.scrollBy(0, 800);
    await tester.pump(Duration(milliseconds: 16));
    final positions = [
      for (
        var position = fixture.layout.findFirstVisibleItemPosition();
        position <= fixture.layout.findLastVisibleItemPosition();
        position++
      )
        position,
    ];
    expect(positions, isNotEmpty);
    expect(positions.where(preparedPositions.contains), isEmpty);
    final entered = [
      for (final position in positions) fixture.list.findViewHolderForAdapterPosition(position)! as _Holder,
    ];
    final events = [
      for (final holder in entered)
        ...holder.work.events.where(
          (event) => event['stage'] == 'jump_beyond_prefetch' && positions.contains(event['position']),
        ),
    ];
    for (final position in positions) {
      expect(_text(position).hitTestable(), findsOneWidget);
    }
    _print('jump_beyond_two_items', {
      'prefetch_item_count': 2,
      'previously_prepared_positions': preparedPositions.toList()..sort(),
      'visible_positions_after_jump': positions,
      'new_holders': fixture.rows.holders.length - createdBefore,
      'entry_frame_bindings': events.where((event) => event['event'] == 'bind').length,
      'entry_frame_body_layouts': events.where((event) => event['event'] == 'body_layout').length,
      'entry_frame_body_paints': events.where((event) => event['event'] == 'body_paint').length,
      'entry_frame_paragraph_layouts': events.where((event) => event['event'] == 'paragraph_layout').length,
      'entry_frame_paragraph_paints': events.where((event) => event['event'] == 'paragraph_paint').length,
      'entry_frame_events': events,
    });
    await fixture.close(tester);
  });

  testWidgets('刚离屏的旧图层在同帧隐藏换绑后不绘制，入屏后才绘制新记录', (tester) async {
    final fixture = _Fixture(blockTypes: true);
    await fixture.open(tester);
    final oldVisible = {
      for (
        var position = fixture.layout.findFirstVisibleItemPosition();
        position <= fixture.layout.findLastVisibleItemPosition();
        position++
      )
        fixture.list.findViewHolderForAdapterPosition(position)! as _Holder,
    };
    expect(oldVisible.every((holder) => holder.work.bodyPaints > 0), isTrue);
    final elements = {
      for (final holder in oldVisible) holder: find.byWidget(holder.itemView, skipOffstage: false).evaluate().single,
    };
    fixture.rows.stage = 'retire_and_prefetch';
    fixture.list.scrollBy(0, 400);
    await tester.pump(Duration(milliseconds: 16));
    final hidden = fixture.rows.holders.where((holder) {
      final position = holder.getBindingAdapterPosition();
      return position >= 8 && position <= 9 && fixture.list.findViewHolderForAdapterPosition(position) == null;
    }).toList();
    expect(hidden, isNotEmpty, reason: '必须确实准备了当前可见窗口之后的另一种结构');
    final reusedPainted = hidden.where(oldVisible.contains).toList();
    expect(reusedPainted, isNotEmpty, reason: '本用例需要命中刚退出可见区、旧帧已经画过的 holder');
    for (final holder in reusedPainted) {
      expect(find.byWidget(holder.itemView, skipOffstage: false).evaluate().single, same(elements[holder]));
      expect(holder.work.disposals, 0);
      expect(fixture.rows.attached, isNot(contains(holder.getBindingAdapterPosition())));
    }
    final hiddenPaints = [
      for (final holder in reusedPainted)
        ...holder.work.events.where(
          (event) =>
              event['stage'] == 'retire_and_prefetch' &&
              event['event'] == 'body_paint' &&
              event['visible_when_recorded'] == false,
        ),
    ];
    final hiddenParagraphPaints = [
      for (final holder in reusedPainted)
        ...holder.work.events.where(
          (event) =>
              event['stage'] == 'retire_and_prefetch' &&
              event['event'] == 'paragraph_paint' &&
              event['visible_when_recorded'] == false,
        ),
    ];
    expect(hiddenPaints, isEmpty);
    expect(hiddenParagraphPaints, isEmpty);
    _print('retired_layer_rebound_offscreen', {
      'visible_positions': fixture.rows.attached.toList()..sort(),
      'prefetched_positions': hidden.map((holder) => holder.getBindingAdapterPosition()).toList()..sort(),
      'reused_previously_painted_holders': reusedPainted.length,
      'hidden_body_paints_after_rebind': hiddenPaints.length,
      'hidden_paragraph_paints_after_rebind': hiddenParagraphPaints.length,
      'hidden_paint_events': hiddenPaints,
      'reused_holder_events': [for (final holder in reusedPainted) holder.work.events],
    });
    fixture.remainingBudget = 0;
    fixture.rows.stage = 'prefetched_records_enter';
    fixture.list.scrollBy(0, 200);
    await tester.pump(Duration(milliseconds: 16));
    for (final holder in reusedPainted) {
      final position = holder.getBindingAdapterPosition();
      expect(fixture.list.findViewHolderForAdapterPosition(position), same(holder));
      expect(find.byWidget(holder.itemView).evaluate().single, same(elements[holder]));
      expect(_text(position).hitTestable(), findsOneWidget);
      expect(
        holder.work.events.any(
          (event) =>
              event['stage'] == 'prefetched_records_enter' &&
              event['event'] == 'paragraph_paint' &&
              event['painted_text'] == '正文 $position' &&
              event['visible_when_recorded'] == true,
        ),
        isTrue,
      );
    }
    expect(tester.takeException(), isNull);
    await fixture.close(tester);
  });

  testWidgets('静态同位置缓存返回保留 OffsetLayer 且不重画正文', (tester) async {
    final fixture = _Fixture(blockTypes: true, prefetchEnabled: false);
    await fixture.open(tester);
    final original = fixture.list.findViewHolderForAdapterPosition(0)! as _Holder;
    final element = find.byWidget(original.itemView).evaluate().single;
    final boundary = _boundary(original);
    final layer = boundary.debugLayer!;
    expect(layer, isA<OffsetLayer>());
    final before = original.work.snapshot();
    final initialBinds = fixture.rows.bindings.where((position) => position == 0).length;

    fixture.rows.stage = 'cache_static';
    fixture.list.scrollBy(0, 100);
    await tester.pump(Duration(milliseconds: 16));
    expect(fixture.list.findViewHolderForAdapterPosition(0), isNull);
    expect(original.getBindingAdapterPosition(), 0);
    expect(find.byWidget(original.itemView, skipOffstage: false).evaluate().single, same(element));
    expect(boundary.debugLayer, same(layer));
    expect(layer.attached, isFalse);
    expect(original.work.bodyPaints, before['body_paints']);
    expect(original.work.paragraphPaints, before['paragraph_paints']);

    fixture.rows.stage = 'return_static';
    fixture.list.scrollBy(0, -100);
    await tester.pump(Duration(milliseconds: 16));
    expect(fixture.list.findViewHolderForAdapterPosition(0), same(original));
    expect(find.byWidget(original.itemView).evaluate().single, same(element));
    expect(boundary.debugLayer, same(layer));
    expect(layer.attached, isTrue);
    expect(fixture.rows.bindings.where((position) => position == 0).length, initialBinds);
    expect(original.work.bodyPaints, before['body_paints']);
    expect(original.work.paragraphPaints, before['paragraph_paints']);
    expect(_text(0).hitTestable(), findsOneWidget);
    _print('static_cache_layer_retained', {
      'element_preserved': true,
      'offset_layer_preserved': identical(boundary.debugLayer, layer),
      'return_delta': _delta(before, original.work.snapshot()),
      'binds_during_return': fixture.rows.bindings.where((position) => position == 0).length - initialBinds,
    });
    await fixture.close(tester);
  });

  testWidgets('嵌套重绘边界隐藏更新不绘制，返回后绘制最新文本且保留原图层', (tester) async {
    final fixture = _Fixture(blockTypes: true, prefetchEnabled: false, nestedBoundary: true);
    await fixture.open(tester);
    final original = fixture.list.findViewHolderForAdapterPosition(0)! as _Holder;
    final element = find.byWidget(original.itemView).evaluate().single;
    final host = _boundary(original);
    final hostLayer = host.debugLayer!;
    final nestedFinder = find.descendant(of: find.byWidget(original.itemView), matching: find.byType(RepaintBoundary));
    final nested = tester.renderObject<RenderRepaintBoundary>(nestedFinder);
    final nestedLayer = nested.debugLayer!;
    final paintedBefore = original.work.paragraphPaints;

    fixture.list.scrollBy(0, 100);
    await tester.pump(Duration(milliseconds: 16));
    expect(fixture.list.findViewHolderForAdapterPosition(0), isNull);
    expect(hostLayer.attached, isFalse);
    expect(nestedLayer.attached, isFalse);
    fixture.rows.stage = 'hidden_nested_update';
    original.work.revision.value = 1;
    await tester.pump(Duration(milliseconds: 16));
    expect(_text(0, revision: 1, skipOffstage: false), findsOneWidget);
    expect(original.work.paragraphPaints, paintedBefore);
    expect(
      original.work.events.where(
        (event) =>
            event['stage'] == 'hidden_nested_update' &&
            (event['event'] == 'body_paint' || event['event'] == 'paragraph_paint'),
      ),
      isEmpty,
    );
    expect(host.debugLayer, same(hostLayer));
    expect(nested.debugLayer, same(nestedLayer));

    fixture.rows.stage = 'return_nested_update';
    fixture.list.scrollBy(0, -100);
    await tester.pump(Duration(milliseconds: 16));
    expect(fixture.list.findViewHolderForAdapterPosition(0), same(original));
    expect(find.byWidget(original.itemView).evaluate().single, same(element));
    expect(host.debugLayer, same(hostLayer));
    expect(nested.debugLayer, same(nestedLayer));
    expect(_text(0, revision: 1).hitTestable(), findsOneWidget);
    expect(original.work.paragraphPaints, greaterThan(paintedBefore));
    expect(
      original.work.events.any(
        (event) =>
            event['stage'] == 'return_nested_update' &&
            event['event'] == 'paragraph_paint' &&
            event['painted_text'] == '正文 0 · 版本 1' &&
            event['visible_when_recorded'] == true,
      ),
      isTrue,
    );
    _print('nested_dirty_boundary_hidden_then_visible', {
      'host_layer_preserved': identical(host.debugLayer, hostLayer),
      'nested_layer_preserved': identical(nested.debugLayer, nestedLayer),
      'paragraph_paints_before_hidden_update': paintedBefore,
      'paragraph_paints_after_return': original.work.paragraphPaints,
      'events': original.work.events,
    });
    expect(tester.takeException(), isNull);
    await fixture.close(tester);
  });
}

void _print(String scenario, Map<String, Object?> report) => debugPrint(
  'RECYCLER_PREFETCH_PHASE ${jsonEncode({'scenario': scenario, 'source': 'actual RecyclerView viewport; RenderProxyBox plus actual RenderParagraph work; budget override only, real cost clock unchanged', 'measurement_scope': 'root/body proxy counts exclude independently relaid-out descendant boundaries; paragraph counts measure actual text layout/paint', ...report})}',
);

Finder _text(int position, {int? revision, bool skipOffstage = true}) => find.byWidgetPredicate(
  (widget) => widget is _MeasuredText && widget.text == '正文 $position${revision == null ? '' : ' · 版本 $revision'}',
  skipOffstage: skipOffstage,
);

RenderRepaintBoundary _boundary(_Holder holder) {
  RenderObject? object = find.byWidget(holder.itemView, skipOffstage: false).evaluate().single.renderObject;
  while (object != null) {
    if (object is RenderRepaintBoundary) return object;
    object = object.parent;
  }
  throw StateError('条目必须位于容器的重绘边界下');
}

Map<String, int> _delta(Map<String, int> before, Map<String, int> after) => {
  for (final entry in after.entries) entry.key: entry.value - before[entry.key]!,
};

class _Fixture {
  _Fixture({
    bool prefetchEnabled = true,
    this.remainingBudget = 1000000,
    bool blockTypes = false,
    bool nestedBoundary = false,
  }) {
    rows = _Rows(blockTypes: blockTypes, nestedBoundary: nestedBoundary);
    layout = rv.LinearLayoutManager()
      ..setInitialPrefetchItemCount(2)
      ..setItemPrefetchEnabled(prefetchEnabled);
    list = rv.RecyclerView()
      ..setLayoutManager(layout)
      ..setAdapter(rows)
      ..setItemViewCacheSize(1);
  }

  late final _Rows rows;
  late final rv.LinearLayoutManager layout;
  late final rv.RecyclerView list;
  int remainingBudget;

  Future<void> open(WidgetTester tester) async {
    // 只取消宿主快慢造成的预算随机性，create/bind/layout 的真实时钟不替换。
    RecyclerTestClock.remainingBudgetMicroseconds = (_) => remainingBudget;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(child: SizedBox(width: 320, height: 400, child: list)),
        ),
      ),
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(SizedBox());
    for (final holder in rows.holders) {
      holder.position.dispose();
      holder.work.revision.dispose();
    }
  }
}

class _Rows extends rv.Adapter<_Holder> {
  _Rows({required this.blockTypes, required this.nestedBoundary}) {
    setHasStableIds(true);
  }

  final bool blockTypes;
  final bool nestedBoundary;
  final holders = <_Holder>[];
  final bindings = <int>[];
  final attached = <int>{};
  String stage = 'prepare';

  _Holder? boundTo(int position) {
    for (final holder in holders) {
      if (holder.getBindingAdapterPosition() == position) return holder;
    }
    return null;
  }

  @override
  int getItemCount() => 1000;
  @override
  int getItemId(int position) => position;
  @override
  int getItemViewType(int position) => blockTypes ? (position ~/ 4) % 2 : 0;
  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final position = ValueNotifier(-1);
    final work = _Work(this, position, holders.length);
    final holder = _Holder(position, work);
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) {
    holder.position.value = position;
    bindings.add(position);
    holder.work.record('bind');
  }

  @override
  void onViewAttachedToWindow(_Holder holder) {
    attached.add(holder.position.value);
    holder.work.record('attach');
  }

  @override
  void onViewDetachedFromWindow(_Holder holder) {
    attached.remove(holder.position.value);
    holder.work.record('detach');
  }
}

class _Holder extends rv.ViewHolder {
  _Holder(this.position, this.work) : super(_MeasuredRow(position, work));
  final ValueNotifier<int> position;
  final _Work work;
}

class _MeasuredRow extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MeasuredRow(this.position, this.work);
  final ValueNotifier<int> position;
  final _Work work;

  @override
  State<_MeasuredRow> createState() => _MeasuredRowState();
}

class _MeasuredRowState extends State<_MeasuredRow> {
  @override
  void initState() {
    super.initState();
    widget.work.mounts++;
    widget.work.record('mount');
  }

  @override
  Widget build(BuildContext context) {
    widget.work.rowBuilds++;
    widget.work.record('row_build');
    Widget text(BuildContext context, int position, int? revision) => _MeasuredText(
      work: widget.work,
      text: '正文 $position${revision == null ? '' : ' · 版本 $revision'}',
      style: DefaultTextStyle.of(context).style,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    Widget content = ValueListenableBuilder(
      valueListenable: widget.position,
      builder: (context, position, _) {
        widget.work.dataBuilds++;
        widget.work.record('data_build');
        if (!widget.work.rows.nestedBoundary) return text(context, position, null);
        return ValueListenableBuilder(
          valueListenable: widget.work.revision,
          builder: (context, revision, _) {
            widget.work.revisionBuilds++;
            widget.work.record('revision_build');
            return text(context, position, revision);
          },
        );
      },
    );
    if (widget.work.rows.nestedBoundary) content = RepaintBoundary(child: content);
    // 两个代理可命中布局缓存，实际文本的独立布局边界另由 RenderParagraph 统计。
    return _PhaseProbe(
      work: widget.work,
      root: true,
      child: SizedBox(
        height: 100,
        child: _PhaseProbe(work: widget.work, child: content),
      ),
    );
  }

  @override
  void dispose() {
    widget.work.disposals++;
    widget.work.record('dispose');
    super.dispose();
  }
}

class _Work {
  _Work(this.rows, this.position, this.serial);
  final _Rows rows;
  final ValueNotifier<int> position;
  final int serial;
  final revision = ValueNotifier(0);
  final events = <Map<String, Object>>[];
  int mounts = 0;
  int disposals = 0;
  int rowBuilds = 0;
  int dataBuilds = 0;
  int revisionBuilds = 0;
  int rootLayouts = 0;
  int bodyLayouts = 0;
  int rootPaints = 0;
  int bodyPaints = 0;
  int paragraphLayouts = 0;
  int paragraphPaints = 0;

  void record(String event, {String? paintedText}) => events.add({
    'holder': serial,
    'position': position.value,
    'stage': rows.stage,
    'event': event,
    'visible_when_recorded': rows.attached.contains(position.value),
    'painted_text': ?paintedText,
  });

  Map<String, int> snapshot() => {
    'mounts': mounts,
    'disposals': disposals,
    'row_builds': rowBuilds,
    'data_builds': dataBuilds,
    'revision_builds': revisionBuilds,
    'root_layouts': rootLayouts,
    'body_layouts': bodyLayouts,
    'root_paints': rootPaints,
    'body_paints': bodyPaints,
    'paragraph_layouts': paragraphLayouts,
    'paragraph_paints': paragraphPaints,
  };
}

class _MeasuredText extends LeafRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MeasuredText({
    required this.work,
    required this.text,
    required this.style,
    required this.textDirection,
    required this.textScaler,
  });
  final _Work work;
  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasuredText(
    TextSpan(text: text, style: style),
    work,
    textDirection: textDirection,
    textScaler: textScaler,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderMeasuredText renderObject) {
    renderObject
      ..text = TextSpan(text: text, style: style)
      ..textDirection = textDirection
      ..textScaler = textScaler;
  }
}

class _RenderMeasuredText extends RenderParagraph {
  _RenderMeasuredText(super.text, this.work, {required super.textDirection, required super.textScaler});
  final _Work work;

  @override
  void performLayout() {
    work.paragraphLayouts++;
    work.record('paragraph_layout');
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    work.paragraphPaints++;
    work.record('paragraph_paint', paintedText: text.toPlainText());
    super.paint(context, offset);
  }
}

class _PhaseProbe extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _PhaseProbe({required this.work, this.root = false, required super.child});
  final _Work work;
  final bool root;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPhaseProbe(work, root);
}

class _RenderPhaseProbe extends RenderProxyBox {
  _RenderPhaseProbe(this.work, this.root);
  final _Work work;
  final bool root;

  @override
  void performLayout() {
    if (root) {
      work.rootLayouts++;
    } else {
      work.bodyLayouts++;
    }
    work.record(root ? 'root_layout' : 'body_layout');
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (root) {
      work.rootPaints++;
    } else {
      work.bodyPaints++;
    }
    work.record(root ? 'root_paint' : 'body_paint');
    super.paint(context, offset);
  }
}
