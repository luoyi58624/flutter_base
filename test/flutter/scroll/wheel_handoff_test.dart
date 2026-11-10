import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fixture {
  _Fixture({this.axis = .vertical, this.reverse = false, this.smoothScroll})
    : outer = reverse ? ElScrollController() : ScrollController(),
      inner = reverse ? ElScrollController() : ScrollController();

  final Axis axis;
  final bool reverse;
  final ElSmoothScroll? smoothScroll;
  final ScrollController outer;
  final ScrollController inner;

  Widget _extent(double value) => axis == .vertical ? SizedBox(height: value) : SizedBox(width: value);

  Future<void> mount(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpAndSettle();
      await tester.pumpWidget(SizedBox.shrink());
      outer.dispose();
      inner.dispose();
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ScrollConfiguration(
          behavior: ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
          child: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: ElScroll.sliver(
                key: ValueKey('outer'),
                controller: outer,
                axis: axis,
                reverse: reverse,
                smoothScroll: smoothScroll,
                physics: ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _extent(60)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      width: axis == .horizontal ? 200 : null,
                      height: axis == .vertical ? 200 : null,
                      child: ElScroll.sliver(
                        key: ValueKey('inner'),
                        controller: inner,
                        axis: axis,
                        reverse: reverse,
                        smoothScroll: smoothScroll,
                        physics: ClampingScrollPhysics(),
                        slivers: [SliverToBoxAdapter(child: _extent(1000))],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _extent(1000)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset innerPoint(WidgetTester tester) =>
      tester.getRect(find.byKey(ValueKey('inner'))).intersect(tester.getRect(find.byKey(ValueKey('outer')))).center;

  Offset outerPoint(WidgetTester tester) {
    final rect = tester.getRect(find.byKey(ValueKey('outer')));
    if (axis == .vertical) return Offset(rect.center.dx, reverse ? rect.bottom - 10 : rect.top + 10);
    return Offset(reverse ? rect.right - 10 : rect.left + 10, rect.center.dy);
  }

  Future<void> wheel(WidgetTester tester, Offset point, {int settleMs = 240}) async {
    final delta = reverse ? -80.0 : 80.0;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: point,
        kind: .mouse,
        scrollDelta: axis == .vertical ? Offset(0, delta) : Offset(delta, 0),
      ),
    );
    await tester.pump();
    if (settleMs > 0) await tester.pump(Duration(milliseconds: settleMs));
  }
}

void main() {
  for (final axis in Axis.values) {
    for (final reverse in [false, true]) {
      for (final smooth in [false, true]) {
        final label = '${axis.name} reverse=$reverse smooth=$smooth';
        _Fixture fixture() => _Fixture(
          axis: axis,
          reverse: reverse,
          smoothScroll: smooth ? ElWindowsSmoothScroll(maxAcceleration: 1) : null,
        );

        testWidgets('$label 内层到边界仍接住连续滚轮，停满 500ms 才交给外层', (tester) async {
          final page = fixture();
          await page.mount(tester);
          final end = page.inner.position.maxScrollExtent;
          page.inner.jumpTo(end - 20);
          await tester.pump();
          final point = page.innerPoint(tester);

          await page.wheel(tester, point);
          expect(page.inner.offset, closeTo(end, .01));
          expect(page.outer.offset, 0, reason: '同一格滚轮的剩余量不能溢出到外层');
          for (var i = 0; i < 3; i++) {
            await tester.pump(Duration(milliseconds: 259));
            await page.wheel(tester, point);
            expect(page.outer.offset, 0, reason: '499ms 时边界空消费仍续期');
          }

          await tester.pump(Duration(milliseconds: 260));
          await page.wheel(tester, point);
          expect(page.inner.offset, closeTo(end, .01));
          expect(page.outer.offset, closeTo(80, .01));
          await tester.pumpAndSettle();
        });

        testWidgets('$label 鼠标移出内层后立即交接', (tester) async {
          final page = fixture();
          await page.mount(tester);
          await page.wheel(tester, page.innerPoint(tester));
          final innerOffset = page.inner.offset;
          final rect = tester.getRect(find.byKey(ValueKey('inner')));
          final outside = axis == .vertical
              ? Offset(rect.center.dx, rect.top - 2)
              : Offset(rect.left - 2, rect.center.dy);
          await page.wheel(tester, outside);
          expect(page.outer.offset, closeTo(80, .01));
          expect(page.inner.offset, closeTo(innerOffset, .01));
          await tester.pumpAndSettle();
        });

        testWidgets('$label 外层连续滚动经过内层不换目标，停顿后才重新命中', (tester) async {
          final page = fixture();
          await page.mount(tester);
          await page.wheel(tester, page.outerPoint(tester));
          await tester.pump(Duration(milliseconds: 259));
          await page.wheel(tester, page.innerPoint(tester));
          expect(page.outer.offset, closeTo(160, .01));
          expect(page.inner.offset, 0);

          await tester.pump(Duration(milliseconds: 260));
          await page.wheel(tester, page.innerPoint(tester));
          expect(page.outer.offset, closeTo(160, .01));
          expect(page.inner.offset, closeTo(80, .01));
          await tester.pumpAndSettle();
        });
      }
    }
  }

  testWidgets('500ms 从最后输入计时，交接时停止旧接收者的长动画', (tester) async {
    final page = _Fixture(smoothScroll: ElWindowsSmoothScroll(duration: Duration(seconds: 1), maxAcceleration: 1));
    await page.mount(tester);
    await page.wheel(tester, page.outerPoint(tester), settleMs: 501);
    final outerOffset = page.outer.offset;
    expect(outerOffset, inExclusiveRange(0, 80));

    await page.wheel(tester, page.innerPoint(tester));
    await tester.pumpAndSettle();
    expect(page.outer.offset, closeTo(outerOffset, .01));
    expect(page.inner.offset, closeTo(80, .01));
  });

  testWidgets('内层起始已贴边且没有接收者锁时，首格直接由外层接收', (tester) async {
    final page = _Fixture();
    await page.mount(tester);
    page.inner.jumpTo(page.inner.position.maxScrollExtent);
    await tester.pump();
    await page.wheel(tester, page.innerPoint(tester));
    expect(page.outer.offset, 80);
  });

  testWidgets('Shift 加纵向滚轮保留官方横向滚动规则', (tester) async {
    final page = _Fixture(axis: .horizontal);
    await page.mount(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(PointerScrollEvent(position: page.innerPoint(tester), scrollDelta: Offset(0, 80)));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(page.inner.offset, 80);
    expect(page.outer.offset, 0);
  });
}
