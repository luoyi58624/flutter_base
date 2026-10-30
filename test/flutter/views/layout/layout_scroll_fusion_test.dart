import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 300, double height = 180, TextDirection direction = .ltr}) => Directionality(
  textDirection: direction,
  child: Align(
    alignment: .topLeft,
    child: SizedBox(width: width, height: height, child: child),
  ),
);

void main() {
  testWidgets('builder inherited 更新同时换条目 Key，索引映射仍指向新条目', (tester) async {
    final key = GlobalKey<ElScrollViewState>();
    final view = ElListView.builder(
      itemCount: 4,
      fixedSize: true,
      itemBuilder: (context, index) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        return ElView(key: ValueKey('$scale-$index'), style: ElStyle(height: 20));
      },
    );
    Widget build(double scale) => _host(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: ElScrollView(key: key, scrollbar: ElNoScrollBar(), children: [view]),
      ),
    );
    await tester.pumpWidget(build(1));
    await tester.pump();
    await tester.pumpWidget(build(2));
    await tester.pump();
    final dynamic viewport = key.currentState!.debugScrollMixinViewportRenderObject;
    expect(viewport.debugLastPaintedChildCount, 4);
    expect(find.byKey(ValueKey('2.0-0')), findsOneWidget);
    expect(find.byKey(ValueKey('1.0-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全量 View 在独立布局与滚动布局间移动可重新接入真实条目', (tester) async {
    final viewKey = GlobalKey();
    final childKey = GlobalKey();
    final view = ElListView(
      key: viewKey,
      children: [ElView(key: childKey, style: ElStyle(height: 20))],
    );
    Widget build(bool hosted) => _host(
      Row(
        children: [
          Expanded(child: hosted ? ElView() : view),
          Expanded(
            child: ElScrollView(key: ValueKey('host'), scrollbar: ElNoScrollBar(), children: [if (hosted) view]),
          ),
        ],
      ),
    );
    await tester.pumpWidget(build(false));
    final element = childKey.currentContext;
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(childKey.currentContext, same(element));
    expect(tester.getTopLeft(find.byKey(childKey)).dx, 150);
    await tester.pumpWidget(build(false));
    await tester.pump();
    expect(childKey.currentContext, same(element));
    expect(tester.getTopLeft(find.byKey(childKey)).dx, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GlobalKey 布局段跨滚动容器移动时保留业务 Element', (tester) async {
    final key = GlobalKey();
    Widget build(bool moved) {
      final view = ElListView.builder(
        key: key,
        itemCount: 3,
        fixedSize: true,
        itemBuilder: (_, index) => ElView(key: ValueKey('moving-$index'), style: ElStyle(height: 20)),
      );
      return _host(
        Row(
          children: [
            Expanded(
              child: ElScrollView(key: ValueKey('left'), scrollbar: ElNoScrollBar(), children: moved ? [] : [view]),
            ),
            Expanded(
              child: ElScrollView(
                key: ValueKey('right'),
                scrollbar: ElNoScrollBar(),
                children: [
                  ElView(style: ElStyle(height: 10)),
                  if (moved) view,
                ],
              ),
            ),
          ],
        ),
      );
    }

    await tester.pumpWidget(build(false));
    await tester.pump();
    final before = tester.element(find.byKey(ValueKey('moving-1')));
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(tester.element(find.byKey(ValueKey('moving-1'))), same(before));
    expect(tester.getTopLeft(find.byKey(ValueKey('moving-0'))), Offset(150, 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('常驻列表和虚拟网格混排，窗口平移不扫描常驻条目', (tester) async {
    final controller = ElScrollController(initialScrollOffset: 20200);
    addTearDown(controller.dispose);
    final key = GlobalKey<ElScrollViewState>();
    await tester.pumpWidget(
      _host(
        ElScrollView(
          key: key,
          controller: controller,
          scrollbar: ElNoScrollBar(),
          cacheExtent: 0,
          children: [
            ElListView(fixedSize: true, children: List.generate(1000, (_) => ElView(style: ElStyle(height: 20)))),
            ElGridView.builder(
              itemCount: 1000000,
              itemBuilder: (_, _) => ElView(),
              crossAxisCount: 3,
              mainAxisExtent: 20,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = key.currentState!;
    final before = state.debugCounters.debugLayoutChildVisitCount;
    controller.jumpTo(20220);
    await tester.pump();
    expect(state.debugCounters.debugLayoutChildVisitCount - before, lessThan(50));
    expect(state.debugExtentStorageSlotCount, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认 List/Grid 全量挂载，滚动只访问可见绘制窗口', (tester) async {
    for (final grid in [false, true]) {
      final controller = ElScrollController();
      final key = GlobalKey<ElScrollViewState>();
      final viewKey = GlobalKey();
      final children = List.generate(
        2000,
        (index) => ElView(key: ValueKey(index), style: ElStyle(height: 20), child: '$index'),
      );
      await tester.pumpWidget(
        _host(
          ElScrollView(
            key: key,
            controller: controller,
            cacheExtent: 0,
            scrollbar: ElNoScrollBar(),
            children: [
              grid
                  ? ElGridView(key: viewKey, crossAxisCount: 3, mainAxisExtent: 20, children: children)
                  : ElListView(key: viewKey, fixedSize: true, children: children),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(ValueKey(1999)), findsOneWidget);
      expect(viewKey.currentContext!.findRenderObject(), grid ? isA<ElRenderGridView>() : isA<ElRenderListView>());
      final state = key.currentState!;
      final beforeLayout = state.debugCounters.debugLayoutChildVisitCount;
      final beforePaint = state.debugCounters.debugPaintCandidateVisitCount;
      controller.jumpTo(1000);
      await tester.pump();
      expect(state.debugCounters.debugLayoutChildVisitCount, beforeLayout);
      expect(state.debugCounters.debugPaintCandidateVisitCount - beforePaint, lessThan(40));
      expect(state.debugExtentStorageSlotCount, lessThan(10));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(_host(ElView()));
      controller.dispose();
    }
  });

  testWidgets('builder 保留 View context、跨段重复 Key 与 GlobalKey 生命周期', (tester) async {
    final left = GlobalKey();
    final right = GlobalKey();
    final item = GlobalKey();
    BuildContext? contextOfBuilder;
    Widget build(bool swapped) {
      final a = ElListView.builder(
        key: left,
        itemCount: 4,
        fixedSize: true,
        itemBuilder: (context, index) {
          contextOfBuilder = context;
          return ElView(key: index == 0 ? item : ValueKey(index), style: ElStyle(height: 20), child: 'a$index');
        },
      );
      final b = ElGridView.builder(
        key: right,
        crossAxisCount: 2,
        mainAxisExtent: 20,
        itemCount: 4,
        itemBuilder: (_, index) => ElView(key: ValueKey(index), child: 'b$index'),
      );
      return _host(ElScrollView(scrollbar: ElNoScrollBar(), children: swapped ? [b, a] : [a, b]));
    }

    await tester.pumpWidget(build(false));
    await tester.pump();
    expect(contextOfBuilder, same(left.currentContext));
    final element = item.currentContext;
    expect(find.descendant(of: find.byKey(left), matching: find.byKey(item)), findsOneWidget);
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(item.currentContext, same(element));
    expect(contextOfBuilder, same(left.currentContext));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_host(ElView()));
    expect(left.currentContext, isNull);
    expect(right.currentContext, isNull);
    expect(item.currentContext, isNull);
  });

  testWidgets('builder context 的 inherited 依赖变化会重建条目并更新固定尺寸', (tester) async {
    final view = ElListView.builder(
      itemCount: 100,
      fixedSize: true,
      itemBuilder: (context, index) => ElView(
        key: ValueKey(index),
        style: ElStyle(height: MediaQuery.textScalerOf(context).scale(20)),
      ),
    );
    Widget build(double scale) => _host(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: ElScrollView(scrollbar: ElNoScrollBar(), children: [view]),
      ),
    );
    await tester.pumpWidget(build(1));
    await tester.pump();
    expect(tester.getSize(find.byKey(ValueKey(1))).height, 20);
    await tester.pumpWidget(build(2));
    await tester.pump();
    expect(tester.getSize(find.byKey(ValueKey(1))).height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('横向网格一次算出范围，方向和物理 gap 与全量模式一致', (tester) async {
    for (final builder in [false, true]) {
      final controller = ElScrollController();
      Widget item(int index) => ElView(key: ValueKey(index));
      final view = builder
          ? ElGridView.builder(
              itemCount: 10,
              itemBuilder: (_, index) => item(index),
              crossAxisCount: 2,
              aspectRatio: 2,
              rowGap: 4,
              columnGap: 6,
            )
          : ElGridView(crossAxisCount: 2, aspectRatio: 2, rowGap: 4, columnGap: 6, children: List.generate(10, item));
      await tester.pumpWidget(
        _host(
          ElScrollView(
            controller: controller,
            axis: .horizontal,
            scrollbar: ElNoScrollBar(),
            padding: .all(10),
            children: [view],
          ),
          height: 124,
        ),
      );
      expect(controller.position.maxScrollExtent, 244);
      expect(tester.getSize(find.byKey(ValueKey(0))), Size(100, 50));
      expect(tester.getTopLeft(find.byKey(ValueKey(0))), Offset(10, 10));
      expect(tester.getTopLeft(find.byKey(ValueKey(1))), Offset(10, 64));
      expect(tester.getTopLeft(find.byKey(ValueKey(2))), Offset(116, 10));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(_host(ElView()));
      controller.dispose();
    }
  });

  testWidgets('垂直 RTL 网格从右向左排，整体 View 保持正确尺寸', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        ElScrollView(
          scrollbar: ElNoScrollBar(),
          children: [
            ElGridView(
              key: key,
              crossAxisCount: 3,
              mainAxisExtent: 20,
              gap: 6,
              children: [for (var i = 0; i < 5; i++) ElView(key: ValueKey(i))],
            ),
          ],
        ),
        direction: .rtl,
      ),
    );
    expect(tester.getTopLeft(find.byKey(ValueKey(0))).dx, 204);
    expect(tester.getTopLeft(find.byKey(ValueKey(1))).dx, 102);
    expect((key.currentContext!.findRenderObject() as RenderBox).size, Size(300, 46));
  });

  testWidgets('两种 builder 独立放置或隔着 Widget 包装均断言失败', (tester) async {
    for (final child in [
      ElListView.builder(itemCount: 1, itemBuilder: (_, _) => ElView()),
      ElGridView.builder(itemCount: 1, itemBuilder: (_, _) => ElView(), crossAxisCount: 1),
    ]) {
      await tester.pumpWidget(_host(child));
      expect(tester.takeException(), isAssertionError);
      await tester.pumpWidget(_host(ElView()));
      await tester.pumpWidget(_host(ElScrollView(children: [ElView(child: child)])));
      expect(tester.takeException(), isNotNull);
      await tester.pumpWidget(_host(ElView()));
      while (tester.takeException() != null) {}
    }
  });
}
