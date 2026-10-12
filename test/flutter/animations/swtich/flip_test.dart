import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('卡片绕 Y 轴翻转，中段清晰可见并保持透视和布局', (tester) async {
    Widget scene(bool value) => animationScene(
      ElFlipAnimation(value, child: SizedBox(width: 80, height: 40)),
    );
    Transform transform() => tester.widget<Transform>(find.byType(Transform));
    double opacity() => tester
        .widget<FadeTransition>(find.byType(FadeTransition))
        .opacity
        .value;
    await tester.pumpWidget(scene(false));
    expect(opacity(), 0);
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 210));
    final matrix = transform().transform;
    expect(matrix.entry(0, 0), inExclusiveRange(0.97, 1));
    expect(matrix.entry(1, 1), 1);
    expect(matrix.entry(3, 2), closeTo(0.001 * matrix.entry(0, 0), 0.000001));
    expect(opacity(), 1);
    expect(tester.getSize(find.byType(ElFlipAnimation)), Size(80, 40));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(transform().transform.entry(0, 0), 1);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(opacity(), 0);
  });
}
