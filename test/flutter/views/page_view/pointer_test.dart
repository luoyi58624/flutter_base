import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  PageController? pages, {
  ScrollController? inner,
  ValueChanged<int>? onChanged,
}) => tester.pumpWidget(
  MaterialApp(
    home: Center(
      child: SizedBox(
        width: 300,
        height: 400,
        child: ElPageView(
          controller: pages,
          physics: ClampingScrollPhysics(),
          onPageChanged: onChanged,
          children: [
            ElScroll(
              key: ValueKey('inner'),
              controller: inner,
              physics: ClampingScrollPhysics(),
              children: [SizedBox(height: 1200, child: Text('第一页'))],
            ),
            Text('第二页'),
            Text('第三页'),
          ],
        ),
      ),
    ),
  ),
);

IgnorePointer _pageBarrier(WidgetTester tester) {
  final page = find.byType(PageView);
  return tester.widget<IgnorePointer>(find.descendant(of: page, matching: find.byType(IgnorePointer)).first);
}

void main() {
  testWidgets('官方拖动和释放惯性期间页面都不忽略指针', (tester) async {
    final pages = PageController();
    addTearDown(pages.dispose);
    await _pump(tester, pages);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElPageView)));
    await gesture.moveBy(Offset(-30, 0), timeStamp: Duration(milliseconds: 16));
    await tester.pump();
    await gesture.moveBy(Offset(-50, 0), timeStamp: Duration(milliseconds: 32));
    await tester.pump();
    expect(pages.position.activity, isA<DragScrollActivity>());
    expect(_pageBarrier(tester).ignoring, isFalse);
    await gesture.up(timeStamp: Duration(milliseconds: 33));
    await tester.pump(Duration(milliseconds: 16));
    expect(pages.position.activity, isA<BallisticScrollActivity>());
    expect(_pageBarrier(tester).ignoring, isFalse);
    await tester.pumpAndSettle();
    expect(pages.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('animateToPage 途中新指针直接滚动内层，不需要先点击停止动画', (tester) async {
    final pages = PageController();
    final inner = ScrollController();
    addTearDown(pages.dispose);
    addTearDown(inner.dispose);
    await _pump(tester, pages, inner: inner);
    final animation = pages.animateToPage(1, duration: Duration(seconds: 1), curve: Curves.linear);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 200));
    expect(pages.position.activity, isA<DrivenScrollActivity>());
    expect(_pageBarrier(tester).ignoring, isFalse);
    // 第一页此时仍有 240px 可见宽度，命中其可见内容而非移出视口的部分。
    final topLeft = tester.getTopLeft(find.byType(ElPageView));
    final gesture = await tester.startGesture(topLeft + Offset(100, 200));
    await gesture.moveBy(Offset(0, -30));
    await tester.pump();
    await gesture.moveBy(Offset(0, -60));
    await tester.pump();
    expect(inner.offset, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    await animation;
    expect(tester.takeException(), isNull);
  });

  testWidgets('外部 PageController 保留初始页、分页比例、替换和释放能力', (tester) async {
    final first = PageController(initialPage: 1, viewportFraction: .8);
    final next = PageController(viewportFraction: .6);
    addTearDown(first.dispose);
    addTearDown(next.dispose);
    final changes = <int>[];
    await _pump(tester, first, onChanged: changes.add);
    expect(first.page, 1);
    expect((first.position as PageMetrics).viewportFraction, .8);
    await tester.pump();
    expect(changes, isEmpty);
    await _pump(tester, next, onChanged: changes.add);
    expect(first.hasClients, isFalse);
    expect(next.hasClients, isTrue);
    expect(next.page, 1);
    expect((next.position as PageMetrics).viewportFraction, .6);
    next.jumpToPage(2);
    await tester.pumpAndSettle();
    expect(next.page, 2);
    await _pump(tester, null);
    expect(next.hasClients, isFalse);
    final state = tester.state<ScrollableState>(
      find.descendant(of: find.byType(PageView), matching: find.byType(Scrollable)).first,
    );
    expect((state.position as PageMetrics).viewportFraction, 1);
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });
}
