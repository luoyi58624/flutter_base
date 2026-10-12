import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('状态标记减速入场，进出场单调且按时完成', (tester) async {
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
    var previous = scale();
    for (var i = 0; i < 10; i++) {
      await tester.pump(Duration(milliseconds: 18));
      expect(scale(), inInclusiveRange(previous, 1));
      previous = scale();
    }
    expect(tester.getSize(find.byType(ElScaleAnimation)), Size(36, 36));
    expect(scale(), 1);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    previous = scale();
    for (var i = 0; i < 10; i++) {
      await tester.pump(Duration(milliseconds: 12));
      expect(scale(), inInclusiveRange(0, previous));
      previous = scale();
    }
    expect(scale(), 0);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
