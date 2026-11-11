import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/src/flutter/views/view/text/text_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

enum _Mode { sliverList, recycler, recyclerSelect, recyclerLocalSelect, recyclerDirect }

enum _Parent { stable, rebuild, selectIdentity, select }

const _rowCount = 500;
const _step = 72.0;

void main() {
  for (var pass = 0; pass < benchmarkPasses; pass++) {
    final modes = pass.isEven ? _Mode.values : _Mode.values.reversed;
    for (final equalRows in [true, false]) {
      for (final mode in modes) {
        testWidgets('sliver ${mode.name} ${equalRows ? 'equal_rows' : 'different_rows'} pass $pass', (tester) async {
          final fixture = _Fixture(tester, mode, equalRows: equalRows);
          await fixture.mount();
          final suffix = '${mode.name}/${equalRows ? 'equal_rows' : 'different_rows'}';

          Future<BenchResult> phase(String name, Future<void> Function(int) action, {int warmup = 2}) => measureBench(
            tester,
            suite: 'sliver',
            name: '$suffix/$name',
            pass: pass,
            counts: fixture.counts,
            action: action,
            warmup: warmup,
          );

          final equal = await phase('equal_notification', (_) => fixture.emit(fixture.records.value));
          fixture.verifyText();
          if (mode == .recyclerSelect || mode == .recyclerLocalSelect || mode == .recyclerDirect) {
            expect(equal.total('card_build'), 0);
            expect(equal.total('view_render_update'), 0);
            expect(equal.total('view_layout'), 0);
          }
          final copied = await phase('equal_new_data', (_) => fixture.emit(List.of(fixture.records.value)));
          if (mode == .recyclerSelect || mode == .recyclerLocalSelect || mode == .recyclerDirect) {
            expect(copied.total('view_render_update'), 0);
          }
          await phase('offscreen_data_change', (iteration) => fixture.replace(_rowCount - 1, '离屏 $iteration'));
          final changed = await phase('visible_text_change', (iteration) => fixture.replace(0, '可见记录 $iteration'));
          fixture.verifyText();
          expect(changed.total('view_layout'), greaterThan(0), reason: '真实换字必须抵达排版，不能缓存旧内容伪造收益。');
          if (mode == .recyclerDirect) {
            expect(changed.total('view_render_update'), 0);
            expect(changed.total('text_environment_build'), 0);
          }

          // 恢复一致数据后滚动：equal_rows 表示不同业务索引具有相同的展示数据。
          await fixture.emit(fixture.initialRows());
          final forward = await phase('scroll_forward', (_) async {
            fixture.controller.jumpTo(fixture.controller.offset + _step);
            await tester.pump();
          }, warmup: 8);
          fixture.verifyText();
          final backward = await phase('scroll_backward', (_) async {
            fixture.controller.jumpTo((fixture.controller.offset - _step).clamp(0, double.infinity));
            await tester.pump();
          });
          fixture.verifyText();
          if (mode != .sliverList) {
            expect(forward.total('rebind') + backward.total('rebind'), greaterThan(0));
            if (equalRows && (mode == .recyclerSelect || mode == .recyclerLocalSelect || mode == .recyclerDirect)) {
              final reused = forward.samples.where((sample) => (sample.counts['slot_mount'] ?? 0) == 0);
              expect(reused, isNotEmpty);
              for (final sample in reused) {
                expect(sample.counts['card_build'] ?? 0, 0);
                expect(sample.counts['view_render_update'] ?? 0, 0);
              }
            }
          } else {
            expect(forward.total('slot_mount'), greaterThan(0));
          }
          await fixture.dispose();
        });
      }
    }

    // 默认 List 身份比较与显式内容比较分开报告，条目自身使用相同文本直达通道。
    final parents = [_Parent.rebuild, _Parent.selectIdentity, _Parent.select];
    for (final parent in pass.isEven ? parents : parents.reversed) {
      for (final mode in [_Mode.sliverList, _Mode.recyclerDirect]) {
        testWidgets('sliver parent ${mode.name}/${parent.name} pass $pass', (tester) async {
          final fixture = _Fixture(tester, mode, equalRows: false, parent: parent, directList: true);
          await fixture.mount();
          for (final copy in [false, true]) {
            final result = await measureBench(
              tester,
              suite: 'sliver_parent',
              name: '${mode.name}/${parent.name}/${copy ? 'equal_new_data' : 'equal_notification'}',
              pass: pass,
              counts: fixture.counts,
              action: (_) => fixture.emit(copy ? List.of(fixture.records.value) : fixture.records.value),
            );
            fixture.verifyText();
            expect(result.total('view_render_create'), 0);
            expect(result.total('view_unmount'), 0);
            expect(result.total('slot_mount'), 0);
            if (parent == .select) {
              expect(result.total('container_builder'), 0);
              expect(result.total('item_factory'), 0);
              expect(result.total('view_render_update'), 0);
            }
          }
          final changed = await measureBench(
            tester,
            suite: 'sliver_parent',
            name: '${mode.name}/${parent.name}/visible_text_change',
            pass: pass,
            counts: fixture.counts,
            action: (iteration) => fixture.replace(0, '父配置数据 $iteration'),
          );
          expect(changed.total('container_builder'), greaterThan(0));
          fixture.verifyText();
          await fixture.dispose();
        });
      }
    }
  }

  // 末项跳转独立验证，避免自然高度估算和回收池状态改变原来的滚动计时轨迹。
  for (final mode in _Mode.values) {
    testWidgets('sliver offscreen ${mode.name} 末项进入视口后展示最新数据', (tester) async {
      final fixture = _Fixture(tester, mode, equalRows: false);
      await fixture.mount();
      expect(fixture.traces.any((trace) => !trace.disposed && trace.index.value == _rowCount - 1), isFalse);
      await fixture.replace(_rowCount - 1, '离屏更新后的最新记录');
      await fixture.verifyLastRecordVisible();
      await fixture.dispose();
    });
  }
}

