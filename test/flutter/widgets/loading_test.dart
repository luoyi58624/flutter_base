import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('加载动画卸载后停止 ticker', (tester) async {
    await tester.pumpWidget(ElLoading(child: SizedBox(width: 10, height: 10)));
    await tester.pump(Duration(milliseconds: 100));
    expect(find.byType(RotationTransition), findsOneWidget);
    await tester.pumpWidget(SizedBox());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });
}
