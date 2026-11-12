import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

// 原始动作与断言来自旧仓库 nested_test.dart:3418 和 official_nested_scroll_test.dart。
// 只把外层宿主换成官方分页，保留途中锁定、新起手让位、反拖及惯性契约。
Future<(PageController, ScrollController)> _pump(WidgetTester tester, Axis axis, {bool disabled = false}) async {
  final pages = PageController(initialPage: 1);
  final inner = ScrollController();
  addTearDown(pages.dispose);
  addTearDown(inner.dispose);
  await tester.pumpWidget(
    Directionality(
      textDirection: .ltr,
      child: ScrollConfiguration(
        behavior: ScrollBehavior().copyWith(
          scrollbars: false,
          overscroll: false,
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        child: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: ElPageView(
              controller: pages,
              scrollDirection: axis,
              physics: disabled ? NeverScrollableScrollPhysics() : ClampingScrollPhysics(),
              children: [
                ColoredBox(color: Colors.blue),
                ElScrollView(
                  key: ValueKey('inner'),
                  controller: inner,
                  axis: axis,
                  physics: ClampingScrollPhysics(),
                  children: [SizedBox(width: 900, height: 900)],
                ),
                ColoredBox(color: Colors.green),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return (pages, inner);
}

// 沿用旧测试的输入适配：触屏、鼠标与原生触控板使用同一段动作。
class _Input {
  _Input(this.tester, this.point, this.kind, this.stamp);
  final WidgetTester tester;
  final Offset point;
  final PointerDeviceKind kind;
  Duration stamp;
  Offset pan = Offset.zero;
  TestGesture? gesture;

  static Future<_Input> start(WidgetTester tester, PointerDeviceKind kind) async {
    final input = _Input(
      tester,
      tester.getCenter(find.byKey(ValueKey('inner'))),
      kind,
      tester.binding.currentSystemFrameTimeStamp,
    );
    if (kind == .trackpad) {
      await tester.sendEventToBinding(
        PointerPanZoomStartEvent(pointer: 79, position: input.point, timeStamp: input.stamp),
      );
    } else {
      input.gesture = await tester.createGesture(kind: kind);
      addTearDown(input.gesture!.removePointer);
      await input.gesture!.down(input.point, timeStamp: input.stamp);
    }
    await tester.pump();
    return input;
  }

  Future<void> move(Offset delta, {int milliseconds = 16}) async {
    final duration = Duration(milliseconds: milliseconds);
    stamp += duration;
    if (kind == .trackpad) {
      pan += delta;
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(pointer: 79, position: point, pan: pan, panDelta: delta, timeStamp: stamp),
      );
    } else {
      await gesture!.moveBy(delta, timeStamp: stamp);
    }
    await tester.pump(duration);
  }

  Future<void> end({bool cancel = false, bool fling = false}) async {
    final duration = Duration(milliseconds: fling ? 1 : 1000);
    stamp += duration;
    await tester.pump(duration);
    if (kind == .trackpad) {
      await tester.sendEventToBinding(PointerPanZoomEndEvent(pointer: 79, position: point, timeStamp: stamp));
    } else if (cancel) {
      await gesture!.cancel(timeStamp: stamp);
    } else {
      await gesture!.up(timeStamp: stamp);
    }
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final kind in <PointerDeviceKind>[.touch, .mouse, .trackpad]) {
    for (final leading in [true, false]) {
      // 旧 nested_test.dart:2873：先贴边，再连续向外拖动六笔，最后应翻页。
      testWidgets('旧 Tab 边缘翻页 ${kind.name} leading=$leading', (tester) async {
        final (pages, inner) = await _pump(tester, .horizontal);
        final edge = leading ? 0.0 : inner.position.maxScrollExtent;
        inner.jumpTo(edge);
        await tester.pump();
        final gesture = await _Input.start(tester, kind);
        for (var i = 0; i < 6; i++) {
          await gesture.move(Offset(leading ? 70 : -70, 0));
        }
        await gesture.end();
        expect(pages.page, leading ? 0 : 2);
        expect(tester.takeException(), isNull);
      });
    }
    for (final axis in Axis.values) {
      for (final leading in [false, true]) {
        testWidgets('旧契约 ${kind.name} ${axis.name} leading=$leading：途中锁定，新手势才让位', (tester) async {
          final (pages, inner) = await _pump(tester, axis);
          final edge = leading ? 0.0 : inner.position.maxScrollExtent;
          final sign = leading ? -1.0 : 1.0;
          Offset drag(double delta) => axis == Axis.horizontal ? Offset(-delta, 0) : Offset(0, -delta);
          inner.jumpTo(edge - sign * 100);
          await tester.pump();
          final start = inner.offset;
          final outerStart = pages.offset;
          final gesture = await _Input.start(tester, kind);
          for (final delta in [30.0, 20.0, 20.0]) {
            await gesture.move(drag(sign * delta));
          }
          expect((inner.offset - start) * sign, greaterThan(0));
          expect((edge - inner.offset) * sign, greaterThan(0));
          await gesture.move(drag(sign * 90));
          expect(inner.offset, closeTo(edge, .01));
          expect(pages.offset, outerStart, reason: '撞边界的同帧余量不能直接写入祖先');
          await gesture.move(drag(sign * 30));
          expect(pages.offset, outerStart, reason: '同手势后续输入也不能交给祖先');
          await gesture.move(drag(sign * 12), milliseconds: 600);
          expect(pages.offset, outerStart, reason: '停顿不等于新手势');
          await gesture.move(drag(-sign * 25));
          expect((edge - inner.offset) * sign, greaterThan(0), reason: '回拖仍归原内层');
          expect(pages.offset, outerStart);
          await gesture.end(cancel: leading);
          expect(pages.offset, outerStart, reason: '结束或取消不得向祖先遗留惯性');

          inner.jumpTo(edge);
          await tester.pump();
          final next = await _Input.start(tester, kind);
          for (final delta in [30.0, 20.0, 20.0]) {
            await next.move(drag(sign * delta));
          }
          expect((pages.offset - outerStart) * sign, greaterThan(0));
          expect(inner.offset, closeTo(edge, .01));
          final beforeReverse = pages.offset;
          await next.move(drag(-sign * 12));
          expect(pages.offset, closeTo(beforeReverse - sign * 12, .01), reason: '新手势选定外层，反拖也不交还内层');
          expect(inner.offset, closeTo(edge, .01));
          await next.end();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final leading in [false, true]) {
    testWidgets('旧契约 leading=$leading：识别起手方向选层，不能等反向 update 才决定', (tester) async {
      final (pages, inner) = await _pump(tester, .horizontal);
      final edge = leading ? 0.0 : inner.position.maxScrollExtent;
      final sign = leading ? 1.0 : -1.0;
      inner.jumpTo(edge);
      await tester.pump();
      final gesture = await _Input.start(tester, .touch);
      await gesture.move(Offset(sign * 36, 0));
      final before = pages.offset;
      await gesture.move(Offset(-sign * 16, 0));
      expect(inner.offset, edge);
      expect(pages.offset, closeTo(before + sign * 16, .001));
      await gesture.end(cancel: true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('旧契约 leading=$leading：内层仅剩一像素仍锁定，不将释放速度交给分页', (tester) async {
      final (pages, inner) = await _pump(tester, .horizontal);
      final edge = leading ? 0.0 : inner.position.maxScrollExtent;
      final sign = leading ? 1.0 : -1.0;
      inner.jumpTo(edge + sign);
      await tester.pump();
      final gesture = await _Input.start(tester, .touch);
      await gesture.move(Offset(sign * 36, 0));
      for (final amount in [32.0, 24.0]) {
        await gesture.move(Offset(sign * amount, 0));
        expect(inner.offset, edge);
        expect(pages.offset, 300);
      }
      await gesture.end(fling: true);
      expect(pages.offset, 300);
      expect(tester.takeException(), isNull);
    });

    testWidgets('旧契约 leading=$leading：释放后惯性撞边界也不切页', (tester) async {
      final (pages, inner) = await _pump(tester, .horizontal);
      final edge = leading ? 0.0 : inner.position.maxScrollExtent;
      final sign = leading ? 1.0 : -1.0;
      inner.jumpTo(edge + sign * 220);
      await tester.pump();
      await tester.fling(find.byKey(ValueKey('inner')), Offset(sign * 60, 0), 1800);
      expect(inner.offset, inExclusiveRange(0, inner.position.maxScrollExtent));
      await tester.pumpAndSettle();
      expect(inner.offset, closeTo(edge, .01));
      expect(pages.offset, 300);
      expect(tester.takeException(), isNull);
    });
  }
}
