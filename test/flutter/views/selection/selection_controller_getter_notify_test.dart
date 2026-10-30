import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('控制器读取可用于监听构建，读取本身不会重复通知', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ElSelectionView(
              controller: controller,
              child: ElView(child: 'alpha beta'),
            ),
            ListenableBuilder(listenable: controller, builder: (_, _) => Text(controller.text ?? 'empty')),
          ],
        ),
      ),
    );
    controller.selectAll();
    await tester.pump();
    expect(controller.text, 'alpha beta');
    expect(controller.hasSelection, isTrue);
    final before = notifications;
    controller.text;
    controller.text;
    await tester.pump();
    expect(notifications, before, reason: '读取已发布的文字不得额外通知');
    controller.clear();
    await tester.pump();
    expect(controller.text, isNull);
    expect(controller.hasSelection, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无监听时读取选区后再监听，清空仍通知一次', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ElSelectionView(
          controller: controller,
          child: const ElView(child: 'alpha beta'),
        ),
      ),
    );
    controller.selectAll();
    expect(controller.text, 'alpha beta');
    await tester.pump();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.clear();
    await tester.pump();
    expect(notifications, 1, reason: '读取不能吞掉后续真实变更通知');
    expect(controller.text, isNull);
    await tester.pump();
    expect(notifications, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('控制器先销毁再卸载文档，不回调已销毁的监听器', (tester) async {
    final controller = ElSelectionController();
    await tester.pumpWidget(
      MaterialApp(
        home: ElSelectionView(
          controller: controller,
          child: ElView(child: 'alpha'),
        ),
      ),
    );
    controller.selectAll();
    await tester.pump();
    expect(controller.text, 'alpha');
    controller.dispose();
    await tester.pumpWidget(MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
