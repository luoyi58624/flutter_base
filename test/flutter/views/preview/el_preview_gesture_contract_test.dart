import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  setUp(EventDispatcher.debugReset);

  testWidgets('PREVIEW-G0: 同一预览连续四次触摸按下立即触发两组双击', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    final position = _previewCenter(tester);

    final first = await tester.createGesture(pointer: 1);
    await first.down(position);
    await first.up();
    await tester.pump(const Duration(milliseconds: 40));
    final second = await tester.createGesture(pointer: 2);
    await second.down(position);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(controller.currentTransform.scale, greaterThan(1));
    await second.up();

    final third = await tester.createGesture(pointer: 3);
    await third.down(position);
    await third.up();
    await tester.pump(const Duration(milliseconds: 40));
    final scaleBeforeFourthDown = controller.currentTransform.scale;
    final fourth = await tester.createGesture(pointer: 4);
    await fourth.down(position);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      controller.currentTransform.scale,
      lessThan(scaleBeforeFourthDown),
      reason: 'Preview 的第 4 次按下必须立即触发第二组双击，不得等待冷却时间',
    );
    await fourth.up();
    await tester.pumpAndSettle();

    expect(controller.currentTransform.scale, closeTo(1, 1e-9));
  });

  testWidgets('PREVIEW-G1: 低速越过 0.35 页或末速越过 400px/s 均提交，否则回原页', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));

    // 80px < 0.35 × 300px，且 200px/s < 400px/s：必须回原页。
    await _dragAndRelease(tester, stepDx: -20, stepCount: 4, stepDuration: const Duration(milliseconds: 100));
    await _finishPageMotion(tester);
    expect(controller.index, 0);

    // 首帧只负责接受拖拽；其余位移仍超过 105px，低速也必须按距离提交。
    await _dragAndRelease(tester, stepDx: -20, stepCount: 8, stepDuration: const Duration(milliseconds: 100));
    await _finishPageMotion(tester);
    expect(controller.index, 1, reason: '低速拖过 0.35 页必须提交下一页');

    controller.jumpToIndex(0);
    await tester.pump();

    // 6 × 8px / 16ms ≈ 500px/s，总位移远小于 105px，必须按末速提交。
    await _dragAndRelease(tester, stepDx: -8, stepCount: 6, stepDuration: const Duration(milliseconds: 16));
    await _finishPageMotion(tester);
    expect(controller.index, 1, reason: '末速超过 400px/s 时短距离也必须提交');

    controller.jumpToIndex(0);
    await tester.pump();

    // 距离已越阈值但末速高速反向时，速度方向优先，不能继续提交。
    final reversed = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(reversed.removePointer);
    await reversed.down(_previewCenter(tester), timeStamp: Duration.zero);
    var elapsed = Duration.zero;
    for (var i = 0; i < 6; i++) {
      elapsed += const Duration(milliseconds: 100);
      await reversed.moveBy(const Offset(-50, 0), timeStamp: elapsed);
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 3; i++) {
      elapsed += const Duration(milliseconds: 16);
      await reversed.moveBy(const Offset(50, 0), timeStamp: elapsed);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await reversed.up(timeStamp: elapsed);
    await _finishPageMotion(tester);
    expect(controller.index, 0, reason: '高速反向释放必须回原页，不能再由距离阈值提交');
  });

  testWidgets('PREVIEW-G2: 非循环首尾使用递增阻尼，松手后回弹到当前页', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));

    final firstKey = const ValueKey<String>('preview-page-0');
    final firstBaseX = tester.getTopLeft(find.byKey(firstKey)).dx;
    final leading = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(leading.removePointer);
    await leading.down(_previewCenter(tester));
    await leading.moveBy(const Offset(40, 0));
    await tester.pump();
    await leading.moveBy(const Offset(40, 0));
    await tester.pump();
    final leadingBefore = tester.getTopLeft(find.byKey(firstKey)).dx;
    await leading.moveBy(const Offset(40, 0));
    await tester.pump();
    final leadingAfter = tester.getTopLeft(find.byKey(firstKey)).dx;

    expect(leadingAfter, greaterThan(firstBaseX), reason: '首页外拉必须有可见反馈');
    expect(leadingAfter - leadingBefore, greaterThan(0));
    expect(leadingAfter - leadingBefore, lessThan(40), reason: '已越界后的同量输入必须被阻尼压缩');

    await leading.up();
    await _finishPageMotion(tester);
    expect(controller.index, 0);
    expect(tester.getTopLeft(find.byKey(firstKey)).dx, closeTo(firstBaseX, 1e-6));

    controller.jumpToIndex(2);
    await tester.pump();
    final lastKey = const ValueKey<String>('preview-page-2');
    final lastBaseX = tester.getTopLeft(find.byKey(lastKey)).dx;
    final trailing = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(trailing.removePointer);
    await trailing.down(_previewCenter(tester));
    await trailing.moveBy(const Offset(-40, 0));
    await tester.pump();
    await trailing.moveBy(const Offset(-40, 0));
    await tester.pump();
    final trailingBefore = tester.getTopLeft(find.byKey(lastKey)).dx;
    await trailing.moveBy(const Offset(-40, 0));
    await tester.pump();
    final trailingAfter = tester.getTopLeft(find.byKey(lastKey)).dx;

    expect(trailingAfter, lessThan(lastBaseX), reason: '末页外拉必须有可见反馈');
    expect((trailingAfter - trailingBefore).abs(), greaterThan(0));
    expect((trailingAfter - trailingBefore).abs(), lessThan(40), reason: '尾部也必须使用同一递增阻尼');

    await trailing.up();
    await _finishPageMotion(tester);
    expect(controller.index, 2);
    expect(tester.getTopLeft(find.byKey(lastKey)).dx, closeTo(lastBaseX, 1e-6));
  });

  testWidgets('PREVIEW-G3: Zoom 先消费到边界，余量同帧拉页；反向先闭合 gap 再还给内容', (tester) async {
    final controller = ElPreviewController()..jumpToTransform(const ElZoomTransform(scale: 2));
    addTearDown(controller.dispose);
    var innerTaps = 0;
    var outerTaps = 0;
    const currentKey = ValueKey<String>('preview-current-content');
    const nextKey = ValueKey<String>('preview-next-content');

    await tester.pumpWidget(
      _shell(
        ElView(
          event: ElEvent(onTap: (_) => outerTaps++),
          child: ElPreviewView(
            controller: controller,
            children: [
              ElView(
                key: currentKey,
                event: ElEvent(onTap: (_) => innerTaps++),
                child: const SizedBox.expand(),
              ),
              const SizedBox.expand(key: nextKey),
            ],
          ),
        ),
      ),
    );
    expect(controller.currentTransform.scale, 2);
    final nextBaseX = tester.getTopLeft(find.byKey(nextKey)).dx;
    expect(nextBaseX, closeTo(300, 1e-6));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await gesture.down(_previewCenter(tester), timeStamp: Duration.zero);
    await gesture.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(-60, 0), timeStamp: const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));

    final contentBeforeEdge = controller.currentTransform.offset.dx;
    expect(contentBeforeEdge, inExclusiveRange(-150, 0), reason: '内容未到边界时应先独占水平位移');
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextBaseX, 1e-6), reason: 'Zoom 还能消费时不得提前露页');

    const edgeMove = 160.0;
    await gesture.moveBy(const Offset(-edgeMove, 0), timeStamp: const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    final expectedGap = edgeMove - (150 + contentBeforeEdge);
    final nextAtEdge = tester.getTopLeft(find.byKey(nextKey)).dx;
    expect(controller.currentTransform.offset.dx, closeTo(-150, 1e-6));
    expect(nextBaseX - nextAtEdge, closeTo(expectedGap, 1e-6), reason: '越过内容边界的剩余量必须在同一帧完整交给 pager');

    await gesture.moveBy(const Offset(30, 0), timeStamp: const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    final nextAfterPartialClose = tester.getTopLeft(find.byKey(nextKey)).dx;
    expect(controller.currentTransform.offset.dx, closeTo(-150, 1e-6), reason: 'page gap 未闭合前反向位移不得先推动内容');
    expect(nextAfterPartialClose - nextAtEdge, closeTo(30, 1e-6));

    final remainingGap = nextBaseX - nextAfterPartialClose;
    await gesture.moveBy(Offset(remainingGap + 20, 0), timeStamp: const Duration(milliseconds: 416));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextBaseX, 1e-6));
    expect(controller.currentTransform.offset.dx, closeTo(-130, 1e-6), reason: '闭合 gap 后的同帧余量必须立即回到 Zoom');

    await gesture.moveBy(const Offset(20, 0), timeStamp: const Duration(milliseconds: 432));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(20, 0), timeStamp: const Duration(milliseconds: 448));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.currentTransform.offset.dx, closeTo(-90, 1e-6));

    final releaseOffset = controller.currentTransform.offset.dx;
    await gesture.up(timeStamp: const Duration(milliseconds: 456));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.currentTransform.offset.dx, greaterThan(releaseOffset), reason: 'page gap 已闭合后，图片向内的单指末速必须继续惯性');
    await _finishPageMotion(tester);
    expect(controller.index, 0);
    expect(controller.currentTransform.offset.dx, greaterThan(releaseOffset));
    expect(innerTaps, 0, reason: '内容拖拽成立后后代 Tap 必须失权');
    expect(outerTaps, 0, reason: '内容拖拽成立后祖先 Tap 必须失权');
  });

  testWidgets('PREVIEW-G4: 半页加第二指保持真实矩阵与焦点，邻页 inert，先抬首指后首帧继续 pan', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    var currentTaps = 0;
    var outerTaps = 0;
    var nextPointerDowns = 0;
    var nextTaps = 0;
    const currentKey = ValueKey<String>('preview-handoff-current');
    const nextKey = ValueKey<String>('preview-handoff-next');

    await tester.pumpWidget(
      _shell(
        ElView(
          event: ElEvent(onTap: (_) => outerTaps++),
          child: ElPreviewView(
            controller: controller,
            panInertia: false,
            children: [
              ElView(
                key: currentKey,
                event: ElEvent(onTap: (_) => currentTaps++),
                child: const SizedBox.expand(),
              ),
              ElView(
                key: nextKey,
                event: ElEvent(onPointerDown: (_) => nextPointerDowns++, onTap: (_) => nextTaps++),
                child: const SizedBox.expand(),
              ),
            ],
          ),
        ),
      ),
    );

    const firstStart = Offset(260, 100);
    var firstPosition = firstStart;
    final first = await tester.createGesture(pointer: 11, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 12, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    await first.down(firstStart);
    for (var i = 0; i < 5; i++) {
      const delta = Offset(-40, 0);
      firstPosition += delta;
      await first.moveBy(delta);
      await tester.pump();
    }

    final viewportRect = tester.getRect(find.byType(ElPreviewView));
    final nextRect = tester.getRect(find.byKey(nextKey));
    final visibleLeft = math.max(viewportRect.left, nextRect.left);
    final visibleRight = math.min(viewportRect.right, nextRect.right);
    expect(visibleRight - visibleLeft, greaterThan(60), reason: '前置条件：第一指已把相邻页拉出接近半页');
    final secondPosition = Offset((visibleLeft + visibleRight) / 2, viewportRect.center.dy);
    expect(nextRect.contains(secondPosition), isTrue);

    final matrixBeforeJoin = _globalMatrix(tester, currentKey);
    final focal = (firstPosition + secondPosition) / 2;
    final inverseBeforeJoin = Matrix4.copy(matrixBeforeJoin)..invert();
    final contentPointAtFocal = MatrixUtils.transformPoint(inverseBeforeJoin, focal);

    await second.down(secondPosition);
    await tester.pump();

    final matrixAfterJoin = _globalMatrix(tester, currentKey);
    _expectMatrixClose(matrixAfterJoin, matrixBeforeJoin);
    _expectOffset(MatrixUtils.transformPoint(matrixAfterJoin, contentPointAtFocal), focal);
    expect(tester.getRect(find.byKey(nextKey)), nextRect, reason: '第二指加入帧邻页不得瞬间消失或跳位');
    expect(controller.index, 0);
    expect(nextPointerDowns, 0, reason: '已露出的预加载邻页仍必须 inert，第二指只加入当前页 transform');

    final initialSpan = secondPosition.dx - firstPosition.dx;
    await second.moveBy(Offset(initialSpan, 0));
    await tester.pump();
    expect(controller.currentTransform.scale, greaterThan(1.5), reason: '半页 pager 必须被第二指原子升级为当前页 Scale');

    final beforePointerReduction = controller.currentTransform;
    await first.up();
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(beforePointerReduction.scale, 1e-6));

    final panDx = beforePointerReduction.offset.dx <= 0 ? 24.0 : -24.0;
    await second.moveBy(Offset(panDx, 0));
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(beforePointerReduction.scale, 1e-6));
    expect(
      controller.currentTransform.offset.dx,
      closeTo(beforePointerReduction.offset.dx + panDx, 1e-6),
      reason: '先抬真实首指后，剩余指针的第一个 move 不得被 rebaseline 吞掉',
    );

    await second.up();
    await tester.pump();
    expect(currentTaps, 0, reason: 'page drag/Scale 成立后当前页 Tap 必须失权');
    expect(outerTaps, 0, reason: 'page drag/Scale 成立后祖先 Tap 必须失权');
    expect(nextTaps, 0, reason: 'inert 邻页不得因第二指 down/up 合成 Tap');
  });

  testWidgets('PREVIEW-G5: 切页动画纯触摸不中断，真实拖动从当前视觉位置无缝接管', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));

    final command = controller.animateToIndex(2);
    var completed = false;
    command.then((_) => completed = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final page = find.byKey(const ValueKey<String>('preview-page-0'));
    final beforeTouch = tester.getTopLeft(page).dx;
    expect(beforeTouch, inExclusiveRange(-160, -60), reason: '切页前段不得在 80ms 内猛冲到终点附近');

    final gesture = await tester.startGesture(_previewCenter(tester), kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(tester.getTopLeft(page).dx, closeTo(beforeTouch, 1e-6), reason: 'pointer down 本身不得把进行中的切页动画瞬移归零');
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getTopLeft(page).dx, lessThan(beforeTouch), reason: '纯 tap 不应冻结或取消切页动画');
    expect(completed, isFalse);

    final takeover = await tester.startGesture(_previewCenter(tester), kind: PointerDeviceKind.touch);
    await takeover.moveBy(const Offset(30, 0));
    await tester.pump();
    final takeoverX = tester.getTopLeft(page).dx;
    await takeover.moveBy(const Offset(12, 0));
    await tester.pump();
    expect(tester.getTopLeft(page).dx, closeTo(takeoverX + 12, 1e-6), reason: '真实水平拖动应从动画当前帧连续接管');
    await takeover.cancel();
    await _finishPageMotion(tester);

    expect(completed, isTrue);
    expect(controller.index, 0);
    expect(tester.getTopLeft(page).dx, closeTo(0, 1e-6));
  });

  testWidgets('PREVIEW-G6: Zoom 余量形成翻页后 pointer cancel 只回滚不提交', (tester) async {
    final controller = ElPreviewController()..jumpToTransform(const ElZoomTransform(scale: 2));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));

    final gesture = await tester.startGesture(_previewCenter(tester), kind: PointerDeviceKind.touch);
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('preview-page-1'))).dx, lessThan(195));

    await gesture.cancel();
    await _finishPageMotion(tester);
    expect(controller.index, 0);
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('preview-page-1'))).dx, closeTo(300, 1e-6));
  });

  testWidgets('PREVIEW-G7: minScale 下的超宽真实 child 先消费平移，到边界才交 pager', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          constrained: false,
          panInertia: false,
          children: const [
            SizedBox(key: ValueKey<String>('wide-content'), width: 600, height: 200),
            SizedBox(key: ValueKey<String>('wide-next'), width: 300, height: 200),
          ],
        ),
      ),
    );
    await tester.pump();

    final nextBaseX = tester.getTopLeft(find.byKey(const ValueKey<String>('wide-next'))).dx;
    final gesture = await tester.startGesture(_previewCenter(tester), kind: PointerDeviceKind.touch);
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();

    expect(controller.currentTransform.scale, 1);
    expect(controller.currentTransform.offset.dx, lessThan(0), reason: 'pan 资格必须来自真实 projected bounds，不是 scale 值');
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('wide-next'))).dx, closeTo(nextBaseX, 1e-6));
    await gesture.up();
  });

  testWidgets('PREVIEW-G8: 内容起手已在边界时仍保留同一 driver，反向余量可立即回内容', (tester) async {
    final controller = ElPreviewController()..jumpToTransform(const ElZoomTransform(scale: 2, offset: Offset(-150, 0)));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));

    const nextKey = ValueKey<String>('preview-page-1');
    final nextBaseX = tester.getTopLeft(find.byKey(nextKey)).dx;
    final gesture = await tester.startGesture(_previewCenter(tester), kind: PointerDeviceKind.touch);
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    final nextAtGap = tester.getTopLeft(find.byKey(nextKey)).dx;
    expect(nextAtGap, lessThan(nextBaseX));
    expect(controller.currentTransform.offset.dx, closeTo(-150, 1e-6));

    final gap = nextBaseX - nextAtGap;
    await gesture.moveBy(Offset(gap + 20, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextBaseX, 1e-6));
    expect(controller.currentTransform.offset.dx, closeTo(-130, 1e-6));
    await gesture.up();
  });

  testWidgets('PREVIEW-G9: handoff 中切页会清旧页 transient，返回旧页矩阵归位', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    const currentKey = ValueKey<String>('transient-current');
    const nextKey = ValueKey<String>('transient-next');
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          panInertia: false,
          children: const [
            SizedBox.expand(key: currentKey),
            SizedBox.expand(key: nextKey),
          ],
        ),
      ),
    );
    final baseMatrix = _globalMatrix(tester, currentKey);
    final first = await tester.createGesture(pointer: 31, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 32, kind: PointerDeviceKind.touch);
    await first.down(const Offset(260, 100));
    for (var i = 0; i < 5; i++) {
      await first.moveBy(const Offset(-40, 0));
      await tester.pump();
    }
    final nextRect = tester.getRect(find.byKey(nextKey));
    await second.down(Offset(nextRect.left + 30, nextRect.center.dy));
    await tester.pump();

    controller.jumpToIndex(1);
    await tester.pump();
    await second.up();
    await first.up();
    controller.jumpToIndex(0);
    await tester.pump();
    _expectMatrixClose(_globalMatrix(tester, currentKey), baseMatrix);
  });

  testWidgets('PREVIEW-G10: 默认关闭 scale inertia，双指松手后停在当前比例', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    final first = await tester.createGesture(pointer: 79);
    final second = await tester.createGesture(pointer: 80);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);

    await first.down(const Offset(50, 100), timeStamp: Duration.zero);
    await second.down(const Offset(150, 100), timeStamp: Duration.zero);
    await second.moveTo(const Offset(210, 100), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(250, 100), timeStamp: const Duration(milliseconds: 32));
    await second.moveTo(const Offset(290, 100), timeStamp: const Duration(milliseconds: 48));
    final releasedScale = controller.currentTransform.scale;
    await first.up(timeStamp: const Duration(milliseconds: 56));
    await second.up(timeStamp: const Duration(milliseconds: 64));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    expect(controller.currentTransform.scale, closeTo(releasedScale, 1e-9));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: '范围内双指松手不得留下缩放 ticker');
  });

  testWidgets('PREVIEW-G10A: 显式启用 scale inertia 时 page commit 会同步终止旧页惯性', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          panInertia: false,
          scaleInertia: true,
          preserveItemTransform: true,
          children: const [
            SizedBox.expand(key: ValueKey<String>('scale-inertia-0')),
            SizedBox.expand(key: ValueKey<String>('scale-inertia-1')),
          ],
        ),
      ),
    );

    final first = await tester.createGesture(pointer: 81);
    final second = await tester.createGesture(pointer: 82);
    await first.down(const Offset(50, 100), timeStamp: Duration.zero);
    await second.down(const Offset(150, 100), timeStamp: Duration.zero);
    await second.moveTo(const Offset(210, 100), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(250, 100), timeStamp: const Duration(milliseconds: 32));
    await second.moveTo(const Offset(290, 100), timeStamp: const Duration(milliseconds: 48));
    await tester.pump();
    final releasedScale = controller.currentTransform.scale;
    await first.up(timeStamp: const Duration(milliseconds: 56));
    await second.up(timeStamp: const Duration(milliseconds: 64));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.currentTransform.scale, greaterThan(releasedScale));

    final stoppedScale = controller.currentTransform.scale;
    controller.jumpToIndex(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    controller.jumpToIndex(0);
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(stoppedScale, 1e-9));
  });

  testWidgets('PREVIEW-G11: 三项 loop 首尾从正确方向进入，慢速越过距离阈值后提交', (tester) async {
    final controller = ElPreviewController(initialIndex: 2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          loop: true,
          panInertia: false,
          children: const [
            SizedBox.expand(key: ValueKey<String>('loop-page-0')),
            SizedBox.expand(key: ValueKey<String>('loop-page-1')),
            SizedBox.expand(key: ValueKey<String>('loop-page-2')),
          ],
        ),
      ),
    );

    final next = await tester.createGesture(pointer: 201, kind: PointerDeviceKind.touch);
    addTearDown(next.removePointer);
    await next.down(_previewCenter(tester), timeStamp: Duration.zero);
    var elapsed = Duration.zero;
    for (var i = 0; i < 8; i++) {
      elapsed += const Duration(milliseconds: 100);
      await next.moveBy(const Offset(-20, 0), timeStamp: elapsed);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-2'))).dx, lessThan(0));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-0'))).dx,
      inExclusiveRange(0, 300),
      reason: '末页向左拖时首页必须从右侧进入',
    );
    await next.up(timeStamp: elapsed);
    await _finishPageMotion(tester);
    expect(controller.index, 0);

    final previous = await tester.createGesture(pointer: 202, kind: PointerDeviceKind.touch);
    addTearDown(previous.removePointer);
    await previous.down(_previewCenter(tester), timeStamp: Duration.zero);
    elapsed = Duration.zero;
    for (var i = 0; i < 8; i++) {
      elapsed += const Duration(milliseconds: 100);
      await previous.moveBy(const Offset(20, 0), timeStamp: elapsed);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-0'))).dx, greaterThan(0));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-2'))).dx,
      inExclusiveRange(-300, 0),
      reason: '首页向右拖时末页必须从左侧进入',
    );
    await previous.up(timeStamp: elapsed);
    await _finishPageMotion(tester);
    expect(controller.index, 2);

    final nextCommand = controller.next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-2'))).dx, lessThan(0));
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-0'))).dx, inExclusiveRange(0, 300));
    await _finishPageMotion(tester);
    await nextCommand;
    expect(controller.index, 0);

    final previousCommand = controller.previous();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-0'))).dx, greaterThan(0));
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-2'))).dx, inExclusiveRange(-300, 0));
    await _finishPageMotion(tester);
    await previousCommand;
    expect(controller.index, 2);
  });

  testWidgets('PREVIEW-G12: loop 半途反向先闭合当前 gap，跨零后才从另一侧显示', (tester) async {
    final controller = ElPreviewController(initialIndex: 1);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          loop: true,
          panInertia: false,
          children: const [
            SizedBox.expand(key: ValueKey<String>('reverse-page-0')),
            SizedBox.expand(key: ValueKey<String>('reverse-page-1')),
            SizedBox.expand(key: ValueKey<String>('reverse-page-2')),
          ],
        ),
      ),
    );

    final gesture = await tester.createGesture(pointer: 203, kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await gesture.down(_previewCenter(tester), timeStamp: Duration.zero);
    await gesture.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(-90, 0), timeStamp: const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));

    const nextKey = ValueKey<String>('reverse-page-2');
    const previousKey = ValueKey<String>('reverse-page-0');
    final nextAtGap = tester.getTopLeft(find.byKey(nextKey)).dx;
    expect(nextAtGap, inExclusiveRange(0, 300));
    final halfGap = (300 - nextAtGap) / 2;

    await gesture.moveBy(Offset(halfGap, 0), timeStamp: const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextAtGap + halfGap, 1e-6));
    expect(tester.getTopLeft(find.byKey(previousKey)).dx, lessThanOrEqualTo(-300), reason: 'gap 未闭合前不得先露出反向页');

    await gesture.moveBy(Offset(halfGap + 60, 0), timeStamp: const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, greaterThanOrEqualTo(300));
    expect(
      tester.getTopLeft(find.byKey(previousKey)).dx,
      inExclusiveRange(-300, 0),
      reason: '跨过零位的同一次 move 必须立即从左侧露出反向页',
    );

    await gesture.cancel(timeStamp: const Duration(milliseconds: 900));
    await _finishPageMotion(tester);
    expect(controller.index, 1);
  });

  testWidgets('PREVIEW-G13: 双项 loop 的同一目标只挂载一次，反向跨零时原子换侧', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          loop: true,
          panInertia: false,
          children: const [
            SizedBox.expand(key: ValueKey<String>('two-loop-current')),
            SizedBox.expand(key: ValueKey<String>('two-loop-target')),
          ],
        ),
      ),
    );

    const targetKey = ValueKey<String>('two-loop-target');
    expect(find.byKey(targetKey), findsOneWidget);
    final targetElement = tester.element(find.byKey(targetKey));
    final gesture = await tester.createGesture(pointer: 204, kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await gesture.down(_previewCenter(tester), timeStamp: Duration.zero);
    await gesture.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(-90, 0), timeStamp: const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));

    final targetAtRight = tester.getTopLeft(find.byKey(targetKey)).dx;
    expect(targetAtRight, inExclusiveRange(0, 300));
    final gap = 300 - targetAtRight;
    await gesture.moveBy(Offset(gap + 60, 0), timeStamp: const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(targetKey), findsOneWidget);
    expect(tester.element(find.byKey(targetKey)), same(targetElement), reason: '换侧不得重建或复制目标页');
    expect(
      tester.getTopLeft(find.byKey(targetKey)).dx,
      inExclusiveRange(-300, 0),
      reason: '双项时 previous/next 虽是同一 ID，仍必须按当前拖动方向换到左侧',
    );

    await gesture.cancel(timeStamp: const Duration(milliseconds: 800));
    await _finishPageMotion(tester);
    expect(controller.index, 0);
  });

  testWidgets('PREVIEW-G14: 高速贴近目标页松手后 spring 单调且不穿越终点', (tester) async {
    final controller = ElPreviewController();
    final committed = Completer<void>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          panInertia: false,
          onIndexChanged: (_) {
            if (!committed.isCompleted) committed.complete();
          },
          children: const [
            SizedBox.expand(key: ValueKey<String>('spring-page-0')),
            SizedBox.expand(key: ValueKey<String>('spring-page-1')),
            SizedBox.expand(key: ValueKey<String>('spring-page-2')),
          ],
        ),
      ),
    );

    const currentKey = ValueKey<String>('spring-page-0');
    final gesture = await tester.createGesture(pointer: 205, kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await gesture.down(_previewCenter(tester), timeStamp: Duration.zero);
    await gesture.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final currentX = tester.getTopLeft(find.byKey(currentKey)).dx;
    await gesture.moveBy(Offset(-230 - currentX, 0), timeStamp: const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(find.byKey(currentKey)).dx, closeTo(-230, 1e-6));

    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(Offset(-20, 0), timeStamp: Duration(milliseconds: 503 + i * 3));
      await tester.pump(const Duration(milliseconds: 3));
    }
    var previous = tester.getTopLeft(find.byKey(currentKey)).dx;
    expect(previous, closeTo(-290, 1e-6), reason: '前置条件必须停在距 -300px 终点仅 10px 处');
    await gesture.up(timeStamp: const Duration(milliseconds: 510));

    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 8));
      final current = tester.getTopLeft(find.byKey(currentKey)).dx;
      expect(current, lessThanOrEqualTo(previous + 1e-6), reason: 'spring 第 $frame 帧不得反向回摆');
      expect(current, greaterThanOrEqualTo(-300 - 1e-6), reason: 'spring 第 $frame 帧不得穿越下一页终点');
      previous = current;
    }

    await _finishPageMotion(tester);
    await committed.future.timeout(const Duration(seconds: 1));
    expect(controller.index, 1);
    expect(tester.getTopLeft(find.byKey(currentKey)).dx, closeTo(-300, 1e-6));
  });

  // 暂跳过：ElScroll 已改用官方 Scrollable 手势，不再作为 ElView 拖拽台账的 driver；
  // 待 ElView 拖拽识别器迁移到官方实现后，按新的手势归属重写本用例。
  testWidgets('PREVIEW-G15: 内部横向 Scroll 精确分账、反向归还且终速不污染 Zoom 惯性', (tester) async {
    const initialTransform = ElZoomTransform(scale: 2, offset: Offset(-150, 0));
    final preview = ElPreviewController()..jumpToTransform(initialTransform);
    final scroll = ScrollController();
    addTearDown(preview.dispose);
    addTearDown(scroll.dispose);
    const currentKey = ValueKey<String>('nested-scroll-current');
    const nextKey = ValueKey<String>('nested-scroll-next');

    await tester.pumpWidget(
      _nestedHorizontalScrollPreview(preview: preview, scroll: scroll, currentKey: currentKey, nextKey: nextKey),
    );
    scroll.jumpTo(200);
    await tester.pump();
    final nextBaseX = tester.getTopLeft(find.byKey(nextKey)).dx;

    final middle = await tester.createGesture(pointer: 211, kind: PointerDeviceKind.touch);
    addTearDown(middle.removePointer);
    await middle.down(_previewCenter(tester), timeStamp: Duration.zero);
    await middle.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final scrollAfterAccept = scroll.offset;
    await middle.moveBy(const Offset(-40, 0), timeStamp: const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));

    expect(scroll.offset, closeTo(scrollAfterAccept + 40, 1e-6), reason: '内部 Scroll 未到边界时应独占全部位移');
    expect(preview.currentTransform, initialTransform, reason: '后代 Scroll 能消费时 Zoom 不得并行平移');
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextBaseX, 1e-6), reason: '内部 Scroll 未到边界时不得露页');
    await middle.cancel(timeStamp: const Duration(milliseconds: 400));
    await tester.pump();

    final maxScroll = scroll.position.maxScrollExtent;
    scroll.jumpTo(maxScroll);
    await tester.pump();
    final edge = await tester.createGesture(pointer: 212, kind: PointerDeviceKind.touch);
    addTearDown(edge.removePointer);
    await edge.down(_previewCenter(tester), timeStamp: Duration.zero);
    await edge.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await edge.moveBy(const Offset(-70, 0), timeStamp: const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));

    expect(scroll.offset, closeTo(maxScroll, 1e-6));
    expect(preview.currentTransform, initialTransform);
    final nextAtGap = tester.getTopLeft(find.byKey(nextKey)).dx;
    expect(nextBaseX - nextAtGap, closeTo(70, 1e-6), reason: '内部 Scroll 与 Zoom 都在边界时，当帧 70px 余量必须完整交给 pager');

    await edge.moveBy(const Offset(90, 0), timeStamp: const Duration(milliseconds: 316));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextBaseX, 1e-6), reason: '反向位移必须先闭合 70px page gap');
    expect(scroll.offset, closeTo(maxScroll - 20, 1e-6), reason: '闭合 gap 后的同帧 20px 余量必须立即还给内部 Scroll');
    expect(preview.currentTransform, initialTransform);

    await edge.moveBy(const Offset(20, 0), timeStamp: const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 4));
    await edge.moveBy(const Offset(20, 0), timeStamp: const Duration(milliseconds: 324));
    await tester.pump(const Duration(milliseconds: 4));
    final scrollBeforeUp = scroll.offset;
    await edge.up(timeStamp: const Duration(milliseconds: 328));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    expect(scroll.offset, lessThan(scrollBeforeUp), reason: '反向末速应只交给实际消费过位移的内部 Scroll');
    expect(preview.currentTransform, initialTransform, reason: 'Zoom 未消费本次 Scroll 位移，松手后不得偷用整段 velocity 启动惯性');
    expect(preview.index, 0);
  }, skip: true);

  // 暂跳过：ElScroll 已改用官方 Scrollable 手势，不再作为 ElView 拖拽台账的 driver；
  // 待 ElView 拖拽识别器迁移到官方实现后，按新的手势归属重写本用例。
  testWidgets('PREVIEW-G16: 内部 Scroll 已消费第一指时第二指 4px span 原子升级且矩阵连续', (tester) async {
    final preview = ElPreviewController();
    final scroll = ScrollController();
    addTearDown(preview.dispose);
    addTearDown(scroll.dispose);
    const currentKey = ValueKey<String>('reserved-scroll-current');
    const nextKey = ValueKey<String>('reserved-scroll-next');

    await tester.pumpWidget(
      _nestedHorizontalScrollPreview(
        preview: preview,
        scroll: scroll,
        currentKey: currentKey,
        nextKey: nextKey,
        panInertia: false,
      ),
    );
    scroll.jumpTo(200);
    await tester.pump();
    final nextBaseX = tester.getTopLeft(find.byKey(nextKey)).dx;

    const firstStart = Offset(230, 100);
    var firstPosition = firstStart;
    final first = await tester.createGesture(pointer: 213, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 214, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    await first.down(firstStart, timeStamp: Duration.zero);
    const acceptDelta = Offset(-30, 0);
    firstPosition += acceptDelta;
    await first.moveBy(acceptDelta, timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    const consumedDelta = Offset(-40, 0);
    firstPosition += consumedDelta;
    await first.moveBy(consumedDelta, timeStamp: const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll.offset, greaterThan(200), reason: '前置条件：第一指已让内部 Scroll 实际消费位移');
    final scrollAtJoin = scroll.offset;

    const secondPosition = Offset(60, 100);
    final focal = (firstPosition + secondPosition) / 2;
    final matrixBeforeJoin = _globalMatrix(tester, currentKey);
    final inverseBeforeJoin = Matrix4.copy(matrixBeforeJoin)..invert();
    final contentPointAtFocal = MatrixUtils.transformPoint(inverseBeforeJoin, focal);

    await second.down(secondPosition, timeStamp: const Duration(milliseconds: 216));
    await tester.pump(const Duration(milliseconds: 16));
    final matrixAfterJoin = _globalMatrix(tester, currentKey);
    _expectMatrixClose(matrixAfterJoin, matrixBeforeJoin);
    _expectOffset(MatrixUtils.transformPoint(matrixAfterJoin, contentPointAtFocal), focal);
    expect(scroll.offset, closeTo(scrollAtJoin, 1e-6));

    await second.moveBy(const Offset(-4, 0), timeStamp: const Duration(milliseconds: 232));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      preview.currentTransform.scale,
      closeTo(_defaultPreviewScale(1.04), 1e-6),
      reason: '第二指 down 已原子交接，4px span 不得再等待 slop',
    );
    expect(scroll.offset, closeTo(scrollAtJoin, 1e-6), reason: 'Scale 接管后内部 Scroll 必须停在交接位置');
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextBaseX, 1e-6));

    await first.up(timeStamp: const Duration(milliseconds: 240));
    await second.up(timeStamp: const Duration(milliseconds: 248));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    expect(scroll.offset, closeTo(scrollAtJoin, 1e-6), reason: 'Scale 接管必须 cancel 旧 Scroll，终态后不得残留惯性');

    final resumed = await tester.createGesture(pointer: 215, kind: PointerDeviceKind.touch);
    addTearDown(resumed.removePointer);
    await resumed.down(_previewCenter(tester), timeStamp: const Duration(seconds: 1));
    await resumed.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 100));
    final beforeResume = scroll.offset;
    await resumed.moveBy(const Offset(-40, 0), timeStamp: const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scroll.offset, greaterThan(beforeResume), reason: '旧 pipeline 结清后下一次内部 Scroll 手势必须正常恢复');
    await resumed.cancel(timeStamp: const Duration(milliseconds: 1400));
    await tester.pump();
    expect(preview.index, 0);
  }, skip: true);

  // 暂跳过：ElScroll 已改用官方 Scrollable 手势，不再作为 ElView 拖拽台账的 driver；
  // 待 ElView 拖拽识别器迁移到官方实现后，按新的手势归属重写本用例。
  testWidgets('PREVIEW-G17: 第二指落在 pipeline 露出的邻页时仍原子收回 gap 并升级 Scale', (tester) async {
    final preview = ElPreviewController();
    final scroll = ScrollController();
    addTearDown(preview.dispose);
    addTearDown(scroll.dispose);
    const currentKey = ValueKey<String>('exposed-join-current');
    const nextKey = ValueKey<String>('exposed-join-next');

    await tester.pumpWidget(
      _nestedHorizontalScrollPreview(
        preview: preview,
        scroll: scroll,
        currentKey: currentKey,
        nextKey: nextKey,
        panInertia: false,
      ),
    );
    final maxScroll = scroll.position.maxScrollExtent;
    scroll.jumpTo(maxScroll);
    await tester.pump();

    const firstStart = Offset(260, 100);
    var firstPosition = firstStart;
    final first = await tester.createGesture(pointer: 216, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 217, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    await first.down(firstStart, timeStamp: Duration.zero);
    const acceptDelta = Offset(-30, 0);
    firstPosition += acceptDelta;
    await first.moveBy(acceptDelta, timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    const gapDelta = Offset(-70, 0);
    firstPosition += gapDelta;
    await first.moveBy(gapDelta, timeStamp: const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));

    expect(scroll.offset, closeTo(maxScroll, 1e-6));
    final nextRectAtGap = tester.getRect(find.byKey(nextKey));
    expect(nextRectAtGap.left, closeTo(230, 1e-6), reason: '前置条件：pipeline 必须已拉出精确 70px 邻页');
    const secondPosition = Offset(260, 100);
    expect(nextRectAtGap.contains(secondPosition), isTrue, reason: '第二指必须真实落在已露出的邻页区域');

    final focal = (firstPosition + secondPosition) / 2;
    final matrixBeforeJoin = _globalMatrix(tester, currentKey);
    final inverseBeforeJoin = Matrix4.copy(matrixBeforeJoin)..invert();
    final contentPointAtFocal = MatrixUtils.transformPoint(inverseBeforeJoin, focal);
    await second.down(secondPosition, timeStamp: const Duration(milliseconds: 216));
    await tester.pump(const Duration(milliseconds: 16));

    final matrixAfterJoin = _globalMatrix(tester, currentKey);
    final layerCenterAfterJoin = tester.getCenter(find.byKey(currentKey));
    _expectMatrixClose(matrixAfterJoin, matrixBeforeJoin);
    _expectOffset(MatrixUtils.transformPoint(matrixAfterJoin, contentPointAtFocal), focal);
    expect(tester.getRect(find.byKey(nextKey)), nextRectAtGap, reason: '收回 pager 所有权的 down 帧不得让邻页视觉跳变');
    expect(scroll.offset, closeTo(maxScroll, 1e-6));

    await second.moveBy(const Offset(4, 0), timeStamp: const Duration(milliseconds: 232));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      preview.currentTransform.scale,
      closeTo(_defaultPreviewScale(1.04), 1e-6),
      reason: '邻页落点不在 Scroll driver 链上，仍必须使用首指保留的 Scale reservation',
    );
    _expectOffset(tester.getCenter(find.byKey(currentKey)), layerCenterAfterJoin);
    expect(scroll.offset, closeTo(maxScroll, 1e-6));
    expect(preview.index, 0);

    await first.up(timeStamp: const Duration(milliseconds: 240));
    await second.up(timeStamp: const Duration(milliseconds: 248));
    await _finishPageMotion(tester);
    expect(preview.index, 0, reason: '第二指加入后本次 page drag 必须取消，不得沿用旧 gap 提交页');
  }, skip: true);

  testWidgets('PREVIEW-G18: 空闲双指未过 Scale slop 时 pager 仍受多指门禁', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    const nextKey = ValueKey<String>('preview-page-1');
    final nextBaseX = tester.getTopLeft(find.byKey(nextKey)).dx;

    final first = await tester.createGesture(pointer: 218, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 219, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    await first.down(const Offset(100, 100), timeStamp: Duration.zero);
    await second.down(const Offset(200, 100), timeStamp: const Duration(milliseconds: 1));
    var time = 1;
    for (var i = 0; i < 3; i++) {
      time += 16;
      await first.moveBy(const Offset(-10, 0), timeStamp: Duration(milliseconds: time));
      await tester.pump(const Duration(milliseconds: 16));
      time += 16;
      await second.moveBy(const Offset(-10, 0), timeStamp: Duration(milliseconds: time));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.currentTransform, const ElZoomTransform(), reason: '两指同向平移且 span 不变，前置窗口仍未成立 Scale');
    expect(
      tester.getTopLeft(find.byKey(nextKey)).dx,
      closeTo(nextBaseX, 1e-6),
      reason: '第二指 down 不得把计数清回 1 并让 pager 在 Scale slop 前抢跑',
    );

    time += 16;
    await second.moveBy(const Offset(40, 0), timeStamp: Duration(milliseconds: time));
    await tester.pump(const Duration(milliseconds: 16));
    time += 16;
    await second.moveBy(const Offset(20, 0), timeStamp: Duration(milliseconds: time));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.currentTransform.scale, greaterThan(1), reason: '越过 Scale slop 后 pinch 必须正常接管');
    expect(controller.index, 0);

    await first.up(timeStamp: Duration(milliseconds: time + 8));
    await second.up(timeStamp: Duration(milliseconds: time + 16));
    await tester.pump();

    controller.jumpToTransform(const ElZoomTransform());
    final remaining = await tester.createGesture(pointer: 247, kind: PointerDeviceKind.touch);
    final lifted = await tester.createGesture(pointer: 248, kind: PointerDeviceKind.touch);
    await remaining.down(const Offset(100, 100));
    await lifted.down(const Offset(200, 100));
    await lifted.up();
    await remaining.moveBy(const Offset(-20, 0));
    await tester.pump();
    await remaining.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, lessThan(nextBaseX), reason: '未过变换阈值退回单指后必须恢复翻页');
    await remaining.cancel();
    await _finishPageMotion(tester);
  });

  testWidgets('PREVIEW-D1: 默认 wheel 围绕光标缩放并阻止平台重复处理', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    const pageKey = ValueKey<String>('preview-page-0');
    const cursor = Offset(100, 100);
    final anchored = MatrixUtils.transformPoint(Matrix4.copy(_globalMatrix(tester, pageKey))..invert(), cursor);
    bool? platformDefaultAllowed;

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: cursor,
        scrollDelta: const Offset(0, -100),
        onRespond: ({required bool allowPlatformDefault}) => platformDefaultAllowed = allowPlatformDefault,
      ),
    );
    await tester.pump();
    final targetScale = math.exp(0.2);
    final samples = <double>[];
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      samples.add(controller.currentTransform.scale);
      final projected = MatrixUtils.transformPoint(_globalMatrix(tester, pageKey), anchored);
      expect(projected.dx, closeTo(cursor.dx, 1e-5));
      expect(projected.dy, closeTo(cursor.dy, 1e-5));
    }

    expect(samples.first, inExclusiveRange(1, targetScale), reason: '首个动画帧必须位于起终值之间，不能瞬间跳到目标');
    expect(samples[1], greaterThan(samples[0]));
    expect(samples[2], greaterThan(samples[1]));
    expect(samples[3], greaterThan(samples[2]));
    expect(samples.take(3), everyElement(lessThan(targetScale)));
    expect(samples.last, closeTo(targetScale, 1e-9));
    expect(platformDefaultAllowed, isFalse);
  });

  testWidgets('PREVIEW-D2: mouseDragPan 只控制鼠标主键翻页，触摸不受影响', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));

    final mouse = await tester.createGesture(pointer: 181, kind: PointerDeviceKind.mouse);
    await mouse.down(_previewCenter(tester));
    for (var i = 0; i < 5; i++) {
      await mouse.moveBy(const Offset(-40, 0));
      await tester.pump();
    }
    await mouse.up();
    await _finishPageMotion(tester);
    expect(controller.index, 1);

    controller.jumpToIndex(0);
    await tester.pumpWidget(_plainPreview(controller, mouseDragPan: false));
    final disabledMouse = await tester.createGesture(pointer: 182, kind: PointerDeviceKind.mouse);
    await disabledMouse.down(_previewCenter(tester));
    for (var i = 0; i < 5; i++) {
      await disabledMouse.moveBy(const Offset(-40, 0));
      await tester.pump();
    }
    await disabledMouse.up();
    await tester.pump();
    expect(controller.index, 0);

    await _dragAndRelease(tester, stepDx: -40, stepCount: 5, stepDuration: const Duration(milliseconds: 40));
    await _finishPageMotion(tester);
    expect(controller.index, 1, reason: 'mouseDragPan=false 不得关闭触摸翻页');
  });

  testWidgets('PREVIEW-D3: trackpad pure-pan 由内容边界交给 pager，pinch 不产生旋转', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    await tester.pump();

    final pan = TestPointer(191, PointerDeviceKind.trackpad);
    const focal = Offset(150, 100);
    await tester.sendEventToBinding(pan.panZoomStart(focal));
    await tester.sendEventToBinding(pan.panZoomUpdate(focal, pan: const Offset(-250, 0)));
    await tester.sendEventToBinding(pan.panZoomUpdate(focal, pan: const Offset(-290, 0)));
    await tester.sendEventToBinding(pan.panZoomEnd());
    await _finishPageMotion(tester);
    expect(controller.index, 1, reason: '内容先消费到边界，剩余 -140px 应提交下一页');

    controller.jumpToIndex(0);
    await tester.pump();
    final pinch = TestPointer(192, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pinch.panZoomStart(focal));
    await tester.sendEventToBinding(pinch.panZoomUpdate(focal, scale: 1.5, rotation: 0.5));
    await tester.sendEventToBinding(pinch.panZoomEnd());
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(_defaultPreviewScale(1.5), 1e-9));
    expect(controller.currentTransform.rotation, 0, reason: '桌面 trackpad rotation 本期恒忽略');
  });

  // 暂跳过：ElScroll 已改用官方 Scrollable 手势，不再作为 ElView 拖拽台账的 driver；
  // 待 ElView 拖拽识别器迁移到官方实现后，按新的手势归属重写本用例。
  testWidgets('PREVIEW-D4: wheel 跨 min 后外层 ElScroll 只消费剩余量', (tester) async {
    final preview = ElPreviewController();
    final outer = ScrollController();
    addTearDown(preview.dispose);
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      _shell(
        ElScroll(
          controller: outer,
          physics: const ClampingScrollPhysics(),
          smoothScroll: null,
          children: [
            SizedBox(
              height: 200,
              child: ElPreviewView(
                controller: preview,
                minScale: 1,
                maxScale: 2,
                panInertia: false,
                children: const [SizedBox.expand(), SizedBox.expand()],
              ),
            ),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    );
    preview.jumpToTransform(const ElZoomTransform(scale: 2));
    await tester.pump();

    await tester.sendEventToBinding(
      PointerScrollEvent(position: const Offset(100, 100), scrollDelta: const Offset(0, 1000)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final expectedRemainder = 1000 - math.log(2) / 0.002;
    expect(preview.currentTransform.scale, closeTo(1, 1e-9));
    expect(outer.offset, closeTo(expectedRemainder, 1e-6), reason: 'Scroll resolver 不得在 flush 时重新吃原始 1000px');
  }, skip: true);

  testWidgets('PREVIEW-D5: trackpad 半页后 pinch 转入 transform，不误提交页面', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    final pointer = TestPointer(193, PointerDeviceKind.trackpad);
    const pageKey = ValueKey<String>('preview-page-0');
    const nextKey = ValueKey<String>('preview-page-1');
    const focal = Offset(90, 80);
    final pageBaseX = tester.getTopLeft(find.byKey(pageKey)).dx;
    final nextBaseX = tester.getTopLeft(find.byKey(nextKey)).dx;

    await tester.sendEventToBinding(pointer.panZoomStart(focal));
    await tester.sendEventToBinding(pointer.panZoomUpdate(focal, pan: const Offset(-120, 0)));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(pageKey)).dx, closeTo(pageBaseX - 120, 1e-6));
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextBaseX - 120, 1e-6));
    final contentPointUnderCursor = MatrixUtils.transformPoint(
      Matrix4.copy(_globalMatrix(tester, pageKey))..invert(),
      focal,
    );
    await tester.sendEventToBinding(pointer.panZoomUpdate(focal, pan: const Offset(-120, 0), scale: 1.5));
    await tester.pump();
    final projected = MatrixUtils.transformPoint(_globalMatrix(tester, pageKey), contentPointUnderCursor);
    expect(projected.dx, closeTo(focal.dx, 1e-5), reason: '半页交接后必须继续围绕未移动的鼠标横坐标缩放');
    expect(projected.dy, closeTo(focal.dy, 1e-5), reason: '半页交接后必须继续围绕未移动的鼠标纵坐标缩放');
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await _finishPageMotion(tester);

    expect(controller.index, 0, reason: 'pinch 接管半页后不得沿用旧 page threshold 提交');
    expect(controller.currentTransform.scale, closeTo(_defaultPreviewScale(1.5), 1e-9));
  });

  testWidgets('PREVIEW-D6: page 回弹中空 trackpad stream 不冻结半页', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    const pageKey = ValueKey<String>('preview-page-0');
    final baseX = tester.getTopLeft(find.byKey(pageKey)).dx;
    await _dragAndRelease(tester, stepDx: -20, stepCount: 4, stepDuration: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 40));
    final beforeStreamX = tester.getTopLeft(find.byKey(pageKey)).dx;
    expect(beforeStreamX, lessThan(baseX - 1));

    final pointer = TestPointer(194, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(const Offset(150, 100)));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      tester.getTopLeft(find.byKey(pageKey)).dx,
      lessThan(baseX - 1),
      reason: '没有位移的 trackpad stream 不得把正在回弹的页面瞬间归零',
    );
    await _finishPageMotion(tester);

    expect(controller.index, 0);
    expect(tester.getTopLeft(find.byKey(pageKey)).dx, closeTo(baseX, 1e-6));
  });

  testWidgets('PREVIEW-D7: trackpad 捏合越过 max 后有限弹性并在结束时回弹', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller, maxScale: 2));
    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    await tester.pump();

    final pointer = TestPointer(195, PointerDeviceKind.trackpad);
    const pageKey = ValueKey<String>('preview-page-0');
    const cursor = Offset(90, 80);
    final contentPointUnderCursor = MatrixUtils.transformPoint(
      Matrix4.copy(_globalMatrix(tester, pageKey))..invert(),
      cursor,
    );
    await tester.sendEventToBinding(pointer.panZoomStart(cursor));
    await tester.sendEventToBinding(pointer.panZoomUpdate(cursor, scale: 2));
    await tester.pump();
    final elasticScale = controller.currentTransform.scale;
    expect(elasticScale, greaterThan(2), reason: '直接捏合越过 max 时必须继续提供可见反馈');
    expect(elasticScale, lessThanOrEqualTo(2 * 1.15 + 1e-9), reason: '弹性视觉上限不得超过硬边界的 15%');
    _expectOffset(MatrixUtils.transformPoint(_globalMatrix(tester, pageKey), contentPointUnderCursor), cursor);

    await tester.sendEventToBinding(pointer.panZoomEnd());
    expect(controller.currentTransform.scale, closeTo(elasticScale, 1e-9), reason: '结束事件只启动回弹，不得同步跳回');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(controller.currentTransform.scale, inInclusiveRange(2, elasticScale));
    expect(controller.currentTransform.scale, lessThan(elasticScale));
    _expectOffset(MatrixUtils.transformPoint(_globalMatrix(tester, pageKey), contentPointUnderCursor), cursor);
    await tester.pumpAndSettle();
    expect(controller.currentTransform.scale, closeTo(2, 1e-9));
    _expectOffset(MatrixUtils.transformPoint(_globalMatrix(tester, pageKey), contentPointUnderCursor), cursor);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('PREVIEW-D8: trackpad 弹性在 Removed、边界热更新和新手势中断时正确沉降', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller, maxScale: 2));
    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    await tester.pump();
    const cursor = Offset(90, 80);

    final removed = TestPointer(196, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(removed.panZoomStart(cursor));
    await tester.sendEventToBinding(removed.panZoomUpdate(cursor, scale: 2));
    await tester.pump();
    expect(controller.currentTransform.scale, greaterThan(2));
    await tester.sendEventToBinding(removed.removePointer());
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(2, 1e-9), reason: 'Removed 必须同步清除瞬态越界值');
    expect(tester.binding.hasScheduledFrame, isFalse);

    final bounded = TestPointer(197, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(bounded.panZoomStart(cursor));
    await tester.sendEventToBinding(bounded.panZoomUpdate(cursor, scale: 2));
    await tester.sendEventToBinding(bounded.panZoomEnd());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(controller.currentTransform.scale, greaterThan(2));
    await tester.pumpWidget(_plainPreview(controller, maxScale: 1.5));
    expect(controller.currentTransform.scale, closeTo(1.5, 1e-9));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.currentTransform.scale, closeTo(1.5, 1e-9), reason: '旧 spring 不得在下一帧恢复旧 max');

    await tester.pumpWidget(_plainPreview(controller, maxScale: 2));
    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    final first = TestPointer(198, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(first.panZoomStart(cursor));
    await tester.sendEventToBinding(first.panZoomUpdate(cursor, scale: 2));
    await tester.sendEventToBinding(first.panZoomEnd());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final interruptedScale = controller.currentTransform.scale;
    expect(interruptedScale, greaterThan(2));
    final second = TestPointer(199, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(second.panZoomStart(cursor));
    expect(controller.currentTransform.scale, closeTo(interruptedScale, 1e-9), reason: '新直接手势必须从当前视觉值无跳变接手');
    await tester.sendEventToBinding(second.panZoomUpdate(cursor, scale: 1.05));
    await tester.sendEventToBinding(second.panZoomEnd());
    await tester.pumpAndSettle();
    expect(controller.currentTransform.scale, closeTo(2, 1e-9));

    final rebounding = TestPointer(201, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(rebounding.panZoomStart(cursor));
    await tester.sendEventToBinding(rebounding.panZoomUpdate(cursor, scale: 2));
    await tester.sendEventToBinding(rebounding.panZoomEnd());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final emptyStreamScale = controller.currentTransform.scale;
    final empty = TestPointer(202, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(empty.panZoomStart(cursor));
    expect(controller.currentTransform.scale, closeTo(emptyStreamScale, 1e-9));
    await tester.sendEventToBinding(empty.panZoomEnd());
    await tester.pumpAndSettle();
    expect(controller.currentTransform.scale, closeTo(2, 1e-9), reason: '空 PanZoom stream 中断回弹后也必须重新归界');
  });

  testWidgets('PREVIEW-D9: 回弹归界回调中启动的新动画不会被旧终态清除', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller, maxScale: 2));
    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    var armed = false;
    var launched = false;
    Future<void>? command;
    controller.addListener(() {
      if (!armed || launched || (controller.currentTransform.scale - 2).abs() > 1e-9) return;
      launched = true;
      command = controller.animateTransform(const ElZoomTransform(scale: 1.5));
    });

    final pointer = TestPointer(200, PointerDeviceKind.trackpad);
    const cursor = Offset(90, 80);
    await tester.sendEventToBinding(pointer.panZoomStart(cursor));
    await tester.sendEventToBinding(pointer.panZoomUpdate(cursor, scale: 2));
    await tester.pump();
    armed = true;
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pumpAndSettle();
    await command;

    expect(launched, isTrue);
    expect(controller.currentTransform.scale, closeTo(1.5, 1e-9));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('PREVIEW-D10: 高 DPI 竖图在中心触控板捏合时忽略同步 pan', (tester) async {
    tester.view.physicalSize = const Size(2216, 1106);
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    const previewKey = ValueKey<String>('screenshot-preview');
    const portraitKey = ValueKey<String>('screenshot-portrait');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          padding: const EdgeInsets.only(left: 48, top: 32, right: 32, bottom: 24),
          child: ElPreviewView(
            key: previewKey,
            controller: controller,
            panInertia: false,
            children: const [
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(key: portraitKey, width: 450.7, height: 800),
              ),
            ],
          ),
        ),
      ),
    );
    controller.jumpToTransform(const ElZoomTransform(scale: 1.22826));
    await tester.pump();

    final cursor = tester.getRect(find.byKey(previewKey)).center;
    _expectOffset(tester.getCenter(find.byKey(portraitKey)), cursor);
    final contentPointUnderCursor = MatrixUtils.transformPoint(
      Matrix4.copy(_globalMatrix(tester, portraitKey))..invert(),
      cursor,
    );
    final pointer = TestPointer(203, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(cursor));
    await tester.sendEventToBinding(pointer.panZoomUpdate(cursor, pan: const Offset(-495.34, -311.03), scale: 1.64283));
    await tester.pump();

    final projected = MatrixUtils.transformPoint(_globalMatrix(tester, portraitKey), contentPointUnderCursor);
    _expectOffset(projected, cursor, epsilon: 1e-5);
    expect(controller.currentTransform.scale, closeTo(1.22826 * _defaultPreviewScale(1.64283), 1e-9));
    await tester.sendEventToBinding(pointer.panZoomEnd());
  });

  testWidgets('PREVIEW-G19: touch 捏合在 min/max 两端弹性受限，reduced motion 结束时同步归位', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller, maxScale: 2));
    const pageKey = ValueKey<String>('preview-page-0');

    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    await tester.pump();
    final maxFirst = await tester.createGesture(pointer: 211, kind: PointerDeviceKind.touch);
    final maxSecond = await tester.createGesture(pointer: 212, kind: PointerDeviceKind.touch);
    await maxFirst.down(const Offset(100, 100), timeStamp: Duration.zero);
    await maxSecond.down(const Offset(200, 100), timeStamp: Duration.zero);
    await maxSecond.moveTo(const Offset(260, 100), timeStamp: const Duration(milliseconds: 16));
    await maxSecond.moveTo(const Offset(420, 100), timeStamp: const Duration(milliseconds: 32));
    await tester.pump();
    final aboveMax = controller.currentTransform.scale;
    expect(aboveMax, greaterThan(2));
    expect(aboveMax, lessThanOrEqualTo(2 * 1.15 + 1e-9));
    await maxFirst.up(timeStamp: const Duration(milliseconds: 40));
    await maxSecond.up(timeStamp: const Duration(milliseconds: 48));
    expect(controller.currentTransform.scale, closeTo(aboveMax, 1e-9));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 8));
    final inertialPeak = controller.currentTransform.scale;
    expect(inertialPeak, lessThan(aboveMax), reason: '默认关闭惯性时，越界松手必须立即反向回弹，不能继续外冲');
    await tester.pump(const Duration(milliseconds: 60));
    expect(controller.currentTransform.scale, inInclusiveRange(2, inertialPeak));
    expect(controller.currentTransform.scale, lessThan(inertialPeak));
    await tester.pumpAndSettle();
    expect(controller.currentTransform.scale, closeTo(2, 1e-9));

    controller.jumpToTransform(const ElZoomTransform(scale: 1.4));
    await tester.pump();
    final minFirst = await tester.createGesture(pointer: 213, kind: PointerDeviceKind.touch);
    final minSecond = await tester.createGesture(pointer: 214, kind: PointerDeviceKind.touch);
    await minFirst.down(const Offset(100, 100));
    await minSecond.down(const Offset(250, 100));
    await minSecond.moveTo(const Offset(190, 100));
    await minSecond.moveTo(const Offset(120, 100));
    await tester.pump();
    final belowMin = controller.currentTransform.scale;
    expect(belowMin, lessThan(1));
    expect(belowMin, greaterThanOrEqualTo(1 / 1.15 - 1e-9));
    await minFirst.up();
    await minSecond.up();
    expect(controller.currentTransform.scale, closeTo(belowMin, 1e-9));
    var previousTranslation = _globalMatrix(tester, pageKey).getTranslation().x;
    var maxTranslationStep = 0.0;
    for (var frame = 0; frame < 40 && tester.binding.hasScheduledFrame; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final translation = _globalMatrix(tester, pageKey).getTranslation().x;
      maxTranslationStep = math.max(maxTranslationStep, (translation - previousTranslation).abs());
      previousTranslation = translation;
    }
    expect(controller.currentTransform.scale, closeTo(1, 1e-9));
    expect(previousTranslation, closeTo(0, 1e-6));
    expect(maxTranslationStep, lessThan(20), reason: 'min 回弹的 offset 必须随 spring 连续收敛，末帧不得跳回中心');

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    final reducedFirst = await tester.createGesture(pointer: 215, kind: PointerDeviceKind.touch);
    final reducedSecond = await tester.createGesture(pointer: 216, kind: PointerDeviceKind.touch);
    await reducedFirst.down(const Offset(100, 100));
    await reducedSecond.down(const Offset(200, 100));
    await reducedSecond.moveTo(const Offset(260, 100));
    await reducedSecond.moveTo(const Offset(420, 100));
    expect(controller.currentTransform.scale, greaterThan(2), reason: 'reduced motion 仍保留手指直接操控反馈');
    await reducedFirst.up();
    await reducedSecond.up();
    expect(controller.currentTransform.scale, closeTo(2, 1e-9), reason: 'reduced motion 松手后必须同步归位');
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('PREVIEW-G20: 缩放锁定经单指平移后重新补指可选择旋转且矩阵连续', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    const contentKey = ValueKey<String>('reentered-rotation-content');
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          panInertia: false,
          scaleInertia: false,
          children: const [
            SizedBox.expand(key: contentKey),
            SizedBox.expand(),
          ],
        ),
      ),
    );

    final first = await tester.createGesture(pointer: 221, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 222, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    await first.down(const Offset(50, 100), timeStamp: Duration.zero);
    await second.down(const Offset(150, 100), timeStamp: Duration.zero);
    await second.moveTo(const Offset(190, 100), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(195.245326, 110.156543), timeStamp: const Duration(milliseconds: 32));
    expect(
      controller.currentTransform.scale,
      closeTo(_defaultPreviewScale(1.04), 1e-6),
      reason: 'Scale 已成立后首个有效跨度变化必须同步呈现，不能再等第二层死区',
    );
    expect(controller.currentTransform.rotation, 0);

    await second.moveTo(const Offset(198.979380, 115.658364), timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(_defaultPreviewScale(1.07), 1e-6));

    await first.moveTo(const Offset(102.5, 9.067333), timeStamp: const Duration(milliseconds: 48));
    await second.moveTo(const Offset(207.5, 190.932667), timeStamp: const Duration(milliseconds: 64));
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(_defaultPreviewScale(1.5), 1e-6));
    expect(controller.currentTransform.rotation, closeTo(0, 1e-9), reason: '同一手势锁定缩放后不得再切换为旋转');
    expect(controller.index, 0);
    final beforeFirstLift = controller.currentTransform;
    await first.up(timeStamp: const Duration(milliseconds: 80));
    expect(controller.currentTransform, beforeFirstLift, reason: '双指减为单指的拓扑帧不得改变矩阵');
    final beforeSinglePan = controller.currentTransform;
    await second.moveBy(const Offset(18, -7), timeStamp: const Duration(milliseconds: 96));
    expect(controller.currentTransform.scale, closeTo(beforeSinglePan.scale, 1e-9));
    expect(controller.currentTransform.rotation, closeTo(beforeSinglePan.rotation, 1e-9));
    _expectOffset(controller.currentTransform.offset, beforeSinglePan.offset + const Offset(18, -7));

    final third = await tester.createGesture(pointer: 223, kind: PointerDeviceKind.touch);
    addTearDown(third.removePointer);
    const center = Offset(175.5, 183.932667);
    final beforeReentry = Matrix4.copy(_globalMatrix(tester, contentKey));
    await third.down(const Offset(125.5, 183.932667), timeStamp: const Duration(milliseconds: 112));
    await tester.pump();
    _expectMatrixClose(_globalMatrix(tester, contentKey), beforeReentry);

    for (var degrees = 1; degrees <= 50; degrees++) {
      final radians = degrees * math.pi / 180;
      final radius = Offset(math.cos(radians) * 50, math.sin(radians) * 50);
      final time = Duration(milliseconds: 112 + degrees * 16);
      await second.moveTo(center + radius, timeStamp: time - const Duration(milliseconds: 8));
      await third.moveTo(center - radius, timeStamp: time);
    }
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(beforeSinglePan.scale, 1e-6));
    const reenteredRotation = 50 * math.pi / 180;
    expect(controller.currentTransform.rotation, closeTo(reenteredRotation, 1e-6), reason: '重新补入第二指必须开启新的意图片段');

    final beforeSecondLift = controller.currentTransform;
    await third.up(timeStamp: const Duration(milliseconds: 928));
    expect(controller.currentTransform, beforeSecondLift, reason: '旋转阶段减为单指的拓扑帧不得改变矩阵');
    expect(controller.currentTransform.rotation, closeTo(reenteredRotation, 1e-6), reason: '减为单指时不得提前吸附角度');
    await second.up(timeStamp: const Duration(milliseconds: 944));
    expect(controller.currentTransform.rotation, closeTo(reenteredRotation, 1e-6), reason: '最后一指抬起后才开始吸附动画');
    await tester.pumpAndSettle();
    expect(controller.currentTransform.rotation, closeTo(math.pi / 2, 1e-9));
  });

  testWidgets('PREVIEW-G21: touch 旋转意图允许同步缩放并在松手后只吸附角度', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));

    final first = await tester.createGesture(pointer: 225, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 226, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    await first.down(const Offset(100, 100), timeStamp: Duration.zero);
    await second.down(const Offset(200, 100), timeStamp: Duration.zero);
    await second.moveTo(const Offset(240, 100), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(200.974848, 200.974848), timeStamp: const Duration(milliseconds: 32));
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(_defaultPreviewScale(1.02), 1e-6));
    expect(controller.currentTransform.rotation, closeTo(math.pi / 4, 1e-6));

    await second.moveTo(const Offset(297.989899, 297.989899), timeStamp: const Duration(milliseconds: 48));
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(_defaultPreviewScale(2), 1e-6), reason: '旋转通道不得屏蔽同步 pinch');
    expect(controller.currentTransform.rotation, closeTo(math.pi / 4, 1e-6));
    final releasedTransform = controller.currentTransform;
    await first.up(timeStamp: const Duration(milliseconds: 64));
    await second.up(timeStamp: const Duration(milliseconds: 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    expect(controller.currentTransform.scale, closeTo(releasedTransform.scale, 1e-6), reason: 'Preview 默认关闭缩放惯性');
    expect(controller.currentTransform.rotation, inInclusiveRange(releasedTransform.rotation, math.pi / 2));
    _expectOffset(controller.currentTransform.offset, releasedTransform.offset);
    await tester.pumpAndSettle();
    expect(controller.currentTransform.rotation, closeTo(math.pi / 2, 1e-9));
    _expectOffset(controller.currentTransform.offset, releasedTransform.offset);
    expect(controller.index, 0);
  });

  testWidgets('PREVIEW-G22: enableRotation=false 保持原缩放快路与惯性', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          enableRotation: false,
          panInertia: false,
          scaleInertia: true,
          children: const [SizedBox.expand()],
        ),
      ),
    );

    final first = await tester.createGesture(pointer: 227, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 228, kind: PointerDeviceKind.touch);
    await first.down(const Offset(50, 100), timeStamp: Duration.zero);
    await second.down(const Offset(150, 100), timeStamp: Duration.zero);
    await second.moveTo(const Offset(210, 100), timeStamp: const Duration(milliseconds: 16));
    await second.moveTo(const Offset(250, 100), timeStamp: const Duration(milliseconds: 32));
    await second.moveTo(const Offset(290, 100), timeStamp: const Duration(milliseconds: 48));
    await tester.pump();
    final releasedScale = controller.currentTransform.scale;
    await first.up(timeStamp: const Duration(milliseconds: 56));
    await second.up(timeStamp: const Duration(milliseconds: 64));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.currentTransform.scale, greaterThan(releasedScale));
    expect(controller.currentTransform.rotation, 0);
  });

  testWidgets('PREVIEW-G23: touch 保持中心与指距也能直接进入旋转', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));

    final first = await tester.createGesture(pointer: 229, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 230, kind: PointerDeviceKind.touch);
    const center = Offset(150, 100);
    await first.down(const Offset(100, 100), timeStamp: Duration.zero);
    await second.down(const Offset(200, 100), timeStamp: Duration.zero);
    for (var degrees = 1; degrees <= 45; degrees++) {
      final radians = degrees * math.pi / 180;
      final radius = Offset(math.cos(radians) * 50, math.sin(radians) * 50);
      final time = Duration(milliseconds: degrees * 16);
      await first.moveTo(center - radius, timeStamp: time - const Duration(milliseconds: 8));
      await second.moveTo(center + radius, timeStamp: time);
    }
    await tester.pump();

    expect(controller.currentTransform.scale, closeTo(1, 1e-6));
    expect(controller.currentTransform.rotation, greaterThan(math.pi / 10), reason: '纯角向移动不得依赖预先 pinch 点火');
    await first.up();
    await second.up();
  });

  testWidgets('PREVIEW-G24: 手势中热更新旋转开关不改变本次已锁策略', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    Widget preview(bool enableRotation) => _shell(
      ElPreviewView(
        controller: controller,
        enableRotation: enableRotation,
        panInertia: false,
        scaleInertia: false,
        children: const [SizedBox.expand()],
      ),
    );

    await tester.pumpWidget(preview(true));
    final rotateFirst = await tester.createGesture(pointer: 231, kind: PointerDeviceKind.touch);
    final rotateSecond = await tester.createGesture(pointer: 232, kind: PointerDeviceKind.touch);
    await rotateFirst.down(const Offset(100, 100));
    await rotateSecond.down(const Offset(200, 100));
    await rotateSecond.moveTo(const Offset(240, 100));
    await rotateSecond.moveTo(const Offset(198.994949, 198.994949));
    await tester.pump();
    expect(controller.currentTransform.rotation, closeTo(math.pi / 4, 1e-6));

    await tester.pumpWidget(preview(false));
    await rotateSecond.moveTo(const Offset(297.989899, 297.989899));
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(_defaultPreviewScale(2), 1e-6));
    expect(controller.currentTransform.rotation, closeTo(math.pi / 4, 1e-6));
    await rotateFirst.up();
    await rotateSecond.up();

    controller.jumpToTransform(const ElZoomTransform());
    await tester.pumpWidget(preview(false));
    final scaleFirst = await tester.createGesture(pointer: 233, kind: PointerDeviceKind.touch);
    final scaleSecond = await tester.createGesture(pointer: 234, kind: PointerDeviceKind.touch);
    await scaleFirst.down(const Offset(100, 100));
    await scaleSecond.down(const Offset(200, 100));
    await scaleSecond.moveTo(const Offset(240, 100));
    await scaleSecond.moveTo(const Offset(260, 100));
    await tester.pump();
    final scale = controller.currentTransform.scale;

    await tester.pumpWidget(preview(true));
    await scaleSecond.moveTo(const Offset(213.137085, 213.137085));
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(scale, 1e-6));
    expect(controller.currentTransform.rotation, 0);
    await scaleFirst.up();
    await scaleSecond.up();
  });

  testWidgets('PREVIEW-G25: 正常双指对称缩放的每个原始 move 都不得平移图片', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          enableRotation: false,
          panInertia: false,
          scaleInertia: false,
          scaleSensitivity: 1,
          children: const [SizedBox.expand()],
        ),
      ),
    );
    controller.jumpToTransform(const ElZoomTransform(scale: 2, offset: Offset(100, 50)));
    await tester.pump();
    const stableOffset = Offset(100, 50);

    final first = await tester.createGesture(pointer: 235, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 236, kind: PointerDeviceKind.touch);
    await first.down(const Offset(60, 100));
    await second.down(const Offset(240, 100));
    for (var step = 0; step <= 3; step++) {
      await first.moveTo(Offset(90.0 + step * 8, 100));
      _expectOffset(controller.currentTransform.offset, stableOffset);
      await second.moveTo(Offset(210.0 - step * 8, 100));
      _expectOffset(controller.currentTransform.offset, stableOffset);
    }

    expect(controller.currentTransform.scale, inExclusiveRange(1, 2));
    expect(controller.currentTransform.rotation, 0);
    await first.up();
    await second.up();
    _expectOffset(controller.currentTransform.offset, stableOffset);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.currentTransform.offset.dx, inExclusiveRange(30, stableOffset.dx));
    expect(controller.currentTransform.offset.dy, inExclusiveRange(20, stableOffset.dy));
    await tester.pumpAndSettle();
    _expectOffset(controller.currentTransform.offset, const Offset(30, 20));
  });

  testWidgets('PREVIEW-G26: 正常双指旋转不平移图片，松手后就近回正', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    const contentKey = ValueKey<String>('stable-rotation-content');
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          panInertia: false,
          scaleInertia: false,
          children: const [SizedBox.expand(key: contentKey)],
        ),
      ),
    );
    controller.jumpToTransform(const ElZoomTransform(scale: 2, offset: Offset(20, -10)));
    await tester.pump();
    const stableOffset = Offset(20, -10);
    final stableVisualCenter = tester.getCenter(find.byKey(contentKey));

    final first = await tester.createGesture(pointer: 237, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 238, kind: PointerDeviceKind.touch);
    const center = Offset(150, 100);
    await first.down(const Offset(100, 100));
    await second.down(const Offset(200, 100));
    for (var degrees = 1; degrees <= 70; degrees++) {
      final radians = degrees * math.pi / 180;
      final radius = Offset(math.cos(radians) * 50, math.sin(radians) * 50);
      await first.moveTo(center - radius);
      expect(controller.currentTransform.offset.dx, closeTo(stableOffset.dx, 1e-6), reason: 'first@$degrees°');
      expect(controller.currentTransform.offset.dy, closeTo(stableOffset.dy, 1e-6), reason: 'first@$degrees°');
      _expectOffset(tester.getCenter(find.byKey(contentKey)), stableVisualCenter);
      await second.moveTo(center + radius);
      _expectOffset(controller.currentTransform.offset, stableOffset);
      _expectOffset(tester.getCenter(find.byKey(contentKey)), stableVisualCenter);
    }
    expect(controller.currentTransform.rotation, inExclusiveRange(math.pi / 4, math.pi / 2));

    await first.up();
    await second.up();
    var previousRotation = controller.currentTransform.rotation;
    for (var frame = 0; frame < 20 && tester.binding.hasScheduledFrame; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final rotation = controller.currentTransform.rotation;
      expect(rotation, inInclusiveRange(previousRotation, math.pi / 2 + 1e-9));
      _expectOffset(controller.currentTransform.offset, stableOffset);
      _expectOffset(tester.getCenter(find.byKey(contentKey)), stableVisualCenter);
      previousRotation = rotation;
    }
    expect(controller.currentTransform.rotation, closeTo(math.pi / 2, 1e-9));
    _expectOffset(controller.currentTransform.offset, stableOffset);

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    controller.jumpToTransform(const ElZoomTransform(scale: 2, offset: stableOffset));
    await tester.pump();
    final reducedFirst = await tester.createGesture(pointer: 243, kind: PointerDeviceKind.touch);
    final reducedSecond = await tester.createGesture(pointer: 244, kind: PointerDeviceKind.touch);
    await reducedFirst.down(const Offset(100, 100));
    await reducedSecond.down(const Offset(200, 100));
    for (final degrees in <int>[30, 80]) {
      final radians = degrees * math.pi / 180;
      final radius = Offset(math.cos(radians) * 50, math.sin(radians) * 50);
      await reducedFirst.moveTo(center - radius);
      _expectOffset(controller.currentTransform.offset, stableOffset);
      await reducedSecond.moveTo(center + radius);
      _expectOffset(controller.currentTransform.offset, stableOffset);
    }
    await reducedFirst.up();
    expect(controller.currentTransform.rotation, inExclusiveRange(math.pi / 4, math.pi / 2));
    await reducedSecond.up();
    expect(controller.currentTransform.rotation, closeTo(math.pi / 2, 1e-9));
    _expectOffset(controller.currentTransform.offset, stableOffset);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('PREVIEW-G27: 双指同向移动在意图未决与锁定后均不平移，减为单指后精确平移', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          panInertia: false,
          scaleInertia: false,
          children: const [SizedBox.expand()],
        ),
      ),
    );
    controller.jumpToTransform(const ElZoomTransform(scale: 2, offset: Offset(20, -10)));
    await tester.pump();
    const stableOffset = Offset(20, -10);

    final first = await tester.createGesture(pointer: 241, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 242, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    await first.down(const Offset(100, 100));
    await second.down(const Offset(200, 100));

    await first.moveBy(const Offset(1, 1));
    _expectOffset(controller.currentTransform.offset, stableOffset);
    await second.moveBy(const Offset(1, 1));
    _expectOffset(controller.currentTransform.offset, stableOffset);
    expect(controller.currentTransform.scale, 2, reason: '低于意图门限的双指同向噪声不得改变缩放');
    expect(controller.currentTransform.rotation, 0, reason: '低于意图门限的双指同向噪声不得改变旋转');

    await first.moveTo(const Offset(71, 101));
    _expectOffset(controller.currentTransform.offset, stableOffset);
    await second.moveTo(const Offset(231, 101));
    _expectOffset(controller.currentTransform.offset, stableOffset);
    await first.moveTo(const Offset(51, 101));
    _expectOffset(controller.currentTransform.offset, stableOffset);
    await second.moveTo(const Offset(251, 101));
    _expectOffset(controller.currentTransform.offset, stableOffset);
    expect(controller.currentTransform.scale, greaterThan(2.4), reason: '对称外扩必须明确锁定缩放意图');

    await first.moveBy(const Offset(12, 6));
    _expectOffset(controller.currentTransform.offset, stableOffset);
    await second.moveBy(const Offset(12, 6));
    _expectOffset(controller.currentTransform.offset, stableOffset);

    await first.up();
    final beforeSinglePan = controller.currentTransform;
    await second.moveBy(const Offset(18, -7));
    expect(controller.currentTransform.scale, closeTo(beforeSinglePan.scale, 1e-9));
    _expectOffset(controller.currentTransform.offset, beforeSinglePan.offset + const Offset(18, -7));
    await second.up();
  });

  testWidgets('PREVIEW-G28: 旋转回正只平滑修正最终朝向确实越界的 offset', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          panInertia: false,
          scaleInertia: false,
          children: const [SizedBox.expand()],
        ),
      ),
    );
    controller.jumpToTransform(const ElZoomTransform(scale: 1, rotation: math.pi / 4, offset: Offset(20, -10)));
    await tester.pump();
    const stableOffset = Offset(20, -10);

    final first = await tester.createGesture(pointer: 245, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 246, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    const center = Offset(150, 100);
    await first.down(const Offset(100, 100));
    await second.down(const Offset(200, 100));
    for (var degrees = 1; degrees <= 70; degrees++) {
      final radians = degrees * math.pi / 180;
      final radius = Offset(math.cos(radians) * 50, math.sin(radians) * 50);
      await first.moveTo(center - radius);
      _expectOffset(controller.currentTransform.offset, stableOffset);
      await second.moveTo(center + radius);
      _expectOffset(controller.currentTransform.offset, stableOffset);
    }

    await first.up();
    await second.up();
    _expectOffset(controller.currentTransform.offset, stableOffset);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.currentTransform.offset.dx, inExclusiveRange(0, stableOffset.dx));
    expect(controller.currentTransform.offset.dy, closeTo(stableOffset.dy, 1e-6));
    final interrupt = await tester.createGesture(pointer: 249, kind: PointerDeviceKind.touch);
    await interrupt.down(center);
    final interrupted = controller.currentTransform;
    await tester.pump(const Duration(milliseconds: 32));
    expect(controller.currentTransform, interrupted, reason: '新触摸必须停住旧回正动画，不能在手指下继续推进');
    await interrupt.up();
    await tester.pumpAndSettle();
    expect(controller.currentTransform.rotation, closeTo(math.pi / 2, 1e-9));
    _expectOffset(controller.currentTransform.offset, const Offset(0, -10));
  });

  testWidgets('PREVIEW-G29: 切页弹簧末段的新同向拖动跨界后立即进入下一页', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));

    await _dragAndRelease(tester, stepDx: -20, stepCount: 8, stepDuration: const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    const firstKey = ValueKey<String>('preview-page-0');
    const currentKey = ValueKey<String>('preview-page-1');
    const nextKey = ValueKey<String>('preview-page-2');
    expect(controller.index, 0, reason: '前置：第一张仍处于向第二张提交的弹簧末段');
    expect(tester.getTopLeft(find.byKey(firstKey)).dx, lessThan(-280));

    final gesture = await tester.createGesture(pointer: 251, kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    const start = Duration(seconds: 2);
    await gesture.down(_previewCenter(tester), timeStamp: start);
    await gesture.moveBy(const Offset(-30, 0), timeStamp: start + const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-20, 0), timeStamp: start + const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.index, 1, reason: '新拖动跨过旧动画终点时必须立即提交第二张，不能等弹簧结束');
    expect(tester.getTopLeft(find.byKey(currentKey)).dx, lessThan(0), reason: '跨界后的剩余位移必须继续推动第二张');
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, lessThan(300), reason: '同一手势必须立即露出第三张');
    await gesture.up(timeStamp: start + const Duration(milliseconds: 48));
    await _finishPageMotion(tester);
    expect(controller.index, 2, reason: '连续第二次快滑必须完成到第三张，不能只解除旧动画的等待');
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(0, 1e-6));
  });

  testWidgets('PREVIEW-G30: 单次长拖动跨整页后同帧余量继续推动下一页', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    final gesture = await tester.createGesture(pointer: 252, kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);

    await gesture.down(_previewCenter(tester), timeStamp: Duration.zero);
    await gesture.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-340, 0), timeStamp: const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));

    const currentKey = ValueKey<String>('preview-page-1');
    const nextKey = ValueKey<String>('preview-page-2');
    expect(controller.index, 1, reason: '手指尚未抬起时，跨过一页边界就应原子提交该页');
    expect(tester.getTopLeft(find.byKey(currentKey)).dx, closeTo(-40, 1e-6));
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(260, 1e-6), reason: '超过整页的 40px 不能被 clamp 丢弃');
    await gesture.cancel(timeStamp: const Duration(milliseconds: 48));
    await _finishPageMotion(tester);
    expect(controller.index, 1);
    expect(tester.getTopLeft(find.byKey(currentKey)).dx, closeTo(0, 1e-6));
  });

  testWidgets('PREVIEW-G31: 连续拖动跨页后可立即反向，不产生边界停顿', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    final gesture = await tester.createGesture(pointer: 253, kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);

    await gesture.down(_previewCenter(tester), timeStamp: Duration.zero);
    await gesture.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-340, 0), timeStamp: const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(100, 0), timeStamp: const Duration(milliseconds: 48));
    await tester.pump(const Duration(milliseconds: 16));

    const previousKey = ValueKey<String>('preview-page-0');
    const currentKey = ValueKey<String>('preview-page-1');
    expect(controller.index, 1);
    expect(tester.getTopLeft(find.byKey(currentKey)).dx, closeTo(60, 1e-6));
    expect(tester.getTopLeft(find.byKey(previousKey)).dx, closeTo(-240, 1e-6), reason: '反向余量必须在同一帧重新露出上一张');
    await gesture.cancel(timeStamp: const Duration(milliseconds: 64));
    await _finishPageMotion(tester);
    expect(controller.index, 1);
  });

  testWidgets('PREVIEW-G32: preloadCount=0 连续跨页也会及时挂载下一张且没有空白帧', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          panInertia: false,
          preloadCount: 0,
          children: const [
            SizedBox.expand(key: ValueKey<String>('zero-page-0')),
            SizedBox.expand(key: ValueKey<String>('zero-page-1')),
            SizedBox.expand(key: ValueKey<String>('zero-page-2')),
          ],
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('zero-page-1')), findsNothing);
    final gesture = await tester.createGesture(pointer: 254, kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);

    await gesture.down(_previewCenter(tester), timeStamp: Duration.zero);
    await gesture.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-340, 0), timeStamp: const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.index, 1);
    expect(find.byKey(const ValueKey<String>('zero-page-0')), findsNothing);
    expect(find.byKey(const ValueKey<String>('zero-page-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('zero-page-2')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('zero-page-1'))).dx, closeTo(-40, 1e-6));
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('zero-page-2'))).dx, closeTo(260, 1e-6));
    await gesture.cancel(timeStamp: const Duration(milliseconds: 48));
    await _finishPageMotion(tester);
    expect(controller.index, 1);
  });

  testWidgets('PREVIEW-G33: loop 尾页可在同一次拖动中连续越过首、次页', (tester) async {
    final controller = ElPreviewController(initialIndex: 2);
    final changes = <int>[];
    final reportedControllerIndices = <int>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          loop: true,
          panInertia: false,
          onIndexChanged: (index) {
            changes.add(index);
            reportedControllerIndices.add(controller.index!);
          },
          children: const [
            SizedBox.expand(key: ValueKey<String>('loop-page-0')),
            SizedBox.expand(key: ValueKey<String>('loop-page-1')),
            SizedBox.expand(key: ValueKey<String>('loop-page-2')),
          ],
        ),
      ),
    );
    final gesture = await tester.createGesture(pointer: 255, kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);

    await gesture.down(_previewCenter(tester), timeStamp: Duration.zero);
    await gesture.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-640, 0), timeStamp: const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.index, 1);
    expect(changes, <int>[0, 1], reason: '每个精确跨过的页边界必须按视觉顺序报告，不能跳页或重复');
    expect(reportedControllerIndices, changes, reason: '跨页回调触发前 controller 必须已同步到新 current');
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-1'))).dx, closeTo(-40, 1e-6));
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('loop-page-2'))).dx, closeTo(260, 1e-6));
    await gesture.cancel(timeStamp: const Duration(milliseconds: 48));
    await _finishPageMotion(tester);
    expect(controller.index, 1);
  });

  testWidgets('PREVIEW-D11: trackpad 单个 pan stream 跨页后可继续推动下一张', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    final pointer = TestPointer(256, PointerDeviceKind.trackpad);
    const focal = Offset(150, 100);

    await tester.sendEventToBinding(pointer.panZoomStart(focal));
    await tester.sendEventToBinding(pointer.panZoomUpdate(focal, pan: const Offset(-340, 0)));
    await tester.pump();
    expect(controller.index, 1);
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('preview-page-1'))).dx, closeTo(-40, 1e-6));
    await tester.sendEventToBinding(pointer.panZoomUpdate(focal, pan: const Offset(-360, 0)));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey<String>('preview-page-1'))).dx, closeTo(-60, 1e-6));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await _finishPageMotion(tester);
    expect(controller.index, 1);
  });

  testWidgets('PREVIEW-D12: 默认与自定义 scaleSensitivity 同时作用于 trackpad pinch', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_shell(ElPreviewView(controller: controller, children: const [SizedBox.expand()])));
    const focal = Offset(150, 100);
    final defaultPointer = TestPointer(261, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(defaultPointer.panZoomStart(focal));
    await tester.sendEventToBinding(defaultPointer.panZoomUpdate(focal, scale: 1.5));
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(_defaultPreviewScale(1.5), 1e-9));
    await tester.sendEventToBinding(defaultPointer.panZoomEnd());
    await tester.pump();

    controller.jumpToTransform(const ElZoomTransform());
    await tester.pumpWidget(
      _shell(ElPreviewView(controller: controller, scaleSensitivity: 2, children: const [SizedBox.expand()])),
    );
    final customPointer = TestPointer(262, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(customPointer.panZoomStart(focal));
    await tester.sendEventToBinding(customPointer.panZoomUpdate(focal, scale: 1.5));
    await tester.pump();
    expect(controller.currentTransform.scale, closeTo(math.pow(1.5, 2), 1e-9));
    await tester.sendEventToBinding(customPointer.panZoomEnd());
  });

  testWidgets('PREVIEW-G34: 切页弹簧中操作已放大图片会立即接管并冻结页面横坐标', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    await tester.pump();
    final command = controller.animateToIndex(1);
    var commandCompleted = false;
    unawaited(command.then((_) => commandCompleted = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    const pageKey = ValueKey<String>('preview-page-0');
    expect(tester.getTopLeft(find.byKey(pageKey)).dx, lessThan(0));

    final gesture = await tester.createGesture(pointer: 257, kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await gesture.down(_previewCenter(tester), timeStamp: Duration.zero);
    await gesture.moveBy(const Offset(0, 30), timeStamp: const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final pageXAfterTakeover = tester.getTopLeft(find.byKey(pageKey)).dx;
    final imageYAfterTakeover = controller.currentTransform.offset.dy;
    await gesture.moveBy(const Offset(0, 20), timeStamp: const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.getTopLeft(find.byKey(pageKey)).dx, closeTo(pageXAfterTakeover, 1e-6), reason: '图片拖动成立后旧切页弹簧不得继续偷跑');
    expect(controller.currentTransform.offset.dy, closeTo(imageYAfterTakeover + 20, 1e-6));
    expect(commandCompleted, isTrue, reason: '被真实手势接管的旧切页命令必须立即完成 Future');
    await gesture.up(timeStamp: const Duration(milliseconds: 48));
    await _finishPageMotion(tester);
    expect(controller.index, 1);
  });

  testWidgets('PREVIEW-G35: handoff 回零弹簧中再次横拖可立即从当前视觉位置接管', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    const pageKey = ValueKey<String>('preview-page-0');
    final first = await tester.createGesture(pointer: 258, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 259, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);

    await first.down(_previewCenter(tester), timeStamp: Duration.zero);
    await first.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await first.moveBy(const Offset(-90, 0), timeStamp: const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));
    await second.down(const Offset(250, 100), timeStamp: const Duration(milliseconds: 48));
    await tester.pump(const Duration(milliseconds: 16));
    await first.up(timeStamp: const Duration(milliseconds: 64));
    await second.up(timeStamp: const Duration(milliseconds: 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final springX = tester.getTopLeft(find.byKey(pageKey)).dx;
    expect(springX, inExclusiveRange(-90, 0));

    final takeover = await tester.createGesture(pointer: 260, kind: PointerDeviceKind.touch);
    addTearDown(takeover.removePointer);
    const takeoverStart = Duration(seconds: 2);
    await takeover.down(_previewCenter(tester), timeStamp: takeoverStart);
    await takeover.moveBy(const Offset(-30, 0), timeStamp: takeoverStart + const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final acceptedX = tester.getTopLeft(find.byKey(pageKey)).dx;
    await takeover.moveBy(const Offset(-20, 0), timeStamp: takeoverStart + const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.getTopLeft(find.byKey(pageKey)).dx, closeTo(acceptedX - 20, 1e-6), reason: 'handoff 动画不能屏蔽下一次真实横拖');
    await takeover.cancel(timeStamp: takeoverStart + const Duration(milliseconds: 48));
    await _finishPageMotion(tester);
    expect(controller.index, 0);
  });

  testWidgets('PREVIEW-G36: Scale 接管后的 PointerRemoved 仍会结束 handoff 并启动回零', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_plainPreview(controller));
    const pageKey = ValueKey<String>('preview-page-0');
    final first = await tester.createGesture(pointer: 263, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 264, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);

    await first.down(_previewCenter(tester), timeStamp: Duration.zero);
    await first.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await first.moveBy(const Offset(-90, 0), timeStamp: const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));
    await second.down(const Offset(250, 100), timeStamp: const Duration(milliseconds: 48));
    await tester.pump(const Duration(milliseconds: 16));

    await first.up(timeStamp: const Duration(milliseconds: 64));
    await second.removePointer(timeStamp: const Duration(milliseconds: 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(tester.getTopLeft(find.byKey(pageKey)).dx, inExclusiveRange(-90, 0));
    await _finishPageMotion(tester);
    expect(controller.index, 0);
  });

  testWidgets('PREVIEW-G37: ancestor loser 取消先于 direct page drag 副作用', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    final settledDuringAncestorCancel = <bool>[];
    await tester.pumpWidget(
      _shell(
        ElView(
          event: ElEvent(onTap: (_) {}, onTapCancel: (_) => settledDuringAncestorCancel.add(controller.isPageSettled)),
          child: ElPreviewView(
            controller: controller,
            panInertia: false,
            children: const [
              SizedBox.expand(key: ValueKey<String>('ordering-page-0')),
              SizedBox.expand(key: ValueKey<String>('ordering-page-1')),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(_previewCenter(tester), kind: PointerDeviceKind.touch);
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();

    expect(settledDuringAncestorCancel, <bool>[true], reason: 'loser 的取消回调必须在 page takeover/direct drag 之前执行');
    expect(controller.isPageSettled, isFalse, reason: '认领完成后本次 direct page drag 应正常成立');
    await gesture.cancel();
    await _finishPageMotion(tester);
  });

  testWidgets('PREVIEW-G38: strictPageDragIntent 下纵向斜拖交给父级，明确横拖仍翻页', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    var parentVerticalStarts = 0;
    var parentVerticalUpdates = 0;
    await tester.pumpWidget(
      _shell(
        ElView(
          event: ElEvent(
            dragStartDistance: 8,
            onVerticalDragStart: (event) {
              parentVerticalStarts++;
              event.stopPropagation();
            },
            onVerticalDragUpdate: (_) => parentVerticalUpdates++,
          ),
          child: ElPreviewView(
            controller: controller,
            panInertia: false,
            strictPageDragIntent: true,
            children: const [
              SizedBox.expand(key: ValueKey<String>('axis-page-0')),
              SizedBox.expand(key: ValueKey<String>('axis-page-1')),
            ],
          ),
        ),
      ),
    );

    final vertical = await tester.startGesture(_previewCenter(tester), kind: PointerDeviceKind.touch);
    await vertical.moveBy(const Offset(-20, 14));
    await tester.pump();
    await vertical.moveBy(const Offset(-90, 160));
    await tester.pump();
    // 前一帧累计方向刚翻成垂直，只公开 DragStart；下一帧才进入 Update。
    await vertical.moveBy(const Offset(0, 40));
    await tester.pump();

    expect(parentVerticalStarts, 1, reason: '非明确横向的斜拖不得被 Preview 横向翻页抢走');
    expect(parentVerticalUpdates, greaterThan(0));
    expect(controller.index, 0);
    expect(controller.isPageSettled, isTrue);
    await vertical.up();
    await tester.pumpAndSettle();

    final horizontal = await tester.startGesture(_previewCenter(tester), kind: PointerDeviceKind.touch);
    await horizontal.moveBy(const Offset(-80, 8));
    await tester.pump();
    await horizontal.moveBy(const Offset(-80, 8));
    await tester.pump();
    await horizontal.moveBy(const Offset(-80, 8));
    await tester.pump();

    expect(parentVerticalStarts, 1, reason: '明确横向翻页不应冒成父级纵向拖拽');
    expect(controller.isPageSettled, isFalse);
    await horizontal.up();
    await _finishPageMotion(tester);
    expect(controller.index, 1);
  });
}

Widget _plainPreview(
  ElPreviewController controller, {
  bool mouseWheelZoom = true,
  bool mouseDragPan = true,
  double minScale = 1,
  double maxScale = 4,
}) {
  return _shell(
    ElPreviewView(
      controller: controller,
      panInertia: false,
      minScale: minScale,
      maxScale: maxScale,
      mouseWheelZoom: mouseWheelZoom,
      mouseDragPan: mouseDragPan,
      children: const [
        SizedBox.expand(key: ValueKey<String>('preview-page-0')),
        SizedBox.expand(key: ValueKey<String>('preview-page-1')),
        SizedBox.expand(key: ValueKey<String>('preview-page-2')),
      ],
    ),
  );
}

Widget _shell(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, height: 200, child: child),
    ),
  );
}

Widget _nestedHorizontalScrollPreview({
  required ElPreviewController preview,
  required ScrollController scroll,
  required Key currentKey,
  required Key nextKey,
  bool panInertia = true,
}) {
  return _shell(
    ElPreviewView(
      controller: preview,
      panInertia: panInertia,
      scaleInertia: false,
      children: [
        SizedBox.expand(
          key: currentKey,
          child: ElScroll(
            axis: Axis.horizontal,
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            smoothScroll: null,
            children: const [SizedBox(width: 900, height: 200)],
          ),
        ),
        SizedBox.expand(key: nextKey),
      ],
    ),
  );
}

Offset _previewCenter(WidgetTester tester) => tester.getCenter(find.byType(ElPreviewView));

Future<void> _dragAndRelease(
  WidgetTester tester, {
  required double stepDx,
  required int stepCount,
  required Duration stepDuration,
}) async {
  final gesture = await tester.startGesture(_previewCenter(tester), kind: PointerDeviceKind.touch);
  var elapsed = Duration.zero;
  for (var i = 0; i < stepCount; i++) {
    elapsed += stepDuration;
    await gesture.moveBy(Offset(stepDx, 0), timeStamp: elapsed);
    await tester.pump(stepDuration);
  }
  await gesture.up(timeStamp: elapsed);
}

Future<void> _finishPageMotion(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 16));
}

Matrix4 _globalMatrix(WidgetTester tester, Key key) {
  return tester.renderObject<RenderBox>(find.byKey(key)).getTransformTo(null);
}

void _expectMatrixClose(Matrix4 actual, Matrix4 expected, {double epsilon = 1e-6}) {
  for (var i = 0; i < 16; i++) {
    expect(actual.storage[i], closeTo(expected.storage[i], epsilon), reason: 'matrix[$i] 在第二指加入时发生跳变');
  }
}

void _expectOffset(Offset actual, Offset expected, {double epsilon = 1e-6}) {
  expect(actual.dx, closeTo(expected.dx, epsilon));
  expect(actual.dy, closeTo(expected.dy, epsilon));
}

double _defaultPreviewScale(double rawScale) => math.pow(rawScale, 1.25).toDouble();
