import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  _windowsTest('Windows 默认滚轮按帧推进且只消费一次，正确回应平台事件', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    final replies = <bool>[];
    await _wheel(
      tester,
      fixture,
      delta: Offset(0, 120),
      onRespond: ({required allowPlatformDefault}) {
        replies.add(allowPlatformDefault);
      },
    );
    expect(fixture.controller.offset, 0, reason: '滚轮不能先被官方 Scrollable 同步滚动一遍');
    await _advance(tester);
    final first = fixture.controller.offset;
    expect(first, greaterThan(0));
    expect(first, lessThan(120));
    await tester.pump(Duration(milliseconds: 16));
    expect(fixture.controller.offset, greaterThan(first));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(fixture.controller.offset, closeTo(120, .01));
    expect(fixture.controller.position.isScrollingNotifier.value, isFalse);
    expect(replies, isNotEmpty);
    expect(replies.every((value) => !value), isTrue, reason: 'Web 宿主不能再把同一事件交给页面滚动');
    await _close(tester, fixture);
  });

  _windowsTest('Chromium 连续滚轮累积目标，反向输入抵消尚未走完的距离', (tester) async {
    final fixture = _Fixture(algorithm: ElChromiumSmoothScroll());
    await _open(tester, fixture);
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await _wheel(tester, fixture, delta: Offset(0, -60));
    expect(fixture.controller.offset, 0);
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(fixture.controller.offset, closeTo(180, .01));
    await _close(tester, fixture);
  });

  _windowsTest('环境算法可替换，关闭后的下一笔事件立即直滚并终止旧目标', (tester) async {
    final fixture = _Fixture(algorithm: ElWindowsSmoothScroll());
    await _open(tester, fixture);
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await _advance(tester);
    fixture.algorithm.value = ElNoSmoothScroll();
    await tester.pump();
    final before = fixture.controller.offset;
    await _wheel(tester, fixture, delta: Offset(0, 60));
    expect(fixture.controller.offset, closeTo(before + 60, .01));
    final direct = fixture.controller.offset;
    await tester.pump(Duration(milliseconds: 400));
    expect(fixture.controller.offset, closeTo(direct, .01));
    fixture.algorithm.value = ElChromiumSmoothScroll();
    await tester.pump();
    await _wheel(tester, fixture, delta: Offset(0, 120));
    expect(fixture.controller.offset, closeTo(direct, .01));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(fixture.controller.offset, closeTo(direct + 120, .01));
    await _close(tester, fixture);
  });

  _windowsTest('小增量触控板会话保持直滚，停顿后恢复鼠标滚轮平滑', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _wheel(tester, fixture, delta: Offset(0, 5));
    expect(fixture.controller.offset, closeTo(5, .01));
    await _wheel(tester, fixture, delta: Offset(0, 120));
    expect(fixture.controller.offset, closeTo(125, .01), reason: '同一触控板会话的大增量也不能二次平滑');
    await tester.pump(Duration(milliseconds: 100));
    await _wheel(tester, fixture, delta: Offset(0, 120));
    expect(fixture.controller.offset, closeTo(125, .01));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(fixture.controller.offset, closeTo(245, .01));
    await _close(tester, fixture);
  });

  _windowsTest('显式 trackpad 类型即使大增量也直接滚动', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _wheel(tester, fixture, delta: Offset(0, 120), kind: PointerDeviceKind.trackpad);
    expect(fixture.controller.offset, closeTo(120, .01));
    await tester.pump(Duration(milliseconds: 400));
    expect(fixture.controller.offset, closeTo(120, .01));
    await _close(tester, fixture);
  });

  _windowsTest('纵横布局、reverse 和 RTL 保留官方滚轮信号方向', (tester) async {
    for (final horizontal in [false, true]) {
      for (final reverse in [false, true]) {
        for (final rtl in horizontal ? [false, true] : [false]) {
          final fixture = _Fixture(horizontal: horizontal, reverse: reverse, rtl: rtl);
          await _open(tester, fixture);
          final reversed = horizontal ? rtl != reverse : reverse;
          final value = reversed ? -120.0 : 120.0;
          await _wheel(tester, fixture, delta: horizontal ? Offset(value, 0) : Offset(0, value));
          expect(fixture.controller.offset, 0);
          await tester.pumpAndSettle(Duration(milliseconds: 16));
          expect(fixture.controller.offset, closeTo(120, .01));
          await _close(tester, fixture);
        }
      }
    }
  });

  _windowsTest('Shift 对鼠标换轴，trackpad 保持原始方向', (tester) async {
    final fixture = _Fixture(horizontal: true);
    await _open(tester, fixture);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(fixture.controller.offset, closeTo(120, .01));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _wheel(tester, fixture, delta: Offset(0, 120), kind: PointerDeviceKind.trackpad);
    expect(fixture.controller.offset, closeTo(120, .01));
    await _wheel(tester, fixture, delta: Offset(120, 0), kind: PointerDeviceKind.trackpad);
    expect(fixture.controller.offset, closeTo(240, .01));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _close(tester, fixture);
  });

  _windowsTest('更深的官方列表先消费事件，到边缘后 RecyclerView 才平滑接管', (tester) async {
    final inner = ScrollController();
    final innerKey = GlobalKey();
    final fixture = _Fixture(
      firstChild: SizedBox(
        height: 300,
        child: Column(
          children: [
            SizedBox(
              key: innerKey,
              height: 160,
              child: ListView.builder(
                controller: inner,
                itemExtent: 24,
                itemCount: 100,
                itemBuilder: (context, index) => Text('inner $index'),
              ),
            ),
            SizedBox(height: 140),
          ],
        ),
      ),
    );
    await _open(tester, fixture);
    final point = tester.getCenter(find.byKey(innerKey));
    await _wheel(tester, fixture, delta: Offset(0, 120), point: point);
    expect(inner.offset, closeTo(120, .01));
    expect(fixture.controller.offset, 0);
    inner.jumpTo(inner.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await _wheel(tester, fixture, delta: Offset(0, 120), point: point);
    expect(fixture.controller.offset, 0);
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(fixture.controller.offset, closeTo(120, .01));
    expect(inner.offset, closeTo(inner.position.maxScrollExtent, .01));
    await _close(tester, fixture);
    inner.dispose();
  });

  _windowsTest('RecyclerView 已到边缘时放行给外层官方列表，不抢占事件', (tester) async {
    final outer = ScrollController();
    final fixture = _Fixture();
    await _open(
      tester,
      fixture,
      body: Align(
        alignment: .topLeft,
        child: SizedBox(
          width: 320,
          height: 400,
          child: ListView(controller: outer, children: [_Viewport(fixture), SizedBox(height: 800)]),
        ),
      ),
    );
    fixture.controller.jumpTo(fixture.controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await _wheel(tester, fixture, delta: Offset(0, 120));
    expect(outer.offset, closeTo(120, .01));
    expect(fixture.controller.offset, closeTo(fixture.controller.position.maxScrollExtent, .01));
    await tester.pump(Duration(milliseconds: 400));
    expect(outer.offset, closeTo(120, .01));
    await _close(tester, fixture);
    outer.dispose();
  });

  for (final command in ['scrollBy', 'scrollToPosition', 'stopScroll', 'fling', 'jumpTo', 'animateTo']) {
    _windowsTest('$command 接管后旧滚轮目标不会继续写入', (tester) async {
      final fixture = _Fixture();
      await _open(tester, fixture);
      fixture.controller.jumpTo(600);
      await tester.pumpAndSettle();
      await _wheel(tester, fixture, delta: Offset(0, 120));
      await _advance(tester);
      final before = fixture.controller.offset;
      expect(before, inExclusiveRange(600, 720));
      double? expected;
      switch (command) {
        case 'scrollBy':
          fixture.list.scrollBy(0, 96);
          expected = before + 96;
        case 'scrollToPosition':
          fixture.list.scrollToPosition(20);
          expected = 960;
        case 'stopScroll':
          fixture.list.stopScroll();
          expected = before;
        case 'fling':
          expect(fixture.list.fling(0, 1800), isTrue);
        case 'jumpTo':
          fixture.controller.jumpTo(1200);
          expected = 1200;
        case 'animateTo':
          unawaited(fixture.controller.animateTo(1200, duration: Duration(milliseconds: 100), curve: Curves.linear));
          expected = 1200;
      }
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      if (expected != null) {
        expect(fixture.controller.offset, closeTo(expected, .01));
      } else {
        expect(fixture.controller.offset, greaterThan(720), reason: '惯性应继续自己的轨迹，不能被旧滚轮拉回 720');
      }
      final settled = fixture.controller.offset;
      await tester.pump(Duration(milliseconds: 400));
      expect(fixture.controller.offset, closeTo(settled, .01));
      await _close(tester, fixture);
    });
  }

  _windowsTest('触摸按下会停止旧滚轮，持指期间不会继续漂移', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await _advance(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(fixture.viewportKey)));
    await tester.pump();
    final held = fixture.controller.offset;
    await tester.pump(Duration(milliseconds: 400));
    expect(fixture.controller.offset, closeTo(held, .01));
    await gesture.up();
    await tester.pumpAndSettle();
    await _close(tester, fixture);
  });

  _windowsTest('Cupertino 滑块拖动接管平滑活动且不被旧目标拉回', (tester) async {
    final fixture = _Fixture();
    await _open(
      tester,
      fixture,
      body: Align(
        alignment: .topLeft,
        child: SizedBox(
          width: 320,
          height: 240,
          child: CupertinoScrollbar(controller: fixture.controller, thumbVisibility: true, child: _Viewport(fixture)),
        ),
      ),
    );
    fixture.controller.jumpTo(1000);
    await tester.pumpAndSettle();
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await _advance(tester);
    final rect = tester.getRect(find.byType(CupertinoScrollbar));
    final fraction = fixture.controller.offset / fixture.controller.position.maxScrollExtent;
    final thumbCenter = Offset(rect.right - 4.5, rect.top + 3 + fraction * (rect.height - 6 - 36) + 18);
    final gesture = await tester.startGesture(thumbCenter);
    await tester.pump(Duration(milliseconds: 130));
    await gesture.moveBy(Offset(0, 50));
    await tester.pump(Duration(milliseconds: 16));
    final dragged = fixture.controller.offset;
    expect(dragged, greaterThan(1200));
    await tester.pump(Duration(milliseconds: 350));
    expect(fixture.controller.offset, closeTo(dragged, .01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fixture.controller.offset, closeTo(dragged, .01));
    await _close(tester, fixture);
  });

  _windowsTest('替换外部控制器时原活动终止，新控制器仍连接实际位置', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await _advance(tester);
    final previous = fixture.controller;
    fixture.replaceController(ScrollController(keepScrollOffset: false));
    await tester.pumpAndSettle();
    expect(previous.hasClients, isFalse);
    expect(fixture.controller.positions, hasLength(1));
    fixture.controller.jumpTo(720);
    await tester.pump(Duration(milliseconds: 400));
    expect(fixture.controller.offset, closeTo(720, .01));
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(fixture.controller.offset, closeTo(840, .01));
    await _close(tester, fixture);
  });

  _windowsTest('物理环境重建 position 时旧动画不能跨实例继续写入', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    final previous = fixture.controller.position;
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await _advance(tester);
    fixture.physics.value = BouncingScrollPhysics();
    await tester.pump();
    expect(fixture.controller.position, isNot(same(previous)), reason: '必须真实触发 Scrollable 的位置换绑');
    final current = fixture.controller.offset;
    await tester.pump(Duration(milliseconds: 400));
    expect(fixture.controller.offset, closeTo(current, .01));
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(fixture.controller.offset, closeTo(current + 120, .01));
    await _close(tester, fixture);
  });

  for (final command in ['jumpTo', 'animateTo']) {
    _windowsTest('ScrollStart 回调中的 $command 优先于刚开始的滚轮活动', (tester) async {
      final fixture = _Fixture();
      var replaced = false;
      await _open(
        tester,
        fixture,
        body: NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            if (!replaced && notification.depth == 0) {
              replaced = true;
              if (command == 'jumpTo') {
                fixture.controller.jumpTo(600);
              } else {
                unawaited(
                  fixture.controller.animateTo(600, duration: Duration(milliseconds: 100), curve: Curves.linear),
                );
              }
            }
            return false;
          },
          child: Align(alignment: .topLeft, child: _Viewport(fixture)),
        ),
      );
      await _wheel(tester, fixture, delta: Offset(0, 120));
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(replaced, isTrue);
      expect(fixture.controller.offset, closeTo(600, .01));
      await tester.pump(Duration(milliseconds: 400));
      expect(fixture.controller.offset, closeTo(600, .01));
      await _close(tester, fixture);
    });
  }

  _windowsTest('GlobalKey 跨父节点重挂保留 State 和像素位置，旧滚轮取消且新输入可恢复', (tester) async {
    final fixture = _Fixture();
    final onRight = ValueNotifier(false);
    await _open(
      tester,
      fixture,
      body: Align(
        alignment: .topLeft,
        child: ValueListenableBuilder<bool>(
          valueListenable: onRight,
          builder: (context, right, child) => Row(
            mainAxisSize: .min,
            children: [
              SizedBox(width: 320, height: 240, child: right ? SizedBox() : _Viewport(fixture)),
              SizedBox(width: 320, height: 240, child: right ? _Viewport(fixture) : SizedBox()),
            ],
          ),
        ),
      ),
    );
    fixture.controller.jumpTo(600);
    await tester.pumpAndSettle();
    final originalState = fixture.listKey.currentState;
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await _advance(tester);
    expect(fixture.controller.offset, inExclusiveRange(600, 720));
    final beforeReparent = fixture.controller.offset;

    onRight.value = true;
    await tester.pump();
    expect(fixture.listKey.currentState, same(originalState), reason: '必须实际重挂现有容器，不能销毁后新建替代');
    expect(fixture.controller.offset, closeTo(beforeReparent, .01), reason: 'SDK 可以重建并吸收 Position，但重挂不能改变实际像素位置');
    expect(fixture.controller.positions, hasLength(1));
    final reattached = fixture.controller.offset;
    await tester.pump(Duration(milliseconds: 400));
    expect(fixture.controller.offset, closeTo(reattached, .01), reason: '重新激活后不能恢复旧滚轮的未完成目标');
    expect(tester.takeException(), isNull);

    await _wheel(tester, fixture, delta: Offset(0, 120));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(fixture.controller.offset, closeTo(reattached + 120, .01));
    expect(fixture.controller.positions, hasLength(1));
    await _close(tester, fixture);
    onRight.dispose();
  });

  _windowsTest('卸载尚在执行的滚轮活动后不留下 ticker 或延迟位置写入', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _wheel(tester, fixture, delta: Offset(0, 120));
    await _advance(tester);
    await tester.pumpWidget(SizedBox());
    expect(fixture.controller.hasClients, isFalse);
    await tester.pump(Duration(milliseconds: 600));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
    fixture.dispose();
  });
}

