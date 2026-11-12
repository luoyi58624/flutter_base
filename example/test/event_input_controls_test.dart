import 'package:example/src/pages/components/event/basic/examples/pointer.dart';
import 'package:example/src/pages/components/event/basic/examples/tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final useElScroll in [true, false]) {
    testWidgets('指针区域内跟踪触摸，区域外可以滚动（${useElScroll ? 'ElScrollView' : 'Flutter'}）', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(320, 500);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      final children = [ElPointerEventExample(), SizedBox(height: 800, key: ValueKey('event-outside-pointer'))];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: useElScroll
                ? ElScrollView(controller: controller, children: children)
                : SingleChildScrollView(
                    controller: controller,
                    child: Column(crossAxisAlignment: .stretch, children: children),
                  ),
          ),
        ),
      );
      expect(controller.position.maxScrollExtent, greaterThan(0));
      final area = find.byKey(ValueKey('event-basic-pointer'));
      final start = tester.getBottomLeft(area) + Offset(24, -24);
      final gesture = await tester.startGesture(start);
      await tester.pump();
      expect(find.textContaining('onPointerDown'), findsOneWidget);
      await gesture.moveBy(Offset(0, -8));
      await gesture.moveBy(Offset(0, -110));
      await tester.pump();
      expect(find.textContaining('onPointerMove'), findsOneWidget);
      expect(controller.offset, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.textContaining('onPointerUp'), findsOneWidget);
      expect(controller.offset, 0);

      final outside = find.byKey(ValueKey('event-outside-pointer'));
      await tester.dragFrom(tester.getTopLeft(outside) + Offset(160, 100), Offset(0, -90));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      await tester.pumpWidget(SizedBox());
    });
  }

  testWidgets('连击窗口内延迟单击，双击和三击结果保持可见', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ElTapEventExample())));
    final target = find.byKey(ValueKey('event-basic-tap'));

    Future<void> tapAgain() async {
      await tester.tap(target);
      await tester.pump(Duration(milliseconds: 60));
    }

    await tapAgain();
    expect(find.text('单击'), findsNothing);
    await tester.pumpAndSettle(Duration(milliseconds: 350));
    expect(find.text('单击'), findsOneWidget);
    expect(find.text('onTap'), findsOneWidget);

    await tapAgain();
    await tapAgain();
    await tester.pumpAndSettle(Duration(milliseconds: 350));
    expect(find.text('双击'), findsOneWidget);
    expect(find.text('onDoubleTap'), findsOneWidget);
    expect(find.text('单击'), findsNothing);

    await tapAgain();
    await tapAgain();
    await tapAgain();
    await tester.pumpAndSettle(Duration(milliseconds: 350));
    expect(find.text('三击'), findsOneWidget);
    expect(find.text('onTripleTap'), findsOneWidget);
    expect(find.text('单击'), findsNothing);
  });
}