class _Fixture {
  _Fixture(this.tester, this.mode, {required this.equalRows, this.parent = .stable, this.directList = false}) {
    records = BenchValue(initialRows());
    counts.observeRebuilds();
  }

  final WidgetTester tester;
  final _Mode mode;
  final bool equalRows;
  final _Parent parent;
  final bool directList;
  final counts = BenchCounts();
  final controller = ScrollController(keepScrollOffset: false);
  late final BenchValue<List<String>> records;
  final traces = <_Trace>[];

  List<String> initialRows() => List.generate(
    _rowCount,
    (index) => equalRows ? '展示内容完全相同' : '记录 $index ${index % 3 == 0 ? '需要换行的详细说明文字，验证自然高度布局仍然正确。' : '简短标题'}',
  );

  Widget _item(BuildContext context, ValueListenable<int> index) {
    counts.add('item_factory');
    final trace = _Trace(index, records, counts);
    traces.add(trace);
    return _Item(trace: trace, mode: directList ? .recyclerDirect : mode);
  }

  Widget _sliver() {
    counts.add('container_builder');
    return mode == .sliverList
        ? SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _item(context, AlwaysStoppedAnimation(index)),
              childCount: records.value.length,
              addAutomaticKeepAlives: false,
            ),
          )
        : ElSliverRecyclerList(itemCount: records.value.length, itemBuilder: _item, maxRecycledItems: 8);
  }

  Future<void> mount() async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(360, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Widget sliver;
    switch (parent) {
      case .stable:
        sliver = _sliver();
      case .rebuild:
        sliver = ValueListenableBuilder<List<String>>(valueListenable: records, builder: (_, _, _) => _sliver());
      case .selectIdentity:
      case .select:
        sliver = ElListenableBuilder<BenchValue<List<String>>, List<String>>(
          listenable: records,
          select: (source) {
            counts.add('outer_select');
            return source.value;
          },
          shouldRebuild: parent == .select
              ? (next, previous) {
                  counts.add('outer_compare');
                  return !ListEquality<String>().equals(next, previous);
                }
              : null,
          builder: (_, _) => _sliver(),
        );
    }
    await tester.pumpWidget(
      benchScene(
        CustomScrollView(
          controller: controller,
          primary: false,
          physics: ClampingScrollPhysics(),
          scrollCacheExtent: ScrollCacheExtent.pixels(144),
          semanticChildCount: _rowCount,
          slivers: [sliver],
        ),
      ),
    );
    await tester.pump();
    verifyText();
  }

  Future<void> emit(List<String> rows) async {
    counts.add('source_notify');
    records.emit(rows);
    await tester.pump();
  }

  Future<void> replace(int index, String text) {
    final rows = List.of(records.value);
    rows[index] = text;
    return emit(rows);
  }

  Future<void> verifyLastRecordVisible() async {
    final index = records.value.length - 1;
    final expected = records.value[index];
    final originalOffset = controller.offset;
    try {
      // 自然高度列表的末端估计会在布局后修正，按最新范围有限次逼近。
      for (var attempt = 0; attempt < 8; attempt++) {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        for (final trace in traces.where((trace) => !trace.disposed && trace.index.value == index)) {
          final finder = find.byKey(trace.titleKey);
          if (finder.evaluate().isEmpty) continue;
          final render = tester.renderObject<ElRenderView>(finder);
          final text = render.content as TextEngine;
          final bounds = text.selectionHitTestBounds;
          if (bounds == null || bounds.isEmpty) continue;
          // 标题拉满整行宽度，盒子中心可能是空白，改在真实文字内检查视口裁剪后的命中。
          final hits = tester.hitTestOnBinding(render.localToGlobal(bounds.center));
          if (!hits.path.any((entry) => identical(entry.target, render))) continue;
          expect(text.payload, expected, reason: '离屏修改的末项进入视口后必须展示最新数据。');
          verifyText();
          return;
        }
      }
      fail('无法将已修改的末项 $index 滚入视口。');
    } finally {
      controller.jumpTo(originalOffset);
      await tester.pump();
    }
  }

  void verifyText() {
    var checked = 0;
    for (final trace in traces.where((trace) => !trace.disposed)) {
      final finder = find.byKey(trace.titleKey, skipOffstage: false);
      final render = tester.renderObject<ElRenderView>(finder);
      expect((render.content as TextEngine).payload, trace.records.value[trace.index.value]);
      checked++;
    }
    expect(checked, greaterThan(0));
    expect(tester.takeException(), isNull);
  }

  Future<void> dispose() async {
    await tester.pumpWidget(SizedBox.shrink());
    expect(traces.every((trace) => trace.disposed), isTrue);
    controller.dispose();
    records.dispose();
  }
}

