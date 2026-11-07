import 'package:example/src/pages/examples/catalog.dart';
import 'package:example/src/pages/examples/recycler_view/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

Finder _rows() => find.byWidgetPredicate(
  (widget) => widget is ElView && widget.child is String && (widget.child as String).startsWith('Item - '),
);

Future<void> _choose(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(ValueKey('text-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('text-mode-$mode')));
  await tester.pumpAndSettle();
}

void main() {
  test('纯文本位于第一项，复杂卡片位于第四项', () {
    expect(recyclerExamples.take(5).map((page) => page.key), [
      'recycler-text',
      'recycler-selection',
      'recycler-chat',
      'recycler-cards',
      'recycler-takeaway',
    ]);
  });

  testWidgets('万条纯文本按需渲染，三种容器往返不添加行样式或固定尺寸', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: RecyclerTextPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView)).getAdapter()!.getItemCount(), 10000);

    for (final mode in ['recyclerView', 'listView', 'elScrollView', 'recyclerView']) {
      await _choose(tester, mode);
      expect(_rows().evaluate().length, lessThan(250));
      expect(tester.widgetList<ElView>(_rows()).any((row) => row.child == 'Item - 0'), isTrue);
      expect(tester.widgetList<ElView>(_rows()).every((row) => row.style == null), isTrue);
      late Finder scroll;
      if (mode == 'recyclerView') {
        scroll = find.byKey(ValueKey('recycler-text-list'));
      } else if (mode == 'listView') {
        scroll = find.byKey(ValueKey('official-text-list'));
        final list = tester.widget<ListView>(scroll);
        expect(list.itemExtent, isNull);
        expect(list.itemExtentBuilder, isNull);
        expect(list.prototypeItem, isNull);
        expect(list.controller!.positions, hasLength(1));
      } else {
        scroll = find.byKey(ValueKey('el-text-list'));
        final list = tester.widget<ElListView>(find.byType(ElListView));
        expect(list.itemCount, 10000);
        expect(list.fixedSize, isFalse);
        expect(list.keepAlive, isFalse);
        expect(tester.widget<ElScrollView>(scroll).controller!.positions, hasLength(1));
      }
      await tester.timedDrag(scroll, Offset(0, -220), Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<ElView>(_rows()).any((row) => int.parse((row.child as String).substring(7)) > 10),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }
    final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
    list.scrollToPosition(9999);
    await tester.pumpAndSettle();
    expect(tester.widgetList<ElView>(_rows()).any((row) => row.child == 'Item - 9999'), isTrue);
    expect(_rows().evaluate().length, lessThan(250));
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('真实无样式文本快速往返不反复创建整屏 holder', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(400, 622);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: RecyclerTextPage()),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
    final layout = list.getLayoutManager()! as rv.LinearLayoutManager;
    // 单独约束可见窗口的结构复用，不让实时预取预算影响断言。
    layout.setItemPrefetchEnabled(false);
    for (var frame = 0; frame < 2; frame++) {
      list.scrollBy(0, 960);
      await tester.pump();
    }
    Set<rv.ViewHolder> visible() => {
      for (var index = layout.findFirstVisibleItemPosition(); index <= layout.findLastVisibleItemPosition(); index++)
        list.findViewHolderForAdapterPosition(index)!,
    };
    final seen = visible();
    final initial = seen.length;
    for (final distance in [960.0, 960.0, 960.0, 960.0, -960.0, -960.0, -960.0, -960.0]) {
      list.scrollBy(0, distance);
      await tester.pump(Duration(milliseconds: 16));
      seen.addAll(visible());
      expect(tester.widgetList<ElView>(_rows()).every((row) => row.style == null), isTrue);
      expect(tester.takeException(), isNull);
    }
    expect(seen.length, lessThanOrEqualTo(initial + 4), reason: '窗口边界和既有缓存允许少量差异，不能每帧换掉整屏结构');
    expect(list.getRecycledViewPool().getRecycledViewCount(0), lessThanOrEqualTo(5));
    await tester.pumpWidget(SizedBox());
  });
}
