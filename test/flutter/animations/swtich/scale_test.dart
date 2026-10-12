import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('状态标记入场小幅回弹，退场不振荡', (tester) async {
    Widget scene(bool value) => animationScene(
      ElScaleAnimation(value, child: SizedBox(width: 36, height: 36)),
    );
    double scale() => tester
        .widget<ScaleTransition>(find.byType(ScaleTransition))
        .scale
        .value;
    await tester.pumpWidget(scene(false));
    expect(scale(), 0);
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 132));
    expect(scale(), inExclusiveRange(1, 1.06));
    expect(tester.getSize(find.byType(ElScaleAnimation)), Size(36, 36));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(scale(), 1);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    var previous = scale();
    for (var i = 0; i < 20; i++) {
      await tester.pump(Duration(milliseconds: 16));
      expect(scale(), inInclusiveRange(0, previous));
      previous = scale();
    }
    expect(scale(), 0);
    expect(tester.takeException(), isNull);
  });
}
