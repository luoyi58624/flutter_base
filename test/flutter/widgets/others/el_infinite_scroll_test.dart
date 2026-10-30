import 'dart:async';

import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 每行 100 高，视口 600：rows ≤ 6 时不满一屏
Widget _host({
  required ScrollController controller,
  required int rows,
  required FutureOr<void> Function() onLoad,
  double distance = 0,
  bool disabled = false,
  bool immediate = true,
  Duration delay = const Duration(milliseconds: 200),
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      height: 600,
      child: ElInfiniteScroll(
        controller: controller,
        onLoad: onLoad,
        distance: distance,
        disabled: disabled,
        immediate: immediate,
        delay: delay,
        child: ListView.builder(
          controller: controller,
          itemCount: rows,
          itemExtent: 100,
          itemBuilder: (context, index) => Text('行 $index'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('滚到底触发加载，防抖后只触发一次', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var loads = 0;

    await tester.pumpWidget(_host(controller: controller, rows: 20, onLoad: () => loads++, immediate: false));
    await tester.pumpAndSettle();
    expect(loads, 0);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    // 防抖未到点不触发
    expect(loads, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(loads, 1);

    // 停在底部继续抖动也只算一次（无进展）
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 200));
    expect(loads, 1);
  });

  testWidgets('distance 提前量让未真正触底也触发', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var loads = 0;

    await tester.pumpWidget(
      _host(controller: controller, rows: 20, distance: 300, onLoad: () => loads++, immediate: false),
    );
    await tester.pumpAndSettle();

    controller.jumpTo(controller.position.maxScrollExtent - 250);
    await tester.pump(const Duration(milliseconds: 200));
    expect(loads, 1);
  });

  testWidgets('disabled 时不触发，恢复后重新判定', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var loads = 0;

    await tester.pumpWidget(
      _host(controller: controller, rows: 20, disabled: true, onLoad: () => loads++, immediate: false),
    );
    await tester.pumpAndSettle();

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 300));
    expect(loads, 0);

    // 解除禁用后无需再滚动也会补判一次
    await tester.pumpWidget(_host(controller: controller, rows: 20, onLoad: () => loads++, immediate: false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(loads, 1);
  });

  testWidgets('immediate 只在挂载时查一次：加载后不自动续补（对齐官方指令）', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var loads = 0;

    await tester.pumpWidget(_host(controller: controller, rows: 2, onLoad: () => loads++));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(loads, 1);

    // 内容依旧不满一屏，但不会自己再要数据——继续加载靠用户滚动
    await tester.pump(const Duration(seconds: 2));
    expect(loads, 1);
  });

  testWidgets('加载未完成期间不重复触发', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var loads = 0;
    final gate = Completer<void>();

    await tester.pumpWidget(
      _host(
        controller: controller,
        rows: 20,
        immediate: false,
        onLoad: () {
          loads++;
          return gate.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 200));
    expect(loads, 1);

    // 加载还没结束，反复抖动也不再触发
    for (var i = 0; i < 3; i++) {
      controller.jumpTo(controller.position.maxScrollExtent - 1);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(loads, 1);

    gate.complete();
    await tester.pumpAndSettle();
  });
}
