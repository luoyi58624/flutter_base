import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

final _innerKey = ValueKey('inner');

ScrollController _controller() {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  return controller;
}

// 关闭越界指示与滚动条，测试只观察滚动位置本身。
Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: ScrollConfiguration(
    behavior: ScrollBehavior().copyWith(overscroll: false, scrollbars: false),
    child: Center(child: SizedBox(width: 300, height: 400, child: child)),
  ),
);

Widget _box(double extent, {Axis axis = Axis.vertical, Widget? child}) => SliverToBoxAdapter(
  child: SizedBox(
    width: axis == Axis.horizontal ? extent : null,
    height: axis == Axis.vertical ? extent : null,
    child: child,
  ),
);

// 外层视口 400、可滚 1300；内层视口 300、可滚 600。
Widget _nested(
  ScrollController? outer,
  ScrollController? inner, {
  ScrollPhysics? outerPhysics,
  bool innerReverse = false,
}) => _app(
  ElScroll(
    controller: outer,
    physics: outerPhysics ?? ClampingScrollPhysics(),
    slivers: [
      _box(200),
      _box(
        300,
        child: ElScroll(
          key: _innerKey,
          controller: inner,
          reverse: innerReverse,
          physics: ClampingScrollPhysics(),
          slivers: [_box(900)],
        ),
      ),
      _box(1200),
    ],
  ),
);

// 第一段位移只用于越过触摸阈值，之后每段都会完整进入滚动位置。
Future<TestGesture> _drag(WidgetTester tester, List<double> steps, {Axis axis = Axis.vertical}) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byKey(_innerKey)));
  for (final step in steps) {
    await gesture.moveBy(axis == Axis.vertical ? Offset(0, step) : Offset(step, 0));
    await tester.pump();
  }
  return gesture;
}