class _Trace {
  _Trace(this.index, this.records, this.counts);

  final ValueListenable<int> index;
  final BenchValue<List<String>> records;
  final BenchCounts counts;
  Key titleKey = UniqueKey();
  bool disposed = false;
}

class _TextBinding extends ChangeNotifier implements ValueListenable<String> {
  _TextBinding(this.trace) : lastIndex = trace.index.value {
    trace.index.addListener(_indexChanged);
    trace.records.addListener(_changed);
  }

  _Trace trace;
  int lastIndex;

  @override
  String get value => trace.records.value[trace.index.value];

  void _indexChanged() {
    if (trace.index.value != lastIndex) trace.counts.add('rebind');
    lastIndex = trace.index.value;
    _changed();
  }

  void _changed() {
    trace.counts.add('binding_notify');
    notifyListeners();
  }

  @override
  void dispose() {
    trace.index.removeListener(_indexChanged);
    trace.records.removeListener(_changed);
    super.dispose();
  }
}

class _Item extends StatefulWidget {
  _Item({required this.trace, required this.mode}) {
    trace.counts.add('host_widget_create');
  }

  final _Trace trace;
  final _Mode mode;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  late _TextBinding binding;

  BenchCounts get counts => widget.trace.counts;

  @override
  void initState() {
    super.initState();
    binding = _TextBinding(widget.trace);
    counts.add('slot_mount');
  }

  @override
  void didUpdateWidget(_Item oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父配置刷新会重新创建工厂配置，State 仍属于原槽位，显式转接新来源。
    if (!identical(oldWidget.trace, widget.trace)) {
      oldWidget.trace.disposed = true;
      widget.trace.titleKey = oldWidget.trace.titleKey;
      if (identical(oldWidget.trace.index, widget.trace.index) &&
          identical(oldWidget.trace.records, widget.trace.records)) {
        binding.trace = widget.trace;
      } else {
        binding.dispose();
        binding = _TextBinding(widget.trace);
      }
    }
    counts.add('host_update');
  }

  Widget _title(Object text) =>
      BenchView(counts: counts, key: widget.trace.titleKey, style: ElStyle(fontSize: 16, maxLines: 3), child: text);

  Widget _select(Widget Function(String) builder) => ElListenableBuilder<_TextBinding, String>(
    listenable: binding,
    select: (source) {
      counts.add('item_select');
      return source.value;
    },
    builder: (_, _) {
      counts.add('item_builder');
      return builder(binding.value);
    },
  );

  Widget _card(Widget title) {
    counts.add('card_build');
    return BenchView(
      counts: counts,
      style: ElStyle(padding: .all(10), backgroundColor: Color(0xffeeeeee), borderRadius: .circular(6)),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          title,
          SizedBox(height: 6),
          BenchView(counts: counts, style: ElStyle(fontSize: 12), child: '固定分类 · 固定状态'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    counts.add('host_build');
    return switch (widget.mode) {
      .sliverList || .recycler => ValueListenableBuilder<String>(
        valueListenable: binding,
        builder: (_, text, _) {
          counts.add('item_builder');
          return _card(_title(text));
        },
      ),
      .recyclerSelect => _select((text) => _card(_title(text))),
      .recyclerLocalSelect => _card(_select(_title)),
      .recyclerDirect => _card(_title(binding)),
    };
  }

  @override
  void dispose() {
    binding.dispose();
    widget.trace.disposed = true;
    counts.add('slot_dispose');
    super.dispose();
  }
}
