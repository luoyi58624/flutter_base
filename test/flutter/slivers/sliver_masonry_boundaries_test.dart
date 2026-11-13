import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _MasonryFixture {
  _MasonryFixture(this.tester, {required this.columns, required this.cacheExtent}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(columns * 120 + (columns - 1) * crossSpacing, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(controller.dispose);
  }

  static const count = 1200;
  static const spacing = 8.0;
  static const crossSpacing = 12.0;
  static const heights = [64.0, 144.0, 88.0, 232.0, 112.0, 72.0, 184.0, 96.0, 128.0];

  final WidgetTester tester;
  final int columns;
  final double cacheExtent;
  final controller = ScrollController();
  final builtIndices = <int>{};
  var buildCalls = 0;

  Future<void> mount() async {
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: CustomScrollView(
          key: ValueKey('masonry-boundaries'),
          controller: controller,
          physics: ClampingScrollPhysics(),
          scrollCacheExtent: ScrollCacheExtent.pixels(cacheExtent),
          slivers: [
            ElSliverMasonry.recycler(
              itemCount: count,
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: crossSpacing,
              itemBuilder: (_, index) => ValueListenableBuilder<int>(
                valueListenable: index,
                builder: (_, value, _) {
                  buildCalls++;
                  builtIndices.add(value);
                  return SizedBox(key: ValueKey(value), height: heights[value % heights.length]);
                },
              ),
            ),
          ],
        ),
      ),
    );
    await settle();
  }

  Future<void> settle() async {
    await tester.pumpAndSettle(Duration(milliseconds: 16), EnginePhase.sendSemanticsUpdate, Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  }

  Future<void> jump(double pixels) async {
    controller.jumpTo(pixels);
    await settle();
  }

  Rect get viewport => tester.getRect(find.byKey(ValueKey('masonry-boundaries')));

  Map<int, Rect> visibleRects() {
    final bounds = viewport;
    final result = <int, Rect>{};
    for (final element
        in find
            .descendant(
              of: find.byKey(ValueKey('masonry-boundaries')),
              matching: find.byWidgetPredicate((widget) => widget is SizedBox && widget.key is ValueKey<int>),
            )
            .evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      if (rect.overlaps(bounds)) {
        result[(element.widget.key! as ValueKey<int>).value] = rect.shift(-bounds.topLeft);
      }
    }
    return result;
  }

  void expectLaneGeometry({bool fillViewport = true}) {
    final cards = visibleRects().values.toList();
    expect(cards, isNotEmpty);
    final lanes = cards.map((rect) => rect.left).toSet();
    if (fillViewport) expect(lanes, hasLength(columns));
    for (final left in lanes) {
      final lane = cards.where((rect) => rect.left == left).toList()..sort((a, b) => a.top.compareTo(b.top));
      expect(left / (120 + crossSpacing), closeTo((left / (120 + crossSpacing)).roundToDouble(), .01));
      for (final rect in lane) {
        expect(rect.width, closeTo(120, .01));
      }
      if (fillViewport) {
        // 视口边缘允许恰好落在真实的 spacing 内。
        expect(lane.first.top, lessThanOrEqualTo(spacing + .01));
        expect(lane.last.bottom, greaterThanOrEqualTo(viewport.height - spacing - .01));
      }
      for (var index = 1; index < lane.length; index++) {
        expect(lane[index].top - lane[index - 1].bottom, closeTo(spacing, .01), reason: '同列相邻条目不能重叠或留下估算接缝。');
      }
    }
  }

  Future<Set<double>> step(double delta) async {
    final before = visibleRects();
    await jump(controller.offset + delta);
    final after = visibleRects();
    final common = before.keys.where(after.containsKey).toList();
    expect(common, isNotEmpty);
    final reference = common.first;
    final referenceBefore = before[reference]!;
    final referenceAfter = after[reference]!;
    final comparedLanes = <double>{};
    for (final index in common) {
      final oldRect = before[index]!;
      final newRect = after[index]!;
      expect(newRect.left, closeTo(oldRect.left, .01), reason: '持续可见的条目 $index 不能因补测而换列。');
      // 允许所有列共同发生坐标修正；不同列不能相对彼此额外移动。
      expect(
        newRect.top - referenceAfter.top,
        closeTo(oldRect.top - referenceBefore.top, .01),
        reason: '步进 $delta 后，条目 $index 与 $reference 的相对位置改变。',
      );
      expect(newRect.size, oldRect.size);
      comparedLanes.add(oldRect.left);
    }
    expectLaneGeometry();
    return comparedLanes;
  }

  Future<void> expectTop() async {
    await jump(0);
    expect(controller.offset, closeTo(0, .01));
    final cards = visibleRects();
    expect(cards.keys, containsAll([for (var index = 0; index < columns; index++) index]));
    for (var index = 0; index < columns; index++) {
      expect(cards[index]!.top, closeTo(0, .01), reason: '首批条目必须齐顶，不能保留各列偏移。');
    }
    for (final rect in cards.values) {
      expect(rect.top, greaterThanOrEqualTo(-.01), reason: '返回起点后不能用负坐标隐藏接缝。');
    }
    expectLaneGeometry();
  }

  Future<void> expectEnd() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      await jump(controller.position.maxScrollExtent);
      final cards = visibleRects();
      final bottom = cards.values.map((rect) => rect.bottom).reduce(math.max);
      if (cards.containsKey(count - 1) &&
          (controller.offset - controller.position.maxScrollExtent).abs() < .01 &&
          (bottom - viewport.height).abs() < .01) {
        break;
      }
    }
    final cards = visibleRects();
    expect(cards, contains(count - 1), reason: '普通高度分布下，有限次追踪末尾应实际显示最后条目。');
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, .01));
    expect(cards.values.map((rect) => rect.bottom).reduce(math.max), closeTo(viewport.height, .01));
    expectLaneGeometry(fillViewport: false);
  }

  Future<void> unmount() async {
    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }
}

void main() {
  for (final (columns, cacheExtent) in [(2, 0.0), (3, 250.0)]) {
    testWidgets('Masonry $columns 列 cache=$cacheExtent 双向补测稳定且首尾没有几何接缝', (tester) async {
      final fixture = _MasonryFixture(tester, columns: columns, cacheExtent: cacheExtent);
      await fixture.mount();
      final initiallyBuilt = fixture.builtIndices.toSet();
      final initialBuildCalls = fixture.buildCalls;
      await fixture.jump(20000);
      expect(fixture.visibleRects().keys.any((index) => index > 100), isTrue);
      expect(fixture.builtIndices.difference(initiallyBuilt).length, lessThanOrEqualTo(80));
      expect(fixture.buildCalls - initialBuildCalls, lessThanOrEqualTo(160), reason: '远跳只能构建目标附近窗口，不能预建全部未知前缀。');
      fixture.expectLaneGeometry();

      final reverseLanes = <double>{};
      final forwardLanes = <double>{};
      for (var step = 0; step < 8; step++) {
        reverseLanes.addAll(await fixture.step(step.isEven ? -24 : -40));
      }
      for (var step = 0; step < 8; step++) {
        forwardLanes.addAll(await fixture.step(step.isEven ? 24 : 40));
      }
      expect(reverseLanes, hasLength(columns), reason: '反向比较必须覆盖所有列。');
      expect(forwardLanes, hasLength(columns), reason: '正向比较必须覆盖所有列。');

      await fixture.expectTop();
      await fixture.expectEnd();
      await fixture.expectTop();
      await fixture.unmount();
    });
  }
}
