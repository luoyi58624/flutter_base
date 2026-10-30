import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 卸载期竞态：滚动视图销毁之后，框架在微任务里派发的滚动指标通知
/// （`ScrollPosition.didUpdateScrollMetrics`）仍会执行一次；此时绑定里
/// `notificationContext` 的兜底不得再去访问已销毁宿主的 `State.context`。
///
/// 对应真机现场：`State.context` 的空断言（framework.dart:959）经
/// `ScrollPositionBinding._context`（scroll_position_binding.dart:122）抛出，
/// 出现在关闭窗口、整棵树卸载之后。
void main() {
  Widget tree(ElScrollController controller, {double height = 2000}) => Directionality(
    textDirection: .ltr,
    child: ElScrollView(
      controller: controller,
      physics: ElClampingScrollPhysics(),
      scrollbar: ElNoScrollBar(),
      children: [ElView(style: ElStyle(height: height, width: 400), child: '内容')],
    ),
  );

  void useViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('直接卸载后，在途指标通知不得触碰已销毁宿主', (tester) async {
    useViewport(tester, const Size(400, 600));
    final controller = ElScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(tree(controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '卸载后不得再触碰已销毁的宿主 context');
  });

  testWidgets('尺寸变化与卸载压在同一帧时，在途指标通知不得触碰已销毁宿主', (tester) async {
    useViewport(tester, const Size(400, 600));
    final controller = ElScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(tree(controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 同一帧里先让视口按新尺寸重排（排下指标通知微任务），随后整棵树卸载：
    // 微任务在卸载之后才执行。
    tester.view.physicalSize = const Size(400, 900);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '卸载后不得再触碰已销毁的宿主 context');
  });

  testWidgets('点击后不等稳定就卸载，在途指标通知不得触碰已销毁宿主', (tester) async {
    useViewport(tester, const Size(400, 600));
    final controller = ElScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(tree(controller));
    await tester.pump();

    // 模拟"随便点几下"：点一下、滚一段，都只推必要帧，不等稳定。
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    controller.jumpTo(400);
    await tester.pump();

    // 立刻"关窗口"：整棵树卸载，不 settle。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull, reason: '卸载后不得再触碰已销毁的宿主 context');
  });

  testWidgets('滚动惯性还在跑时立刻卸载，在途指标通知不得触碰已销毁宿主', (tester) async {
    useViewport(tester, const Size(400, 600));
    final controller = ElScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(tree(controller));
    await tester.pump();

    // 拖出一段带惯性的滚动，然后趁它还在跑就卸载。
    final gesture = await tester.startGesture(const Offset(200, 400));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull, reason: '卸载后不得再触碰已销毁的宿主 context');
  });

  testWidgets('尺寸变化后不等稳定就卸载，在途指标通知不得触碰已销毁宿主', (tester) async {
    useViewport(tester, const Size(400, 600));
    final controller = ElScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(tree(controller));
    await tester.pump();

    tester.view.physicalSize = const Size(400, 900);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull, reason: '卸载后不得再触碰已销毁的宿主 context');
  });

  testWidgets('宿主销毁后 position 再收指标变化，通知不得触碰已销毁宿主', (tester) async {
    useViewport(tester, const Size(400, 600));
    final controller = ElScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(tree(controller));
    await tester.pumpAndSettle();

    // 卸载前抓住 position：真机现场里，框架已经把指标通知排进了微任务，
    // 宿主随后在帧外（平台消息）销毁，通知才轮到执行。
    final position = controller.position;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // 复刻那一刻：宿主已经没了，框架的指标路径仍会来读这两个入口
    // （真机栈里命中 didUpdateScrollMetrics → notificationContext）。
    position.context.axisDirection;
    position.context.notificationContext;

    expect(tester.takeException(), isNull, reason: '宿主销毁后不得再触碰它的 context');
  });

  testWidgets('内容变矮与卸载压在同一帧时，在途指标通知不得触碰已销毁宿主', (tester) async {
    useViewport(tester, const Size(400, 600));
    final controller = ElScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(tree(controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 内容高度变化会走 applyContentDimensions → 排下指标通知微任务。
    await tester.pumpWidget(tree(controller, height: 400));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '卸载后不得再触碰已销毁的宿主 context');
  });
}
