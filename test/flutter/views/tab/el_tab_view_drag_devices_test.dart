import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 哪些设备能拖着翻页。
///
/// 口径 = 与 ElScrollView 单源：默认跟随环境
/// `ScrollConfiguration.dragDevices`（官方 touch-like，**不含 mouse**），
/// widget 的 [ElTabView.dragDevices] 作覆写。曾经默认是 null=不过滤，鼠标能拖
/// 是漏出来的行为，且与滚动容器口径正好相反。
void main() {
  Future<ElTabController> pumpTabs(
    WidgetTester tester, {
    Set<PointerDeviceKind>? dragDevices,
    ScrollBehavior? behavior,
  }) async {
    final controller = ElTabController(length: 3);
    addTearDown(controller.dispose);
    Widget child = SizedBox(
      width: 400,
      height: 600,
      child: ElTabView(
        controller: controller,
        dragDevices: dragDevices,
        children: const [Text('p0'), Text('p1'), Text('p2')],
      ),
    );
    if (behavior != null) child = ScrollConfiguration(behavior: behavior, child: child);
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: child));
    return controller;
  }

  /// 用指定设备横拖并松手，返回 (拖拽中 position, 停靠后 position)。
  Future<(double, double)> dragWith(WidgetTester tester, ElTabController controller, PointerDeviceKind kind) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)), kind: kind);
    var stamp = Duration.zero;
    for (var i = 0; i < 10; i++) {
      stamp += const Duration(milliseconds: 8);
      await gesture.moveBy(const Offset(-30, 0), timeStamp: stamp);
      await tester.pump(const Duration(milliseconds: 8));
    }
    final held = controller.position;
    await gesture.up(timeStamp: stamp);
    await tester.pumpAndSettle();
    return (held, controller.position);
  }

  /// 触控板两指横扫（PointerPanZoom 通道，不是 down/move/up）。
  Future<(double, double)> panWith(
    WidgetTester tester,
    ElTabController controller, {
    double dx = -30,
    int steps = 10,
  }) async {
    final center = tester.getCenter(find.byType(ElTabView));
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    var stamp = Duration.zero;
    await tester.sendEventToBinding(pointer.panZoomStart(center, timeStamp: stamp));
    await tester.pump();
    var pan = Offset.zero;
    for (var i = 0; i < steps; i++) {
      stamp += const Duration(milliseconds: 8);
      pan += Offset(dx, 0);
      await tester.sendEventToBinding(pointer.panZoomUpdate(center, pan: pan, timeStamp: stamp));
      await tester.pump(const Duration(milliseconds: 8));
    }
    final held = controller.position;
    await tester.sendEventToBinding(pointer.panZoomEnd(timeStamp: stamp));
    await tester.pumpAndSettle();
    return (held, controller.position);
  }

  group('默认（跟随环境）', () {
    testWidgets('触摸可以拖着翻页', (tester) async {
      final controller = await pumpTabs(tester);
      final (held, settled) = await dragWith(tester, controller, PointerDeviceKind.touch);

      expect(held, greaterThan(0.0), reason: '触摸没能拖动');
      expect(settled, 1.0);
    });

    testWidgets('鼠标拖不动——与 ElScrollView 同口径', (tester) async {
      final controller = await pumpTabs(tester);
      final (held, settled) = await dragWith(tester, controller, PointerDeviceKind.mouse);

      expect(held, 0.0, reason: '默认不该让鼠标拖页（环境 dragDevices 不含 mouse）');
      expect(settled, 0.0);
    });

    testWidgets('触控板两指横扫可以拖着翻页（PointerPanZoom 通道）', (tester) async {
      final controller = await pumpTabs(tester);
      final (held, settled) = await panWith(tester, controller);

      expect(held, greaterThan(0.0), reason: '触控板 pan 没接进翻页');
      expect(settled, 1.0, reason: '触控板松手该停靠到下一页');
    });

    testWidgets('触控板反向横扫回到上一页', (tester) async {
      final controller = await pumpTabs(tester);
      await panWith(tester, controller);
      expect(controller.position, 1.0);

      final (_, settled) = await panWith(tester, controller, dx: 30);
      expect(settled, 0.0, reason: '反向 pan 没回到上一页');
    });

    testWidgets('触控板竖向 pan 不翻页', (tester) async {
      final controller = await pumpTabs(tester);
      final center = tester.getCenter(find.byType(ElTabView));
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      var stamp = Duration.zero;
      await tester.sendEventToBinding(pointer.panZoomStart(center, timeStamp: stamp));
      await tester.pump();
      var pan = Offset.zero;
      for (var i = 0; i < 10; i++) {
        stamp += const Duration(milliseconds: 8);
        pan += const Offset(0, -30);
        await tester.sendEventToBinding(pointer.panZoomUpdate(center, pan: pan, timeStamp: stamp));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await tester.sendEventToBinding(pointer.panZoomEnd(timeStamp: stamp));
      await tester.pumpAndSettle();

      expect(controller.position, 0.0, reason: '竖向 pan 不该翻页');
    });
  });

  group('覆写', () {
    testWidgets('widget 显式给 mouse → 桌面鼠标可拖', (tester) async {
      final controller = await pumpTabs(tester, dragDevices: {PointerDeviceKind.mouse});
      final (held, settled) = await dragWith(tester, controller, PointerDeviceKind.mouse);

      expect(held, greaterThan(0.0), reason: '显式允许 mouse 后仍拖不动');
      expect(settled, 1.0);
    });

    testWidgets('widget 显式只给 mouse → 触摸反而拖不动（集合是整体覆写）', (tester) async {
      final controller = await pumpTabs(tester, dragDevices: {PointerDeviceKind.mouse});
      final (held, _) = await dragWith(tester, controller, PointerDeviceKind.touch);

      expect(held, 0.0, reason: 'dragDevices 是整值覆写，不是并集');
    });

    testWidgets('环境 behavior 加 mouse → 无需逐个 widget 传', (tester) async {
      final controller = await pumpTabs(tester, behavior: const _MouseDraggableBehavior());
      final (held, settled) = await dragWith(tester, controller, PointerDeviceKind.mouse);

      expect(held, greaterThan(0.0), reason: '没读到环境 behavior 的 dragDevices');
      expect(settled, 1.0);
    });

    testWidgets('环境不含 trackpad → 触控板 pan 也不翻页', (tester) async {
      final controller = await pumpTabs(tester, dragDevices: {PointerDeviceKind.touch});
      final (held, settled) = await panWith(tester, controller);

      expect(held, 0.0, reason: 'dragDevices 排除 trackpad 后 pan 通道也该闭嘴');
      expect(settled, 0.0);
    });
  });
}

class _MouseDraggableBehavior extends ScrollBehavior {
  const _MouseDraggableBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {...super.dragDevices, PointerDeviceKind.mouse};
}
