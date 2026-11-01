import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 420, double height = 100, TextDirection direction = .ltr}) => Directionality(
  textDirection: direction,
  child: Align(
    alignment: .topLeft,
    child: SizedBox(width: width, height: height, child: child),
  ),
);

void main() {
  for (final builder in [false, true]) {
    testWidgets('itemWidth builder=$builder 混排、窗口缩放与属性更新同步滚动范围', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      Widget item(int index) => SizedBox(key: ValueKey('cell-$index'));
      Widget build(double width, double itemWidth) {
        final grid = builder
            ? ElGridView.builder(
                key: ValueKey('grid'),
                itemWidth: itemWidth,
                mainAxisExtent: 20,
                rowGap: 6,
                columnGap: 10,
                itemCount: 7,
                itemBuilder: (_, index) => item(index),
              )
            : ElGridView(
                key: ValueKey('grid'),
                itemWidth: itemWidth,
                mainAxisExtent: 20,
                rowGap: 6,
                columnGap: 10,
                children: List.generate(7, item),
              );
        return _host(
          ElScrollView(
            controller: controller,
            scrollbar: ElNoScrollBar(),
            padding: .all(10),
            gap: 8,
            cacheExtent: 0,
            children: [
              SizedBox(height: 24),
              grid,
              SizedBox(key: ValueKey('footer'), height: 16),
            ],
          ),
          width: width,
        );
      }

      for (final (width, itemWidth, cellWidth, gridHeight) in [
        (420.0, 150.0, 195.0, 98.0),
        (620.0, 150.0, 142.5, 46.0),
        (620.0, 250.0, 295.0, 98.0),
      ]) {
        await tester.pumpWidget(build(width, itemWidth));
        await tester.pump();
        expect(tester.getSize(find.byKey(ValueKey('cell-0'))), Size(cellWidth, 20));
        expect(tester.getTopLeft(find.byKey(ValueKey('cell-0'))), Offset(10, 42));
        expect(tester.getSize(find.byKey(ValueKey('grid'))), Size(width - 20, gridHeight));
        expect(tester.getTopLeft(find.byKey(ValueKey('footer'))), Offset(10, 50 + gridHeight));
        expect(controller.position.maxScrollExtent, gridHeight - 24);
        expect(tester.takeException(), isNull);
      }

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(ValueKey('footer'))).dy, 74);
      expect(tester.takeException(), isNull);
    });

    testWidgets('itemWidth builder=$builder 横向保持物理格宽，RTL 滚动范围一致', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      Widget item(int index) => SizedBox(key: ValueKey(index));
      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        final grid = builder
            ? ElGridView.builder(
                itemWidth: 100,
                aspectRatio: 2,
                rowGap: 4,
                columnGap: 6,
                itemCount: 10,
                itemBuilder: (_, index) => item(index),
              )
            : ElGridView(itemWidth: 100, aspectRatio: 2, rowGap: 4, columnGap: 6, children: List.generate(10, item));
        await tester.pumpWidget(
          _host(
            ElScrollView(
              controller: controller,
              axis: .horizontal,
              scrollbar: ElNoScrollBar(),
              padding: .all(10),
              cacheExtent: 0,
              children: [grid],
            ),
            width: 300,
            height: 124,
            direction: direction,
          ),
        );
        await tester.pump();
        expect(controller.position.maxScrollExtent, 244);
        final first = direction == .ltr ? 0 : 8;
        final next = direction == .ltr ? 2 : 6;
        expect(tester.getSize(find.byKey(ValueKey(first))), Size(100, 50));
        final firstX = direction == .ltr ? 10.0 : 190.0;
        final nextX = direction == .ltr ? 116.0 : 84.0;
        expect(tester.getTopLeft(find.byKey(ValueKey(first))), Offset(firstX, 10));
        expect(tester.getTopLeft(find.byKey(ValueKey(first + 1))), Offset(firstX, 64));
        expect(tester.getTopLeft(find.byKey(ValueKey(next))), Offset(nextX, 10));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('itemWidth builder=$builder shrinkWrap 使用完整网格尺寸', (tester) async {
      Widget item(int index) => SizedBox(key: ValueKey(index));
      final grid = builder
          ? ElGridView.builder(
              itemWidth: 150,
              aspectRatio: 2,
              columnGap: 10,
              rowGap: 6,
              itemCount: 5,
              itemBuilder: (_, index) => item(index),
            )
          : ElGridView(itemWidth: 150, aspectRatio: 2, columnGap: 10, rowGap: 6, children: List.generate(5, item));
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 420,
              child: ElScrollView(
                key: ValueKey('scroll'),
                shrinkWrap: true,
                padding: .all(10),
                scrollbar: ElNoScrollBar(),
                children: [grid],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byKey(ValueKey('scroll'))), Size(420, 324.5));
      expect(tester.getTopLeft(find.byKey(ValueKey(4))), Offset(10, 217));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('百万条 itemWidth 网格首帧范围精确，远跳仅构建和布局窗口内条目', (tester) async {
    final controller = ElScrollController();
    addTearDown(controller.dispose);
    final key = GlobalKey<ElScrollViewState>();
    final built = <int>[];
    await tester.pumpWidget(
      _host(
        ElScrollView(
          key: key,
          controller: controller,
          scrollbar: ElNoScrollBar(),
          cacheExtent: 0,
          children: [
            ElGridView.builder(
              itemWidth: 100,
              mainAxisExtent: 20,
              columnGap: 10,
              rowGap: 6,
              itemCount: 1000000,
              itemBuilder: (_, index) {
                built.add(index);
                return SizedBox(key: ValueKey(index));
              },
            ),
          ],
        ),
        width: 300,
        height: 180,
      ),
    );
    await tester.pump();
    final state = key.currentState!;
    expect(controller.position.maxScrollExtent, 333334 * 20 + 333333 * 6 - 180);
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(280 / 3, 20));
    expect(built.length, lessThan(40));
    expect(state.debugCounters.debugMaxMountedChildCount, lessThan(40));
    expect(state.debugExtentStorageSlotCount, lessThan(20));

    final beforeLayout = state.debugCounters.debugLayoutChildVisitCount;
    built.clear();
    controller.jumpTo(2600000);
    await tester.pump();
    expect(find.byKey(ValueKey(300000)), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(ValueKey(300000))), Offset.zero);
    expect(built.length, lessThan(40));
    expect(state.debugCounters.debugLayoutChildVisitCount - beforeLayout, lessThan(50));
    expect(state.debugCounters.debugMaxMountedChildCount, lessThan(40));
    expect(state.debugExtentStorageSlotCount, lessThan(20));
    expect(tester.takeException(), isNull);
  });
}
