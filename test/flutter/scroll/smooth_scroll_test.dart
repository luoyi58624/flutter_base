import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/src/flutter/scroll/scroll_position.dart' show ScrollHostPosition;
import 'package:flutter_test/flutter_test.dart';

Widget _app(ScrollController controller, {Object? smoothScroll}) => Directionality(
  textDirection: TextDirection.ltr,
  child: ScrollConfiguration(
    behavior: ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
    child: Center(
      child: SizedBox(
        width: 300,
        height: 400,
        child: ElScroll.sliver(
          key: ValueKey('smooth-scroll'),
          controller: controller,
          smoothScroll: smoothScroll,
          physics: ClampingScrollPhysics(),
          slivers: [SliverToBoxAdapter(child: SizedBox(height: 1800))],
        ),
      ),
    ),
  ),
);

Future<void> _wheel(WidgetTester tester, double delta, {int ms = 0}) => tester.sendEventToBinding(
  PointerScrollEvent(
    position: tester.getCenter(find.byKey(ValueKey('smooth-scroll'))),
    scrollDelta: Offset(0, delta),
    timeStamp: Duration(milliseconds: ms),
  ),
);

void main() {
  testWidgets('嵌套的官方子列表不误用 ScrollHostPosition', (tester) async {
    final outer = ScrollController();
    final inner = ScrollController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 400,
          child: ElScroll(
            controller: outer,
            children: [
              SizedBox(
                height: 240,
                child: ListView.builder(
                  controller: inner,
                  itemCount: 50,
                  itemBuilder: (context, index) => SizedBox(height: 36, child: Text('Row $index')),
                ),
              ),
              SizedBox(height: 500),
            ],
          ),
        ),
      ),
    );
    expect(inner.position, isNot(isA<ScrollHostPosition>()));
    expect(outer.position, isA<ScrollHostPosition>());
  });

  testWidgets('外部 ScrollController 创建 ScrollHostPosition，鼠标滚轮由位置层处理', (tester) async {
    final controller = ScrollController(initialScrollOffset: 140);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, smoothScroll: ElWindowsSmoothScroll()));
    expect(controller.position, isA<ScrollHostPosition>());
    expect(controller.offset, closeTo(140, 0.01));
    await _wheel(tester, 120);
    await tester.pump(Duration(milliseconds: 16));
    await tester.pump(Duration(milliseconds: 16));
    expect(controller.offset, greaterThan(140));
    expect(controller.offset, lessThan(260));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThanOrEqualTo(260));
  });

  testWidgets('平滑滚轮在真实位置上逐帧变化，连滚追加目标', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, smoothScroll: ElWindowsSmoothScroll()));
    await _wheel(tester, 120);
    await tester.pump(Duration(milliseconds: 16));
    await tester.pump(Duration(milliseconds: 16));
    final first = controller.offset;
    expect(first, inExclusiveRange(0, 120), reason: '平滑不能瞬时跳到第一个目标');
    await _wheel(tester, 120, ms: 50);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(200), reason: '后续滚轮应累积到尚未完成的目标上');
  });

  testWidgets('显式 null 禁用平滑滚轮，当前输入立即落在位置上', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await _wheel(tester, 120);
    await tester.pump();
    expect(controller.offset, closeTo(120, 0.01));
  });

  testWidgets('滚轮动画进行中 jumpTo 接管活动，不允许旧目标回写', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, smoothScroll: ElWindowsSmoothScroll()));
    await _wheel(tester, 400);
    await tester.pump(Duration(milliseconds: 16));
    controller.jumpTo(800);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(800, 0.01));
  });
}
