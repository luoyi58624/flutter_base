import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('动画状态监听支持同一控制器更换回调', (tester) async {
    final controller = AnimationController(vsync: tester);
    addTearDown(controller.dispose);
    final calls = <String>[];
    void first(AnimationStatus status) => calls.add('first');
    void second(AnimationStatus status) => calls.add('second');
    Widget scene(AnimationStatusListener callback) => HookBuilder(
      builder: (_) {
        useAnimationStatusListener(controller, callback);
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(first));
    controller.value = 1;
    await tester.pumpWidget(scene(second));
    controller.value = 0;
    expect(calls, ['first', 'second']);
    await tester.pumpWidget(SizedBox());
    controller.value = 1;
    expect(calls.length, 2);
  });
}