void _windowsTest(String description, Future<void> Function(WidgetTester) callback) =>
    testWidgets(description, callback, variant: TargetPlatformVariant.only(TargetPlatform.windows));

class _Fixture {
  _Fixture({
    this.horizontal = false,
    this.reverse = false,
    this.rtl = false,
    ElSmoothScroll? algorithm,
    Widget? firstChild,
  }) : algorithm = ValueNotifier(algorithm),
       rows = _Rows(firstChild),
       controller = ScrollController(keepScrollOffset: false) {
    controllers.add(controller);
    layout = rv.LinearLayoutManager(null, horizontal ? rv.RecyclerView.HORIZONTAL : rv.RecyclerView.VERTICAL, reverse)
      ..setItemPrefetchEnabled(false);
    list = _createList();
    content = ValueNotifier<Widget>(list);
  }

  final bool horizontal;
  final bool reverse;
  final bool rtl;
  final viewportKey = GlobalKey();
  final listKey = GlobalKey();
  final ValueNotifier<ElSmoothScroll?> algorithm;
  final physics = ValueNotifier<ScrollPhysics>(ClampingScrollPhysics());
  final _Rows rows;
  final controllers = <ScrollController>{};
  ScrollController controller;
  late final rv.LinearLayoutManager layout;
  late final ValueNotifier<Widget> content;
  late rv.RecyclerView list;
  var inputMs = 1000;

