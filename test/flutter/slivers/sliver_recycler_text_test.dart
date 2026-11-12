import 'package:flutter/foundation.dart' show ChangeNotifier, ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderObject, ScrollCacheExtent;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Layout { list, grid, masonry }

class _RecordText extends ChangeNotifier implements ValueListenable<String> {
  _RecordText(this.index, this.records) {
    index.addListener(notifyListeners);
    records.addListener(notifyListeners);
  }

  final ValueListenable<int> index;
  final ValueListenable<List<String>> records;

  @override
  String get value => records.value[index.value];

  @override
  void dispose() {
    index.removeListener(notifyListeners);
    records.removeListener(notifyListeners);
    super.dispose();
  }
}

class _Trace {
  _Trace(this.index, this.records);

  final ValueListenable<int> index;
  final ValueListenable<List<String>> records;
  final key = UniqueKey();
  late _RecordText text;
  int builds = 0;
  int updates = 0;
  bool disposed = false;
}

class _TextItem extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _TextItem({required this.trace, required this.fixedHeight});

  final _Trace trace;
  final bool fixedHeight;

  @override
  State<_TextItem> createState() => _TextItemState();
}

class _TextItemState extends State<_TextItem> {
  @override
  void initState() {
    super.initState();
    widget.trace.text = _RecordText(widget.trace.index, widget.trace.records);
  }

  @override
  Widget build(BuildContext context) {
    widget.trace.builds++;
    return _TextView(widget.trace, height: widget.fixedHeight ? 80 : null);
  }

  @override
  void dispose() {
    widget.trace.text.dispose();
    widget.trace.disposed = true;
    super.dispose();
  }
}

class _TextView extends ElView {
  _TextView(this.trace, {double? height})
    : super(
        key: trace.key,
        child: trace.text,
        style: ElStyle(height: height, fontSize: 16, padding: .all(8)),
        semantics: ElSemantics(container: true),
      );

  final _Trace trace;

  @override
  void updateRenderObject(BuildContext context, ElRenderView renderObject) {
    trace.updates++;
    super.updateRenderObject(context, renderObject);
  }
}

typedef _Snapshot = ({Element element, Widget widget, RenderObject render, int builds, int updates});

_Snapshot _snapshot(WidgetTester tester, _Trace trace) {
  final element = tester.element(find.byKey(trace.key));
  return (
    element: element,
    widget: element.widget,
    render: tester.renderObject(find.byKey(trace.key)),
    builds: trace.builds,
    updates: trace.updates,
  );
}

void _expectUnchanged(WidgetTester tester, _Trace trace, _Snapshot before) {
  final after = _snapshot(tester, trace);
  expect(after.element, same(before.element));
  expect(after.widget, same(before.widget));
  expect(after.render, same(before.render));
  expect(after.builds, before.builds, reason: '文本通知和序号换绑不能重建固定业务结构。');
  expect(after.updates, before.updates, reason: '纯文本更新不能经过整个 ElView 的配置更新。');
  expect(tester.getSemantics(find.byKey(trace.key)).label, trace.text.value);
}

class _Fixture {
  _Fixture(this.tester, this.layout, {this.fixedHeight = false});

  final WidgetTester tester;
  final _Layout layout;
  final bool fixedHeight;
  final controller = ScrollController();
  final records = ValueNotifier(List.generate(200, (index) => '记录 $index'));
  final traces = <_Trace>[];
  void Function()? _disposeSemantics;

  void _releaseSemantics() {
    final dispose = _disposeSemantics;
    _disposeSemantics = null;
    dispose?.call();
  }

  Future<void> mount() async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(320, 240);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(controller.dispose);
    addTearDown(records.dispose);
    final semantics = tester.ensureSemantics();
    _disposeSemantics = semantics.dispose;
    addTearDown(_releaseSemantics);

    Widget builder(BuildContext context, ValueListenable<int> index) {
      final trace = _Trace(index, records);
      traces.add(trace);
      return _TextItem(trace: trace, fixedHeight: fixedHeight);
    }

    final sliver = switch (layout) {
      .list => ElSliverList.recycler(itemCount: records.value.length, itemBuilder: builder, maxRecycledItems: 0),
      .grid => ElSliverGrid.recycler(
        itemCount: records.value.length,
        itemBuilder: builder,
        crossAxisCount: 2,
        maxRecycledItems: 0,
      ),
      .masonry => ElSliverMasonry.recycler(
        itemCount: records.value.length,
        itemBuilder: builder,
        crossAxisCount: 2,
        maxRecycledItems: 0,
      ),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          physics: ClampingScrollPhysics(),
          scrollCacheExtent: ScrollCacheExtent.pixels(0),
          slivers: [sliver],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  _Trace traceAt(int index) => traces.singleWhere((trace) => !trace.disposed && trace.index.value == index);

  void replaceText(int index, String text) {
    final next = [...records.value];
    next[index] = text;
    records.value = next;
  }

  Future<void> unmount() async {
    await tester.pumpWidget(SizedBox.shrink());
    expect(traces.every((trace) => trace.disposed), isTrue);
    records.value = [];
    await tester.pump();
    expect(tester.takeException(), isNull);
    _releaseSemantics();
  }
}

void main() {
  for (final layout in _Layout.values) {
    testWidgets('${layout.name} 换绑和数据通知走 ElView 文本快路径，固定视图不更新配置', (tester) async {
      final fixture = _Fixture(tester, layout, fixedHeight: true);
      await fixture.mount();
      final initial = {for (final trace in fixture.traces) trace: _snapshot(tester, trace)};
      final initialIndices = {for (final trace in fixture.traces) trace: trace.index.value};

      for (final offset in [240.0, 480.0, 720.0]) {
        fixture.controller.jumpTo(offset);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(fixture.traces.length, initial.length, reason: '换绑同类条目不应继续创建新的槽位。');
        for (final entry in initial.entries) {
          expect(entry.key.index.value, isNot(initialIndices[entry.key]));
          _expectUnchanged(tester, entry.key, entry.value);
        }
      }

      final trace = fixture.traces.first;
      fixture.replaceText(trace.index.value, '编辑 ${trace.index.value}');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final entry in initial.entries) {
        _expectUnchanged(tester, entry.key, entry.value);
      }
      await fixture.unmount();
    });

    testWidgets('${layout.name} ElView 文本直接变高和收缩会重新布局，保留原视图与起点', (tester) async {
      final fixture = _Fixture(tester, layout);
      await fixture.mount();
      final first = fixture.traceAt(0);
      final next = fixture.traceAt(layout == .list ? 1 : 2);
      final before = _snapshot(tester, first);
      final firstHeight = tester.getSize(find.byKey(first.key)).height;
      final nextTop = tester.getTopLeft(find.byKey(next.key)).dy;

      fixture.replaceText(0, '更新 0\n第二行\n第三行');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      _expectUnchanged(tester, first, before);
      final growth = tester.getSize(find.byKey(first.key)).height - firstHeight;
      expect(growth, greaterThan(0));
      expect(tester.getTopLeft(find.byKey(next.key)).dy, closeTo(nextTop + growth, .01));
      expect(fixture.controller.offset, 0);

      fixture.replaceText(0, '记录 0');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      _expectUnchanged(tester, first, before);
      expect(tester.getSize(find.byKey(first.key)).height, closeTo(firstHeight, .01));
      expect(tester.getTopLeft(find.byKey(next.key)).dy, closeTo(nextTop, .01));
      expect(fixture.controller.offset, 0);
      await fixture.unmount();
    });
  }
}
