import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/src/flutter/scroll/dual_axis_scroll.dart';
import 'package:flutter_base/src/flutter/scroll/viewport.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/support/scrollbar_thumb.dart';

class _Behavior extends ElScrollBehavior {
  const _Behavior(this.platform);
  final TargetPlatform platform;

  @override
  TargetPlatform getPlatform(BuildContext context) => platform;
}

Widget _app(
  ScrollController controller,
  TargetPlatform platform, {
  Axis axis = Axis.vertical,
  bool reverse = false,
  bool smooth = false,
}) {
  return MaterialApp(
    home: ScrollConfiguration(
      behavior: _Behavior(platform),
      child: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: ElScroll.sliver(
            controller: controller,
            smoothScroll: smooth ? ElWindowsSmoothScroll() : null,
            axis: axis,
            reverse: reverse,
            physics: ClampingScrollPhysics(),
            slivers: [SliverToBoxAdapter(child: SizedBox(width: 1800, height: 1800))],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform 保留官方移动滚动条并共享滚动位置', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, platform));
      expect(find.byType(platform == TargetPlatform.iOS ? CupertinoScrollbar : Scrollbar), findsOneWidget);
      expect(find.byType(ElDesktopScrollbar), findsNothing);
      controller.jumpTo(300);
      await tester.pumpAndSettle();
      expect(controller.offset, 300);
    });
  }

  for (final axis in Axis.values) {
    testWidgets('Windows $axis 首帧占位，滑块使用官方拖动', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, TargetPlatform.windows, axis: axis));
      expect(tester.getSize(find.byType(ElViewport)), axis == Axis.vertical ? Size(285, 400) : Size(300, 385));
      expect(find.byWidgetPredicate((widget) => widget is RawScrollbar), findsOneWidget);
      await tester.pumpAndSettle();
      final thumb = elThumbRect(tester, controller.position)!;
      final gesture = await tester.startGesture(thumb.center, kind: PointerDeviceKind.mouse);
      await gesture.moveBy(axis == Axis.vertical ? Offset(0, 100) : Offset(100, 0));
      await tester.pump();
      expect(controller.offset, greaterThan(100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
    for (final axis in Axis.values) {
      testWidgets('$platform $axis 滑块两侧细边界属于拖动区域', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(controller, platform, axis: axis));
        await tester.pumpAndSettle();
        for (final trailing in [false, true]) {
          controller.jumpTo(200);
          await tester.pump();
          await tester.pump(Duration(milliseconds: 300));
          final thumb = elThumbRect(tester, controller.position)!;
          final point = axis == Axis.vertical
              ? Offset(trailing ? thumb.right - 0.5 : thumb.left + 0.5, thumb.center.dy)
              : Offset(thumb.center.dx, trailing ? thumb.bottom - 0.5 : thumb.top + 0.5);
          final gesture = await tester.startGesture(point, kind: PointerDeviceKind.mouse);
          // 等过轨道点击识别时限，按住边界也不能触发翻页。
          await tester.pump(Duration(milliseconds: 150));
          expect(controller.offset, 200);
          await gesture.moveBy(axis == Axis.vertical ? Offset(0, 60) : Offset(60, 0));
          await tester.pump();
          expect(controller.offset, greaterThan(200), reason: '细边界必须能够拖动滑块');
          await gesture.up();
          await tester.pumpAndSettle();
        }
      });
    }
  }

  for (final axis in Axis.values) {
    for (final reverse in [false, true]) {
      testWidgets('Windows $axis reverse=$reverse 轨道按下立即定位到滑块中心', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(controller, TargetPlatform.windows, axis: axis, reverse: reverse));
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byType(ElDesktopScrollbar));
        final point = axis == Axis.vertical
            ? Offset(rect.right - 7.5, rect.top + 260)
            : Offset(rect.left + 200, rect.bottom - 7.5);
        final pointer = await tester.startGesture(point, kind: PointerDeviceKind.mouse);
        expect(controller.offset, greaterThan(controller.position.viewportDimension));
        final jumped = controller.offset;
        await tester.pump();
        final thumb = elThumbRect(tester, controller.position)!;
        expect(
          axis == Axis.vertical ? thumb.center.dy : thumb.center.dx,
          closeTo(axis == Axis.vertical ? point.dy : point.dx, 1),
        );
        await tester.pump(Duration(milliseconds: 200));
        expect(controller.offset, jumped, reason: '不能在直接定位后又执行官方轨道翻页');
        await pointer.up();
        await tester.pumpAndSettle();
      });
    }
  }

  for (final axis in Axis.values) {
    for (final reverse in [false, true]) {
      testWidgets('Windows $axis reverse=$reverse 轨道定位后同一指针立即继续拖动', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(controller, TargetPlatform.windows, axis: axis, reverse: reverse));
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byType(ElDesktopScrollbar));
        final origin = axis == Axis.vertical
            ? Offset(rect.right - 7.5, rect.top + 260)
            : Offset(rect.left + 200, rect.bottom - 7.5);
        final pointer = await tester.startGesture(origin, kind: PointerDeviceKind.mouse);
        final jumped = controller.offset;
        // 不抬手、不等下一帧，直接移动同一指针。
        await pointer.moveBy(axis == Axis.vertical ? Offset(0, -40) : Offset(-40, 0));
        await tester.pump();
        expect(reverse ? controller.offset > jumped : controller.offset < jumped, isTrue);
        final moved = controller.offset;
        await pointer.moveBy(axis == Axis.vertical ? Offset(0, 20) : Offset(20, 0));
        await tester.pump();
        expect(reverse ? controller.offset < moved : controller.offset > moved, isTrue);
        await pointer.cancel();
        await tester.pumpAndSettle();
        final stopped = controller.offset;
        await tester.pump(Duration(milliseconds: 500));
        expect(controller.offset, stopped);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('轨道转拖动后卸载，不遗留活动指针或滚动状态', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, TargetPlatform.windows));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(ElDesktopScrollbar));
    final pointer = await tester.startGesture(Offset(rect.right - 7.5, rect.top + 260), kind: PointerDeviceKind.mouse);
    await pointer.moveBy(Offset(0, -40));
    await tester.pump();
    await tester.pumpWidget(SizedBox());
    await pointer.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final axis in Axis.values) {
    testWidgets('Windows $axis 箭头点击步进、长按连续滚动、取消后停止', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, TargetPlatform.windows, axis: axis));
      await tester.pumpAndSettle();
      final forwardLabel = axis == Axis.vertical ? '向下滚动' : '向右滚动';
      final backwardLabel = axis == Axis.vertical ? '向上滚动' : '向左滚动';
      Finder button(String label) =>
          find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);
      expect(tester.getSize(button(forwardLabel)), axis == Axis.vertical ? Size(15, 18) : Size(18, 15));
      await tester.tap(button(forwardLabel));
      await tester.pumpAndSettle();
      expect(controller.offset, inInclusiveRange(16, 48));
      await tester.tap(button(backwardLabel));
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      final hold = await tester.startGesture(tester.getCenter(button(forwardLabel)), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.pump(Duration(milliseconds: 150));
      final singleStep = controller.offset;
      await tester.pump(Duration(milliseconds: 250));
      await tester.pump();
      var previous = controller.offset;
      final deltas = <double>[];
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(Duration(milliseconds: 16));
        deltas.add(controller.offset - previous);
        previous = controller.offset;
      }
      for (final delta in deltas) {
        expect(delta, greaterThan(0), reason: '每帧都应滚动，不能每 50ms 才跳一次');
        expect(delta, lessThan(singleStep));
        expect(delta, closeTo(deltas.first, .001), reason: '连续滚动速度不应忽快忽慢');
      }
      expect(controller.offset, greaterThan(singleStep * 2));
      await hold.cancel();
      await tester.pumpAndSettle();
      final stopped = controller.offset;
      await tester.pump(Duration(seconds: 1));
      expect(controller.offset, stopped);
      expect(tester.takeException(), isNull);
    });
  }

  for (final axis in Axis.values) {
    for (final region in ['track', 'thumb', 'arrow']) {
      testWidgets('Windows $axis $region 滚轮复用正文平滑动画且只消费一次', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(controller, TargetPlatform.windows, axis: axis, smooth: true));
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byType(ElDesktopScrollbar));
        final point = switch (region) {
          'thumb' => elThumbRect(tester, controller.position)!.center,
          'arrow' =>
            axis == Axis.vertical
                ? Offset(rect.right - 7.5, rect.bottom - 9)
                : Offset(rect.right - 9, rect.bottom - 7.5),
          _ =>
            axis == Axis.vertical
                ? Offset(rect.right - 7.5, rect.top + 250)
                : Offset(rect.left + 200, rect.bottom - 7.5),
        };
        await tester.sendEventToBinding(
          PointerScrollEvent(position: point, scrollDelta: axis == Axis.vertical ? Offset(0, 100) : Offset(100, 0)),
        );
        expect(controller.offset, 0, reason: '滚轮事件不能直接跳完');
        await tester.pump();
        await tester.pump(Duration(milliseconds: 16));
        final first = controller.offset;
        expect(first, inExclusiveRange(0, 100));
        await tester.pump(Duration(milliseconds: 16));
        expect(controller.offset, inExclusiveRange(first, 100));
        await tester.pumpAndSettle();
        expect(controller.offset, closeTo(100, .001), reason: '轨道和正文不能重复消费同一个滚轮事件');
      });
    }
  }

  testWidgets('箭头长按松手立即停止，卸载后不保留帧回调', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, TargetPlatform.windows));
    await tester.pumpAndSettle();
    final arrow = find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == '向下滚动');
    final hold = await tester.startGesture(tester.getCenter(arrow), kind: PointerDeviceKind.mouse);
    await tester.pump(Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 16));
    await hold.up();
    final stopped = controller.offset;
    await tester.pump(Duration(milliseconds: 100));
    expect(controller.offset, stopped);
    final next = await tester.startGesture(tester.getCenter(arrow), kind: PointerDeviceKind.mouse);
    await tester.pump(Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 16));
    await tester.pumpWidget(SizedBox());
    await next.cancel();
    await tester.pump(Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('反向列表滑块从末端拖向首端仍更新真实位置', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, TargetPlatform.windows, reverse: true));
    await tester.pumpAndSettle();
    final thumb = elThumbRect(tester, controller.position)!;
    final gesture = await tester.startGesture(thumb.center, kind: PointerDeviceKind.mouse);
    await gesture.moveBy(Offset(0, -100));
    await tester.pump();
    expect(controller.offset, greaterThan(100));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('macOS 滚动条悬浮，显示后可用官方滑块拖动', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, TargetPlatform.macOS));
    expect(tester.getSize(find.byType(ElViewport)), Size(300, 400));
    controller.jumpTo(200);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 300));
    final gesture = await tester.startGesture(
      elThumbRect(tester, controller.position)!.center,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(Offset(0, 80));
    await tester.pump();
    expect(controller.offset, greaterThan(200));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('包装官方 ListView 时可以共享 PrimaryScrollController', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PrimaryScrollController(
          controller: controller,
          child: ScrollConfiguration(
            behavior: ScrollBehavior().copyWith(scrollbars: false),
            child: ElDesktopScrollbar.windows(child: ListView(primary: true, children: [SizedBox(height: 3000)])),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      elThumbRect(tester, controller.position)!.center,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(Offset(0, 100));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Windows 双轴各占 15 像素且滚动通知不串轴', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ScrollConfiguration(
          behavior: _Behavior(TargetPlatform.windows),
          child: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: DualAxisScroll(
                horizontalController: horizontal,
                verticalController: vertical,
                contentWidth: (_) => 1000,
                slivers: [SliverToBoxAdapter(child: SizedBox(height: 1800))],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(horizontal.position.viewportDimension, 285);
    expect(vertical.position.viewportDimension, 385);
    for (final controller in [horizontal, vertical]) {
      final other = identical(controller, horizontal) ? vertical : horizontal;
      final before = other.offset;
      final gesture = await tester.startGesture(
        elThumbRect(tester, controller.position)!.center,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(identical(controller, horizontal) ? Offset(60, 0) : Offset(0, 60));
      await tester.pump();
      expect(controller.offset, greaterThan(0));
      expect(other.offset, before);
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });
}
