import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const childKey = ValueKey('collapse-child');

  Widget subject({required bool show, bool keepState = true}) {
    return Directionality(
      textDirection: .ltr,
      child: Align(
        alignment: .topLeft,
        child: ElCollapseAnimation(
          show,
          keepState: keepState,
          child: const SizedBox(key: childKey, width: 80, height: 100),
        ),
      ),
    );
  }

  Finder collapseHost() => find.byType(SizeTransition);

  testWidgets('收起过程按弹簧进度改变占位，child 尺寸保持不变', (tester) async {
    await tester.pumpWidget(subject(show: true));
    expect(tester.getSize(collapseHost()), const Size(800, 100));

    await tester.pumpWidget(subject(show: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // 当前公共动效使用弹簧；仍严格校验占位等于内容高度乘动画进度。
    final factor = tester.widget<SizeTransition>(collapseHost()).sizeFactor.value;
    expect(factor, allOf(greaterThan(0), lessThan(1)));
    expect(tester.getSize(collapseHost()).height, moreOrLessEquals(100 * factor, epsilon: 0.1));
    expect(tester.getSize(find.byKey(childKey)), const Size(80, 100));

    await tester.pumpAndSettle();
    expect(tester.getSize(collapseHost()), const Size(800, 0));
  });

  testWidgets('keepState=false 在收起动画结束后销毁 child', (tester) async {
    await tester.pumpWidget(subject(show: true, keepState: false));

    await tester.pumpWidget(subject(show: false, keepState: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(childKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(childKey), findsNothing);
  });
}
