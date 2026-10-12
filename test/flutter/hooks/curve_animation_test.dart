import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('曲线 hook 保留实例并响应曲线变化', (tester) async {
    final controller = AnimationController(vsync: tester)..value = 0.5;
    addTearDown(controller.dispose);
    late CurvedAnimation current;
    Widget scene(Curve curve) => HookBuilder(
      builder: (_) {
        current = useCurvedAnimation(parent: controller, curve: curve);
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(Curves.linear));
    final first = current;
    expect(current.value, 0.5);
    await tester.pumpWidget(scene(Curves.easeIn));
    expect(current, same(first));
    expect(current.value, closeTo(Curves.easeIn.transform(0.5), 0.0001));
    await tester.pumpWidget(SizedBox());
  });
}
