import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final button = find.byType(ElButtonView);
  ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(button);

  Widget build({required VoidCallback onPressed, bool disabled = false}) => Directionality(
    textDirection: .ltr,
    child: Center(
      child: ElButtonView(
        onPressed: onPressed,
        disabled: disabled,
        style: ElStyle(width: 100, height: 60).withTapScale(),
      ),
    ),
  );

  testWidgets('按下缩小，松开后恢复并触发点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++));
    final render = renderOf(tester);
    expect(render.committedResolvedStyle.box.transform, isNull);

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(render.committedResolvedStyle.box.transform, const ElTransform.scale(0.95));
    expect(taps, 0);

    await gesture.up();
    await tester.pump();
    expect(taps, 1);

    await tester.pump(const Duration(milliseconds: 100));
    expect(render.committedResolvedStyle.box.transform, isNull);
  });

  testWidgets('禁用时不缩放且不触发点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++, disabled: true));

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 100));
    expect(renderOf(tester).committedResolvedStyle.box.transform, isNull);

    await gesture.up();
    expect(taps, 0);
  });
}
