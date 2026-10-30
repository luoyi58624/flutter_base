import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  testWidgets('PREVIEW-T1: PointerRemoved 回滚活动 pipeline 并允许下一手重新分账', (tester) async {
    const initialTransform = ElZoomTransform(scale: 2, offset: Offset(-150, 0));
    final preview = ElPreviewController()..jumpToTransform(initialTransform);
    final scroll = ScrollController();
    addTearDown(preview.dispose);
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: preview,
          panInertia: false,
          scaleInertia: false,
          children: [
            _horizontalScroll(scroll),
            const SizedBox.expand(key: _nextPageKey),
          ],
        ),
      ),
    );
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final nextBaseX = tester.getTopLeft(find.byKey(_nextPageKey)).dx;

    final removed = await _dragPageGap(tester, pointer: 501, delta: -70);
    expect(nextBaseX - tester.getTopLeft(find.byKey(_nextPageKey)).dx, closeTo(70, 1e-6));
    expect(preview.currentTransform, initialTransform);

    await removed.removePointer(timeStamp: const Duration(milliseconds: 320));
    await _finishPageMotion(tester);
    expect(preview.index, 0);
    expect(preview.currentTransform, initialTransform, reason: 'removed 只终止交互，不得改写已提交的内容变换');
    expect(
      tester.getTopLeft(find.byKey(_nextPageKey)).dx,
      closeTo(nextBaseX, 1e-6),
      reason: 'removed 必须回滚未提交的 page gap',
    );
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'removed 收尾后不得残留 page/Zoom ticker');

    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final next = await _dragPageGap(tester, pointer: 502, delta: -40);
    expect(
      nextBaseX - tester.getTopLeft(find.byKey(_nextPageKey)).dx,
      closeTo(40, 1e-6),
      reason: '旧 pipeline 必须已解散，下一手可重新建立分账',
    );
    await next.cancel(timeStamp: const Duration(milliseconds: 320));
    await next.removePointer(timeStamp: const Duration(milliseconds: 336));
    await _finishPageMotion(tester);
    expect(tester.getTopLeft(find.byKey(_nextPageKey)).dx, closeTo(nextBaseX, 1e-6));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('PREVIEW-T2: 活动 roster 宿主卸载只 cancel 一次并释放下一手', (tester) async {
    const initialTransform = ElZoomTransform(scale: 2, offset: Offset(-150, 0));
    final preview = ElPreviewController()..jumpToTransform(initialTransform);
    final scroll = ScrollController();
    addTearDown(preview.dispose);
    addTearDown(scroll.dispose);
    var showPreview = true;
    var driverCancels = 0;
    var rosterCancels = 0;
    late StateSetter rebuild;
    const nextKey = ValueKey<String>('terminal-config-next-page');

    await tester.pumpWidget(
      _shell(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            if (!showPreview) return const SizedBox.expand();
            return ElPreviewView(
              controller: preview,
              panInertia: false,
              scaleInertia: false,
              children: [
                ElView(
                  event: ElEvent(
                    dragProxy: ElDragProxy(axis: Axis.horizontal, onDragOverflow: (_) {}),
                    onHorizontalDragCancel: (_) => rosterCancels++,
                  ),
                  child: _horizontalScroll(scroll, event: ElEvent(onHorizontalDragCancel: (_) => driverCancels++)),
                ),
                const SizedBox.expand(key: nextKey),
              ],
            );
          },
        ),
      ),
    );
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final nextBaseX = tester.getTopLeft(find.byKey(nextKey)).dx;

    final interrupted = await _dragPageGap(tester, pointer: 601, delta: -70);
    expect(nextBaseX - tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(70, 1e-6));
    expect(driverCancels, 0);
    expect(rosterCancels, 0);

    rebuild(() => showPreview = false);
    await tester.pump();
    expect(driverCancels, 1, reason: '卸载活动 Preview/Zoom 子树必须终止 driver');
    expect(rosterCancels, 1, reason: '同一复合事务的 roster cancel 必须恰好一次');
    expect(preview.currentTransform, initialTransform);

    await interrupted.up(timeStamp: const Duration(milliseconds: 336));
    await tester.pump();
    expect(driverCancels, 1, reason: '卸载已终止的 driver 不得在 up 重复 cancel');
    expect(rosterCancels, 1);

    rebuild(() => showPreview = true);
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextBaseX, 1e-6), reason: '重挂后不得恢复旧 page gap');
    scroll.jumpTo(scroll.position.maxScrollExtent);
    final recovered = await _dragPageGap(tester, pointer: 602, delta: -40);
    expect(
      nextBaseX - tester.getTopLeft(find.byKey(nextKey)).dx,
      closeTo(40, 1e-6),
      reason: '卸载必须完整解散旧 pipeline，重挂后下一手可重建',
    );

    await recovered.cancel(timeStamp: const Duration(milliseconds: 320));
    await _finishPageMotion(tester);
    expect(driverCancels, 2);
    expect(rosterCancels, 2);
    expect(tester.getTopLeft(find.byKey(nextKey)).dx, closeTo(nextBaseX, 1e-6));
    await recovered.removePointer(timeStamp: const Duration(milliseconds: 336));
    await tester.pump();
    expect(driverCancels, 2, reason: 'cancel 后的 removed 不得重复终止');
    expect(rosterCancels, 2);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('PREVIEW-T3: 半页 handoff 中一指 Removed 后剩余指 up 必须完整回滚', (tester) async {
    const initialTransform = ElZoomTransform(scale: 2, offset: Offset(-150, 0));
    final preview = ElPreviewController()..jumpToTransform(initialTransform);
    final scroll = ScrollController();
    addTearDown(preview.dispose);
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: preview,
          panInertia: false,
          scaleInertia: false,
          children: [
            _horizontalScroll(scroll),
            const SizedBox.expand(key: _nextPageKey),
          ],
        ),
      ),
    );
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final nextBaseX = tester.getTopLeft(find.byKey(_nextPageKey)).dx;

    final first = await _dragPageGap(tester, pointer: 701, delta: -120);
    expect(nextBaseX - tester.getTopLeft(find.byKey(_nextPageKey)).dx, closeTo(120, 1e-6));
    final second = await tester.createGesture(pointer: 702, kind: PointerDeviceKind.touch);
    addTearDown(second.removePointer);
    await second.down(const Offset(250, 100), timeStamp: const Duration(milliseconds: 316));
    await tester.pump(const Duration(milliseconds: 16));

    await first.removePointer(timeStamp: const Duration(milliseconds: 332));
    await tester.pump(const Duration(milliseconds: 16));
    await second.up(timeStamp: const Duration(milliseconds: 348));
    await _finishPageMotion(tester);
    expect(preview.index, 0);
    expect(preview.currentTransform, initialTransform);
    expect(
      tester.getTopLeft(find.byKey(_nextPageKey)).dx,
      closeTo(nextBaseX, 1e-6),
      reason: '2→Removed→1→up 必须结清 transient 并回滚 page gap',
    );
    expect(tester.binding.hasScheduledFrame, isFalse);

    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final recovered = await _dragPageGap(tester, pointer: 703, delta: -40);
    expect(
      nextBaseX - tester.getTopLeft(find.byKey(_nextPageKey)).dx,
      closeTo(40, 1e-6),
      reason: 'Removed handoff 结清后下一手必须可重建 pipeline',
    );
    await recovered.cancel(timeStamp: const Duration(milliseconds: 320));
    await _finishPageMotion(tester);
  });
}

const _nextPageKey = ValueKey<String>('terminal-next-page');

Widget _horizontalScroll(ScrollController controller, {ElEvent? event}) {
  return ElScrollView(
    axis: Axis.horizontal,
    controller: controller,
    event: event,
    physics: const ClampingScrollPhysics(),
    smoothScroll: const ElNoSmoothScroll(),
    scrollbar: const ElNoScrollBar(),
    children: const [SizedBox(width: 900, height: 200)],
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

Future<TestGesture> _dragPageGap(WidgetTester tester, {required int pointer, required double delta}) async {
  final gesture = await tester.createGesture(pointer: pointer, kind: PointerDeviceKind.touch);
  await gesture.down(const Offset(150, 100), timeStamp: Duration.zero);
  await gesture.moveBy(const Offset(-30, 0), timeStamp: const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.moveBy(Offset(delta, 0), timeStamp: const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 200));
  return gesture;
}

Future<void> _finishPageMotion(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 16));
}