Future<void> _release(WidgetTester tester, TestGesture gesture) async {
  await gesture.up();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  group('同轴嵌套接力', () {
    testWidgets('内层起手贴尾部边界，拖动由外层接力', (tester) async {
      final outer = _controller();
      final inner = _controller();
      await tester.pumpWidget(_nested(outer, inner));
      outer.jumpTo(120);
      inner.jumpTo(inner.position.maxScrollExtent);
      await tester.pump();

      final gesture = await _drag(tester, [-30, -20, -20]);
      expect(inner.offset, 600);
      expect(outer.offset, closeTo(160, 0.01));
      await _release(tester, gesture);
      expect(inner.offset, 600);
    });

    testWidgets('内层起手贴头部边界，拖动由外层接力', (tester) async {
      final outer = _controller();
      final inner = _controller();
      await tester.pumpWidget(_nested(outer, inner));
      outer.jumpTo(120);
      await tester.pump();

      final gesture = await _drag(tester, [30, 20, 20]);
      expect(inner.offset, 0);
      expect(outer.offset, closeTo(80, 0.01));
      await _release(tester, gesture);
    });

    testWidgets('不传控制器也能接力', (tester) async {
      await tester.pumpWidget(_nested(null, null));
      final outer = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final inner = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
      outer.jumpTo(120);
      inner.jumpTo(inner.maxScrollExtent);
      await tester.pump();

      final gesture = await _drag(tester, [-30, -20, -20]);
      expect(inner.pixels, 600);
      expect(outer.pixels, closeTo(160, 0.01));
      await _release(tester, gesture);
    });

    testWidgets('途中撞边界锁定在内层，新手势才交给外层', (tester) async {
      final outer = _controller();
      final inner = _controller();
      await tester.pumpWidget(_nested(outer, inner));
      outer.jumpTo(120);
      inner.jumpTo(500);
      await tester.pump();

      final gesture = await _drag(tester, [-30, -20, -20]);
      expect(inner.offset, closeTo(540, 0.01));
      expect(outer.offset, 120);

      await gesture.moveBy(Offset(0, -90));
      await tester.pump();
      expect(inner.offset, 600);
      expect(outer.offset, 120, reason: '撞边界的余量不能写入外层');

      await gesture.moveBy(Offset(0, -30));
      await tester.pump();
      expect(outer.offset, 120, reason: '同一手势的后续输入也不能交给外层');

      await gesture.moveBy(Offset(0, 25));
      await tester.pump();
      expect(inner.offset, closeTo(575, 0.01), reason: '回拖仍归内层');
      expect(outer.offset, 120);
      await _release(tester, gesture);

      inner.jumpTo(600);
      await tester.pump();
      final next = await _drag(tester, [-30, -20, -20]);
      expect(inner.offset, 600);
      expect(outer.offset, closeTo(160, 0.01));
      await _release(tester, next);
    });

    testWidgets('内层惯性撞边界不移动外层', (tester) async {
      final outer = _controller();
      final inner = _controller();
      await tester.pumpWidget(_nested(outer, inner));
      outer.jumpTo(120);
      inner.jumpTo(440);
      await tester.pump();

      var outerMoved = false;
      outer.addListener(() => outerMoved = true);
      // 拖动段最多走 120，离边界还有余量，边界只能由释放后的惯性到达。
      await tester.fling(find.byKey(_innerKey), Offset(0, -120), 2000);
      await tester.pumpAndSettle();

      expect(inner.offset, 600);
      expect(outerMoved, isFalse);
      expect(outer.offset, 120);
    });

    testWidgets('外层接力后的释放惯性属于外层', (tester) async {
      final outer = _controller();
      final inner = _controller();
      await tester.pumpWidget(_nested(outer, inner));
      outer.jumpTo(120);
      inner.jumpTo(inner.position.maxScrollExtent);
      await tester.pump();

      await tester.fling(find.byKey(_innerKey), Offset(0, -120), 2000);
      await tester.pumpAndSettle();

      expect(inner.offset, 600);
      expect(outer.offset, greaterThan(260), reason: '外层应继续走完释放惯性');
    });

    testWidgets('内层 reverse 时各层按自己的方向判定', (tester) async {
      final outer = _controller();
      final inner = _controller();
      await tester.pumpWidget(_nested(outer, inner, innerReverse: true));
      outer.jumpTo(120);
      await tester.pump();

      // 反向内层的 0 在视觉底部，手指上推已无余量，应由外层前进。
      final gesture = await _drag(tester, [-30, -20, -20]);
      expect(inner.offset, 0);
      expect(outer.offset, closeTo(160, 0.01));
      await _release(tester, gesture);

      final next = await _drag(tester, [30, 20, 20]);
      expect(inner.offset, closeTo(40, 0.01));
      expect(outer.offset, closeTo(160, 0.01));
      await _release(tester, next);
    });
  });

  group('接力边界', () {
    testWidgets('禁止用户滚动的外层不会被接力', (tester) async {
      final outer = _controller();
      final inner = _controller();
      await tester.pumpWidget(_nested(outer, inner, outerPhysics: NeverScrollableScrollPhysics()));
      outer.jumpTo(120);
      inner.jumpTo(inner.position.maxScrollExtent);
      await tester.pump();

      final gesture = await _drag(tester, [-30, -20, -20]);
      expect(inner.offset, 600);
      expect(outer.offset, 120);
      await _release(tester, gesture);
      expect(outer.offset, 120);
    });

    testWidgets('异轴外层不会被接力', (tester) async {
      final outer = _controller();
      final inner = _controller();
      await tester.pumpWidget(
        _app(
          ElScroll(
            controller: outer,
            axis: Axis.horizontal,
            physics: ClampingScrollPhysics(),
            slivers: [
              _box(
                300,
                axis: Axis.horizontal,
                child: ElScroll(
                  key: _innerKey,
                  controller: inner,
                  physics: ClampingScrollPhysics(),
                  slivers: [_box(900)],
                ),
              ),
              _box(1200, axis: Axis.horizontal),
            ],
          ),
        ),
      );
      inner.jumpTo(inner.position.maxScrollExtent);
      await tester.pump();
      final edge = inner.offset;

      final gesture = await _drag(tester, [-30, -20, -20]);
      expect(inner.offset, edge);
      expect(outer.offset, 0);
      await _release(tester, gesture);
    });

    // 中层视口 350、可滚 550，内层排在中层末尾；外层可滚 1250。
    Widget threeLevels(ScrollController outer, ScrollController middle, ScrollController inner) => _app(
      ElScroll(
        controller: outer,
        physics: ClampingScrollPhysics(),
        slivers: [
          _box(100),
          _box(
            350,
            child: ElScroll(
              controller: middle,
              physics: ClampingScrollPhysics(),
              slivers: [
                _box(600),
                _box(
                  300,
                  child: ElScroll(
                    key: _innerKey,
                    controller: inner,
                    physics: ClampingScrollPhysics(),
                    slivers: [_box(900)],
                  ),
                ),
              ],
            ),
          ),
          _box(1200),
        ],
      ),
    );

    testWidgets('三级嵌套先交给仍可滚动的中层', (tester) async {
      final outer = _controller();
      final middle = _controller();
      final inner = _controller();
      await tester.pumpWidget(threeLevels(outer, middle, inner));
      middle.jumpTo(500);
      await tester.pump();
      inner.jumpTo(inner.position.maxScrollExtent);
      await tester.pump();

      final gesture = await _drag(tester, [-30, -20, -20]);
      expect(inner.offset, 600);
      expect(middle.offset, closeTo(540, 0.01));
      expect(outer.offset, 0);
      await _release(tester, gesture);
    });

    testWidgets('三级嵌套中层也贴边时交给最外层', (tester) async {
      final outer = _controller();
      final middle = _controller();
      final inner = _controller();
      await tester.pumpWidget(threeLevels(outer, middle, inner));
      middle.jumpTo(middle.position.maxScrollExtent);
      await tester.pump();
      inner.jumpTo(inner.position.maxScrollExtent);
      await tester.pump();

      final gesture = await _drag(tester, [-30, -20, -20]);
      expect(inner.offset, 600);
      expect(middle.offset, 550);
      expect(outer.offset, closeTo(40, 0.01));
      await _release(tester, gesture);
    });
  });

  group('外部控制器', () {
    testWidgets('更换控制器沿用同一滚动位置', (tester) async {
      final first = _controller();
      final second = _controller();
      Widget page(ScrollController controller) =>
          _app(ElScroll(controller: controller, physics: ClampingScrollPhysics(), slivers: [_box(1200)]));

      await tester.pumpWidget(page(first));
      first.jumpTo(80);
      await tester.pumpWidget(page(second));

      expect(first.hasClients, isFalse);
      expect(second.hasClients, isTrue);
      expect(second.offset, 80);
    });

    testWidgets('控制器的初始偏移生效', (tester) async {
      final controller = ScrollController(initialScrollOffset: 150);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(ElScroll(controller: controller, physics: ClampingScrollPhysics(), slivers: [_box(1200)])),
      );
      expect(controller.offset, 150);
    });
  });
}
