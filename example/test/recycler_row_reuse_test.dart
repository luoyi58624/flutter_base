import 'dart:convert';

import 'package:example/src/pages/examples/recycler_view/chat.dart';
import 'package:example/src/pages/examples/recycler_view/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('真实复选行等状态跨数据复用保留内部 State，回调始终对应当前 ID', (tester) async {
    await _open(tester, RecyclerSelectionPage());
    final list = _list(tester);
    await _controlledReuse(tester, list);
    final original = list.findViewHolderForAdapterPosition(0)!;
    expect(tester.widget<Checkbox>(_inside(original, find.byType(Checkbox))).value, isFalse);
    final before = _SelectionTree.capture(tester, original);

    list.scrollToPosition(9000);
    await tester.pump();
    await tester.pump();
    expect(_visible(list), contains(original), reason: '必须让原 holder 实际换绑，不能只比较没有移动的行');
    final reboundId = original.getItemId();
    expect(reboundId, inInclusiveRange(9000, 9020));
    final after = _SelectionTree.capture(tester, original);
    after.expectSameStructure(before);
    expect(_frameworkWidgets(original, chat: false), before.frameworkWidgets, reason: '同状态换绑只更新数据叶子，不更新整行框架');
    expect(_inside(original, find.text(_selectionTitle(reboundId))), findsOneWidget);
    expect(tester.widget<Checkbox>(_inside(original, find.byType(Checkbox))).value, isFalse);

    await tester.tap(_inside(original, find.byType(ElCheckbox)));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(_inside(original, find.byType(Checkbox))).value, isTrue);
    _SelectionTree.capture(tester, original).expectSameStructure(after);

    list.scrollToPosition(0);
    await tester.pumpAndSettle();
    final first = list.findViewHolderForItemId(0)!;
    expect(tester.widget<Checkbox>(_inside(first, find.byType(Checkbox))).value, isFalse);
    final untouched = list.findViewHolderForItemId(1)!;
    expect(tester.widget<Checkbox>(_inside(untouched, find.byType(Checkbox))).value, isFalse);

    list.scrollToPosition(reboundId);
    await tester.pumpAndSettle();
    final selected = list.findViewHolderForItemId(reboundId)!;
    expect(tester.widget<Checkbox>(_inside(selected, find.byType(Checkbox))).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨数据从选中变未选中只重置复选动画叶子，不重建整行或回写旧 ID', (tester) async {
    await _open(tester, RecyclerSelectionPage());
    final list = _list(tester);
    await _controlledReuse(tester, list);
    final original = list.findViewHolderForItemId(0)!;
    await tester.tap(_inside(original, find.byType(ElCheckbox)));
    await tester.pumpAndSettle();
    final before = _SelectionTree.capture(tester, original);

    list.scrollToPosition(7000);
    await tester.pump();
    await tester.pump();
    expect(_visible(list), contains(original));
    expect(original.getItemId(), inInclusiveRange(7000, 7020));
    final after = _SelectionTree.capture(tester, original);
    after.expectSameFrame(before);
    expect(after.checkboxState, isNot(same(before.checkboxState)), reason: '另一条数据不能接着播放旧记录的选中动画');
    expect(tester.widget<Checkbox>(_inside(original, find.byType(Checkbox))).value, isFalse);

    list.scrollToPosition(0);
    await tester.pumpAndSettle();
    final first = list.findViewHolderForItemId(0)!;
    expect(tester.widget<Checkbox>(_inside(first, find.byType(Checkbox))).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('真实聊天两种气泡跨消息复用固定布局，正文与时间重新绑定', (tester) async {
    await _open(tester, RecyclerChatPage());
    final list = _list(tester);
    await _controlledReuse(tester, list);
    final originals = {for (final holder in _visible(list)) holder: _ChatTree.capture(holder)};
    final originalIds = {for (final holder in originals.keys) holder: holder.getItemId()};

    list.scrollToPosition(5000);
    await tester.pump();
    await tester.pump();
    final shared = originals.keys.toSet().intersection(_visible(list));
    expect(shared, isNotEmpty);
    expect(shared.map((holder) => holder.getItemViewType()).toSet(), containsAll([0, 1]));
    for (final holder in shared) {
      final id = holder.getItemId();
      expect(id, isNot(originalIds[holder]));
      _ChatTree.capture(holder).expectSameStructure(originals[holder]!);
      expect(_frameworkWidgets(holder, chat: true), originals[holder]!.frameworkWidgets);
      final text = _inside(
        holder,
        find.byType(Text),
      ).evaluate().map((element) => (element.widget as Text).data).toList();
      expect(text.whereType<String>().any((value) => value.contains('消息 #${id + 1}：')), isTrue);
      final time = DateTime(2026, 1, 1, 9).add(Duration(minutes: id));
      final label = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      expect(text, contains(label));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('真实行复用后主题和宽度更新仍生效且选中状态不被环境更新覆盖', (tester) async {
    final page = RecyclerSelectionPage();
    await _open(tester, page);
    final list = _list(tester);
    await _controlledReuse(tester, list);
    final first = list.findViewHolderForAdapterPosition(0)!;
    await tester.tap(_inside(first, find.byType(ElCheckbox)));
    await tester.pumpAndSettle();
    final before = _SelectionTree.capture(tester, first);

    await _open(tester, page, width: 280, brightness: Brightness.dark);
    final visible = list.findViewHolderForItemId(0)!;
    final after = _SelectionTree.capture(tester, visible);
    after.expectSameStructure(before);
    expect(tester.getSize(find.byWidget(visible.itemView)).width, closeTo(280, .01));
    expect(Theme.of(tester.element(_inside(visible, find.byType(Checkbox)))).brightness, Brightness.dark);
    expect(tester.widget<Checkbox>(_inside(visible, find.byType(Checkbox))).value, isTrue);
    expect(_inside(visible, find.text(_selectionTitle(0))), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final chat in [false, true]) {
    testWidgets('真实${chat ? '聊天' : '复选'}连续跨行滚动记录内部 Element 更替与重新绑定规模', (tester) async {
      await _open(tester, chat ? RecyclerChatPage() : RecyclerSelectionPage());
      final list = _list(tester);
      await _controlledReuse(tester, list);
      final known = <rv.ViewHolder>{..._visible(list)};
      var rebindings = 0;
      var retainedElements = 0;
      var addedElements = 0;
      var removedElements = 0;
      var frameworkChanges = 0;
      var framesWithNewData = 0;
      final pumpUs = <int>[];

      for (final delta in [
        ...List<double>.filled(32, chat ? -120 : 88),
        ...List<double>.filled(32, chat ? 120 : -88),
      ]) {
        final before = {
          for (final holder in _visible(list))
            holder: (
              id: holder.getItemId(),
              elements: _elements(holder),
              framework: _frameworkWidgets(holder, chat: chat),
            ),
        };
        final clock = Stopwatch()..start();
        list.scrollBy(0, delta);
        await tester.pump(Duration(milliseconds: 8));
        clock.stop();
        pumpUs.add(clock.elapsedMicroseconds);
        var changed = false;
        for (final holder in _visible(list)) {
          known.add(holder);
          final previous = before[holder];
          if (previous == null || previous.id == holder.getItemId()) continue;
          changed = true;
          rebindings++;
          final current = _elements(holder);
          retainedElements += current.intersection(previous.elements).length;
          addedElements += current.difference(previous.elements).length;
          removedElements += previous.elements.difference(current).length;
          final framework = _frameworkWidgets(holder, chat: chat);
          for (var index = 0; index < framework.length; index++) {
            if (!identical(framework[index], previous.framework[index])) frameworkChanges++;
          }
        }
        if (changed) framesWithNewData++;
      }

      expect(rebindings, greaterThan(chat ? 12 : 40), reason: '检测必须实际进入不同数据，不能只在一屏内微移');
      expect(framesWithNewData, greaterThan(chat ? 10 : 40));
      expect(retainedElements, greaterThan(0));
      expect(addedElements, 0, reason: '正文跨数据绑定应更新已有 Element，不能重新挂载结构');
      expect(removedElements, 0);
      expect(frameworkChanges, 0, reason: '数据重新绑定应限于叶子，不能重复更新固定卡片与布局描述');
      expect(known.length, lessThan(30), reason: '真实长列表的已观察 holder 数量保持有界');
      expect(tester.takeException(), isNull);
      final metrics = {
        'page': chat ? 'chat' : 'selection',
        'items': 10000,
        'frames': pumpUs.length,
        'frames_with_rebinding': framesWithNewData,
        'same_holder_cross_id_bindings': rebindings,
        'observed_holders': known.length,
        'retained_elements_on_rebind': retainedElements,
        'added_elements_on_rebind': addedElements,
        'removed_elements_on_rebind': removedElements,
        'framework_widget_changes_on_rebind': frameworkChanges,
        'pump_wall': _timings(pumpUs),
        'environment': 'flutter_test/debug; host pump wall time, not device FrameTiming/FPS',
      };
      debugPrint('RECYCLER_REAL_ROW_PERF ${jsonEncode(metrics)}');
    });
  }
}

Future<void> _open(
  WidgetTester tester,
  Widget page, {
  double width = 390,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

rv.RecyclerView _list(WidgetTester tester) => tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));

Future<void> _controlledReuse(WidgetTester tester, rv.RecyclerView list) async {
  list.setItemViewCacheSize(0);
  (list.getLayoutManager()! as rv.LinearLayoutManager).setItemPrefetchEnabled(false);
  for (final type in [0, 1]) {
    list.getRecycledViewPool().setMaxRecycledViews(type, 20);
  }
  await tester.pumpAndSettle();
}

Set<rv.ViewHolder> _visible(rv.RecyclerView list) {
  final layout = list.getLayoutManager()! as rv.LinearLayoutManager;
  return {
    for (var index = layout.findFirstVisibleItemPosition(); index <= layout.findLastVisibleItemPosition(); index++)
      ?list.findViewHolderForAdapterPosition(index),
  };
}

Finder _inside(rv.ViewHolder holder, Finder matching) =>
    find.descendant(of: find.byWidget(holder.itemView, skipOffstage: false), matching: matching, matchRoot: true);

String _selectionTitle(int id) => '条目 ${(id + 1).toString().padLeft(5, '0')}';

Set<Element> _elements(rv.ViewHolder holder) {
  final root = find.byWidget(holder.itemView, skipOffstage: false).evaluate().single;
  final result = <Element>{};
  void visit(Element element) {
    result.add(element);
    element.visitChildren(visit);
  }

  visit(root);
  return result;
}

Map<String, double> _timings(List<int> values) {
  final sorted = [...values]..sort();
  double percentile(double q) => sorted[((sorted.length - 1) * q).floor()] / 1000;
  return {'p50_ms': percentile(.5), 'p95_ms': percentile(.95), 'max_ms': percentile(1)};
}

List<Widget> _frameworkWidgets(rv.ViewHolder holder, {required bool chat}) => [
  _inside(holder, find.byType(ElCardView)).evaluate().first.widget,
  if (chat) ...[
    _inside(holder, find.byType(Padding)).evaluate().first.widget,
    _inside(holder, find.byType(LayoutBuilder)).evaluate().first.widget,
  ] else ...[
    _inside(holder, find.byType(Row)).evaluate().first.widget,
    _inside(holder, find.byType(ElCheckbox)).evaluate().single.widget,
  ],
];

class _SelectionTree {
  _SelectionTree(this.card, this.cardRenderObject, this.row, this.checkbox, this.checkboxState, this.frameworkWidgets);

  factory _SelectionTree.capture(WidgetTester tester, rv.ViewHolder holder) {
    final card = _inside(holder, find.byType(ElCardView)).evaluate().first;
    return _SelectionTree(
      card,
      card.renderObject!,
      _inside(holder, find.byType(Row)).evaluate().first,
      _inside(holder, find.byType(ElCheckbox)).evaluate().single,
      tester.state(_inside(holder, find.byType(Checkbox))),
      _frameworkWidgets(holder, chat: false),
    );
  }

  final Element card;
  final RenderObject cardRenderObject;
  final Element row;
  final Element checkbox;
  final State checkboxState;
  final List<Widget> frameworkWidgets;

  void expectSameStructure(_SelectionTree previous) {
    expectSameFrame(previous);
    expect(checkbox, same(previous.checkbox));
    expect(checkboxState, same(previous.checkboxState), reason: '等选中值换绑与同 ID 用户切换都应保留复选 State');
  }

  void expectSameFrame(_SelectionTree previous) {
    expect(card, same(previous.card), reason: '数据 ID 改变不能替换整棵真实行子树');
    expect(cardRenderObject, same(previous.cardRenderObject));
    expect(row, same(previous.row));
  }
}

class _ChatTree {
  _ChatTree(this.card, this.cardRenderObject, this.layout, this.padding, this.align, this.frameworkWidgets);

  factory _ChatTree.capture(rv.ViewHolder holder) {
    final card = _inside(holder, find.byType(ElCardView)).evaluate().first;
    return _ChatTree(
      card,
      card.renderObject!,
      _inside(holder, find.byType(LayoutBuilder)).evaluate().first,
      _inside(holder, find.byType(Padding)).evaluate().first,
      _inside(holder, find.byType(Align)).evaluate().first,
      _frameworkWidgets(holder, chat: true),
    );
  }

  final Element card;
  final RenderObject cardRenderObject;
  final Element layout;
  final Element padding;
  final Element align;
  final List<Widget> frameworkWidgets;

  void expectSameStructure(_ChatTree previous) {
    expect(card, same(previous.card), reason: '聊天换绑不同消息不能重建整棵气泡');
    expect(cardRenderObject, same(previous.cardRenderObject));
    expect(layout, same(previous.layout));
    expect(padding, same(previous.padding));
    expect(align, same(previous.align));
  }
}
