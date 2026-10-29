import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/cores/scroll/common/render/scroll_viewport_base.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/reparent.dart';
import '../support/scrollbar_thumb.dart';

Widget _row(int i) => ElView(key: ValueKey('row-$i'), style: ElStyle(height: 70), child: 'row-$i');

RenderVirtualScrollView _viewport(WidgetTester tester) => tester.renderObject<RenderVirtualScrollView>(
  find.byElementPredicate(
    (element) => element is RenderObjectElement && element.renderObject is RenderVirtualScrollView,
  ),
);

void main() {
  testWidgets('滚动条 thumb 拖动中重挂，内容继续跟随不中断', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final controller = ElScrollController();
    addTearDown(() async {
      await tester.pumpWidget(ElView());
      controller.dispose();
    });
    await tester.pumpWidget(
      lifecycleHost(
        ReparentHarness(
          key: move,
          child: ElScrollView(
            controller: controller,
            physics: ElClampingScrollPhysics(),
            scrollbar: const ElWindowScrollBar(),
            children: [for (var i = 0; i < 60; i++) _row(i)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final render = _viewport(tester);
    final thumb = elThumbRect(tester, render)!;
    final gesture = await tester.startGesture(render.localToGlobal(thumb.center), kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    final x = thumb.center.dx;
    final top = thumb.center.dy;
    await gesture.moveTo(render.localToGlobal(Offset(x, top + 80)));
    await tester.pump();
    final before = controller.offset;
    expect(before, greaterThan(0), reason: '拖动 thumb 必须先产生位移');
    await reparent(tester, move, settle: false);
    await gesture.moveTo(render.localToGlobal(Offset(x, top + 220)));
    await tester.pump();
    expect(controller.offset, greaterThan(before), reason: '重挂不是手势结束，thumb 拖动必须继续消费');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('手势进行中整体卸载宿主，无悬挂状态且重新挂载后滚动正常', (tester) async {
    final controller = ElScrollController();
    Widget build() => lifecycleHost(
      ElScrollView(
        controller: controller,
        physics: ElClampingScrollPhysics(),
        scrollbar: ElNoScrollBar(),
        children: [for (var i = 0; i < 60; i++) _row(i)],
      ),
    );
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(Offset(400, 400));
    await gesture.moveBy(Offset(0, -25));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(Offset(0, -15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.offset, greaterThan(0));
    // 手指未抬，整体移除宿主。
    await tester.pumpWidget(ElView());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    // 重新挂载同一 controller，必须还能正常滚动且位置被保留。
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(controller.hasClients, isTrue);
    final before = controller.offset;
    final next = await tester.startGesture(Offset(400, 400));
    await next.moveBy(Offset(0, -25));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 12; i++) {
      await next.moveBy(Offset(0, -15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.offset, greaterThan(before));
    await next.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(ElView());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });
}
