import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required ElPortalController controller, Key? popupKey}) => Directionality(
    textDirection: .ltr,
    child: MaterialApp(
      home: ElView(
        style: const ElStyle(width: 800, height: 600),
        child: Align(
          alignment: .topLeft,
          child: ElPortal(
            controller: controller,
            exitDuration: const Duration(milliseconds: 80),
            overlayBuilder: (_) => ElView(key: popupKey, style: const ElStyle(width: 120, height: 60)),
            child: const ElView(style: ElStyle(width: 80, height: 32)),
          ),
        ),
      ),
    ),
  );

  testWidgets('退场期间重开会等待旧 entry 摘除且 closed 对应当前会话', (tester) async {
    final controller = ElPortalController();
    final popupKey = GlobalKey();
    await tester.pumpWidget(host(controller: controller, popupKey: popupKey));

    controller.open();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(popupKey), findsOneWidget);

    controller.close();
    final firstClosed = controller.closed;
    var firstClosedDone = false;
    firstClosed.then((_) => firstClosedDone = true);
    controller.open();
    await tester.pump();
    expect(controller.isOpen, isFalse);
    expect(find.byKey(popupKey), findsOneWidget);
    expect(firstClosedDone, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(firstClosedDone, isTrue);
    expect(controller.isOpen, isTrue);
    await tester.pump();
    expect(find.byKey(popupKey), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('第二次 toggle 可以取消退场期间排队的重开', (tester) async {
    final controller = ElPortalController();
    const popupKey = ValueKey<String>('queued-popup');
    await tester.pumpWidget(host(controller: controller, popupKey: popupKey));

    controller.open();
    await tester.pump();
    controller.close();
    controller.toggle();
    controller.toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(controller.isOpen, isFalse);
    expect(find.byKey(popupKey), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('同一控制器不能同时挂载到两个 Portal', (tester) async {
    final controller = ElPortalController();
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: MaterialApp(
          home: Row(
            children: [
              for (var index = 0; index < 2; index++)
                SizedBox(
                  width: 100,
                  height: 100,
                  child: ElPortal(
                    controller: controller,
                    overlayBuilder: (_) => const ElView(),
                    child: ElView(child: index.toString()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isA<StateError>());
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
