import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('进出场单调停靠且没有振荡或越界', (tester) async {
    Widget scene(bool value) => _MotionProbe(value, child: SizedBox());
    double position() =>
        tester.widget<_MotionValue>(find.byType(_MotionValue)).animation.value;
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    var previous = position();
    for (var i = 0; i < 20; i++) {
      await tester.pump(Duration(milliseconds: 16));
      expect(position(), inInclusiveRange(previous, 1));
      previous = position();
    }
    expect(position(), 1);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    previous = position();
    for (var i = 0; i < 20; i++) {
      await tester.pump(Duration(milliseconds: 16));
      expect(position(), inInclusiveRange(0, previous));
      previous = position();
    }
    expect(position(), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('反转保持位置连续并在下一帧直接朝新目标运动', (tester) async {
    Widget scene(bool value) => _MotionProbe(value, child: SizedBox());
    double position() =>
        tester.widget<_MotionValue>(find.byType(_MotionValue)).animation.value;
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 60));
    final beforeTurn = position();
    await tester.pumpWidget(scene(false));
    await tester.pump();
    expect(position(), closeTo(beforeTurn, 0.000001));
    await tester.pump(Duration(milliseconds: 1));
    expect(position(), lessThan(beforeTurn));
    await tester.pump(Duration(milliseconds: 16));
    expect(position(), lessThan(beforeTurn));
    final secondTurn = position();
    await tester.pumpWidget(scene(true));
    await tester.pump();
    expect(position(), closeTo(secondTurn, 0.000001));
    await tester.pump(Duration(milliseconds: 1));
    expect(position(), greaterThan(secondTurn));
    await tester.pump(Duration(milliseconds: 119));
    expect(position(), 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('折叠按 200ms 入场和 160ms 退场，内容保持尺寸与清晰度', (tester) async {
    Widget scene(bool value) => animationScene(
      ElCollapseAnimation(
        value,
        key: ValueKey('current'),
        child: SizedBox(key: ValueKey('content'), width: 80, height: 240),
      ),
    );
    double height(String key) =>
        tester.getSize(find.byKey(ValueKey(key))).height;
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    expect(height('current'), inExclusiveRange(0, 240));
    expect(tester.getSize(find.byKey(ValueKey('content'))), Size(80, 240));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(FadeTransition), findsNothing);
    await tester.pump(Duration(milliseconds: 100));
    expect(height('current'), 240);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 80));
    expect(height('current'), inExclusiveRange(0, 240));
    expect(tester.getSize(find.byKey(ValueKey('content'))), Size(80, 240));
    await tester.pump(Duration(milliseconds: 80));
    expect(height('current'), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('连续快速切换保持位置，最后一次反转 120ms 内结束', (tester) async {
    double position() =>
        tester.widget<_MotionValue>(find.byType(_MotionValue)).animation.value;
    Widget scene(bool value) => _MotionProbe(value, child: SizedBox());
    await tester.pumpWidget(scene(false));
    for (var i = 0; i < 15; i++) {
      final value = i.isEven;
      final before = position();
      await tester.pumpWidget(scene(value));
      expect(position(), closeTo(before, 0.000001));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 16));
      expect(position(), inInclusiveRange(0, 1));
      expect(position(), value ? greaterThan(before) : lessThan(before));
    }
    final before = position();
    await tester.pumpWidget(scene(false));
    expect(position(), closeTo(before, 0.000001));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 120));
    expect(position(), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

class _MotionProbe extends ElSwitcherAnimation {
  const _MotionProbe(super.value, {required super.child});

  @override
  Widget builder(BuildContext context, Animation<double> animation) =>
      _MotionValue(animation: animation, child: child);
}

class _MotionValue extends StatelessWidget {
  const _MotionValue({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
