import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ScrollController controller) => MaterialApp(
  home: Scaffold(
    body: ScrollConfiguration(
      behavior: ElScrollBehavior(),
      child: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: ElScroll.sliver(
            controller: controller,
            physics: ClampingScrollPhysics(),
            slivers: [SliverToBoxAdapter(child: SizedBox(height: 1800))],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('Android 官方 Scrollbar 绑定 ElScroll 的同一滚动位置', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(_app(controller));
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(CupertinoScrollbar), findsNothing);
    controller.jumpTo(300);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(300, .001));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows 复用 ElWindowScrollBar 并在首帧预留 gutter', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app(controller));
    expect(find.byKey(ValueKey('el-scrollbar-win-strip-vertical')), findsOneWidget);
    expect(find.byKey(ValueKey('el-scrollbar-thumb-vertical')), findsOneWidget);
    final viewport = find.byType(Viewport);
    expect(tester.getSize(viewport).width, closeTo(285, 0.01));
    expect(controller.position.viewportDimension, closeTo(400, 0.01));
    controller.jumpTo(400);
    await tester.pump();
    expect(controller.offset, closeTo(400, 0.01));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows 真实 thumb 拖动直接接管位置，松开后不会恢复旧目标', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    final thumb = find.byKey(ValueKey('el-scrollbar-thumb-vertical'));
    expect(thumb, findsOneWidget);
    final origin = tester.getCenter(thumb);
    final gesture = await tester.startGesture(origin, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveBy(Offset(0, 130));
    await tester.pump(Duration(milliseconds: 16));
    expect(controller.offset, greaterThan(100));
    final held = controller.offset;
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(held, 0.01));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows 步进按钮与轨道点击驱动真实 position', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    final strip = tester.getRect(find.byKey(ValueKey('el-scrollbar-win-strip-vertical')));
    await tester.tapAt(Offset(strip.center.dx, strip.bottom - 9));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0), reason: '末端步进按钮必须改变滚动位置');
    final afterButton = controller.offset;
    await tester.tapAt(Offset(strip.center.dx, strip.top + 240));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(afterButton), reason: '轨道点击不能只是外观效果');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS 官方 CupertinoScrollbar 绑定 ElScroll 的同一滚动位置', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_app(controller));
    expect(find.byType(CupertinoScrollbar), findsOneWidget);
    expect(find.byType(Scrollbar), findsNothing);
    controller.jumpTo(300);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(300, .001));
    debugDefaultTargetPlatformOverride = null;
  });
}
