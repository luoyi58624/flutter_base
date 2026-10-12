import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  for (final height in [40.0, 120.0]) {
    testWidgets('高度 $height 的通知始终轻移 12px，位移和透明度同步', (tester) async {
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
      expect(dy(), 12);
      expect(opacity(), 0);
      await tester.pumpWidget(scene(true));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 120));
      expect(opacity(), inExclusiveRange(0.9, 1));
      expect(dy(), closeTo(12 * (1 - opacity()), 0.0001));
      expect(dy(), greaterThan(0));
      expect(dy(), lessThan(3));
      expect(
        tester.getSize(find.byType(ElFadeSlideAnimation)),
        Size(80, height),
      );
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(dy(), 0);
      await tester.pumpWidget(scene(false));
      await tester.pump();
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(opacity(), 0);
      expect(dy(), 12);
    });
  }
}
