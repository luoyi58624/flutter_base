import 'dart:math' as math;

import 'package:example/src/pages/examples/recycler_view/media.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

typedef _Frame = ({double pixels, double maxExtent, double thumb, Map<int, Rect> items});

_Frame _readFrame(
  WidgetTester tester,
  rv.RecyclerView list,
  ScrollPosition position,
  ScrollbarPainter painter,
  Rect viewport,
) {
  final manager = list.getLayoutManager()! as rv.StaggeredGridLayoutManager;
  final first = manager.findFirstVisibleItemPositions();
  final last = manager.findLastVisibleItemPositions();
  expect(first, hasLength(2));
  expect(last, hasLength(2));
  expect(first, everyElement(greaterThanOrEqualTo(0)));

  final items = <int, Rect>{};
  for (var index = first.reduce(math.min); index <= last.reduce(math.max); index++) {
    final holder = list.findViewHolderForAdapterPosition(index);
    if (holder == null) continue;
    final rect = tester.getRect(find.byWidget(holder.itemView));
    if (rect.overlaps(viewport)) items[holder.getItemId()] = rect;
  }
  return (
    pixels: position.pixels,
    maxExtent: position.maxScrollExtent,
    thumb: painter.getThumbScrollOffset(),
    items: items,
  );
}

void _expectCovered(_Frame frame, Rect viewport, String phase) {
  // 测量外层条目，列内设计留白已包含在条目高度中。
  for (final left in [true, false]) {
    final column = frame.items.values.where((rect) => (rect.left < viewport.center.dx) == left).toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    expect(column, isNotEmpty, reason: '$phase，滚动偏移 ${frame.pixels}');
    var nextTop = viewport.top;
    for (final rect in column) {
      expect(rect.top, lessThanOrEqualTo(nextTop + .01), reason: '$phase，滚动偏移 ${frame.pixels}，列内出现空洞');
      expect(rect.top, lessThan(viewport.bottom));
      if (nextTop != viewport.top) {
        expect(rect.top, closeTo(nextTop, .01), reason: '$phase，滚动偏移 ${frame.pixels}，同列卡片重叠');
      }
      nextTop = rect.bottom;
    }
    expect(nextTop, greaterThanOrEqualTo(viewport.bottom - .01), reason: '$phase，滚动偏移 ${frame.pixels}，列底露白');
  }
}

void _expectStationary(_Frame actual, _Frame expected, String phase) {
  expect(actual.pixels, closeTo(expected.pixels, .01), reason: '$phase，内容偏移变化');
  expect(actual.maxExtent, closeTo(expected.maxExtent, .01), reason: '$phase，列表总滚动范围变化');
  expect(actual.thumb, closeTo(expected.thumb, .01), reason: '$phase，滑块移动');
  expect(actual.items, expected.items, reason: '$phase，同一可见范围的卡片 ID 或矩形变化');
}

void main() {
  for (final screen in [(size: Size(1080, 2400), dpr: 2.75), (size: Size(1256, 2760), dpr: 3.0)]) {
    testWidgets('安卓瀑布流滑块快速下拖再上拖，停住和松手后保持两列卡片坐标 ${screen.dpr}x', (tester) async {
      tester.view.devicePixelRatio = screen.dpr;
      tester.view.physicalSize = screen.size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.mobileComponents,
          child: MaterialApp(
            theme: ThemeData(platform: .android),
            home: RecyclerWaterfallPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listFinder = find.byKey(ValueKey('media-recycler-waterfall'));
      final list = tester.widget<rv.RecyclerView>(listFinder);
      final viewport = tester.getRect(listFinder);
      final barFinder = find.byWidgetPredicate((widget) => widget is CupertinoScrollbar);
      final position = tester.widget<CupertinoScrollbar>(barFinder).controller!.position;
      final barState = tester.state<RawScrollbarState<CupertinoScrollbar>>(barFinder);
      // 读取画出的滑块偏移，确保事件落在实际滚动条上。
      // ignore: invalid_use_of_protected_member
      final painter = barState.scrollbarPainter;
      final rail = tester.getRect(barFinder);
      final start = Offset(rail.right - 4.5, rail.top + 21);
      expect(painter.hitTestOnlyThumbInteractive(start - rail.topLeft, .touch), isTrue);
      final initialMaxExtent = position.maxScrollExtent;
      final travel = initialMaxExtent / painter.getTrackToScroll(1);
      final gesture = await tester.startGesture(start);
      var time = Duration(milliseconds: 140);
      await tester.pump(time);

      _Frame read() => _readFrame(tester, list, position, painter, viewport);
      _Frame? previous;
      double? peak;
      final extentChanges = <double, double>{};
      final cardSteps = <({double fraction, int id, double error})>[];
      var comparedBothColumns = false;
      for (final fraction in [.13, .31, .52, .73, .60, .49, .37, .251, .25075, .2505, .25025, .25]) {
        final interval = Duration(microseconds: 8333);
        time += interval;
        await gesture.moveTo(start.translate(0, travel * fraction), timeStamp: time);
        final requested = position.pixels;
        await tester.pump(interval);
        final frame = read();
        extentChanges[fraction] = frame.maxExtent - initialMaxExtent;
        _expectCovered(frame, viewport, '滑块拖至 $fraction');
        if (previous case final before?) {
          expect(frame.pixels, peak == null ? greaterThan(before.pixels) : lessThan(before.pixels));
          final columns = <bool>{};
          for (final MapEntry(key: id, value: oldRect) in before.items.entries) {
            if (frame.items[id] case final rect?) {
              columns.add(rect.left < viewport.center.dx);
              expect(rect.left, closeTo(oldRect.left, .01), reason: '持续可见的卡片 $id 不应换列');
              expect(rect.size, oldRect.size, reason: '持续可见的卡片 $id 应保持尺寸');
              cardSteps.add((fraction: fraction, id: id, error: rect.top - oldRect.top + requested - before.pixels));
            }
          }
          comparedBothColumns |= columns.length == 2;
        }
        previous = frame;
        if (fraction == .73) {
          peak = frame.pixels;
          final hold = Duration(milliseconds: 32);
          time += hold;
          await tester.pump(hold);
          _expectStationary(read(), frame, '保持按住滑块');
        }
      }

      final stopped = read();
      expect(stopped.pixels, greaterThan(10000));
      expect(stopped.pixels, lessThan(peak!));
      // 不在最后一次 move 与 up 间停顿，避免速度追踪器掩盖滑块松手后的惯性。
      await gesture.up(timeStamp: time);
      for (final delay in [8, 16, 80, 240]) {
        await tester.pump(Duration(milliseconds: delay));
        _expectStationary(read(), stopped, '松手后下一帧间隔 ${delay}ms');
      }
      expect(comparedBothColumns, isTrue, reason: '反向微调应同时保留两列已显示的卡片');
      for (final step in cardSteps) {
        expect(step.error, closeTo(0, .01), reason: '拖至 ${step.fraction} 时卡片 ${step.id} 相对拖动位移错位');
      }
      for (final MapEntry(key: fraction, value: change) in extentChanges.entries) {
        expect(change, closeTo(0, .01), reason: '拖至 $fraction 后列表总长度改变，滑块对应的位置会漂移');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
