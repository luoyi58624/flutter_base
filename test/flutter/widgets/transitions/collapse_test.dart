import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('折叠完成后按 keepState 参数移除内容', (tester) async {
    Widget scene(bool show) => ElCollapseAnimation(
      show,
      keepState: false,
      child: SizedBox(key: ValueKey('content'), width: 20, height: 20),
    );
    await tester.pumpWidget(scene(true));
    expect(find.byKey(ValueKey('content')), findsOneWidget);
    await tester.pumpWidget(scene(false));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('content')), findsNothing);
  });
}
