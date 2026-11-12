import 'dart:math' as math;

import 'package:example/src/pages/components/event/basic/examples/rotation.dart';
import 'package:example/src/pages/components/event/basic/examples/scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<ScrollController> _show(WidgetTester tester, Widget example, bool useElScroll) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  final children = [SizedBox(height: 60), example, SizedBox(height: 800)];
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 540,
              child: useElScroll
                  ? ElScrollView(controller: controller, children: children)
                  : SingleChildScrollView(
                      controller: controller,
                      child: Column(crossAxisAlignment: .stretch, children: children),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(controller.position.maxScrollExtent, greaterThan(0));
  return controller;
}

void main() {
  for (final useElScroll in [true, false]) {
    final scrollName = useElScroll ? 'ElScrollView' : 'Flutter';
    testWidgets('$scrollName 内从缩放舞台空白处缓慢捏合，整区响应且不滚动', (tester) async {
      final scroll = await _show(tester, ElScaleEventExample(), useElScroll);
      final area = _key('event-basic-scale');
      final rect = tester.getRect(area);
      final block = _key('event-basic-scale-block');
      expect(rect.width, greaterThan(300));
      expect(rect.height, greaterThan(230));
      final firstPoint = rect.topLeft + Offset(70, 55);
      final secondPoint = rect.topLeft + Offset(70, 185);
      expect(tester.getRect(block).contains(firstPoint), isFalse);
      expect(tester.getRect(block).contains(secondPoint), isFalse);
      for (final point in [firstPoint, secondPoint]) {
        expect(tester.hitTestOnBinding(point).path.any((entry) => entry.target == tester.renderObject(area)), isTrue);
      }
      final first = await tester.startGesture(firstPoint, pointer: 1);
      final second = await tester.startGesture(secondPoint, pointer: 2);
      for (var step = 0; step < 5; step++) {
        await first.moveBy(Offset(0, -8));
        await second.moveBy(Offset(0, 8));
        await tester.pump(Duration(milliseconds: 16));
        expect(scroll.offset, 0);
      }
      double scale() => tester.renderObject<RenderBox>(block).getTransformTo(null).getMaxScaleOnAxis();
      final expanded = scale();
      expect(expanded, greaterThan(1.1));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(scale(), expanded);
      await tester.tap(_key('event-basic-scale-reset'));
      await tester.pumpAndSettle();
      expect(scale(), 1);
      await tester.pumpWidget(SizedBox());
    });

    testWidgets('$scrollName 内一指固定、另一指缓慢撑开也能缩放', (tester) async {
      final scroll = await _show(tester, ElScaleEventExample(), useElScroll);
      scroll.jumpTo(40);
      await tester.pump();
      final origin = tester.getTopLeft(_key('event-basic-scale'));
      final first = await tester.startGesture(origin + Offset(70, 80), pointer: 1);
      final second = await tester.startGesture(origin + Offset(70, 160), pointer: 2);
      for (var step = 0; step < 7; step++) {
        await second.moveBy(Offset(0, 8));
        await tester.pump(Duration(milliseconds: 16));
        expect(scroll.offset, 40);
      }
      final block = tester.renderObject<RenderBox>(_key('event-basic-scale-block'));
      expect(block.getTransformTo(null).getMaxScaleOnAxis(), greaterThan(1.1));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(find.text('onScaleEnd'), findsOneWidget);
      await tester.pumpWidget(SizedBox());
    });

    testWidgets('$scrollName 内从旋转舞台空白处转动，整区响应且不改变大小', (tester) async {
      final scroll = await _show(tester, ElRotationEventExample(), useElScroll);
      final area = _key('event-basic-rotation');
      final rect = tester.getRect(area);
      final block = _key('event-basic-rotation-block');
      final center = rect.center;
      expect(rect.width, greaterThan(300));
      expect(rect.height, greaterThan(230));
      final firstPoint = center - Offset(80, 0);
      final secondPoint = center + Offset(80, 0);
      expect(tester.getRect(block).contains(firstPoint), isFalse);
      expect(tester.getRect(block).contains(secondPoint), isFalse);
      final first = await tester.startGesture(firstPoint, pointer: 1);
      final second = await tester.startGesture(secondPoint, pointer: 2);
      for (var step = 1; step <= 6; step++) {
        final angle = step * math.pi / 18;
        final radius = Offset(math.cos(angle), math.sin(angle)) * 80;
        await first.moveTo(center - radius);
        await second.moveTo(center + radius);
        await tester.pump(Duration(milliseconds: 16));
        expect(scroll.offset, 0);
      }
      final transform = tester.renderObject<RenderBox>(block).getTransformTo(null);
      expect(transform.storage[1].abs(), greaterThan(0.3));
      expect(transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      await tester.tap(_key('event-basic-rotation-reset'));
      await tester.pumpAndSettle();
      expect(tester.renderObject<RenderBox>(block).getTransformTo(null).storage[1], 0);
      await tester.pumpWidget(SizedBox());
    });
  }
}
