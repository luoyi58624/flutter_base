import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('$direction 沿阅读方向揭示且保留完整占位', (tester) async {
      Widget scene(bool value) => animationScene(
        ElRevealAnimation(value, child: SizedBox(width: 80, height: 40)),
        direction: direction,
      );
      Rect clip() => tester
          .widget<ClipRect>(find.byType(ClipRect))
          .clipper!
          .getClip(Size(80, 40));
      await tester.pumpWidget(scene(false));
      expect(clip().isEmpty, true);
      await tester.pumpWidget(scene(true));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 160));
      expect(clip().width, inExclusiveRange(0, 80));
      expect(clip().height, 40);
      expect(
        direction == TextDirection.ltr ? clip().left : clip().right,
        direction == TextDirection.ltr ? 0 : 80,
      );
      expect(tester.getSize(find.byType(ElRevealAnimation)), Size(80, 40));
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(clip(), Rect.fromLTWH(0, 0, 80, 40));
      await tester.pumpWidget(scene(false));
      await tester.pump();
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(clip().isEmpty, true);
    });
  }
}
