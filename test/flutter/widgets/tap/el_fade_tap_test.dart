import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElFadeTap));

  Widget build({required VoidCallback onPressed, bool disabled = false, ElStyle? style}) => Directionality(
    textDirection: .ltr,
    child: Center(
      child: ElFadeTap(
        onPressed: onPressed,
        disabled: disabled,
        style: style,
        child: ElView(style: ElStyle(width: 100, height: 60)),
      ),
    ),
  );

  testWidgets('轻触松手立即开始 250ms 二次缓动恢复，不补足最短反馈', (tester) async {
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

    await tester.pump(Duration(milliseconds: 50));
    expect(render.committedResolvedStyle.box.opacity, closeTo(0.264, 0.00001));

    await tester.pump(Duration(milliseconds: 75));
    expect(render.committedResolvedStyle.box.opacity, closeTo(0.6, 0.00001));

    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, isNull);
  });

  testWidgets('移出恢复，重新移入以 150ms 变淡，松手从当前值恢复', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++));
    final render = renderOf(tester);
    final center = tester.getCenter(find.byType(ElFadeTap));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveTo(center + Offset(100, 0));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 250));
    expect(render.committedResolvedStyle.box.opacity, isNull);

    await gesture.moveTo(center);
    await tester.pump();
    expect(render.committedResolvedStyle.box.opacity ?? 1, 1);
    await tester.pump(Duration(milliseconds: 75));
    expect(render.committedResolvedStyle.box.opacity, closeTo(0.6, 0.00001));
    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, closeTo(0.8, 0.00001));
    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, isNull);
  });

  testWidgets('取消不触发点击，250ms 恢复用户的常态透明度', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++, style: ElStyle(opacity: 0.7)));
    final render = renderOf(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElFadeTap)));
    await tester.pump();
    expect(render.committedResolvedStyle.box.opacity, 0.2);
    await gesture.cancel();
    await tester.pump();
    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, closeTo(0.45, 0.00001));
    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, 0.7);
    expect(taps, 0);
  });

  testWidgets('恢复中再次按下立即变淡，按住不自动恢复', (tester) async {
    await tester.pumpWidget(build(onPressed: () {}));
    final render = renderOf(tester);
    final center = tester.getCenter(find.byType(ElFadeTap));
    final first = await tester.startGesture(center);
    await tester.pump();
    await first.up();
    await tester.pump();
    await tester.pump(Duration(milliseconds: 125));
    final second = await tester.startGesture(center);
    await tester.pump();
    expect(render.committedResolvedStyle.box.opacity, 0.2);
    await tester.pump(Duration(milliseconds: 300));
    expect(render.committedResolvedStyle.box.opacity, 0.2);
    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets('按住时禁用清除反馈并阻止点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElFadeTap)));
    await tester.pump();
    await tester.pumpWidget(build(onPressed: () => taps++, disabled: true));
    await tester.pump(Duration(milliseconds: 250));
    expect(renderOf(tester).committedResolvedStyle.box.opacity, isNull);
    await gesture.up();
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('保留用户按压透明度和恢复过渡覆写', (tester) async {
    await tester.pumpWidget(
      build(
        onPressed: () {},
        style: ElStyle(
          opacity: 0.8,
          onTap: ElStyle(opacity: 0.4),
          transition: [ElTransition.field(ElTransitionField.opacity, Duration(milliseconds: 100), Curves.linear)],
        ),
      ),
    );
    final render = renderOf(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElFadeTap)));
    await tester.pump();
    expect(render.committedResolvedStyle.box.opacity, 0.4);
    await gesture.up();
    await tester.pump();
    await tester.pump(Duration(milliseconds: 50));
    expect(render.committedResolvedStyle.box.opacity, closeTo(0.6, 0.00001));
    await tester.pump(Duration(milliseconds: 50));
    expect(render.committedResolvedStyle.box.opacity, 0.8);
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
