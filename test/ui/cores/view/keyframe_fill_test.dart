import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fill in ElAnimationFillMode.values) {
    for (final direction in ElAnimationDirection.values) {
      testWidgets('动态添加关键帧：$fill / $direction 的延迟与分数迭代终态', (tester) async {
        final key = GlobalKey();
        Widget build(List<ElAnimation>? animations) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ElView(
              key: key,
              style: ElStyle(width: 4, height: 4, opacity: 0.6, animations: animations),
            ),
          ),
        );
        await tester.pumpWidget(build(null));
        await tester.pumpWidget(
          build([
            ElAnimation(
              keyframes: const {0: ElStyle(opacity: 0.2), 100: ElStyle(opacity: 0.8)},
              duration: const Duration(milliseconds: 100),
              delay: const Duration(milliseconds: 100),
              iterationCount: 1.25,
              curve: Curves.linear,
              fillMode: fill,
              direction: direction,
            ),
          ]),
        );
        await tester.pump();
        final render = tester.renderObject<ElRenderView>(find.byKey(key));
        void expectOpacity(double value) {
          expect(render.committedResolvedStyle.box.opacity, closeTo(value, 1e-9));
          expect(render.targetStyleForTest.box.opacity, 0.6);
        }

        final startReversed =
            direction == ElAnimationDirection.reverse || direction == ElAnimationDirection.alternateReverse;
        final fillsBefore = fill == ElAnimationFillMode.backwards || fill == ElAnimationFillMode.both;
        final before = fillsBefore ? (startReversed ? 0.8 : 0.2) : 0.6;
        expectOpacity(before);
        await tester.pump(const Duration(milliseconds: 50));
        expectOpacity(before);
        await tester.pump(const Duration(milliseconds: 100));
        expectOpacity(0.5);
        await tester.pump(const Duration(milliseconds: 75));
        final fillsAfter = fill == ElAnimationFillMode.forwards || fill == ElAnimationFillMode.both;
        final endReversed = direction == ElAnimationDirection.reverse || direction == ElAnimationDirection.alternate;
        final after = fillsAfter ? (endReversed ? 0.65 : 0.35) : 0.6;
        expectOpacity(after);
        await tester.pump(const Duration(milliseconds: 75));
        expectOpacity(after);
      });
    }
  }
}
