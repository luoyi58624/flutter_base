import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('小型反馈迅速缩放且不会回弹越界', (tester) async {
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
    expect(scale(), inExclusiveRange(0.9, 1));
    expect(tester.getSize(find.byType(ElScaleAnimation)), Size(36, 36));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(scale(), 1);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(scale(), 0);
    expect(tester.takeException(), isNull);
  });
}
