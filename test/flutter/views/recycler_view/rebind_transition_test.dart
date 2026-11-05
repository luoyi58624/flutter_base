import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElRenderView;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('跨记录出现的新 starting 节点直接提交，同记录新增节点保留入场过渡', (tester) async {
    final adapter = _Rows(entering: true);
    final list = await _open(tester, adapter);
    list.scrollBy(0, 360);
    await tester.pump();
    final holder = list.findViewHolderForAdapterPosition(2)!;
    ElRenderView entry() => tester.renderObject<ElRenderView>(_inside(holder, find.byKey(ValueKey('entering'))));
    expect(entry().committedResolvedStyle.box.opacity, 1);
    expect(entry().hasActiveAnimationsForTest, isFalse);

    adapter.changed.add(2);
    adapter.notifyItemChanged(2);
    await tester.pumpAndSettle();
    expect(_inside(holder, find.byKey(ValueKey('entering'))), findsNothing);
    adapter.changed.remove(2);
    adapter.notifyItemChanged(2);
    await tester.pump();
    expect(entry().committedResolvedStyle.box.opacity, 0);
    expect(entry().hasActiveAnimationsForTest, isTrue);
    await tester.pumpAndSettle();
    expect(entry().committedResolvedStyle.box.opacity, 1);
    await tester.pumpWidget(SizedBox());
    adapter.dispose();
  });
  testWidgets('真实视口异记录换绑直接提交开关和进度，同记录更新仍播放过渡', (tester) async {
    final adapter = _Rows();
    final list = await _open(tester, adapter);
    final original = list.findViewHolderForAdapterPosition(0)!;
    final before = _elements(find.byWidget(original.itemView).evaluate().single);
    list.scrollBy(0, 360);
    await tester.pump();
    expect(original.getItemId(), inInclusiveRange(2, 3));
    final after = _elements(find.byWidget(original.itemView).evaluate().single);
    expect(after.difference(before), isEmpty);
    expect(before.difference(after), isEmpty);
    expect(_renders(original).any((render) => render.hasActiveAnimationsForTest), isFalse);
    expect(_progressPainter(original).ratio, .9);
    final alignment = tester.widget<AnimatedAlign>(_inside(original, find.byType(AnimatedAlign)));
    expect(alignment.alignment, Alignment.centerRight);
    expect(alignment.duration, Duration.zero);
    expect(tester.binding.transientCallbackCount, 0);

    adapter.changed.add(original.getItemId());
    adapter.notifyItemChanged(original.getBindingAdapterPosition());
    await tester.pump();
    expect(_renders(original).any((render) => render.hasActiveAnimationsForTest), isTrue);
    expect(
      tester.widget<AnimatedAlign>(_inside(original, find.byType(AnimatedAlign))).duration,
      greaterThan(Duration.zero),
    );
    await tester.pumpAndSettle();
    expect(_progressPainter(original).ratio, .1);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(SizedBox());
    adapter.dispose();
  });

  testWidgets('换绑不关闭可见的不确定进度与持续关键帧', (tester) async {
    final adapter = _Rows(loop: true);
    final list = await _open(tester, adapter);
    list.scrollBy(0, 360);
    await tester.pump();
    final holder = list.findViewHolderForAdapterPosition(2)!;
    final firstPhase = _progressPainter(holder, indefinite: true).phase;
    await tester.pump(Duration(milliseconds: 100));
    expect(_progressPainter(holder, indefinite: true).phase, isNot(firstPhase));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    adapter.dispose();
  });

  testWidgets('一个 holder 换绑不会抑制同一 buildScope 中另一行的正常过渡', (tester) async {
    final adapter = _Rows();
    final list = await _open(tester, adapter);
    final first = list.findViewHolderForAdapterPosition(0)! as _Holder;
    final retained = list.findViewHolderForAdapterPosition(1)! as _Holder;
    adapter.onBind = (holder, position) {
      if (identical(holder, first) && position != 0) retained.data.value = (position: 1, selected: true);
    };
    list.scrollBy(0, 180);
    await tester.pump();
    expect(retained.getItemId(), 1);
    expect(_renders(retained).any((render) => render.hasActiveAnimationsForTest), isTrue);
    expect(_renders(first).any((render) => render.hasActiveAnimationsForTest), isFalse);
    await tester.pumpAndSettle();
    await tester.pumpWidget(SizedBox());
    adapter.dispose();
  });
}

Future<rv.RecyclerView> _open(WidgetTester tester, _Rows adapter) async {
  final list = rv.RecyclerView()
    ..setAdapter(adapter)
    ..setItemViewCacheSize(0)
    ..setLayoutManager(rv.LinearLayoutManager()..setItemPrefetchEnabled(false));
  await tester.pumpWidget(
    MaterialApp(
      home: ElComponentProvider(
        components: el.mobileComponents,
        child: Align(child: SizedBox(width: 320, height: 360, child: list)),
      ),
    ),
  );
  if (adapter.loop) {
    await tester.pump(Duration(seconds: 1));
  } else {
    await tester.pumpAndSettle();
  }
  return list;
}

Finder _inside(rv.ViewHolder holder, Finder matching) =>
    find.descendant(of: find.byWidget(holder.itemView), matching: matching);
Iterable<ElRenderView> _renders(rv.ViewHolder holder) =>
    _inside(holder, find.byType(ElView)).evaluate().map((element) => element.renderObject).whereType<ElRenderView>();

dynamic _progressPainter(rv.ViewHolder holder, {bool indefinite = false}) => _inside(holder, find.byType(CustomPaint))
    .evaluate()
    .map((element) => (element.widget as CustomPaint).painter)
    .firstWhere(
      (painter) =>
          painter.runtimeType.toString() == '_ProgressPainter' && (painter as dynamic).indeterminate == indefinite,
    );

Set<Element> _elements(Element root) {
  final result = <Element>{};
  void visit(Element element) {
    result.add(element);
    element.visitChildren(visit);
  }

  visit(root);
  return result;
}

class _Rows extends rv.Adapter<_Holder> {
  _Rows({this.loop = false, this.entering = false}) {
    setHasStableIds(true);
  }
  final bool loop;
  final bool entering;
  final changed = <int>{};
  final holders = <_Holder>[];
  void Function(_Holder holder, int position)? onBind;

  @override
  int getItemCount() => 100;
  @override
  int getItemId(int position) => position;
  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final holder = _Holder(loop, entering);
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) {
    holder.data.value = (position: position, selected: ((position ~/ 2).isOdd != changed.contains(position)));
    onBind?.call(holder, position);
  }

  void dispose() {
    for (final holder in holders) {
      holder.data.dispose();
    }
  }
}

class _Holder extends rv.ViewHolder {
  _Holder(bool loop, bool entering) : this._(ValueNotifier((position: -1, selected: false)), loop, entering);
  _Holder._(this.data, bool loop, bool entering)
    : super(
        ValueListenableBuilder(
          valueListenable: data,
          builder: (context, value, _) => SizedBox(
            height: 180,
            child: Column(
              children: [
                ElSwitch(value: value.selected, semanticLabel: '条目开关'),
                ElProgress(value: value.selected ? 90 : 10),
                if (loop) ElProgress(),
                if (loop) ElLoadingIndicator(),
                if (entering && value.selected)
                  ElView(
                    key: ValueKey('entering'),
                    style: ElStyle(
                      width: 20,
                      height: 20,
                      opacity: 1,
                      starting: ElStyle(opacity: 0),
                      transition: [ElTransition.all(Duration(milliseconds: 200))],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  final ValueNotifier<({int position, bool selected})> data;
}
