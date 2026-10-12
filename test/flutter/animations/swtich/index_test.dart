import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  Widget scene(bool value) => _MotionProbe(value, child: SizedBox());
  AnimationController controller(WidgetTester tester) =>
      tester.widget<_MotionValue>(find.byType(_MotionValue)).animation;

  testWidgets('进出场单调且自然停靠，结束后不保留 ticker', (tester) async {
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    var previous = 0.0;
    for (var i = 0; i < 28; i++) {
      await tester.pump(Duration(milliseconds: 16));
      expect(controller(tester).value, inInclusiveRange(previous, 1));
      previous = controller(tester).value;
    }
    expect(controller(tester).value, 1);
    expect(controller(tester).status, AnimationStatus.completed);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    previous = 1;
    for (var i = 0; i < 28; i++) {
      await tester.pump(Duration(milliseconds: 16));
      expect(controller(tester).value, inInclusiveRange(0, previous));
      previous = controller(tester).value;
    }
    expect(controller(tester).value, 0);
    expect(controller(tester).status, AnimationStatus.dismissed);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('改变目标承接位置和速度，不强行折断原有运动', (tester) async {
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 60));
    final before = controller(tester).value;
    final velocity = controller(tester).velocity;
    expect(velocity, greaterThan(0));
    await tester.pumpWidget(scene(false));
    expect(controller(tester).value, closeTo(before, 0.000001));
    expect(controller(tester).velocity, closeTo(velocity, 0.00001));
    expect(controller(tester).status, AnimationStatus.reverse);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 32));
    expect(controller(tester).velocity, lessThan(0));
    final secondPosition = controller(tester).value;
    final secondVelocity = controller(tester).velocity;
    await tester.pumpWidget(scene(true));
    expect(controller(tester).value, closeTo(secondPosition, 0.000001));
    expect(controller(tester).velocity, closeTo(secondVelocity, 0.00001));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 32));
    expect(controller(tester).velocity, greaterThan(0));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(controller(tester).value, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('折叠只改变布局占位，内容尺寸和清晰度保持完整', (tester) async {
    Widget fold(bool value) => animationScene(
      ElCollapseAnimation(
        value,
        key: ValueKey('fold'),
        child: SizedBox(key: ValueKey('content'), width: 80, height: 240),
      ),
    );
    double height() => tester.getSize(find.byKey(ValueKey('fold'))).height;
    await tester.pumpWidget(fold(false));
    await tester.pumpWidget(fold(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    expect(height(), inExclusiveRange(120, 240));
    expect(tester.getSize(find.byKey(ValueKey('content'))), Size(80, 240));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(FadeTransition), findsNothing);
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(height(), 240);
    await tester.pumpWidget(fold(false));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    expect(height(), inExclusiveRange(0, 120));
    expect(tester.getSize(find.byKey(ValueKey('content'))), Size(80, 240));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(height(), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('连续切换不提高响应强度，峰值速度不超过完整单次动作', (tester) async {
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    var baselinePeak = 0.0;
    for (var t = 0; t < 450; t += 2) {
      await tester.pump(Duration(milliseconds: 2));
      final speed = controller(tester).velocity.abs();
      if (speed > baselinePeak) baselinePeak = speed;
    }
    for (final interval in [16, 50]) {
      await tester.pumpWidget(SizedBox());
      await tester.pumpWidget(scene(false));
      for (var cycle = 0; cycle < 12; cycle++) {
        final before = controller(tester).value;
        await tester.pumpWidget(scene(cycle.isEven));
        expect(controller(tester).value, closeTo(before, 0.000001));
        await tester.pump();
        for (var t = 0; t < interval; t += 2) {
          await tester.pump(Duration(milliseconds: 2));
          expect(controller(tester).value, inInclusiveRange(0, 1));
          expect(
            controller(tester).velocity.abs(),
            lessThanOrEqualTo(baselinePeak + 0.01),
          );
        }
      }
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(controller(tester).value, 0);
      expect(tester.binding.transientCallbackCount, 0);
    }
  });

  for (final kind in ['缩放', '透明度']) {
    testWidgets('$kind 的快速响应在连续反转时仍保持速度衔接', (tester) async {
      Widget effect(bool value) => animationScene(
        kind == '缩放'
            ? ElScaleAnimation(value, child: SizedBox(width: 36, height: 36))
            : ElFadeAnimation(value, child: SizedBox(width: 36, height: 36)),
      );
      AnimationController current() =>
          (kind == '缩放'
                  ? tester
                        .widget<ScaleTransition>(find.byType(ScaleTransition))
                        .scale
                  : tester
                        .widget<FadeTransition>(find.byType(FadeTransition))
                        .opacity)
              as AnimationController;
      await tester.pumpWidget(effect(false));
      await tester.pumpWidget(effect(true));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 40));
      final before = current().value;
      final velocity = current().velocity;
      await tester.pumpWidget(effect(false));
      expect(current().value, closeTo(before, 0.000001));
      expect(current().velocity, closeTo(velocity, 0.00001));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 32));
      expect(current().velocity, lessThan(0));
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(current().value, 0);
      expect(current().status, AnimationStatus.dismissed);
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('短间隔再次改变目标不会重新启动或清零速度', (tester) async {
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 60));
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 2));
    final before = controller(tester).value;
    final velocity = controller(tester).velocity;
    expect(velocity, greaterThan(0));
    await tester.pumpWidget(scene(true));
    expect(controller(tester).value, closeTo(before, 0.000001));
    expect(controller(tester).velocity, closeTo(velocity, 0.00001));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(controller(tester).value, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

class _MotionProbe extends ElSwitcherAnimation {
  const _MotionProbe(super.value, {required super.child});

  @override
  Widget builder(BuildContext context, AnimationController animation) =>
      _MotionValue(animation: animation, child: child);
}

class _MotionValue extends StatelessWidget {
  const _MotionValue({required this.animation, required this.child});

  final AnimationController animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
