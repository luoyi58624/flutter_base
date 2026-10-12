import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('初次挂载直接呈现 value 对应状态', (tester) async {
    Widget scene(bool value) => ElFadeAnimation(value, child: SizedBox());
    await tester.pumpWidget(scene(false));
    expect(_opacity(tester), 0);
    expect(
      tester.widget<ElFadeAnimation>(find.byType(ElFadeAnimation)).value,
      false,
    );
    await tester.pumpWidget(SizedBox());
    await tester.pumpWidget(scene(true));
    expect(_opacity(tester), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('显隐立即响应且迅速精确停靠', (tester) async {
    Widget scene(bool value) => ElFadeAnimation(value, child: SizedBox());
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 60));
    expect(_opacity(tester), inExclusiveRange(0.6, 1));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(_opacity(tester), 1);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 60));
    expect(_opacity(tester), inExclusiveRange(0, 0.4));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(_opacity(tester), 0);
  });

  testWidgets('中途反向切换保持透明度连续并最终隐藏', (tester) async {
    Widget scene(bool value) => ElFadeAnimation(value, child: SizedBox());
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 50));
    final before = _opacity(tester);
    await tester.pumpWidget(scene(false));
    expect(_opacity(tester), closeTo(before, 0.0001));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 0);
  });

  testWidgets('隐藏保留内容状态并禁用指针交互', (tester) async {
    var taps = 0;
    Widget scene(bool value) => ElFadeAnimation(
      value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => taps++,
        child: SizedBox(key: ValueKey('target'), width: 40, height: 40),
      ),
    );
    await tester.pumpWidget(scene(false));
    expect(find.byKey(ValueKey('target')), findsOneWidget);
    await tester.tap(find.byType(GestureDetector), warnIfMissed: false);
    expect(taps, 0);
    await tester.pumpWidget(scene(true));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GestureDetector));
    expect(taps, 1);
  });

  testWidgets('动画途中卸载释放控制器', (tester) async {
    Widget scene(bool value) => ElFadeAnimation(value, child: SizedBox());
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    await tester.pump(Duration(milliseconds: 20));
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

double _opacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;
