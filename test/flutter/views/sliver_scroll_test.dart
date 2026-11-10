import 'dart:math' as math;

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
  ElScroll.sliver(
    controller: outer,
    physics: outerPhysics ?? ClampingScrollPhysics(),
    slivers: [
      _box(200),
      _box(
        300,
        child: ElScroll.sliver(
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

// 每笔 moveBy 都产生更新；同样的事件在官方 CustomScrollView 下也会消费第一笔 30px。
Future<TestGesture> _drag(WidgetTester tester, List<double> steps, {Axis axis = Axis.vertical, Finder? on}) async {
  final gesture = await tester.startGesture(tester.getCenter(on ?? find.byKey(_innerKey)));
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

// 行程 50 的折叠头：手指上推先收起，正文回到顶部后的下拉余量再展开。
class _Header extends ElNestedScrollParent {
  double collapsed = 0;
  double? releaseVelocity;
  final log = <String>[];

  @override
  void onNestedScrollStart(Axis axis, ElScrollDeltaSource source) => log.add('start');

  @override
  double onNestedPreScroll(double delta, ElScrollDeltaSource source) {
    if (delta >= 0) return 0;
    final taken = math.min(-delta, 50 - collapsed);
    collapsed += taken;
    return -taken;
  }

  @override
  double onNestedPostScroll(double unconsumed, ElScrollDeltaSource source) {
    if (unconsumed <= 0) return 0;
    final taken = math.min(unconsumed, collapsed);
    collapsed -= taken;
    return taken;
  }

  @override
  double onNestedPreFling(double velocity) {
    log.add('fling');
    releaseVelocity = velocity;
    return velocity;
  }

  @override
  void onNestedScrollEnd() => log.add('end');
}

// 视口 400、可滚 800 的单层滚动，外面包一个折叠头协作方。
Widget _withHeader(_Header header, ScrollController controller) => _app(
  ElNestedScroll(
    parent: header,
    child: ElScroll.sliver(controller: controller, physics: ClampingScrollPhysics(), slivers: [_box(1200)]),
  ),
);

void main() {
  group('官方滚动基线', () {
    testWidgets('官方 CustomScrollView 对同一组拖拽事件的起始位移', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(_app(CustomScrollView(controller: controller, physics: ClampingScrollPhysics(), slivers: [_box(1200)])));
      final gesture = await _drag(tester, [-30, -20, -20], on: find.byType(CustomScrollView));
      expect(controller.offset, closeTo(70, 0.01));
      await _release(tester, gesture);
    });
  });

  group('默认构造', () {
    testWidgets('直接排列 children，撑满交叉轴并应用内边距与间距', (tester) async {
      final controller = _controller();
      final first = ValueKey('first');
      final second = ValueKey('second');
      await tester.pumpWidget(
        _app(
          ElScroll(
            controller: controller,
            physics: ClampingScrollPhysics(),
            padding: EdgeInsets.all(10),
            gap: 20,
            children: [
              SizedBox(key: first, height: 300),
              SizedBox(key: second, height: 300),
              SizedBox(height: 300),
            ],
          ),
        ),
      );

      expect(tester.getSize(find.byKey(first)).width, 280);
      expect(tester.getTopLeft(find.byKey(second)).dy - tester.getBottomLeft(find.byKey(first)).dy, 20);
      // 内容总长 10 + 300 + 20 + 300 + 20 + 300 + 10，视口 400。
      expect(controller.position.maxScrollExtent, 560);

      final gesture = await _drag(tester, [-30, -20, -20], on: find.byType(ElScroll));
      expect(controller.offset, closeTo(70, 0.01));
      await _release(tester, gesture);
    });
  });

  group('协作方', () {
    testWidgets('拖动先由协作方消费，余量进入正文', (tester) async {
      final header = _Header();
      final controller = _controller();
      await tester.pumpWidget(_withHeader(header, controller));

      final gesture = await _drag(tester, [-30, -20, -20, -20], on: find.byType(ElScroll));
      expect(header.collapsed, 50);
      expect(controller.offset, closeTo(40, 0.01));
      await _release(tester, gesture);
    });

    testWidgets('正文到边界后的余量交给协作方', (tester) async {
      final header = _Header()..collapsed = 50;
      final controller = _controller();
      await tester.pumpWidget(_withHeader(header, controller));
      controller.jumpTo(30);
      await tester.pump();

      final gesture = await _drag(tester, [30, 20, 20, 20], on: find.byType(ElScroll));
      expect(controller.offset, 0);
      expect(header.collapsed, closeTo(0, 0.01));
      await _release(tester, gesture);
    });

    testWidgets('开始、松手速度、结束依次通知，慢拖松手也交接', (tester) async {
      final header = _Header();
      final controller = _controller();
      await tester.pumpWidget(_withHeader(header, controller));

      final gesture = await _drag(tester, [-30, -20], on: find.byType(ElScroll));
      expect(header.log, ['start']);
      await _release(tester, gesture);
      expect(header.log, ['start', 'fling', 'end']);
      expect(header.releaseVelocity, isNotNull);
    });

    testWidgets('惯性位移继续先经过协作方', (tester) async {
      final header = _Header();
      final controller = _controller();
      await tester.pumpWidget(_withHeader(header, controller));

      // 真实采样的短甩：前段小于 50px，必须由释放后继续运行的惯性补足。
      final drag = await tester.startGesture(tester.getCenter(find.byType(ElScroll)));
      for (var i = 1; i <= 6; i++) {
        await drag.moveBy(Offset(0, -7), timeStamp: Duration(milliseconds: i * 6));
        await tester.pump(Duration(milliseconds: 6));
      }
      expect(header.collapsed, lessThan(50));
      await drag.up(timeStamp: Duration(milliseconds: 40));
      await tester.pump();
      expect(header.releaseVelocity, lessThan(0), reason: '短甩释放时应该传递真实速度');
      await tester.pumpAndSettle();

      expect(header.releaseVelocity, lessThan(0), reason: '协作方收到的是手指方向的速度');
      expect(header.collapsed, closeTo(50, 0.001));
      expect(controller.offset, greaterThan(0), reason: '协作方收满后惯性继续推动正文');
      expect(header.log, ['start', 'fling', 'end']);
    });

    testWidgets('正文已经在顶部时，向下短甩仍可用同一次惯性展开页头', (tester) async {
      final header = _Header()..collapsed = 50;
      final controller = _controller();
      await tester.pumpWidget(_withHeader(header, controller));
      final drag = await tester.startGesture(tester.getCenter(find.byType(ElScroll)));
      for (var i = 1; i <= 6; i++) {
        await drag.moveBy(Offset(0, 7), timeStamp: Duration(milliseconds: i * 6));
        await tester.pump(Duration(milliseconds: 6));
      }
      expect(header.collapsed, inExclusiveRange(0, 50));
      expect(controller.offset, 0);
      await drag.up(timeStamp: Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(header.releaseVelocity, greaterThan(0));
      expect(header.collapsed, closeTo(0, 0.001));
      expect(controller.offset, 0);
    });

    testWidgets('页头惯性运行中执行 jumpTo 必须接管活动，旧弹道不得回写正文', (tester) async {
      final header = _Header();
      final controller = _controller();
      await tester.pumpWidget(_withHeader(header, controller));
      final drag = await tester.startGesture(tester.getCenter(find.byType(ElScroll)));
      for (var i = 1; i <= 6; i++) {
        await drag.moveBy(Offset(0, -7), timeStamp: Duration(milliseconds: i * 6));
        await tester.pump(Duration(milliseconds: 6));
      }
      await drag.up(timeStamp: Duration(milliseconds: 40));
      await tester.pump(Duration(milliseconds: 16));
      controller.jumpTo(200);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(200, 0.001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('内层把手势交给外层后，内外层之间的协作方不参与', (tester) async {
      final header = _Header();
      final outer = _controller();
      final inner = _controller();
      await tester.pumpWidget(
        _app(
          ElScroll.sliver(
            controller: outer,
            physics: ClampingScrollPhysics(),
            slivers: [
              _box(200),
              _box(
                300,
                child: ElNestedScroll(
                  parent: header,
                  child: ElScroll.sliver(
                    key: _innerKey,
                    controller: inner,
                    physics: ClampingScrollPhysics(),
                    slivers: [_box(900)],
                  ),
                ),
              ),
              _box(1200),
            ],
          ),
        ),
      );
      outer.jumpTo(120);
      inner.jumpTo(inner.position.maxScrollExtent);
      await tester.pump();

      final gesture = await _drag(tester, [-30, -20, -20]);
      expect(outer.offset, closeTo(160, 0.01));
      expect(header.log, isEmpty);
      expect(header.collapsed, 0);
      await _release(tester, gesture);
    });
  });

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
          ElScroll.sliver(
            controller: outer,
            axis: Axis.horizontal,
            physics: ClampingScrollPhysics(),
            slivers: [
              _box(
                300,
                axis: Axis.horizontal,
                child: ElScroll.sliver(
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
      ElScroll.sliver(
        controller: outer,
        physics: ClampingScrollPhysics(),
        slivers: [
          _box(100),
          _box(
            350,
            child: ElScroll.sliver(
              controller: middle,
              physics: ClampingScrollPhysics(),
              slivers: [
                _box(600),
                _box(
                  300,
                  child: ElScroll.sliver(
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
          _app(ElScroll.sliver(controller: controller, physics: ClampingScrollPhysics(), slivers: [_box(1200)]));

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
        _app(ElScroll.sliver(controller: controller, physics: ClampingScrollPhysics(), slivers: [_box(1200)])),
      );
      expect(controller.offset, 150);
    });
  });
}
