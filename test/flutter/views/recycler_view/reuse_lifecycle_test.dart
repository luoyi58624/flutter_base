import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('池中同标签 Hero 不参与导航收集，可见 Hero 仍正常飞行', (tester) async {
    final rows = _LifecycleRows(hero: true);
    final list = _list(rows);
    final navigator = GlobalKey<NavigatorState>();
    await _pump(tester, list, height: 90, navigator: navigator);
    final first = list.findViewHolderForAdapterPosition(0)!;
    list.scrollToPosition(1);
    await tester.pumpAndSettle();
    expect(list.getRecycledViewPool().getRecycledViewCount(0), 1);
    expect(list.findViewHolderForAdapterPosition(1), isNotNull);
    expect(find.byType(Hero, skipOffstage: false), findsNWidgets(2));
    final hidden = tester.element(find.byWidget(first.itemView, skipOffstage: false));
    expect(hidden.findAncestorWidgetOfExactType<HeroMode>()!.enabled, isFalse);

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: Center(
            child: Hero(
              tag: 'shared-record',
              child: SizedBox(width: 100, height: 100, child: Text('详情')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(list.findViewHolderForAdapterPosition(1), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载关键帧与进行中过渡进入池后停止请求帧，返回可见区恢复加载', (tester) async {
    final rows = _LifecycleRows(loading: true);
    final list = _list(rows);
    await _pump(tester, list, height: 90);
    await tester.pump(Duration(milliseconds: 16));
    rows.fade.value = true;
    await tester.pump();
    await tester.pump(Duration(milliseconds: 16));
    final visibleCallbacks = tester.binding.transientCallbackCount;
    expect(visibleCallbacks, greaterThan(0), reason: '先确认真实可见加载动画正在运行');

    list.scrollToPosition(1);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 32));
    expect(list.getRecycledViewPool().getRecycledViewCount(0), 1);
    expect(find.byType(ElLoadingIndicator, skipOffstage: false), findsOneWidget);
    expect(find.byType(ElLoadingIndicator), findsNothing);
    final hiddenCallbacks = tester.binding.transientCallbackCount;
    print(
      'RECYCLER_HIDDEN_PERF ${jsonEncode({'visible_transient_callbacks': visibleCallbacks, 'hidden_transient_callbacks': hiddenCallbacks, 'hidden_scheduled_frame': tester.binding.hasScheduledFrame})}',
    );
    expect(hiddenCallbacks, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    list.scrollToPosition(0);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 16));
    expect(find.byType(ElLoadingIndicator), findsOneWidget);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('顶部弹性拖出边界时内容和远端结构更新保持拖动位置', (tester) async {
    final rows = _LifecycleRows();
    final list = _list(rows);
    await _pump(tester, list, bounce: true);
    final position = _position(tester, list);
    final gesture = await _pull(tester, list, down: true);
    final before = position.pixels;
    expect(before, lessThan(0));
    rows.revision++;
    rows.notifyItemChanged(0, 'title');
    await tester.pump();
    expect(position.pixels, closeTo(before, .001));

    rows.items.add(1000);
    rows.notifyItemInserted(rows.items.length - 1);
    await tester.pump();
    expect(position.pixels, closeTo(before, .001));
    rows.items.removeLast();
    rows.notifyItemRemoved(rows.items.length);
    await tester.pump();
    expect(position.pixels, closeTo(before, .001));
    final last = rows.items.removeLast();
    rows.items.insert(rows.items.length - 1, last);
    rows.notifyItemMoved(rows.items.length - 1, rows.items.length - 2);
    await tester.pump();
    expect(position.pixels, closeTo(before, .001));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(0, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部弹性拖出边界时内容更新不夹紧回弹位置', (tester) async {
    final rows = _LifecycleRows();
    final list = _list(rows);
    await _pump(tester, list, bounce: true);
    list.scrollToPosition(rows.items.length - 1);
    await tester.pumpAndSettle();
    final position = _position(tester, list);
    final gesture = await _pull(tester, list, down: false);
    final before = position.pixels;
    expect(before, greaterThan(position.maxScrollExtent));
    rows.revision++;
    rows.notifyItemChanged(rows.items.length - 1, 'title');
    await tester.pump();
    expect(position.pixels, closeTo(before, .001));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('弹性越界中的明确定位仍进入目标内容范围', (tester) async {
    final rows = _LifecycleRows();
    final list = _list(rows);
    await _pump(tester, list, bounce: true);
    final position = _position(tester, list);
    final gesture = await _pull(tester, list, down: true);
    expect(position.pixels, lessThan(0));
    list.scrollToPosition(10);
    await tester.pump();
    expect(position.pixels, greaterThanOrEqualTo(0));
    expect(position.pixels, lessThanOrEqualTo(position.maxScrollExtent));
    expect(list.findViewHolderForAdapterPosition(10), isNotNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _LifecycleHolder extends rv.ViewHolder {
  _LifecycleHolder(this.value, Widget view) : super(view);
  final ValueNotifier<String> value;
}

class _LifecycleRows extends rv.Adapter<_LifecycleHolder> {
  _LifecycleRows({this.hero = false, this.loading = false}) {
    setHasStableIds(true);
  }
  final bool hero;
  final bool loading;
  final items = List.generate(100, (index) => index);
  final fade = ValueNotifier(false);
  int revision = 0;

  @override
  int getItemCount() => items.length;

  @override
  int getItemId(int position) => items[position];

  @override
  int getItemViewType(int position) => (hero || loading) && position == 0 ? 0 : 1;

  @override
  _LifecycleHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final value = ValueNotifier('');
    Widget content = ValueListenableBuilder(valueListenable: value, builder: (_, text, _) => Text(text));
    if (hero) {
      content = Hero(tag: 'shared-record', child: content);
    } else if (loading && viewType == 0) {
      content = ValueListenableBuilder(
        valueListenable: fade,
        builder: (_, faded, _) => ElView(
          style: ElStyle(
            opacity: faded ? .3 : 1,
            transition: [ElTransition.all(Duration(milliseconds: 500), Curves.linear)],
          ),
          child: ElLoadingIndicator(),
        ),
      );
    }
    return _LifecycleHolder(
      value,
      SizedBox(
        height: 100,
        child: Align(alignment: Alignment.centerLeft, child: content),
      ),
    );
  }

  @override
  void onBindViewHolder(_LifecycleHolder holder, int position, [List<Object> payloads = const []]) {
    holder.value.value = '记录 ${items[position]} · $revision';
  }
}

rv.RecyclerView _list(_LifecycleRows rows) => rv.RecyclerView()
  ..setLayoutManager(rv.LinearLayoutManager()..setItemPrefetchEnabled(false))
  ..setAdapter(rows)
  ..setItemViewCacheSize(0);

Future<void> _pump(
  WidgetTester tester,
  rv.RecyclerView list, {
  double height = 190,
  bool bounce = false,
  GlobalKey<NavigatorState>? navigator,
}) => tester.pumpWidget(
  MaterialApp(
    navigatorKey: navigator,
    scrollBehavior: bounce ? _BounceBehavior() : null,
    home: Scaffold(
      body: ElComponentProvider(
        components: el.mobileComponents,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 320, height: height, child: list),
        ),
      ),
    ),
  ),
);

ScrollPosition _position(WidgetTester tester, rv.RecyclerView list) => tester
    .state<ScrollableState>(find.descendant(of: find.byWidget(list), matching: find.byType(Scrollable)).first)
    .position;

Future<TestGesture> _pull(WidgetTester tester, rv.RecyclerView list, {required bool down}) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byWidget(list)));
  final direction = down ? 1.0 : -1.0;
  await gesture.moveBy(Offset(0, direction * 70));
  await tester.pump();
  await gesture.moveBy(Offset(0, direction * 35));
  await tester.pump();
  return gesture;
}

class _BounceBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
