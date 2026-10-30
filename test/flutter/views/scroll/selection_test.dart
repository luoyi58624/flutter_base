import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

class _NoChromeBehavior extends ScrollBehavior {
  const _NoChromeBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

class _MouseDragNoChromeBehavior extends _NoChromeBehavior {
  const _MouseDragNoChromeBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{...super.dragDevices, PointerDeviceKind.mouse};
}

void main() {
  group('滚动与选区交互', () {
    setUp(EventDispatcher.debugResetEagerGestureOwners);

    const scrollKey = ValueKey('scroll');

    Widget shell({
      required ScrollController controller,
      required bool withSelection,
      bool textChildren = true,
      bool mouseContentDrag = false,
    }) {
      final scroll = SizedBox(
        key: scrollKey,
        width: 200,
        height: 300,
        child: ElScrollView(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          children: List<Widget>.generate(
            60,
            (i) => textChildren
                ? ElView(
                    key: ValueKey('item-$i'),
                    style: const ElStyle(width: 200, height: 40),
                    child: 'item $i — selectable text row',
                  )
                : ElView(
                    key: ValueKey('item-$i'),
                    style: ElStyle(width: 200, height: 40, bgColor: Color(0xff222222 + i)),
                  ),
          ),
        ),
      );
      return MaterialApp(
        scrollBehavior: mouseContentDrag ? const _MouseDragNoChromeBehavior() : const _NoChromeBehavior(),
        home: Align(
          alignment: Alignment.topLeft,
          child: withSelection ? ElSelectionView(child: scroll) : scroll,
        ),
      );
    }

    Future<void> lightReverseFlick(WidgetTester tester, Offset center, int pointer, Duration base) async {
      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: pointer);
      await g.down(center, timeStamp: base);
      await tester.pump(const Duration(milliseconds: 4));
      await g.moveBy(const Offset(0, 9), timeStamp: base + const Duration(milliseconds: 8));
      await tester.pump(const Duration(milliseconds: 4));
      await g.moveBy(const Offset(0, 15), timeStamp: base + const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 4));
      await g.up(timeStamp: base + const Duration(milliseconds: 24));
    }

    Future<void> lightForwardFlick(WidgetTester tester, Offset center, int pointer, Duration base) async {
      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: pointer);
      await g.down(center, timeStamp: base);
      await tester.pump(const Duration(milliseconds: 4));
      await g.moveBy(const Offset(0, -9), timeStamp: base + const Duration(milliseconds: 8));
      await tester.pump(const Duration(milliseconds: 4));
      await g.moveBy(const Offset(0, -15), timeStamp: base + const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 4));
      await g.up(timeStamp: base + const Duration(milliseconds: 24));
    }

    for (final withSelection in [false, true]) {
      final label = withSelection ? 'ElSelectionView 包裹' : '无包裹(对照)';

      testWidgets('SEL-A[$label]: 向下惯性中反向轻扫必须立即回滚,不能死停', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(shell(controller: controller, withSelection: withSelection));
        await tester.pump();

        final center = tester.getCenter(find.byKey(scrollKey));
        for (var i = 0; i < 4; i++) {
          controller.jumpTo(800);
          await tester.pump();
          await tester.fling(find.byKey(scrollKey), const Offset(0, -200), 2200);
          await tester.pump(const Duration(milliseconds: 48));
          final duringBallistic = controller.offset;
          expect(duringBallistic, greaterThan(800), reason: '第 ${i + 1} 轮前置:向下惯性推进中');

          await lightReverseFlick(tester, center, 400 + i, Duration(milliseconds: 5000 + i * 200));
          await tester.pump();
          final afterRelease = controller.offset;
          await tester.pump(const Duration(milliseconds: 96));

          expect(
            controller.offset,
            lessThan(duringBallistic - 4),
            reason: '第 ${i + 1} 轮[$label]:惯性中的反向轻扫必须立刻让 offset 回落',
          );
          expect(
            controller.offset,
            lessThan(afterRelease - 1),
            reason: '第 ${i + 1} 轮[$label]:反向轻扫松手后必须继续反向惯性,不能停在 release 位置',
          );
          await tester.pumpAndSettle();
        }
      });

      testWidgets('SEL-B[$label]: 快速连续同向轻扫必须持续推进,不能偶发死停', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(shell(controller: controller, withSelection: withSelection));
        await tester.pump();

        final center = tester.getCenter(find.byKey(scrollKey));
        var previous = controller.offset;
        for (var i = 0; i < 6; i++) {
          await lightForwardFlick(tester, center, 420 + i, Duration(milliseconds: 8000 + i * 120));
          await tester.pump();
          // 每次轻扫间隔仅几帧——下一次 down 会打断上一次的 ballistic(官方 catch
          // 语义),但轻扫自身的 move+velocity 必须继续推进 offset。
          await tester.pump(const Duration(milliseconds: 48));
          final now = controller.offset;
          expect(now, greaterThan(previous + 4), reason: '第 ${i + 1} 次连续轻扫后[$label] offset 必须继续增长(轻扫被吞=中断滚动)');
          previous = now;
        }
        await tester.pumpAndSettle();
      });
    }

    testWidgets('SEL-C: selection 包裹下轻扫期间不得误触发选区/长按选词', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller, withSelection: true));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      controller.jumpTo(400);
      await tester.pump();

      // 连续 3 次轻扫后停顿——期间任何一次都不该建立选区。
      for (var i = 0; i < 3; i++) {
        await lightForwardFlick(tester, center, 440 + i, Duration(milliseconds: 12000 + i * 100));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      final selection = find.byType(ElSelectionView);
      expect(selection, findsOneWidget);
      expect(controller.offset, greaterThan(400), reason: '轻扫累计必须推进滚动');
    });

    for (final kind in <PointerDeviceKind>[PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      testWidgets('SEL-D[$kind]: 顶部外拖后同一手势反向立即恢复滚动', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          shell(controller: controller, withSelection: true, mouseContentDrag: kind == PointerDeviceKind.mouse),
        );
        await tester.pump();

        final gesture = await tester.createGesture(kind: kind);
        addTearDown(gesture.removePointer);
        await gesture.down(tester.getCenter(find.byKey(scrollKey)));
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        expect(controller.offset, 0, reason: '顶部向外拖仍应保持在起点');

        await gesture.moveBy(const Offset(0, -80));
        await tester.pump();
        expect(controller.offset, greaterThan(0), reason: 'Selection 不得被误判为边界接力者并锁死当前手势');

        await gesture.up();
        await tester.pumpAndSettle();
      });
    }

    testWidgets(
      'SEL-E: 空白处长按被拒绝后同一触摸指针仍可开始滚动',
      (tester) async {
        final scroll = ScrollController();
        final selection = ElSelectionController();
        addTearDown(scroll.dispose);
        addTearDown(selection.dispose);
        const blankKey = ValueKey<String>('selection-blank-start');
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: const _NoChromeBehavior(),
            home: Align(
              alignment: Alignment.topLeft,
              child: ElSelectionView(
                controller: selection,
                child: SizedBox(
                  key: scrollKey,
                  width: 200,
                  height: 300,
                  child: ElScrollView(
                    controller: scroll,
                    physics: const ClampingScrollPhysics(),
                    children: <Widget>[
                      const ElView(
                        key: blankKey,
                        style: ElStyle(width: 200, height: 120, userSelect: .none),
                      ),
                      for (var i = 0; i < 30; i++)
                        ElView(style: const ElStyle(width: 200, height: 40), child: 'row $i selectable text'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
        addTearDown(gesture.removePointer);
        await gesture.down(tester.getCenter(find.byKey(blankKey)));
        await tester.pump(const Duration(milliseconds: 450));

        expect(selection.text, isNull, reason: '空白起手不得建立文本选区');
        final selectionRender = tester.allRenderObjects.whereType<RenderSelectionView>().first;
        expect(selectionRender.isSelectionDragging, isFalse);
        expect(selectionRender.isHandleDragInProgress, isFalse);

        await gesture.moveBy(const Offset(0, -40));
        await tester.pump();
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump();
        expect(scroll.offset, greaterThan(0), reason: '拒绝长按不能夺走当前 pointer，后续拖动仍归滚动');

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );
  });
}
