import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/scroll/common/render/scroll_viewport_base.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/reparent.dart';
import '../support/scrollbar_thumb.dart';

Widget _row(int i) => ElView(key: ValueKey('row-$i'), style: ElStyle(height: 70), child: 'row-$i');

/// 缓慢拖动以产生真实触摸增量并等待惯性沉淀。
Future<void> _dragBy(WidgetTester tester, double delta) async {
  final gesture = await tester.startGesture(Offset(400, delta < 0 ? 480 : 160));
  await gesture.moveBy(Offset(0, delta.sign * 25));
  await tester.pump(const Duration(milliseconds: 16));
  for (var i = 0; i < 12; i++) {
    await gesture.moveBy(Offset(0, delta / 12));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 200));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('反向列表重挂保留像素位置与双向滚动能力', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final controller = ElScrollController();
    addTearDown(() async {
      await tester.pumpWidget(ElView());
      controller.dispose();
    });
    await tester.pumpWidget(lifecycleHost(ReparentHarness(
      key: move,
      child: ElScrollView(
        controller: controller,
        reverse: true,
        physics: ElClampingScrollPhysics(),
        scrollbar: ElNoScrollBar(),
        children: [for (var i = 0; i < 60; i++) _row(i)],
      ),
    )));
    await tester.pumpAndSettle();
    controller.jumpTo(500);
    await tester.pumpAndSettle();
    final position = controller.position;
    for (var i = 0; i < 3; i++) {
      await reparent(tester, move);
      expect(controller.position, same(position));
      expect(controller.offset, closeTo(500, .01));
    }
    final before = controller.offset;
    await _dragBy(tester, -200);
    final mid = controller.offset;
    expect(mid, isNot(closeTo(before, .01)));
    await _dragBy(tester, 400);
    expect(controller.offset, isNot(closeTo(mid, .01)));
    await tester.pumpWidget(ElView());
    expect(tester.takeException(), isNull);
  });

  testWidgets('双轴滚动重挂保留纵横位置与客户端连接', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final vertical = ElScrollController();
    final horizontal = ElScrollController();
    addTearDown(() async {
      await tester.pumpWidget(ElView());
      vertical.dispose();
      horizontal.dispose();
    });
    await tester.pumpWidget(lifecycleHost(ReparentHarness(
      key: move,
      child: ElScrollView(
        axis: null,
        controller: vertical,
        horizontalController: horizontal,
        physics: ElClampingScrollPhysics(),
        scrollbar: ElNoScrollBar(),
        children: [ElView(style: ElStyle(width: 1600, height: 2400), child: 'big')],
      ),
    )));
    await tester.pumpAndSettle();
    expect(vertical.hasClients, isTrue);
    expect(horizontal.hasClients, isTrue);
    vertical.jumpTo(300);
    horizontal.jumpTo(200);
    await tester.pumpAndSettle();
    final vpos = vertical.position;
    final hpos = horizontal.position;
    for (var i = 0; i < 3; i++) {
      await reparent(tester, move);
      expect(vertical.position, same(vpos));
      expect(horizontal.position, same(hpos));
      expect(vertical.offset, closeTo(300, .01));
      expect(horizontal.offset, closeTo(200, .01));
    }
    await tester.pumpWidget(ElView());
    expect(tester.takeException(), isNull);
  });

  testWidgets('重挂到尺寸变化的宿主后重新布局且滚动仍可用', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final controller = ElScrollController();
    addTearDown(() async {
      await tester.pumpWidget(ElView());
      controller.dispose();
    });
    await tester.pumpWidget(lifecycleHost(ReparentHarness(
      key: move,
      wrap: (generation, child) => Center(
        child: SizedBox(width: 600, height: generation.isEven ? 500 : 300, child: child),
      ),
      child: ElScrollView(
        controller: controller,
        physics: ElClampingScrollPhysics(),
        scrollbar: ElNoScrollBar(),
        children: [for (var i = 0; i < 60; i++) _row(i)],
      ),
    )));
    await tester.pumpAndSettle();
    controller.jumpTo(1000);
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await reparent(tester, move);
      expect(controller.hasClients, isTrue);
      expect(controller.offset, greaterThan(0));
    }
    await _dragBy(tester, -150);
    expect(controller.offset, greaterThan(0));
    await tester.pumpWidget(ElView());
    expect(tester.takeException(), isNull);
  });

  testWidgets('TickerMode 暂停跨重挂后恢复仍可滚动', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final controller = ElScrollController();
    final enabled = ValueNotifier(true);
    addTearDown(() async {
      await tester.pumpWidget(ElView());
      controller.dispose();
      enabled.dispose();
    });
    await tester.pumpWidget(lifecycleHost(ValueListenableBuilder<bool>(
      valueListenable: enabled,
      builder: (context, value, child) => TickerMode(enabled: value, child: child!),
      child: ReparentHarness(
        key: move,
        child: ElScrollView(
          controller: controller,
          physics: ElClampingScrollPhysics(),
          scrollbar: ElNoScrollBar(),
          children: [for (var i = 0; i < 60; i++) _row(i)],
        ),
      ),
    )));
    await tester.pumpAndSettle();
    enabled.value = false;
    await tester.pumpAndSettle();
    await reparent(tester, move);
    enabled.value = true;
    await tester.pumpAndSettle();
    await _dragBy(tester, -220);
    expect(controller.offset, greaterThan(0));
    await tester.pumpWidget(ElView());
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动条 thumb 在重挂后几何正确且跟随位置', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final controller = ElScrollController();
    addTearDown(() async {
      await tester.pumpWidget(ElView());
      controller.dispose();
    });
    RenderVirtualScrollView viewport() => tester.renderObject<RenderVirtualScrollView>(
      find.byElementPredicate(
        (element) => element is RenderObjectElement && element.renderObject is RenderVirtualScrollView,
      ),
    );
    await tester.pumpWidget(lifecycleHost(ReparentHarness(
      key: move,
      child: ElScrollView(
        controller: controller,
        physics: ElClampingScrollPhysics(),
        scrollbar: const ElWindowScrollBar(),
        children: [for (var i = 0; i < 60; i++) _row(i)],
      ),
    )));
    await tester.pumpAndSettle();
    final top = elThumbRect(tester, viewport())!;
    controller.jumpTo(1500);
    await tester.pumpAndSettle();
    final moved = elThumbRect(tester, viewport())!;
    expect(moved.top, greaterThan(top.top));
    for (var i = 0; i < 3; i++) {
      await reparent(tester, move);
      final thumb = elThumbRect(tester, viewport())!;
      expect(thumb.height, closeTo(moved.height, .5));
      expect(thumb.top, closeTo(moved.top, .5));
    }
    await tester.pumpWidget(ElView());
    expect(tester.takeException(), isNull);
  });

  testWidgets('手势进行中重挂后同一条拖动继续消费', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final controller = ElScrollController();
    addTearDown(() async {
      await tester.pumpWidget(ElView());
      controller.dispose();
    });
    await tester.pumpWidget(lifecycleHost(ReparentHarness(
      key: move,
      child: ElScrollView(
        controller: controller,
        physics: ElClampingScrollPhysics(),
        scrollbar: ElNoScrollBar(),
        children: [for (var i = 0; i < 60; i++) _row(i)],
      ),
    )));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(Offset(400, 400));
    await gesture.moveBy(Offset(0, -25));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, -15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = controller.offset;
    expect(before, greaterThan(0));
    await reparent(tester, move, settle: false);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, -15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.offset, greaterThan(before), reason: '重挂不是手势结束，同一条手势必须继续消费');
    await gesture.up();
    await tester.pumpAndSettle();
    // 下一条手势仍需正常。
    final next = controller.offset;
    await _dragBy(tester, 420);
    expect(controller.offset, isNot(closeTo(next, .01)));
    await tester.pumpWidget(ElView());
    expect(tester.takeException(), isNull);
  });
}
