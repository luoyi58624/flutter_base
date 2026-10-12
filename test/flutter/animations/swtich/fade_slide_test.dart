import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  for (final height in [40.0, 120.0]) {
    testWidgets('高度 $height 的通知轻移 16px，透明度先完成', (tester) async {
      Widget scene(bool value) => animationScene(
        ElFadeSlideAnimation(value, child: SizedBox(width: 80, height: height)),
      );
      double opacity() => tester
          .widget<FadeTransition>(find.byType(FadeTransition))
          .opacity
          .value;
      double dy() => tester
          .widget<Transform>(find.byType(Transform))
          .transform
          .entry(1, 3);
      await tester.pumpWidget(scene(false));
      expect(dy(), 16);
      expect(opacity(), 0);
      await tester.pumpWidget(scene(true));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 90));
      expect(opacity(), inExclusiveRange(0.95, 1));
      expect(dy(), inExclusiveRange(0, 4));
      expect(
        tester.getSize(find.byType(ElFadeSlideAnimation)),
        Size(80, height),
      );
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(dy(), 0);
      await tester.pumpWidget(scene(false));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 75));
      expect(opacity(), inExclusiveRange(0, 0.1));
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(opacity(), 0);
      expect(dy(), 16);
    });
  }

  testWidgets('位移和透明度独立运行时反向仍连续', (tester) async {
    Widget scene(bool value) => animationScene(
      ElFadeSlideAnimation(value, child: SizedBox(width: 80, height: 40)),
    );
    double opacity() => tester
        .widget<FadeTransition>(find.byType(FadeTransition))
        .opacity
        .value;
    double dy() =>
        tester.widget<Transform>(find.byType(Transform)).transform.entry(1, 3);
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 40));
    final beforeOpacity = opacity();
    final beforeOffset = dy();
    await tester.pumpWidget(scene(false));
    expect(opacity(), closeTo(beforeOpacity, 0.000001));
    expect(dy(), closeTo(beforeOffset, 0.000001));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(opacity(), 0);
    expect(dy(), 16);
  });
}
