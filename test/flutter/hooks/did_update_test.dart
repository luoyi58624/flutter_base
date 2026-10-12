import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('useDidUpdate 首次更新传递初始 widget', (tester) async {
    final updates = <Widget>[];
    final first = SizedBox(width: 1);
    final second = SizedBox(width: 2);
    Widget scene(Widget widget) => HookBuilder(
      builder: (_) {
        useDidUpdate(updates.add, widget);
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(first));
    expect(updates, isEmpty);
    await tester.pumpWidget(scene(second));
    expect(updates, [first]);
  });
}
