import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 回归：`ElTabController.animateTo` 返回的 Future 在动画被打断时也必须
/// resolve（对齐官方 PageController 口径）。曾直接返回 TickerFuture 的
/// whenComplete 派生 Future——`stop()`（canceled）后主 Future 永不 resolve，
/// `await controller.animateTo(...)` 的调用方永久挂起。
void main() {
  Widget harness(ElTabController controller) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: ElTabView(controller: controller, children: const [Text('page-0'), Text('page-1'), Text('page-2')]),
        ),
      ),
    );
  }

  testWidgets('animateTo natural completion resolves and settles', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(harness(controller));

    var completed = false;
    controller.animateTo(2).whenComplete(() => completed = true);
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(controller.index, 2);
    expect(controller.position, 2.0);
    controller.dispose();
  });

  testWidgets('animateTo interrupted by a second animateTo still resolves', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(harness(controller));

    var firstCompleted = false;
    controller.animateTo(2).whenComplete(() => firstCompleted = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(firstCompleted, isFalse, reason: '动画进行中不该提前 resolve');

    // 快速连点：第二次 animateTo 开头 stop() 掉第一条动画。
    controller.animateTo(0);
    await tester.pump();
    await tester.pump();
    expect(firstCompleted, isTrue, reason: '被替换打断的 Future 必须 resolve');

    await tester.pumpAndSettle();
    expect(controller.index, 0);
    controller.dispose();
  });

  testWidgets('animateTo interrupted by jumpTo still resolves', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(harness(controller));

    var completed = false;
    controller.animateTo(2).whenComplete(() => completed = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(completed, isFalse);

    controller.jumpTo(1);
    await tester.pump();
    await tester.pump();
    expect(completed, isTrue, reason: 'jumpTo 打断的 Future 必须 resolve');
    expect(controller.index, 1);
    controller.dispose();
  });
}
