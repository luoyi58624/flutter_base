import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('useWatch 切换观察对象后以新对象当前值作为旧值', (tester) async {
    final first = ValueNotifier(1);
    final second = ValueNotifier(10);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final changes = <(int, int)>[];
    Widget scene(ValueNotifier<int> model) => HookBuilder(
      builder: (_) {
        useWatch(model, (value, old) {
          changes.add((value, old));
          return null;
        });
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(first));
    first.value = 2;
    expect(changes, [(2, 1)]);
    await tester.pumpWidget(scene(second));
    first.value = 3;
    second.value = 11;
    expect(changes, [(2, 1), (11, 10)]);
    await tester.pumpWidget(SizedBox());
    second.value = 12;
    expect(changes.length, 2);
  });
}
