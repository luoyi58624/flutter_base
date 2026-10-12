import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('弹窗轻微放大，透明度与几何变化连续同步', (tester) async {
    Widget scene(bool value) => animationScene(
      ElFadeScaleAnimation(value, child: SizedBox(width: 80, height: 40)),
    );
    double scale() => tester
        .widget<ScaleTransition>(find.byType(ScaleTransition))
        .scale
        .value;
    double opacity() => tester
        .widget<FadeTransition>(find.byType(FadeTransition))
        .opacity
        .value;
    await tester.pumpWidget(scene(false));
    expect(opacity(), 0);
    expect(scale(), 0.96);
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 120));
    expect(opacity(), inExclusiveRange(0.9, 1));
    expect(scale(), closeTo(0.96 + 0.04 * opacity(), 0.0001));
    expect(tester.getSize(find.byType(ElFadeScaleAnimation)), Size(80, 40));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(scale(), 1);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(opacity(), 0);
    expect(scale(), 0.96);
  });
}
