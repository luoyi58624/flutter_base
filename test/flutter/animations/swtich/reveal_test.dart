import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('$direction 圆形遮罩从中心扩展且保留完整占位', (tester) async {
      Widget scene(bool value) => animationScene(
        ElRevealAnimation(value, child: SizedBox(width: 80, height: 40)),
        direction: direction,
      );
      Path clip() => tester
          .widget<ClipPath>(find.byType(ClipPath))
          .clipper!
          .getClip(Size(80, 40));
      await tester.pumpWidget(scene(false));
      expect(clip().getBounds().isEmpty, true);
      await tester.pumpWidget(scene(true));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 45));
      expect(clip().contains(Offset(40, 20)), true);
      expect(clip().contains(Offset(0.01, 0.01)), false);
      expect(clip().getBounds().center.dx, closeTo(40, 0.00001));
      expect(clip().getBounds().center.dy, closeTo(20, 0.00001));
      expect(tester.getSize(find.byType(ElRevealAnimation)), Size(80, 40));
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(clip().contains(Offset(0.01, 0.01)), true);
      expect(clip().contains(Offset(79.99, 39.99)), true);
      await tester.pumpWidget(scene(false));
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(clip().getBounds().isEmpty, true);
    });
  }
}
