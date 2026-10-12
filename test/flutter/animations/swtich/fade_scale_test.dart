import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  Widget scene(bool value) => animationScene(
    ElFadeScaleAnimation(value, child: SizedBox(width: 80, height: 40)),
  );
  double scale(WidgetTester tester) =>
      tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;
  double opacity(WidgetTester tester) =>
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

  testWidgets('弹窗从 80% 尺寸进入，文字先清晰，几何随后停靠', (tester) async {
    await tester.pumpWidget(scene(false));
    expect(opacity(tester), 0);
    expect(scale(tester), 0.8);
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 60));
    expect(opacity(tester), 1);
    expect(scale(tester), inExclusiveRange(0.9, 1));
    expect(tester.getSize(find.byType(ElFadeScaleAnimation)), Size(80, 40));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(scale(tester), 1);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 75));
    expect(opacity(tester), 0);
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(scale(tester), 0.8);
  });

  testWidgets('快速反向时透明度和缩放都从当前值衔接', (tester) async {
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 30));
    final firstScale = scale(tester);
    final firstOpacity = opacity(tester);
    await tester.pumpWidget(scene(false));
    expect(scale(tester), closeTo(firstScale, 0.000001));
    expect(opacity(tester), closeTo(firstOpacity, 0.000001));
    await tester.pump(Duration(milliseconds: 16));
    final secondScale = scale(tester);
    final secondOpacity = opacity(tester);
    await tester.pumpWidget(scene(true));
    expect(scale(tester), closeTo(secondScale, 0.000001));
    expect(opacity(tester), closeTo(secondOpacity, 0.000001));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(scale(tester), 1);
    expect(opacity(tester), 1);
    await tester.pumpWidget(SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });
}