  rv.RecyclerView _createList() => rv.RecyclerView(key: listKey, controller: controller)
    ..setLayoutManager(layout)
    ..setItemViewCacheSize(0)
    ..setAdapter(rows);

  void replaceController(ScrollController value) {
    controller = value;
    controllers.add(value);
    content.value = list = _createList();
  }

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    algorithm.dispose();
    physics.dispose();
    content.dispose();
  }
}

class _Viewport extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Viewport(this.fixture);
  final _Fixture fixture;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: fixture.viewportKey,
    width: 320,
    height: 240,
    child: ValueListenableBuilder<Widget>(valueListenable: fixture.content, builder: (context, child, _) => child),
  );
}

Future<void> _open(WidgetTester tester, _Fixture fixture, {Widget? body}) async {
  await tester.pumpWidget(
    ValueListenableBuilder<ElSmoothScroll?>(
      valueListenable: fixture.algorithm,
      builder: (context, algorithm, child) => ElViewProvider(smoothScrollBuilder: (_) => algorithm, child: child!),
      child: MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: fixture.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: ValueListenableBuilder<ScrollPhysics>(
              valueListenable: fixture.physics,
              builder: (context, physics, child) => ScrollConfiguration(behavior: _Behavior(physics), child: child!),
              child: body ?? Align(alignment: .topLeft, child: _Viewport(fixture)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _wheel(
  WidgetTester tester,
  _Fixture fixture, {
  required Offset delta,
  Offset? point,
  PointerDeviceKind kind = PointerDeviceKind.mouse,
  RespondPointerEventCallback? onRespond,
}) async {
  fixture.inputMs += 30;
  await tester.sendEventToBinding(
    PointerScrollEvent(
      kind: kind,
      position: point ?? tester.getCenter(find.byKey(fixture.viewportKey)),
      scrollDelta: delta,
      timeStamp: Duration(milliseconds: fixture.inputMs),
      onRespond: onRespond,
    ),
  );
}

Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: 16));
}

Future<void> _close(WidgetTester tester, _Fixture fixture) async {
  await tester.pumpWidget(SizedBox());
  await tester.pump(Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
  fixture.dispose();
}

class _Behavior extends MaterialScrollBehavior {
  _Behavior(this.physics);
  final ScrollPhysics physics;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => physics;
  @override
  bool shouldNotify(covariant _Behavior oldDelegate) => physics != oldDelegate.physics;
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class _Rows extends rv.Adapter<_Holder> {
  _Rows(this.firstChild);
  final Widget? firstChild;
  @override
  int getItemCount() => 100;
  @override
  int getItemViewType(int position) => position == 0 && firstChild != null ? 1 : 0;
  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) =>
      viewType == 1 ? _Holder.fixed(firstChild!) : _Holder.row();
  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) =>
      holder.model?.value = position;
}

class _Holder extends rv.ViewHolder {
  _Holder.fixed(super.itemView) : model = null;
  _Holder.row() : this._(ValueNotifier<int>(-1));
  _Holder._(this.model)
    : super(
        SizedBox(
          width: 48,
          height: 48,
          child: ValueListenableBuilder<int>(
            valueListenable: model!,
            builder: (context, value, child) => Text('row $value'),
          ),
        ),
      );
  final ValueNotifier<int>? model;
}
