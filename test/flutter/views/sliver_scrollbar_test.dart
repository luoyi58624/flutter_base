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

  testWidgets('Windows 复用原滚动条条带并首帧预留 gutter', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app(controller));
    expect(find.byType(ElDesktopScrollbar), findsOneWidget);
    expect(find.byType(Scrollbar), findsNothing);
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

  testWidgets('Windows 轨道按下直接跳转到目标位置，无需等待松手或渐显', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    final strip = tester.getRect(find.byKey(ValueKey('el-scrollbar-win-strip-vertical')));
    final pointer = await tester.startGesture(Offset(strip.center.dx, strip.top + 290), kind: PointerDeviceKind.mouse);
    expect(controller.offset, inExclusiveRange(900, 1350), reason: '轨道按下须定位到点击对应区间，不能只移动一页');
    final jumped = controller.offset;
    await pointer.moveBy(Offset(0, -65));
    await tester.pump();
    expect(controller.offset, lessThan(jumped - 100), reason: '轨道按下后应立即接着拖动滑块，不需要重新按下');
    await pointer.up();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows 端点步进按钮保持交互', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    final strip = tester.getRect(find.byKey(ValueKey('el-scrollbar-win-strip-vertical')));
    await tester.tapAt(Offset(strip.center.dx, strip.bottom - 9));
    await tester.pumpAndSettle();
    expect(controller.offset, inExclusiveRange(10, 60), reason: '点击按钮要滚一小步，而不是轨道位置跳转');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS 保留自定义悬浮条带，未显示时也能直接按轨道跳转', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    expect(find.byType(ElDesktopScrollbar), findsOneWidget);
    expect(find.byType(CupertinoScrollbar), findsNothing);
    expect(find.byKey(ValueKey('el-scrollbar-strip-vertical')), findsOneWidget);
    expect(tester.getSize(find.byType(Viewport)).width, closeTo(300, 0.01));
    final strip = tester.getRect(find.byKey(ValueKey('el-scrollbar-strip-vertical')));
    final pointer = await tester.startGesture(Offset(strip.center.dx, strip.top + 290), kind: PointerDeviceKind.mouse);
    expect(controller.offset, inExclusiveRange(900, 1350), reason: 'Mac 悬浮滑块未显示时，首击也须定位到轨道目标');
    await pointer.up();
    await tester.pumpAndSettle();
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
