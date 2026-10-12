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

  testWidgets('弹窗轻微放大入场，退出仅淡出，不见后才复位', (tester) async {
    await tester.pumpWidget(scene(false));
    expect(opacity(tester), 0);
    expect(scale(tester), 0.92);
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 90));
    expect(opacity(tester), 1);
    expect(scale(tester), inExclusiveRange(0.98, 1));
    expect(tester.getSize(find.byType(ElFadeScaleAnimation)), Size(80, 40));
    await tester.pump(Duration(milliseconds: 90));
    expect(scale(tester), 1);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 35));
    expect(opacity(tester), inExclusiveRange(0, 1));
    expect(scale(tester), 1);
    await tester.pump(Duration(milliseconds: 35));
    expect(opacity(tester), 0);
    expect(scale(tester), 0.92);
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 45));
    expect(scale(tester), inExclusiveRange(0.92, 1));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(scale(tester), 1);
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

  testWidgets('淡出保持尺寸期间卸载会取消复位，不访问已销毁的控制器', (tester) async {
    await tester.pumpWidget(scene(true));
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 20));
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
