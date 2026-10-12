import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('透明度过渡响应显示状态', (tester) async {
    Widget scene(bool show) =>
        ElFadeAnimation(show, child: SizedBox(width: 10, height: 10));
    await tester.pumpWidget(scene(false));
    expect(
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value,
      0,
    );
    await tester.pumpWidget(scene(true));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value,
      1,
    );
    await tester.pumpWidget(SizedBox());
  });
}
