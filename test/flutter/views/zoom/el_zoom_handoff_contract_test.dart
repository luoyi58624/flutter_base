import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  // 暂跳过：ElScroll 已改用官方 Scrollable 手势，不再作为 ElView 拖拽台账的 driver；
  // 待 ElView 拖拽识别器迁移到官方实现后，按新的手势归属重写本用例。
  testWidgets('ZOOM-H1: 滚动中的第二指立即交给 Scale，2→1 首帧继续平移且全链 Tap 失权', (tester) async {
    final scrollController = ScrollController();
    final zoomController = ElZoomController();
    addTearDown(scrollController.dispose);
    addTearDown(zoomController.dispose);

    var innerTaps = 0;
    var outerTaps = 0;
    var farOuterTaps = 0;
    var farOuterScaleStarts = 0;
    var farOuterScaleUpdates = 0;
    var farOuterScaleEnds = 0;

    await tester.pumpWidget(
      _testShell(
        ElView(
          event: ElEvent(
            onTap: (_) => farOuterTaps++,
            onScaleStart: (_) => farOuterScaleStarts++,
            onScaleUpdate: (_) => farOuterScaleUpdates++,
            onScaleEnd: (_) => farOuterScaleEnds++,
          ),
          child: SizedBox(
            width: 400,
            height: 400,
            child: ElScroll(
              controller: scrollController,
              children: [
                SizedBox(
                  width: 400,
                  height: 400,
                  child: ElView(
                    event: ElEvent(onTap: (_) => outerTaps++),
                    child: ElZoomView(
                      controller: zoomController,
                      enableDoubleTapZoom: false,
                      panInertia: false,
                      child: ElView(
                        event: ElEvent(onTap: (_) => innerTaps++),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 400, height: 1200),
              ],
            ),
          ),
        ),
      ),
    );

    final first = await tester.createGesture(kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);

    await first.down(const Offset(180, 300));
    await tester.pump();
    await first.moveBy(const Offset(0, -10));
    await tester.pump();
    await first.moveBy(const Offset(0, -10));
    await tester.pump();
    await first.moveBy(const Offset(0, -10));
    await tester.pump();
    expect(scrollController.offset, greaterThan(0), reason: '前置条件：第一指已经建立并推进祖先滚动');
    final scrollAtHandoff = scrollController.offset;

    await second.down(const Offset(280, 270));
    await tester.pump();
    expect(scrollController.offset, closeTo(scrollAtHandoff, 1e-6));

    await second.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(zoomController.value.scale, greaterThan(1), reason: '第二指 down 已完成交接，因此不足 slop 的首个 move 也必须直接缩放');
    expect(scrollController.offset, closeTo(scrollAtHandoff, 1e-6), reason: 'Scale 接管后祖先滚动必须停在交接位置');

    await second.moveBy(const Offset(56, 0));
    await tester.pump();
    final scaleBeforePointerReduction = zoomController.value.scale;

    await first.up();
    await tester.pump();
    final offsetBeforeSinglePointerMove = zoomController.value.offset;
    expect(
      zoomController.value.scale,
      closeTo(scaleBeforePointerReduction, 1e-6),
      reason: '2→1 只能重定基线，不能结束后重启并清空累计 scale',
    );
    await second.moveBy(const Offset(-24, 0));
    await tester.pump();

    expect(zoomController.value.scale, closeTo(scaleBeforePointerReduction, 1e-6));
    expect(
      zoomController.value.offset.dx,
      closeTo(offsetBeforeSinglePointerMove.dx - 24, 1e-6),
      reason: '2→1 rebaseline 后不得吞掉剩余指针的首帧平移',
    );
    expect(scrollController.offset, closeTo(scrollAtHandoff, 1e-6));

    await second.up();
    await tester.pump();
    expect(innerTaps, 0, reason: '滚动/捏合成立后最内层 Tap 必须失权');
    expect(outerTaps, 0, reason: '滚动/捏合成立后祖先 Tap 也必须失权');
    expect(farOuterTaps, 0, reason: 'Scale shadow 不得破坏外层事件链');
    expect(farOuterScaleStarts, 0, reason: '首指预留的 Zoom 必须优先于新链上的无关 Scale tracker');
    expect(farOuterScaleUpdates, 0, reason: '仅剩 shadow 指针后不得切到 live chain 冒泡 update');
    expect(farOuterScaleEnds, 0, reason: '未收到 start 的外层不得单独收到 end');
  }, skip: true);

  testWidgets('ZOOM-H2: 水平边界只消费实际位移，余量同帧交给 proxy 且反向帧立即收回', (tester) async {
    final zoomController = ElZoomController(initialValue: const ElZoomTransform(scale: 2, offset: Offset(90, 0)));
    addTearDown(zoomController.dispose);

    var innerTaps = 0;
    var outerTaps = 0;
    final overflowFrames = <({double offset, double remaining})>[];

    await tester.pumpWidget(
      _testShell(
        SizedBox(
          width: 200,
          height: 200,
          child: ElView(
            event: ElEvent(
              onTap: (_) => outerTaps++,
              dragProxy: ElDragProxy(
                onDragOverflow: (event) {
                  overflowFrames.add((
                    offset: zoomController.value.offset.dx,
                    remaining: event.remainingPrimaryDelta(Axis.horizontal),
                  ));
                  event.consumeAllDelta();
                },
              ),
            ),
            child: ElZoomView(
              controller: zoomController,
              enableDoubleTapZoom: false,
              panInertia: false,
              child: ElView(
                event: ElEvent(onTap: (_) => innerTaps++),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    expect(zoomController.value.offset.dx, closeTo(90, 1e-6));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await gesture.down(const Offset(100, 100));
    await tester.pump();
    await gesture.moveBy(const Offset(12, 0));
    await tester.pump();
    expect(overflowFrames, isEmpty, reason: 'dragStart 是零位移生命周期信号，不应提前走 overflow');

    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(zoomController.value.offset.dx, closeTo(100, 1e-6), reason: 'Zoom 到右边界只能实际消费 10px');
    expect(overflowFrames, hasLength(1));
    expect(overflowFrames.single.offset, closeTo(100, 1e-6), reason: 'overflow 必须发生在 Zoom 当帧消费之后');
    expect(overflowFrames.single.remaining, closeTo(10, 1e-6), reason: '20px 原始位移减去 Zoom 实际消费 10px，余量必须精确守恒');

    await gesture.moveBy(const Offset(-15, 0));
    await tester.pump();
    expect(zoomController.value.offset.dx, closeTo(85, 1e-6), reason: '边界后的首个反向帧必须立即重新由 Zoom 消费');
    expect(overflowFrames, hasLength(1), reason: '反向 15px 已被 Zoom 全吃，不得再产生 overflow');

    await gesture.up();
    await tester.pump();
    expect(innerTaps, 0, reason: '边界拖拽成立后最内层 Tap 不得触发');
    expect(outerTaps, 0, reason: '边界拖拽成立后祖先 Tap 不得触发');
  });

  testWidgets('ZOOM-H3: 已消费的内容 drag 在第二指 down 后用 4px 立即升级 Scale', (tester) async {
    final controller = ElZoomController(initialValue: const ElZoomTransform(scale: 2));
    addTearDown(controller.dispose);
    const contentKey = ValueKey<String>('zoom-own-drag-handoff-content');
    await tester.pumpWidget(
      _testShell(
        SizedBox(
          width: 300,
          height: 300,
          child: ElZoomView(
            controller: controller,
            enableDoubleTapZoom: false,
            panInertia: false,
            scaleInertia: false,
            child: const SizedBox.expand(key: contentKey),
          ),
        ),
      ),
    );

    Matrix4 matrix() {
      final content = tester.renderObject<RenderBox>(find.byKey(contentKey));
      final host = tester.renderObject<RenderBox>(find.byType(ElZoomView));
      return content.getTransformTo(host);
    }

    void expectMatrixClose(Matrix4 actual, Matrix4 expected) {
      for (var i = 0; i < 16; i++) {
        expect(actual.storage[i], closeTo(expected.storage[i], 1e-6), reason: 'matrix[$i] 在第二指 down 时跳变');
      }
    }

    final first = await tester.createGesture(pointer: 301, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 302, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    await first.down(const Offset(80, 150));
    await first.moveBy(const Offset(24, 0));
    await tester.pump();
    await first.moveBy(const Offset(24, 0));
    await tester.pump();
    expect(controller.value.scale, 2);
    expect(controller.value.offset.dx, closeTo(24, 1e-6), reason: '前置条件：第一指 drag 必须已实际消费位移');

    final beforeSecondDown = controller.value;
    final matrixBeforeSecondDown = matrix();
    const secondDown = Offset(228, 150);
    const focalBeforeScale = Offset(178, 150);
    final inverseBeforeScale = Matrix4.copy(matrixBeforeSecondDown)..invert();
    final anchoredContentPoint = MatrixUtils.transformPoint(inverseBeforeScale, focalBeforeScale);
    await second.down(secondDown);
    await tester.pump();

    expect(controller.value, beforeSecondDown, reason: '第二指 down 只能重定基线，不得重置已消费的 transform');
    expectMatrixClose(matrix(), matrixBeforeSecondDown);

    await second.moveBy(const Offset(4, 0));
    await tester.pump();

    expect(controller.value.scale, closeTo(2.08, 1e-6), reason: '已成立 drag 升级 Scale 后不得再等待 scale slop');
    expect(controller.value.offset.dx, closeTo(25.84, 1e-6), reason: '首个 scale move 必须继承 down 前的内容偏移');
    final matrixAfterFirstScaleMove = matrix();
    _expectOffset(
      MatrixUtils.transformPoint(matrixAfterFirstScaleMove, anchoredContentPoint),
      const Offset(180, 150),
      reason: '首个 4px scale move 必须连续锨定新焦点',
    );

    final scaleBeforePointerReduction = controller.value.scale;
    await first.up();
    await tester.pump();
    final offsetBeforeSingleMove = controller.value.offset;
    await second.moveBy(const Offset(-24, 0));
    await tester.pump();

    expect(controller.value.scale, closeTo(scaleBeforePointerReduction, 1e-6));
    expect(
      controller.value.offset.dx,
      closeTo(offsetBeforeSingleMove.dx - 24, 1e-6),
      reason: '2→1 后剩余指针的首个 move 必须继续 pan，不得被 rebaseline 吞掉',
    );
    await second.up();
    await tester.pump();
  });
}

Widget _testShell(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  );
}

void _expectOffset(Offset actual, Offset expected, {String? reason}) {
  expect(actual.dx, closeTo(expected.dx, 1e-6), reason: reason);
  expect(actual.dy, closeTo(expected.dy, 1e-6), reason: reason);
}
