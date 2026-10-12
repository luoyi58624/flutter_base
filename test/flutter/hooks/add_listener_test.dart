import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('useAddListener 同一对象切换回调并在卸载时解绑', (tester) async {
    final model = ValueNotifier(0);
    addTearDown(model.dispose);
    final calls = <String>[];
    void first() => calls.add('first');
    void second() => calls.add('second');
    Widget scene(VoidCallback callback) => HookBuilder(
      builder: (_) {
        useAddListener(model, callback);
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(first));
    model.value = 1;
    await tester.pumpWidget(scene(second));
    model.value = 2;
    expect(calls, ['first', 'second']);
    await tester.pumpWidget(SizedBox());
    model.value = 3;
    expect(calls, ['first', 'second']);
  });
}
