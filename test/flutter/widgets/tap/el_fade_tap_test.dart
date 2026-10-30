import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElFadeTap));

  Widget build({required VoidCallback onPressed, bool disabled = false}) => Directionality(
    textDirection: .ltr,
    child: Center(
      child: ElFadeTap(
        onPressed: onPressed,
        disabled: disabled,
        child: const ElView(style: ElStyle(width: 100, height: 60)),
      ),
    ),
  );

  testWidgets('轻触补足 100ms 后用 250ms 恢复，点击仍在抬手时触发', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++));
    final render = renderOf(tester);
    expect(render.committedResolvedStyle.box.opacity, isNull);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElFadeTap)));
    await tester.pump();
    expect(render.committedResolvedStyle.box.opacity, 0.2);
    expect(taps, 0);

    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    expect(render.committedResolvedStyle.box.opacity, 0.2);

    await tester.pump(Duration(milliseconds: 100));
    expect(render.committedResolvedStyle.box.opacity, 0.2, reason: '反馈截止后才开始恢复动画');

    await tester.pump(const Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, inExclusiveRange(0.2, 1.0));

    await tester.pump(const Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, isNull);
  });

  testWidgets('禁用时不应用透明反馈且不触发点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++, disabled: true));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElFadeTap)));
    await tester.pump();
    expect(renderOf(tester).committedResolvedStyle.box.opacity, isNull);

    await gesture.up();
    await tester.pump();
    expect(taps, 0);
  });
}
