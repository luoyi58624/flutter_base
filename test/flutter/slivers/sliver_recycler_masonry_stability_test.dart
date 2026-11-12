import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fixture {
  _Fixture(
    this.tester, {
    required this.count,
    required this.heightAt,
    this.typeAt,
    this.spacing = 0,
    this.crossSpacing = 0,
    Size? size,
  }) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size ?? Size(320, 240);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(controller.dispose);
  }

  final WidgetTester tester;
  final int count;
  final double Function(int) heightAt;
  final Object? Function(int)? typeAt;
  final double spacing;
  final double crossSpacing;
  final controller = ScrollController();
  final builtIndices = <int>{};
  final taps = <int>[];

  Widget _sliver() => ElSliverMasonry.recycler(
    itemCount: count,
    crossAxisCount: 2,
    mainAxisSpacing: spacing,
    crossAxisSpacing: crossSpacing,
    itemType: typeAt,
    itemBuilder: (_, index) => ValueListenableBuilder<int>(
      valueListenable: index,
      builder: (_, value, _) {
        builtIndices.add(value);
        return SizedBox(
          key: ValueKey(value),
          height: heightAt(value),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps.add(index.value),
            child: Text('卡片 $value'),
          ),
        );
      },
    ),
  );

  Widget _scrollView(Widget sliver) => CustomScrollView(
    key: ValueKey('masonry-stability'),
    controller: controller,
    physics: ClampingScrollPhysics(),
    scrollCacheExtent: ScrollCacheExtent.pixels(0),
    slivers: [sliver],
  );

  Future<void> mount({bool rebuildForConstraints = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: rebuildForConstraints ? LayoutBuilder(builder: (_, _) => _scrollView(_sliver())) : _scrollView(_sliver()),
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

  Rect get viewport => tester.getRect(find.byKey(ValueKey('masonry-stability')));

  Rect rect(int index) => tester.getRect(find.byKey(ValueKey(index))).shift(-viewport.topLeft);

  Map<int, Rect> visibleRects() {
    final visible = <int, Rect>{};
    final bounds = viewport;
    for (final element
        in find
            .descendant(
              of: find.byKey(ValueKey('masonry-stability')),
              matching: find.byWidgetPredicate((widget) => widget is SizedBox && widget.key is ValueKey<int>),
            )
            .evaluate()) {
      final index = (element.widget.key! as ValueKey<int>).value;
      final global = tester.getRect(find.byWidget(element.widget));
      if (global.overlaps(bounds)) visible[index] = global.shift(-bounds.topLeft);
    }
    return visible;
  }

  void expectSamePositions(Map<int, Rect> before) {
    for (final entry in before.entries) {
      expect(find.byKey(ValueKey(entry.key)), findsOneWidget, reason: '原本仍在视口内的卡片不能因重算丢失。');
      final after = rect(entry.key);
      expect(after.left, closeTo(entry.value.left, .01), reason: '卡片 ${entry.key} 不能换列。');
      expect(after.top, closeTo(entry.value.top, .01), reason: '卡片 ${entry.key} 的可见位置不能跳动。');
      expect(after.size, entry.value.size);
    }
  }

  void expectFilledViewport() {
    final cards = visibleRects().values.toList();
    final lanes = cards.map((rect) => rect.left).toSet();
    expect(lanes.length, 2);
    for (final left in lanes) {
      final column = cards.where((rect) => rect.left == left).toList()..sort((a, b) => a.top.compareTo(b.top));
      expect(column.first.top, lessThanOrEqualTo(.01));
      expect(column.last.bottom, greaterThanOrEqualTo(viewport.height - .01));
      for (var index = 1; index < column.length; index++) {
        expect(column[index].top, closeTo(column[index - 1].bottom + spacing, .01));
      }
    }
  }

  Future<void> unmount() async {
    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }
}

void main() {
  testWidgets('Masonry 同一视口扩展首次测得新类型时保持两列已显示卡片的位置', (tester) async {
    bool lateType(int index) => (index >= 10 && index <= 18) || (index >= 100 && index <= 108);
    final fixture = _Fixture(
      tester,
      count: 400,
      typeAt: (index) => lateType(index) ? 1 : 0,
      heightAt: (index) => lateType(index) ? 250 : 100,
    );
    // 保持原 Sliver Widget，只扩大主轴可视范围，排除父级重建导致的缓存清理。
    await fixture.mount();
    final originalSliver = tester.widget<ElSliverGrid>(
      find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry),
    );
    await fixture.jump(4000);
    expect(fixture.builtIndices.any(lateType), isFalse);
    final before = fixture.visibleRects();
    expect(before.keys, containsAll([80, 81, 82, 83, 84, 85]));
    expect(before[80]!.top, 0);
    expect(before[81]!.top, 0);
    final beforeOffset = fixture.controller.offset;
    final beforeTotal = fixture.controller.position.maxScrollExtent + fixture.controller.position.viewportDimension;

    // 新露出的第100项给出250高的首次样本；前方10..18仍只拥有已推算的位置。
    tester.view.physicalSize = Size(320, 1400);
    await fixture.settle();
    expect(
      tester.widget<ElSliverGrid>(
        find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry),
      ),
      same(originalSliver),
    );
    expect(fixture.builtIndices.contains(100), isTrue);
    expect(fixture.controller.offset, closeTo(beforeOffset, .01), reason: '新类型的估值只能影响后续推算，不能回溯移动已经显示的卡片。');
    fixture.expectSamePositions(before);
    fixture.expectFilledViewport();
    final afterTotal = fixture.controller.position.maxScrollExtent + fixture.controller.position.viewportDimension;
    expect(afterTotal, greaterThan(beforeTotal), reason: '新测尺寸仍须更新后续范围，不能通过冻结总长度掩盖跳动。');

    await fixture.jump(fixture.controller.position.maxScrollExtent);
    expect(find.byKey(ValueKey(fixture.count - 1)), findsOneWidget, reason: '必须实际布局到最后一张卡片。');
    final finalTotal = fixture.controller.position.maxScrollExtent + fixture.controller.position.viewportDimension;
    expect((finalTotal - afterTotal).abs(), lessThanOrEqualTo(250.01), reason: '末尾都是已知100高条目，列尾差不能吞掉前方9张未测卡片的整段估值差。');
    await fixture.unmount();
  });

  testWidgets('Masonry 首次远跳测得新类型尺寸时服从滚动目标，连续目标不会被旧锚点拉回', (tester) async {
    bool lateType(int index) => (index >= 10 && index <= 18) || (index >= 100 && index <= 108);
    final fixture = _Fixture(
      tester,
      count: 400,
      typeAt: (index) => lateType(index) ? 1 : 0,
      heightAt: (index) => lateType(index) ? 250 : 100,
    );
    await fixture.mount();
    expect(fixture.builtIndices.any(lateType), isFalse, reason: '初始视口还没有测量第二种卡片。');

    // 跳到未知区域后首次获得第二种卡片的真实高度；前方仍有同类型的未测条目。
    await fixture.jump(5000);
    expect(fixture.builtIndices.any(lateType), isTrue);
    expect(fixture.controller.offset, closeTo(5000, .01), reason: '拖动目标没有真实旧可见锚点，不能用估算条目反向改写用户请求的位置。');
    fixture.expectFilledViewport();

    // 滚动条连续改写目标时，下一帧只应服从最后一次用户请求。
    fixture.controller.jumpTo(2200);
    fixture.controller.jumpTo(7800);
    await fixture.settle();
    expect(fixture.controller.offset, closeTo(7800, .01));
    fixture.expectFilledViewport();
    await fixture.jump(1200);
    expect(fixture.controller.offset, closeTo(1200, .01));
    fixture.expectFilledViewport();

    final visible = fixture.visibleRects().entries.first;
    final hit = visible.value.intersect(Offset.zero & fixture.viewport.size).center + fixture.viewport.topLeft;
    await tester.tapAt(hit);
    expect(fixture.taps, [visible.key]);
    await fixture.unmount();
  });

  testWidgets('Masonry 主轴视口收缩和恢复重建后保持已见卡片位置与滚动偏移', (tester) async {
    final heights = [100.0, 160.0, 80.0, 240.0, 120.0, 60.0, 180.0];
    final fixture = _Fixture(
      tester,
      count: 200,
      heightAt: (index) => heights[index % heights.length],
      spacing: 8,
      crossSpacing: 12,
      size: Size(360, 480),
    );
    // 返回动画或祖先布局变化会重建声明；数据、列数、列宽和间距没有变化。
    await fixture.mount(rebuildForConstraints: true);
    for (final pixels in [300.0, 700.0, 1100.0]) {
      await fixture.jump(pixels);
    }
    final beforeOffset = fixture.controller.offset;
    final before = Map<int, Rect>.fromEntries(
      fixture.visibleRects().entries.where((entry) => entry.value.top < 240 && entry.value.bottom > 0),
    );
    expect(beforeOffset, greaterThan(300));
    expect(before.length, greaterThanOrEqualTo(2));
    expect(before.values.map((rect) => rect.left).toSet().length, 2);

    for (final height in [360.0, 430.0, 480.0]) {
      tester.view.physicalSize = Size(360, height);
      await fixture.settle();
      expect(fixture.controller.offset, closeTo(beforeOffset, .01), reason: '仅主轴可视范围变化不能把已测尺寸和位置重置成估值。');
      fixture.expectSamePositions(before);
    }
    await fixture.unmount();
  });
}
