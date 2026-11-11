import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

Widget _app(ScrollController controller, TargetPlatform platform, {Axis axis = Axis.vertical, bool reverse = false}) {
  return MaterialApp(
    home: ScrollConfiguration(
      behavior: _Behavior(platform),
      child: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: ElScroll.sliver(
            controller: controller,
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
      expect(find.byType(RawScrollbar), findsOneWidget);
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

  testWidgets('Windows 轨道点击采用官方翻页', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, TargetPlatform.windows));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(ElDesktopScrollbar));
    await tester.tapAt(Offset(rect.right - 7.5, rect.top + 300), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, lessThanOrEqualTo(controller.position.viewportDimension));
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
