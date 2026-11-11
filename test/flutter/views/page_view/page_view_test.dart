import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(PageController, ScrollController)> _pump(
  WidgetTester tester, {
  bool reverse = false,
  bool innerReverse = false,
  bool disabled = false,
  bool bouncing = false,
  Axis axis = Axis.horizontal,
}) async {
  final pages = PageController();
  final inner = ScrollController(initialScrollOffset: innerReverse ? 100 : 500);
  addTearDown(pages.dispose);
  addTearDown(inner.dispose);
  await tester.pumpWidget(
    Directionality(
      textDirection: .ltr,
      child: ScrollConfiguration(
        behavior: ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
        child: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: ElPageView(
              controller: pages,
              reverse: reverse,
              scrollDirection: axis,
              physics: disabled ? NeverScrollableScrollPhysics() : ClampingScrollPhysics(),
              children: [
                ElScroll(
                  key: ValueKey('inner'),
                  controller: inner,
                  reverse: innerReverse,
                  axis: axis,
                  physics: bouncing ? BouncingScrollPhysics() : ClampingScrollPhysics(),
                  children: [SizedBox(width: 900, height: 900)],
                ),
                ColoredBox(color: Colors.blue),
                ColoredBox(color: Colors.green),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return (pages, inner);
}

Future<TestGesture> _start(WidgetTester tester, {Axis axis = Axis.horizontal, double sign = -1}) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('inner'))));
  for (final distance in [30.0, 20.0]) {
    await gesture.moveBy(axis == Axis.horizontal ? Offset(sign * distance, 0) : Offset(0, sign * distance));
    await tester.pump();
  }
  return gesture;
}

void main() {
  for (final bouncing in [false, true]) {
    testWidgets('内层到边缘后同一笔余量交给 PageView，反拖保持分页归属 bouncing=$bouncing', (tester) async {
      final (pages, inner) = await _pump(tester, bouncing: bouncing);
      final gesture = await _start(tester);
      expect(inner.offset, greaterThan(500));
      expect(pages.offset, 0);
      final room = inner.position.maxScrollExtent - inner.offset;
      await gesture.moveBy(Offset(-room - 60, 0));
      await tester.pump();
      expect(inner.offset, closeTo(600, .01));
      expect(pages.offset, closeTo(60, .01));
      await gesture.moveBy(Offset(20, 0));
      await tester.pump();
      expect(inner.offset, closeTo(600, .01));
      expect(pages.offset, closeTo(40, .01));
      await gesture.moveBy(Offset(-150, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pages.page, closeTo(1, .001));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('反向内层的边界余量仍按手指方向翻页', (tester) async {
    final (pages, inner) = await _pump(tester, innerReverse: true);
    final gesture = await _start(tester);
    final room = inner.offset;
    await gesture.moveBy(Offset(-room - 75, 0));
    await tester.pump();
    expect(inner.offset, closeTo(0, .01));
    expect(pages.offset, closeTo(75, .01));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(pages.page, closeTo(0, .001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('反向 PageView 接住向右的边界余量', (tester) async {
    final (pages, inner) = await _pump(tester, reverse: true);
    inner.jumpTo(100);
    final gesture = await _start(tester, sign: 1);
    await gesture.moveBy(Offset(inner.offset + 80, 0));
    await tester.pump();
    expect(inner.offset, closeTo(0, .01));
    expect(pages.offset, closeTo(80, .01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('竖向分页沿同一轴接收余量', (tester) async {
    final (pages, inner) = await _pump(tester, axis: .vertical);
    final gesture = await _start(tester, axis: .vertical);
    await gesture.moveBy(Offset(0, -(600 - inner.offset) - 70));
    await tester.pump();
    expect(pages.offset, closeTo(70, .01));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('禁止分页拖动时不交接', (tester) async {
    final (pages, inner) = await _pump(tester, disabled: true);
    final gesture = await _start(tester);
    await gesture.moveBy(Offset(-200, 0));
    await tester.pump();
    expect(inner.offset, 600);
    expect(pages.offset, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('短距离交接后的松手速度交给官方分页吸附', (tester) async {
    final (pages, inner) = await _pump(tester);
    inner.jumpTo(590);
    final gesture = await _start(tester);
    await gesture.moveBy(Offset(-25, 0), timeStamp: Duration(milliseconds: 20));
    await tester.pump();
    await gesture.moveBy(Offset(-25, 0), timeStamp: Duration(milliseconds: 40));
    await tester.pump();
    expect(pages.page, lessThan(.5));
    await gesture.up(timeStamp: Duration(milliseconds: 45));
    await tester.pumpAndSettle();
    expect(pages.page, closeTo(1, .001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('分页已经到末页时不会接走内层的边界拖动', (tester) async {
    final (pages, inner) = await _pump(tester, reverse: true);
    final gesture = await _start(tester);
    await gesture.moveBy(Offset(-200, 0));
    await tester.pump();
    expect(inner.offset, 600);
    expect(pages.offset, 0);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('接管后外部跳页终止旧拖动，随后卸载不会重复结束', (tester) async {
    final (pages, inner) = await _pump(tester);
    final gesture = await _start(tester);
    await gesture.moveBy(Offset(-(600 - inner.offset) - 60, 0));
    await tester.pump();
    pages.jumpToPage(1);
    await tester.pump();
    await gesture.moveBy(Offset(-30, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pages.page, 1);
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });
}
