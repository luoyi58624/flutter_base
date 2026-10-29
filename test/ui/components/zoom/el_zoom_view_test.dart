// ElZoomView 判别测试：捏合缩放数学（焦点锚定 + 跨度比）/ min-max 钳制 /
// 双击缩放切换 / 与祖先滚动的手势归属边界 / 松手惯性 / 触控板捏合。
import 'dart:math' as math;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  Future<void> pumpZoom(
    WidgetTester tester, {
    double minScale = 1.0,
    double maxScale = 4.0,
    double doubleTapScale = 2.0,
    double scaleSensitivity = 1.0,
    ElZoomController? controller,
    bool panInertia = true,
    bool scaleInertia = false,
    bool enableRotation = false,
    bool mouseWheelZoom = false,
    bool mouseDragPan = true,
    double wheelScaleSensitivity = 0.002,
    ElEvent? ancestorEvent,
  }) {
    final zoom = SizedBox(
      width: 400,
      height: 400,
      child: ElZoomView(
        controller: controller,
        minScale: minScale,
        maxScale: maxScale,
        doubleTapScale: doubleTapScale,
        scaleSensitivity: scaleSensitivity,
        panInertia: panInertia,
        scaleInertia: scaleInertia,
        enableRotation: enableRotation,
        mouseWheelZoom: mouseWheelZoom,
        mouseDragPan: mouseDragPan,
        wheelScaleSensitivity: wheelScaleSensitivity,
        child: const SizedBox.expand(),
      ),
    );
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ancestorEvent == null
              ? zoom
              : ElView(style: const ElStyle(width: 400, height: 400), event: ancestorEvent, child: zoom),
        ),
      ),
    );
  }

  // 变换已从 Transform widget 下沉到自定义 render 的 paint 变换：从内容
  // render 到宿主 render 的真实几何（applyPaintTransform）取矩阵做断言。
  Matrix4 matrixOf(WidgetTester tester) {
    final content = tester.renderObject<RenderBox>(
      find.descendant(of: find.byType(ElZoomView), matching: find.byType(SizedBox)),
    );
    final host = tester.renderObject<RenderBox>(find.byType(ElZoomView));
    return content.getTransformTo(host);
  }

  double scaleOf(WidgetTester tester) => matrixOf(tester).storage[0];

  Offset translationOf(WidgetTester tester) {
    final translation = matrixOf(tester).getTranslation();
    return Offset(translation.x, translation.y);
  }

  testWidgets('ZOOM-1: 双指捏合 scale 等于跨度比，焦点锚定 + 焦点平移记账', (tester) async {
    await pumpZoom(tester);

    final g1 = await tester.createGesture();
    final g2 = await tester.createGesture();
    await g1.down(const Offset(100, 200));
    await g2.down(const Offset(200, 200));
    // span 50 → 80（Δ30 越过 scale slop）：起步帧，重定基线 span=80。
    await g2.moveTo(const Offset(260, 200));
    // span 100：scale = 100/80 = 1.25；焦点 (180,200) → (200,200)。
    // 上一帧焦点 (180,200) 下的内容点随本帧焦点移动到 (200,200)：
    // dx = 200 - 200 - (180 - 200) * 1.25 = 25，矩阵平移 = 25 - 50 = -25。
    await g2.moveTo(const Offset(300, 200));
    await tester.pump();

    expect(scaleOf(tester), closeTo(1.25, 1e-9));
    final translation = translationOf(tester);
    expect(translation.dx, closeTo(-25, 1e-6));
    expect(translation.dy, closeTo(-50, 1e-6));

    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('ZOOM-1A: scaleSensitivity 在对数域放大双指指距比例', (tester) async {
    await pumpZoom(tester, scaleSensitivity: 2);
    final first = await tester.createGesture();
    final second = await tester.createGesture();
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);

    await first.down(const Offset(100, 200));
    await second.down(const Offset(200, 200));
    await second.moveTo(const Offset(260, 200));
    await second.moveTo(const Offset(300, 200));
    await tester.pump();

    expect(scaleOf(tester), closeTo(math.pow(1.25, 2), 1e-9));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets('ZOOM-2: 捏合放大止步 maxScale', (tester) async {
    await pumpZoom(tester, maxScale: 1.2);

    final g1 = await tester.createGesture();
    final g2 = await tester.createGesture();
    await g1.down(const Offset(100, 200));
    await g2.down(const Offset(200, 200));
    await g2.moveTo(const Offset(260, 200));
    await g2.moveTo(const Offset(340, 200)); // 跨度比 1.5，应被钳到 1.2
    await tester.pump();

    expect(scaleOf(tester), closeTo(1.2, 1e-9));

    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('ZOOM-3: 双击在 minScale 与 doubleTapScale 间切换并围绕点击位置锚定', (tester) async {
    await pumpZoom(tester);
    const tapPosition = Offset(100, 100);

    final first = await tester.createGesture(pointer: 31, kind: PointerDeviceKind.touch);
    await first.down(tapPosition);
    await first.up();
    await tester.pump(const Duration(milliseconds: 50));
    final second = await tester.createGesture(pointer: 32, kind: PointerDeviceKind.touch);
    await second.down(tapPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(scaleOf(tester), greaterThan(1), reason: '双击缩放必须从第二次 PointerDown 立即开始，不能等待 PointerUp');
    await second.up();
    await tester.pumpAndSettle();

    expect(scaleOf(tester), closeTo(2.0, 1e-9));
    // 点击点锚定：offset = focal - focal*2 = (-100,-100)。
    expect(translationOf(tester).dx, closeTo(-100, 1e-6));
    expect(translationOf(tester).dy, closeTo(-100, 1e-6));

    final third = await tester.createGesture(pointer: 33, kind: PointerDeviceKind.mouse);
    await third.down(tapPosition);
    await third.up();
    await tester.pump(const Duration(milliseconds: 50));
    final fourth = await tester.createGesture(pointer: 34, kind: PointerDeviceKind.mouse);
    await fourth.down(tapPosition);
    await tester.pump();
    await fourth.up();
    await tester.pumpAndSettle();

    expect(scaleOf(tester), closeTo(1.0, 1e-9));
    expect(translationOf(tester), Offset.zero);
  });

  testWidgets('ZOOM-3A: 缩放动画未结束时连续四次触摸按下仍触发两组双击', (tester) async {
    await pumpZoom(tester);
    const tapPosition = Offset(100, 100);

    final first = await tester.createGesture(pointer: 41);
    await first.down(tapPosition);
    await first.up();
    await tester.pump(const Duration(milliseconds: 40));

    final second = await tester.createGesture(pointer: 42);
    await second.down(tapPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(scaleOf(tester), greaterThan(1));
    await second.up();

    final third = await tester.createGesture(pointer: 43);
    await third.down(tapPosition);
    await third.up();
    await tester.pump(const Duration(milliseconds: 40));
    final scaleBeforeFourthDown = scaleOf(tester);
    expect(scaleBeforeFourthDown, greaterThan(1));

    final fourth = await tester.createGesture(pointer: 44);
    await fourth.down(tapPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(scaleOf(tester), lessThan(scaleBeforeFourthDown), reason: '第 4 次按下必须立即触发第二组双击并开始缩回');
    await fourth.up();
    await tester.pumpAndSettle();

    expect(scaleOf(tester), closeTo(1, 1e-9));
  });

  testWidgets('ZOOM-3B: 同一鼠标 pointer 连续四次按下触发两组双击', (tester) async {
    await pumpZoom(tester);
    const tapPosition = Offset(100, 100);
    final mouse = await tester.createGesture(pointer: 51, kind: PointerDeviceKind.mouse);

    await mouse.down(tapPosition);
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 40));
    await mouse.down(tapPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(scaleOf(tester), greaterThan(1));
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 20));

    await mouse.down(tapPosition);
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 40));
    final scaleBeforeFourthDown = scaleOf(tester);
    await mouse.down(tapPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(scaleOf(tester), lessThan(scaleBeforeFourthDown), reason: '复用 pointer id 时第 4 次按下也必须立即触发第二组双击');
    await mouse.up();
    await tester.pumpAndSettle();

    expect(scaleOf(tester), closeTo(1, 1e-9));
  });

  testWidgets('ZOOM-4: 嵌套滚动的手势归属——未缩放单指让滚动，双指捏合独占', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 400,
            child: ElScrollView(
              controller: controller,
              children: [
                SizedBox(width: 400, height: 400, child: ElZoomView(child: const SizedBox.expand())),
                const SizedBox(width: 400, height: 1200),
              ],
            ),
          ),
        ),
      ),
    );

    // —— 未缩放单指上滑：滚动消费，缩放视图不动。
    final drag = await tester.startGesture(const Offset(200, 300));
    await drag.moveBy(const Offset(0, -60));
    await drag.moveBy(const Offset(0, -60));
    await drag.up();
    await tester.pump();
    expect(controller.offset, greaterThan(20), reason: '未缩放时单指拖拽必须让给祖先滚动');
    expect(scaleOf(tester), closeTo(1.0, 1e-9));
    expect(translationOf(tester), Offset.zero);
    await tester.pumpAndSettle();

    controller.jumpTo(0);
    await tester.pump();

    // —— 双指纵向撑开：捏合独占，滚动纹丝不动。
    final g1 = await tester.createGesture();
    final g2 = await tester.createGesture();
    await g1.down(const Offset(200, 100));
    await g2.down(const Offset(200, 200));
    await g2.moveTo(const Offset(200, 280));
    await g2.moveTo(const Offset(200, 320));
    await tester.pump();

    expect(scaleOf(tester), greaterThan(1.0));
    expect(controller.offset, 0, reason: '双指捏合成立后滚动不得并行消费');

    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('ZOOM-5: 已缩放单指平移，松手快甩产生惯性滑行', (tester) async {
    await pumpZoom(tester);

    // 双击放大到 2.0（内容 800，可平移区间 [-400, 0]）。
    await tester.tapAt(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    expect(scaleOf(tester), closeTo(2.0, 1e-9));

    // 已缩放单指快甩向左（-40px/16ms = 2500 px/s）。
    final gesture = await tester.createGesture();
    var t = Duration.zero;
    await gesture.down(const Offset(300, 200), timeStamp: t);
    for (var i = 0; i < 4; i++) {
      t += const Duration(milliseconds: 16);
      await gesture.moveBy(const Offset(-40, 0), timeStamp: t);
    }
    t += const Duration(milliseconds: 8);
    await gesture.up(timeStamp: t);
    await tester.pump();
    final releaseDx = translationOf(tester).dx;
    expect(releaseDx, lessThan(-100), reason: '前置：平移已随手指推进');

    // 惯性首帧必须接住约 2500px/s 的末速，随后逐帧自然衰减。
    await tester.pump(const Duration(milliseconds: 16));
    final firstInertiaDx = translationOf(tester).dx;
    await tester.pump(const Duration(milliseconds: 16));
    final secondInertiaDx = translationOf(tester).dx;
    final firstStep = firstInertiaDx - releaseDx;
    final secondStep = secondInertiaDx - firstInertiaDx;
    expect(firstStep, lessThan(-30), reason: '离手首帧不得把 2500px/s 末速硬刹成缓慢 ease');
    expect(secondStep, inExclusiveRange(firstStep, 0), reason: '摩擦速度应连续且逐帧衰减');
    await tester.pumpAndSettle();
  });

  testWidgets('ZOOM-5A: 惯性逐轴归界，撞边横轴不得压慢仍可移动的纵轴', (tester) async {
    final controller = ElZoomController(initialValue: const ElZoomTransform(scale: 2, offset: Offset(-200, 0)));
    addTearDown(controller.dispose);
    await pumpZoom(tester, controller: controller);

    final gesture = await tester.createGesture(pointer: 43);
    var elapsed = Duration.zero;
    await gesture.down(const Offset(200, 200), timeStamp: elapsed);
    for (var i = 0; i < 4; i++) {
      elapsed += const Duration(milliseconds: 16);
      await gesture.moveBy(const Offset(-40, 10), timeStamp: elapsed);
    }
    elapsed += const Duration(milliseconds: 8);
    await gesture.up(timeStamp: elapsed);
    await tester.pump();
    final released = controller.value.offset;
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.value.offset.dx, closeTo(-200, 1e-6));
    expect(controller.value.offset.dy, greaterThan(released.dy + 6), reason: '横轴撞边时纵轴仍须接住自身末速');
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('ZOOM-7: 已缩放后嵌套滚动里单指平移——缩放视图消费，滚动纹丝不动', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 400,
            child: ElScrollView(
              controller: controller,
              children: [
                SizedBox(width: 400, height: 400, child: ElZoomView(child: const SizedBox.expand())),
                const SizedBox(width: 400, height: 1200),
              ],
            ),
          ),
        ),
      ),
    );

    // 双击放大到 2.0。
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();
    expect(scaleOf(tester), closeTo(2.0, 1e-9));
    final baseDy = translationOf(tester).dy;

    // 已缩放单指**慢速**上滑（20px/步）：缩放视图 8px 阈先越先 eager；
    // 外层滚动 18px（真机 8-9）本会在第一步就抢走手势——判别修复前
    // "慢速平移被滚动窃取"的真机缺陷。
    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -20));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.offset, 0, reason: '已缩放单指平移必须由缩放视图独占，滚动不得并行消费');
    expect(translationOf(tester).dy, lessThan(baseDy - 90), reason: '内容必须随单指平移（起手帧 seed=0 丢弃后 5 步全额记账）');
  });

  testWidgets('ZOOM-8: 已缩放单指平移的起手阈值是 hit slop（18），不是 scale 机的 pan slop（36）', (tester) async {
    await pumpZoom(tester);

    await tester.tapAt(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    expect(scaleOf(tester), closeTo(2.0, 1e-9));
    final baseDx = translationOf(tester).dx; // -100

    // 总位移 34px < pan slop(36)：旧实现（纯 scale 焦点通道）完全不动；
    // drag 通道 24px 越过 hit slop(18) 接受（seed=0 起手帧丢弃），第二段
    // 10px 全额平移。
    final gesture = await tester.createGesture();
    await gesture.down(const Offset(300, 200));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    expect(translationOf(tester).dx, closeTo(baseDx - 10, 1e-6));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('ZOOM-9: log-scale inertia 首速连续、乘法衰减并保持焦点锚定', (tester) async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    await pumpZoom(tester, controller: controller, panInertia: false, scaleInertia: true);

    final first = await tester.createGesture(pointer: 41);
    final second = await tester.createGesture(pointer: 42);
    await first.down(const Offset(100, 200), timeStamp: Duration.zero);
    await second.down(const Offset(200, 200), timeStamp: Duration.zero);
    await second.moveTo(const Offset(240, 200), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(245, 200), timeStamp: const Duration(milliseconds: 32));
    final previousScale = controller.value.scale;
    await second.moveTo(const Offset(250, 200), timeStamp: const Duration(milliseconds: 48));
    await tester.pump();

    const focal = Offset(175, 200);
    final inverse = Matrix4.copy(matrixOf(tester))..invert();
    final anchoredContentPoint = MatrixUtils.transformPoint(inverse, focal);
    final releasedScale = controller.value.scale;
    final releasedLogVelocity = math.log(releasedScale / previousScale) / 0.016;
    final scales = <double>[releasedScale];
    await first.up(timeStamp: const Duration(milliseconds: 56));
    await second.moveTo(const Offset(250, 200), timeStamp: const Duration(milliseconds: 60));
    await second.up(timeStamp: const Duration(milliseconds: 64));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      scales.add(controller.value.scale);
      final projected = MatrixUtils.transformPoint(matrixOf(tester), anchoredContentPoint);
      expect(projected.dx, closeTo(focal.dx, 1e-5));
      expect(projected.dy, closeTo(focal.dy, 1e-5));
    }

    final logSteps = <double>[for (var i = 1; i < scales.length; i++) math.log(scales[i] / scales[i - 1])];
    expect(logSteps.every((step) => step > 0), isTrue);
    expect(logSteps.first / (releasedLogVelocity * 0.016), inInclusiveRange(0.8, 1.05));
    expect(logSteps[2], lessThan(logSteps[1]));
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      controller.value.scale,
      inExclusiveRange(releasedScale * 1.25, 2),
      reason: 'frames=$scales, released=$releasedScale, velocity=$releasedLogVelocity',
    );
  });

  testWidgets('ZOOM-10: 普通 ElZoomView 默认关闭 scale inertia', (tester) async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    await pumpZoom(tester, controller: controller, panInertia: false);

    final first = await tester.createGesture(pointer: 51);
    final second = await tester.createGesture(pointer: 52);
    await first.down(const Offset(100, 200), timeStamp: Duration.zero);
    await second.down(const Offset(200, 200), timeStamp: Duration.zero);
    await second.moveTo(const Offset(260, 200), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(300, 200), timeStamp: const Duration(milliseconds: 32));
    await second.moveTo(const Offset(340, 200), timeStamp: const Duration(milliseconds: 48));
    await tester.pump();
    final releasedScale = controller.value.scale;
    await first.up(timeStamp: const Duration(milliseconds: 56));
    await second.up(timeStamp: const Duration(milliseconds: 64));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    expect(controller.value.scale, releasedScale);
  });

  testWidgets('ZOOM-11: 负 log-scale velocity 继续缩小并 hard clamp 到 min', (tester) async {
    final controller = ElZoomController(initialValue: const ElZoomTransform(scale: 3));
    addTearDown(controller.dispose);
    await pumpZoom(tester, controller: controller, panInertia: false, scaleInertia: true);

    final first = await tester.createGesture(pointer: 61);
    final second = await tester.createGesture(pointer: 62);
    await first.down(const Offset(100, 200), timeStamp: Duration.zero);
    await second.down(const Offset(300, 200), timeStamp: Duration.zero);
    await second.moveTo(const Offset(240, 200), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(220, 200), timeStamp: const Duration(milliseconds: 32));
    await second.moveTo(const Offset(200, 200), timeStamp: const Duration(milliseconds: 48));
    await tester.pump();
    final releasedScale = controller.value.scale;
    await first.up(timeStamp: const Duration(milliseconds: 56));
    await second.up(timeStamp: const Duration(milliseconds: 64));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(controller.value.scale, lessThan(releasedScale));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.value.scale, closeTo(1, 1e-9));
  });

  testWidgets('ZOOM-12: 新 pointer down 不等 slop 就终止 scale inertia', (tester) async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    await pumpZoom(tester, controller: controller, panInertia: false, scaleInertia: true);

    final first = await tester.createGesture(pointer: 71);
    final second = await tester.createGesture(pointer: 72);
    await first.down(const Offset(100, 200), timeStamp: Duration.zero);
    await second.down(const Offset(200, 200), timeStamp: Duration.zero);
    await second.moveTo(const Offset(260, 200), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(300, 200), timeStamp: const Duration(milliseconds: 32));
    await second.moveTo(const Offset(340, 200), timeStamp: const Duration(milliseconds: 48));
    await first.up(timeStamp: const Duration(milliseconds: 56));
    await second.up(timeStamp: const Duration(milliseconds: 64));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final third = await tester.createGesture(pointer: 73);
    await third.down(const Offset(200, 200), timeStamp: const Duration(milliseconds: 80));
    await tester.pump();
    final stopped = controller.value;
    await tester.pump(const Duration(milliseconds: 64));
    expect(controller.value, stopped);
    await third.up(timeStamp: const Duration(milliseconds: 144));
  });

  testWidgets('ZOOM-13: reduced motion 保留直接捏合结果但不启动 scale inertia', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    await pumpZoom(tester, controller: controller, panInertia: false, scaleInertia: true);

    final first = await tester.createGesture(pointer: 91);
    final second = await tester.createGesture(pointer: 92);
    await first.down(const Offset(100, 200), timeStamp: Duration.zero);
    await second.down(const Offset(200, 200), timeStamp: Duration.zero);
    await second.moveTo(const Offset(260, 200), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(300, 200), timeStamp: const Duration(milliseconds: 32));
    await second.moveTo(const Offset(340, 200), timeStamp: const Duration(milliseconds: 48));
    await tester.pump();
    final releasedScale = controller.value.scale;
    await first.up(timeStamp: const Duration(milliseconds: 56));
    await second.up(timeStamp: const Duration(milliseconds: 64));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    expect(controller.value.scale, releasedScale);
  });

  testWidgets('ZOOM-14: pan+scale ballistic 保持独立缩放时序并在 anchor 后叠加 pan', (tester) async {
    Future<ElZoomTransform> run({required bool panInertia, required int pointerBase}) async {
      final controller = ElZoomController();
      addTearDown(controller.dispose);
      await pumpZoom(tester, controller: controller, panInertia: panInertia, scaleInertia: true);
      final first = await tester.createGesture(pointer: pointerBase);
      final second = await tester.createGesture(pointer: pointerBase + 1);
      await first.down(const Offset(100, 200), timeStamp: Duration.zero);
      await second.down(const Offset(200, 200), timeStamp: Duration.zero);
      await second.moveTo(const Offset(260, 200), timeStamp: const Duration(milliseconds: 16));
      await second.moveTo(const Offset(300, 200), timeStamp: const Duration(milliseconds: 32));
      await second.moveTo(const Offset(340, 200), timeStamp: const Duration(milliseconds: 48));
      await first.up(timeStamp: const Duration(milliseconds: 56));
      await second.up(timeStamp: const Duration(milliseconds: 64));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      final value = controller.value;
      controller.jumpTo(value);
      return value;
    }

    final anchorOnly = await run(panInertia: false, pointerBase: 101);
    final combined = await run(panInertia: true, pointerBase: 111);
    expect(combined.scale, closeTo(anchorOnly.scale, 1e-9));
    expect(combined.offset.dx, greaterThan(anchorOnly.offset.dx), reason: '正向焦点终速应在 scale anchor 之后叠加正向 pan');
  });

  testWidgets('ZOOM-D1: wheel 默认透传，启用后按 exp 缩放并逐帧锚定光标', (tester) async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    final remaining = <Offset>[];
    final ancestorEvent = ElEvent(onPointerSignal: (event) => remaining.add(event.remainingDelta));
    const cursor = Offset(100, 100);
    bool? platformDefaultAllowed;

    await pumpZoom(tester, controller: controller, ancestorEvent: ancestorEvent);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: cursor,
        scrollDelta: const Offset(0, -100),
        onRespond: ({required bool allowPlatformDefault}) => platformDefaultAllowed = allowPlatformDefault,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(controller.value.scale, 1);
    expect(remaining.single, const Offset(0, -100));
    expect(platformDefaultAllowed, isTrue);

    remaining.clear();
    platformDefaultAllowed = null;
    await pumpZoom(tester, controller: controller, mouseWheelZoom: true, ancestorEvent: ancestorEvent);
    final inverse = Matrix4.copy(matrixOf(tester))..invert();
    final anchoredContentPoint = MatrixUtils.transformPoint(inverse, cursor);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: cursor,
        scrollDelta: const Offset(0, -100),
        onRespond: ({required bool allowPlatformDefault}) => platformDefaultAllowed = allowPlatformDefault,
      ),
    );
    expect(platformDefaultAllowed, isFalse);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      final projected = MatrixUtils.transformPoint(matrixOf(tester), anchoredContentPoint);
      expect(projected.dx, closeTo(cursor.dx, 1e-5));
      expect(projected.dy, closeTo(cursor.dy, 1e-5));
    }
    await tester.pump(const Duration(milliseconds: 30));
    expect(controller.value.scale, closeTo(math.exp(0.2), 1e-9));
  });

  testWidgets('ZOOM-D2: wheel 跨 min/max 只消费对数区间并保留水平分量', (tester) async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    final remaining = <Offset>[];
    await pumpZoom(
      tester,
      controller: controller,
      maxScale: 2,
      mouseWheelZoom: true,
      ancestorEvent: ElEvent(onPointerSignal: (event) => remaining.add(event.remainingDelta)),
    );

    await tester.sendEventToBinding(
      const PointerScrollEvent(position: Offset(100, 100), scrollDelta: Offset(20, -1000)),
    );
    final maxRemainder = -1000 + math.log(2) / 0.002;
    final firstRemainder = remaining.removeLast();
    expect(firstRemainder.dx, 20);
    expect(firstRemainder.dy, closeTo(maxRemainder, 1e-6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.value.scale, closeTo(2, 1e-9));

    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(100, 100), scrollDelta: Offset(0, -100)));
    expect(remaining.removeLast(), const Offset(0, -100), reason: '已在 max 向外时应全量透传');

    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(100, 100), scrollDelta: Offset(0, 1000)));
    final minRemainder = 1000 - math.log(2) / 0.002;
    expect(remaining.removeLast().dy, closeTo(minRemainder, 1e-6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.value.scale, closeTo(1, 1e-9));
    expect(maxRemainder, closeTo(-653.4264097200273, 1e-9));
  });

  testWidgets('ZOOM-D3: wheel burst 累计 target，pointer 与 reduced motion 正确终止', (tester) async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    await pumpZoom(tester, controller: controller, mouseWheelZoom: true);
    for (final delta in const <double>[-100, -100, 100]) {
      await tester.sendEventToBinding(
        PointerScrollEvent(position: const Offset(100, 100), scrollDelta: Offset(0, delta)),
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.value.scale, closeTo(math.exp(0.2), 1e-9));

    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(100, 100), scrollDelta: Offset(0, -100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final pointer = TestPointer(151, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.down(const Offset(200, 200)));
    await tester.pump();
    final stopped = controller.value;
    await tester.pump(const Duration(milliseconds: 160));
    expect(controller.value, stopped);
    await tester.sendEventToBinding(pointer.up());

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    controller.jumpTo(const ElZoomTransform());
    await tester.sendEventToBinding(
      PointerScrollEvent(position: const Offset(100, 100), scrollDelta: const Offset(0, -100)),
    );
    expect(controller.value.scale, closeTo(math.exp(0.2), 1e-9));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('ZOOM-D4: mouseDragPan=false 只排除鼠标，触摸仍可平移', (tester) async {
    final controller = ElZoomController(initialValue: const ElZoomTransform(scale: 2));
    addTearDown(controller.dispose);
    await pumpZoom(tester, controller: controller, panInertia: false, mouseDragPan: false);

    final mouse = await tester.createGesture(pointer: 161, kind: PointerDeviceKind.mouse);
    await mouse.down(const Offset(200, 200));
    await mouse.moveBy(const Offset(40, 0));
    await mouse.moveBy(const Offset(40, 0));
    await tester.pump();
    await mouse.up();
    expect(controller.value.offset, Offset.zero);

    final touch = await tester.createGesture(pointer: 162, kind: PointerDeviceKind.touch);
    await touch.down(const Offset(200, 200));
    await touch.moveBy(const Offset(40, 0));
    await touch.moveBy(const Offset(40, 0));
    await tester.pump();
    await touch.up();
    expect(controller.value.offset.dx, greaterThan(0));

    controller.jumpTo(const ElZoomTransform(scale: 2));
    await pumpZoom(tester, controller: controller, panInertia: false);
    final enabledMouse = await tester.createGesture(pointer: 163, kind: PointerDeviceKind.mouse);
    await enabledMouse.down(const Offset(200, 200));
    await enabledMouse.moveBy(const Offset(40, 0));
    await enabledMouse.moveBy(const Offset(40, 0));
    await tester.pump();
    await enabledMouse.up();
    expect(controller.value.offset.dx, greaterThan(0), reason: '默认 mouseDragPan=true 必须保留既有主键平移');
  });

  testWidgets('ZOOM-D5: trackpad pinch 固定鼠标锚点并忽略同步 pan 与旋转', (tester) async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    final remaining = <Offset>[];
    await pumpZoom(
      tester,
      controller: controller,
      enableRotation: true,
      ancestorEvent: ElEvent(onPointerPanZoomUpdate: (event) => remaining.add(event.remainingDelta)),
    );

    final pointer = TestPointer(171, PointerDeviceKind.trackpad);
    const start = Offset(100, 100);
    const pan = Offset(-240, -160);
    final anchoredContentPoint = MatrixUtils.transformPoint(Matrix4.copy(matrixOf(tester))..invert(), start);
    await tester.sendEventToBinding(pointer.panZoomStart(start));
    await tester.sendEventToBinding(pointer.panZoomUpdate(start, pan: pan, scale: 1.5, rotation: 0.4));
    await tester.pump();
    final projected = MatrixUtils.transformPoint(matrixOf(tester), anchoredContentPoint);
    expect(projected.dx, closeTo(start.dx, 1e-5), reason: '捏合帧附带的 pan 不得把鼠标下内容横向拖走');
    expect(projected.dy, closeTo(start.dy, 1e-5), reason: '捏合帧附带的 pan 不得把鼠标下内容纵向拖走');
    expect(controller.value.rotation, 0, reason: '桌面 trackpad rotation 本期恒忽略');
    expect(remaining, isEmpty, reason: 'pinch 由 Zoom 独占，不交祖先');
    await tester.sendEventToBinding(pointer.panZoomUpdate(start, pan: pan));
    await tester.pump();
    expect(controller.value.scale, closeTo(1, 1e-9));
    expect(remaining, isEmpty, reason: '同一 stream 一旦 pinch，scale 回到 1 也不得泄漏给祖先');
    await tester.sendEventToBinding(pointer.panZoomEnd());

    controller.jumpTo(const ElZoomTransform(scale: 2));
    final panPointer = TestPointer(172, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(panPointer.panZoomStart(const Offset(200, 200)));
    await tester.sendEventToBinding(panPointer.panZoomUpdate(const Offset(200, 200), pan: const Offset(300, 0)));
    await tester.pump();
    expect(controller.value.offset.dx, closeTo(200, 1e-6));
    expect(remaining.single.dx, closeTo(100, 1e-6));
    await tester.sendEventToBinding(panPointer.panZoomEnd());
  });

  testWidgets('ZOOM-D6: trackpad 已平移后捏合仍围绕鼠标位置缩放', (tester) async {
    final controller = ElZoomController(initialValue: const ElZoomTransform(scale: 2));
    addTearDown(controller.dispose);
    await pumpZoom(tester, controller: controller, panInertia: false, scaleInertia: false);

    final pointer = TestPointer(173, PointerDeviceKind.trackpad);
    const cursor = Offset(120, 140);
    const pan = Offset(40, 0);
    await tester.sendEventToBinding(pointer.panZoomStart(cursor));
    await tester.sendEventToBinding(pointer.panZoomUpdate(cursor, pan: pan));
    await tester.pump();
    expect(controller.value.offset.dx, closeTo(40, 1e-6), reason: '前置 pan 必须真实移动内容，不能以空手势伪造锚点测试');

    // pan 是内容位移，不代表鼠标光标移动；后续只有 scale 变化时，当前鼠标下
    // 的内容点仍应留在鼠标位置，不能改用 cursor + 累计 pan 作为缩放原点。
    final contentPointUnderCursor = MatrixUtils.transformPoint(Matrix4.copy(matrixOf(tester))..invert(), cursor);
    await tester.sendEventToBinding(pointer.panZoomUpdate(cursor, pan: pan, scale: 1.5));
    await tester.pump();
    final projected = MatrixUtils.transformPoint(matrixOf(tester), contentPointUnderCursor);
    await tester.sendEventToBinding(pointer.panZoomEnd());

    expect(controller.value.scale, closeTo(3, 1e-9));
    expect(projected.dx, closeTo(cursor.dx, 1e-5), reason: '缩放原点必须保持在未移动的鼠标横坐标');
    expect(projected.dy, closeTo(cursor.dy, 1e-5), reason: '缩放原点必须保持在未移动的鼠标纵坐标');
  });

  testWidgets('ZOOM-6: 触控板捏合缩放围绕焦点锚定', (tester) async {
    await pumpZoom(tester);

    final pointer = TestPointer(30, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(const Offset(200, 200)));
    await tester.sendEventToBinding(pointer.panZoomUpdate(const Offset(200, 200), scale: 1.5));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(scaleOf(tester), closeTo(1.5, 1e-9));
    // 焦点 (200,200) 锚定：offset = focal - focal*1.5 = (-100,-100)。
    expect(translationOf(tester).dx, closeTo(-100, 1e-6));
    expect(translationOf(tester).dy, closeTo(-100, 1e-6));
  });
}
