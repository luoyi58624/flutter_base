import '../../support/overlay.dart';
import 'package:flutter_base/src/ui/cores/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  for (final box in [false, true]) {
    testWidgets('Preview 后代 ${box ? '对象' : '字符'} 拖选独占页面与第二指缩放', (tester) async {
      final preview = ElPreviewController();
      final selection = ElSelectionController();
      final objects = ElBoxSelectionController();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        selection.dispose();
        objects.dispose();
        preview.dispose();
      });
      var contentTaps = 0;
      var outerTaps = 0;

      await tester.pumpWidget(
        _shell(
          onOuterTap: () => outerTaps++,
          child: ElPreviewView(
            controller: preview,
            panInertia: false,
            scaleInertia: false,
            children: [
              if (box)
                ElBoxSelectionView(
                  key: _selectionPageKey,
                  controller: objects,
                  child: _selectionFixture(box, () => contentTaps++),
                )
              else
                ElSelectionView(
                  key: _selectionPageKey,
                  controller: selection,
                  child: _selectionFixture(box, () => contentTaps++),
                ),
              const SizedBox.expand(key: _nextPageKey),
            ],
          ),
        ),
      );
      await tester.pump();

      final basePageLeft = tester.getTopLeft(find.byKey(_selectionPageKey)).dx;
      final baseNextLeft = tester.getTopLeft(find.byKey(_nextPageKey)).dx;
      final (start, end) = _selectionDragPoints(tester, box);
      final mouse = await tester.createGesture(pointer: 301 + (box ? 10 : 0), kind: PointerDeviceKind.mouse);
      final second = await tester.createGesture(pointer: 302 + (box ? 10 : 0), kind: PointerDeviceKind.touch);
      addTearDown(mouse.removePointer);
      addTearDown(second.removePointer);

      await mouse.down(start);
      await mouse.moveBy(const Offset(8, 0));
      await tester.pump();
      await mouse.moveTo(end);
      await tester.pump();
      final pageLeftDuringSelection = tester.getTopLeft(find.byKey(_selectionPageKey)).dx;
      final nextLeftDuringSelection = tester.getTopLeft(find.byKey(_nextPageKey)).dx;

      await second.down(const Offset(70, 160));
      await tester.pump();
      await second.moveBy(const Offset(-50, 0));
      await tester.pump();
      final scaleDuringSecondPointer = preview.currentTransform.scale;
      // 第二指只验证缩放门禁，取消其独立序列，避免混入边界内正常的 touch tap。
      await second.cancel();
      await tester.pump();
      await mouse.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pump();

      expect(box ? objects.selectedCount > 0 : selection.text != null, isTrue, reason: '越过阈值后必须形成真实选区');
      expect(pageLeftDuringSelection, closeTo(basePageLeft, 1e-6), reason: 'Selection winner 成立后当前页不得跟随横向拖选');
      expect(nextLeftDuringSelection, closeTo(baseNextLeft, 1e-6), reason: 'Selection winner 成立后相邻页不得露出');
      expect(scaleDuringSecondPointer, closeTo(1, 1e-9), reason: 'Selection 是 incompatible winner，第二指不得偷回 Scale');
      expect(preview.index, 0);
      expect(preview.currentTransform, const ElZoomTransform());
      expect(contentTaps, 0, reason: '拖选成立后的 pointer up 不得合成内容 tap');
      expect(outerTaps, 0, reason: '拖选成立后的 pointer up 不得合成祖先 tap');
    });
  }

  testWidgets('Preview 后代 DnD 独占横向拖放并完整结清 session', (tester) async {
    final preview = ElPreviewController();
    final selection = ElSelectionController();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      selection.dispose();
      preview.dispose();
    });
    var starts = 0;
    var drops = 0;
    var ends = 0;
    var accepted = false;
    var sourceTaps = 0;
    var outerTaps = 0;

    await tester.pumpWidget(
      _shell(
        onOuterTap: () => outerTaps++,
        child: ElPreviewView(
          controller: preview,
          panInertia: false,
          scaleInertia: false,
          children: [
            ElSelectionView(
              key: _dndPageKey,
              controller: selection,
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 70,
                    child: ElDraggable<String>(
                      data: 'card',
                      onDragStarted: () => starts++,
                      onDragEnded: (value) {
                        ends++;
                        accepted = value;
                      },
                      ghostBuilder: (_) => const ElView(
                        key: _ghostKey,
                        style: ElStyle(width: 44, height: 44, bgColor: Color(0x882266aa)),
                      ),
                      child: ElView(
                        key: _dragKey,
                        event: ElEvent(onTap: (_) => sourceTaps++),
                        style: const ElStyle(width: 60, height: 60, bgColor: Color(0xff2266aa), alignment: .center),
                        child: 'drag',
                      ),
                    ),
                  ),
                  Positioned(
                    left: 190,
                    top: 60,
                    child: ElDropTarget<String>(
                      onDrop: (data, details) => drops++,
                      builder: (context, candidate) => ElView(
                        key: _dropKey,
                        style: ElStyle(
                          width: 90,
                          height: 80,
                          bgColor: candidate == null ? const Color(0xff333333) : const Color(0xff22aa66),
                          alignment: .center,
                        ),
                        child: 'drop',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox.expand(key: _dndNextPageKey),
          ],
        ),
      ),
    );
    await tester.pump();

    final basePageLeft = tester.getTopLeft(find.byKey(_dndPageKey)).dx;
    final baseNextLeft = tester.getTopLeft(find.byKey(_dndNextPageKey)).dx;
    final mouse = await tester.createGesture(pointer: 401, kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.down(tester.getCenter(find.byKey(_dragKey)));
    await mouse.moveBy(const Offset(8, 0));
    await tester.pump();
    await mouse.moveBy(const Offset(42, 0));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.byKey(_dropKey)));
    await tester.pump();
    await tester.pump();
    final pageLeftDuringDrag = tester.getTopLeft(find.byKey(_dndPageKey)).dx;
    final nextLeftDuringDrag = tester.getTopLeft(find.byKey(_dndNextPageKey)).dx;
    await mouse.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(starts, 1);
    expect(drops, 1);
    expect(ends, 1);
    expect(accepted, isTrue);
    expect(find.byKey(_ghostKey), findsNothing, reason: '正常终态必须同步关闭 ghost 并结清拖放 session');
    expect(pageLeftDuringDrag, closeTo(basePageLeft, 1e-6), reason: 'DnD winner 成立后当前页不得跟随横向拖动');
    expect(nextLeftDuringDrag, closeTo(baseNextLeft, 1e-6), reason: 'DnD winner 成立后相邻页不得露出');
    expect(preview.index, 0);
    expect(preview.currentTransform, const ElZoomTransform());
    expect(selection.text, isNull, reason: '更深的 DnD winner 必须让 Selection pending 候选退出');
    expect(sourceTaps, 0);
    expect(outerTaps, 0);
  });

  testWidgets('Preview 活跃 DnD 拒绝第二指 Scale，cancel 后可重新开始', (tester) async {
    final preview = ElPreviewController();
    var starts = 0;
    final ended = <bool>[];
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      preview.dispose();
    });

    await tester.pumpWidget(
      _shell(
        onOuterTap: () {},
        child: _cancelableDndPreview(preview: preview, onStarted: () => starts++, onEnded: ended.add),
      ),
    );
    await tester.pump();

    final first = await tester.createGesture(pointer: 501, kind: PointerDeviceKind.mouse);
    final second = await tester.createGesture(pointer: 502, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    addTearDown(second.removePointer);
    await first.down(tester.getCenter(find.byKey(_cancelDragKey)));
    await first.moveBy(const Offset(50, 0));
    await tester.pump();
    await tester.pump();
    expect(starts, 1);
    expect(find.byKey(_cancelGhostKey), findsOneWidget);

    await second.down(const Offset(70, 160));
    await second.moveBy(const Offset(-50, 0));
    await tester.pump();
    expect(preview.currentTransform, const ElZoomTransform(), reason: 'DnD 是 incompatible winner，第二指不得偷回 Scale');
    expect(preview.index, 0);

    await first.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(ended, <bool>[false], reason: 'PointerCancel 必须且只能结清一次 DnD');
    expect(find.byKey(_cancelGhostKey), findsNothing);
    await second.up();
    await tester.pump();

    final restart = await tester.createGesture(pointer: 503, kind: PointerDeviceKind.mouse);
    addTearDown(restart.removePointer);
    await restart.down(tester.getCenter(find.byKey(_cancelDragKey)));
    await restart.moveBy(const Offset(50, 0));
    await tester.pump();
    await tester.pump();
    expect(starts, 2, reason: 'cancel 后 singleton session 必须已经释放，允许同一 source 重新开始');
    expect(find.byKey(_cancelGhostKey), findsOneWidget);
    await restart.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(ended, <bool>[false, false]);
    expect(find.byKey(_cancelGhostKey), findsNothing);

    final removed = await tester.createGesture(pointer: 504, kind: PointerDeviceKind.mouse);
    addTearDown(removed.removePointer);
    await removed.down(tester.getCenter(find.byKey(_cancelDragKey)));
    await removed.moveBy(const Offset(50, 0));
    await tester.pump();
    await tester.pump();
    expect(starts, 3);
    await removed.removePointer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(ended, <bool>[false, false, false], reason: 'eager DnD 的 PointerRemoved 也必须结清 session');
    expect(find.byKey(_cancelGhostKey), findsNothing);

    final page = await tester.createGesture(pointer: 505, kind: PointerDeviceKind.touch);
    addTearDown(page.removePointer);
    final nextBaseX = tester.getTopLeft(find.byKey(_cancelNextPageKey)).dx;
    await page.down(const Offset(150, 100));
    await page.moveBy(const Offset(-30, 0));
    await tester.pump();
    await page.moveBy(const Offset(-70, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(_cancelNextPageKey)).dx,
      lessThan(nextBaseX),
      reason: 'Removed 后 Preview 指针账必须恢复',
    );
    await page.cancel();
    await tester.pump(const Duration(milliseconds: 260));
  });

  testWidgets('DnD ghost host dispose 会取消仍存活 source 的 session 并允许重启', (tester) async {
    final preview = ElPreviewController();
    final liveTreeKey = GlobalKey(debugLabel: 'live-dnd-preview-tree');
    var starts = 0;
    final ended = <bool>[];
    var hostMounted = true;
    StateSetter? rebuildHost;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      preview.dispose();
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 200,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuildHost = setState;
                final liveTree = KeyedSubtree(
                  key: liveTreeKey,
                  child: _cancelableDndPreview(preview: preview, onStarted: () => starts++, onEnded: ended.add),
                );
                return hostMounted ? ElTestOverlay(key: _disposableHostKey, child: liveTree) : liveTree;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final first = await tester.createGesture(pointer: 511, kind: PointerDeviceKind.mouse);
    addTearDown(first.removePointer);
    await first.down(tester.getCenter(find.byKey(_cancelDragKey)));
    await first.moveBy(const Offset(50, 0));
    await tester.pump();
    await tester.pump();
    expect(starts, 1);
    expect(find.byKey(_cancelGhostKey), findsOneWidget);

    rebuildHost!(() => hostMounted = false);
    await tester.pump();
    await tester.pump();
    final endedAfterHostDispose = List<bool>.of(ended);
    final ghostClosedWithHost = find.byKey(_cancelGhostKey).evaluate().isEmpty;

    rebuildHost!(() => hostMounted = true);
    await tester.pump();
    final restart = await tester.createGesture(pointer: 512, kind: PointerDeviceKind.mouse);
    addTearDown(restart.removePointer);
    await restart.down(tester.getCenter(find.byKey(_cancelDragKey)));
    await restart.moveBy(const Offset(50, 0));
    await tester.pump();
    await tester.pump();
    final startsAfterRestart = starts;
    await restart.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await first.removePointer();

    expect(
      endedAfterHostDispose,
      <bool>[false],
      reason:
          'ghost host dispose 必须主动取消仍存活 source 的 DnD session；'
          'ghostClosed=$ghostClosedWithHost, restartStarts=$startsAfterRestart, finalEnded=$ended',
    );
    expect(ghostClosedWithHost, isTrue);
    expect(startsAfterRestart, 2, reason: 'host dispose 后旧 session 必须释放，新 host 下可以重新 start');
    expect(ended, <bool>[false, false]);
    expect(find.byKey(_cancelGhostKey), findsNothing);
  });

  testWidgets('同一 Overlay host 内 active ElDraggable GlobalKey reparent 会取消 session', (tester) async {
    final sourceKey = GlobalKey(debugLabel: 'reparented-dnd-source');
    var sourceOnLeft = true;
    StateSetter? rebuildSource;
    var starts = 0;
    final ended = <bool>[];
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });

    Widget source() {
      return ElDraggable<String>(
        key: sourceKey,
        data: 'reparent-card',
        onDragStarted: () => starts++,
        onDragEnded: ended.add,
        ghostBuilder: (_) => const ElView(
          key: _reparentGhostKey,
          style: ElStyle(width: 44, height: 44, bgColor: Color(0x882266aa)),
        ),
        child: const ElView(
          key: _reparentDragKey,
          style: ElStyle(width: 60, height: 60, bgColor: Color(0xff2266aa)),
        ),
      );
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTestOverlay(
              child: StatefulBuilder(
                builder: (context, setState) {
                  rebuildSource = setState;
                  return Stack(
                    children: [
                      if (sourceOnLeft)
                        Positioned(left: 20, top: 70, child: source())
                      else
                        Align(alignment: Alignment.centerRight, child: source()),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final stateBeforeReparent = tester.state(find.byKey(sourceKey));

    final first = await tester.createGesture(pointer: 521, kind: PointerDeviceKind.mouse);
    addTearDown(first.removePointer);
    await first.down(tester.getCenter(find.byKey(_reparentDragKey)));
    await first.moveBy(const Offset(50, 0));
    await tester.pump();
    await tester.pump();
    expect(starts, 1);
    expect(find.byKey(_reparentGhostKey), findsOneWidget);

    rebuildSource!(() => sourceOnLeft = false);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    final stateAfterReparent = tester.state(find.byKey(sourceKey));
    final endedAfterReparent = List<bool>.of(ended);
    final ghostClosedAfterReparent = find.byKey(_reparentGhostKey).evaluate().isEmpty;
    await first.removePointer();

    final restart = await tester.createGesture(pointer: 522, kind: PointerDeviceKind.mouse);
    addTearDown(restart.removePointer);
    await restart.down(tester.getCenter(find.byKey(_reparentDragKey)));
    await restart.moveBy(const Offset(-50, 0));
    await tester.pump();
    await tester.pump();
    final startsAfterRestart = starts;
    await restart.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(stateAfterReparent, same(stateBeforeReparent), reason: 'GlobalKey reparent 必须保留 ElDraggable State');
    expect(
      endedAfterReparent,
      <bool>[false],
      reason:
          'source detach 必须取消旧 session；ghostClosed=$ghostClosedAfterReparent, '
          'restartStarts=$startsAfterRestart, finalEnded=$ended',
    );
    expect(ghostClosedAfterReparent, isTrue);
    expect(startsAfterRestart, 2, reason: 'reparent terminal 必须释放 singleton，允许同一 State 再次 start');
    expect(ended, <bool>[false, false]);
    expect(find.byKey(_reparentGhostKey), findsNothing);
  });

  testWidgets('direct Preview 半页时 GlobalKey reparent 保持进度并允许下一手', (tester) async {
    final previewKey = GlobalKey(debugLabel: 'reparented-direct-preview');
    final controller = ElPreviewController();
    var firstParent = true;
    StateSetter? rebuildParent;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    Widget preview() {
      return ElPreviewView(
        key: previewKey,
        controller: controller,
        panInertia: false,
        scaleInertia: false,
        children: const [
          SizedBox.expand(key: _reparentCurrentPageKey),
          SizedBox.expand(key: _reparentNextPageKey),
        ],
      );
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 200,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuildParent = setState;
                return firstParent
                    ? KeyedSubtree(key: const ValueKey<String>('preview-parent-a'), child: preview())
                    : Align(
                        alignment: Alignment.center,
                        child: SizedBox(width: 300, height: 200, child: preview()),
                      );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final stateBeforeReparent = tester.state(find.byKey(previewKey));
    final nextBaseX = tester.getTopLeft(find.byKey(_reparentNextPageKey)).dx;

    final first = await tester.createGesture(pointer: 531, kind: PointerDeviceKind.touch);
    addTearDown(first.removePointer);
    await first.down(const Offset(150, 100));
    await first.moveBy(const Offset(-30, 0));
    await tester.pump();
    await first.moveBy(const Offset(-70, 0));
    await tester.pump();
    expect(nextBaseX - tester.getTopLeft(find.byKey(_reparentNextPageKey)).dx, closeTo(70, 1e-6));

    rebuildParent!(() => firstParent = false);
    await tester.pump();
    final stateAfterReparent = tester.state(find.byKey(previewKey));
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    final gapAfterReparent = nextBaseX - tester.getTopLeft(find.byKey(_reparentNextPageKey)).dx;
    await first.removePointer();

    final restart = await tester.createGesture(pointer: 532, kind: PointerDeviceKind.touch);
    addTearDown(restart.removePointer);
    await restart.down(const Offset(150, 100));
    await restart.moveBy(const Offset(-30, 0));
    await tester.pump();
    await restart.moveBy(const Offset(-40, 0));
    await tester.pump();
    final gapAfterRestart = nextBaseX - tester.getTopLeft(find.byKey(_reparentNextPageKey)).dx;
    await restart.cancel();
    await tester.pumpAndSettle(const Duration(milliseconds: 16));

    expect(stateAfterReparent, same(stateBeforeReparent), reason: 'GlobalKey reparent 必须保留 ElPreviewView State');
    expect(
      gapAfterReparent,
      closeTo(70, 1e-6),
      reason: '重挂保持未提交半页进度，不得回滚；restartGap=$gapAfterRestart, index=${controller.index}',
    );
    expect(gapAfterRestart, closeTo(110, 1e-6), reason: '重挂保留的半页进度（70）必须能被下一手接着拖（+40）');
    expect(controller.index, 0);
    expect(controller.currentTransform, const ElZoomTransform());
  });
}

const _selectionPageKey = ValueKey<String>('selection-page');
const _nextPageKey = ValueKey<String>('selection-next-page');
const _characterTargetKey = ValueKey<String>('selection-character-target');
const _blockStartKey = ValueKey<String>('selection-block-start');
const _blockEndKey = ValueKey<String>('selection-block-end');
const _dndPageKey = ValueKey<String>('dnd-page');
const _dndNextPageKey = ValueKey<String>('dnd-next-page');
const _dragKey = ValueKey<String>('preview-dnd-source');
const _dropKey = ValueKey<String>('preview-dnd-target');
const _ghostKey = ValueKey<String>('preview-dnd-ghost');
const _cancelDragKey = ValueKey<String>('preview-cancel-dnd-source');
const _cancelGhostKey = ValueKey<String>('preview-cancel-dnd-ghost');
const _cancelNextPageKey = ValueKey<String>('preview-cancel-dnd-next');
const _disposableHostKey = ValueKey<String>('preview-disposable-dnd-host');
const _reparentDragKey = ValueKey<String>('reparent-dnd-source-child');
const _reparentGhostKey = ValueKey<String>('reparent-dnd-ghost');
const _reparentCurrentPageKey = ValueKey<String>('reparent-preview-current');
const _reparentNextPageKey = ValueKey<String>('reparent-preview-next');

Widget _selectionFixture(bool box, VoidCallback onTap) {
  if (!box) {
    return Align(
      alignment: Alignment.topLeft,
      child: ElView(
        key: _characterTargetKey,
        event: ElEvent(onTap: (_) => onTap()),
        style: const ElStyle(width: 280, height: 80, padding: .all(16), fontSize: 20),
        child: 'alpha beta gamma delta epsilon',
      ),
    );
  }
  return Align(
    alignment: Alignment.topLeft,
    child: ElView(
      event: ElEvent(onTap: (_) => onTap()),
      style: const ElStyle(width: 280, height: 100, padding: .all(16)),
      child: const Row(
        spacing: 20,
        children: [
          ElBoxSelectable(
            key: _blockStartKey,
            value: 'block-a',
            child: ElView(style: ElStyle(width: 90, height: 60, bgColor: Color(0xff335577))),
          ),
          ElBoxSelectable(
            key: _blockEndKey,
            value: 'block-b',
            child: ElView(style: ElStyle(width: 90, height: 60, bgColor: Color(0xff557733))),
          ),
        ],
      ),
    ),
  );
}

(Offset, Offset) _selectionDragPoints(WidgetTester tester, bool box) {
  if (!box) {
    final rect = tester.getRect(find.byKey(_characterTargetKey));
    return (rect.topLeft + const Offset(18, 34), rect.topLeft + const Offset(230, 34));
  }
  final startRect = tester.getRect(find.byKey(_blockStartKey));
  final endRect = tester.getRect(find.byKey(_blockEndKey));
  return (startRect.topLeft + const Offset(2, 2), endRect.bottomRight - const Offset(2, 2));
}

Widget _cancelableDndPreview({
  required ElPreviewController preview,
  required VoidCallback onStarted,
  required ValueChanged<bool> onEnded,
}) {
  return ElPreviewView(
    controller: preview,
    panInertia: false,
    scaleInertia: false,
    children: [
      Align(
        alignment: Alignment.topLeft,
        child: ElDraggable<String>(
          data: 'cancel-card',
          onDragStarted: onStarted,
          onDragEnded: onEnded,
          ghostBuilder: (_) => const ElView(
            key: _cancelGhostKey,
            style: ElStyle(width: 44, height: 44, bgColor: Color(0x882266aa)),
          ),
          child: const ElView(
            key: _cancelDragKey,
            style: ElStyle(width: 60, height: 60, bgColor: Color(0xff2266aa), alignment: .center),
            child: 'drag',
          ),
        ),
      ),
      const SizedBox.expand(key: _cancelNextPageKey),
    ],
  );
}

Widget _shell({required Widget child, required VoidCallback onOuterTap}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 300,
        height: 200,
        child: ElTestOverlay(
          child: ElView(
            event: ElEvent(onTap: (_) => onOuterTap()),
            child: child,
          ),
        ),
      ),
    ),
  );
}
