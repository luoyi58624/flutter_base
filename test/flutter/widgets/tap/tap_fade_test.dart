import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final button = find.byType(ElButtonView);
  ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(button);
  double recovered(double from, double to, double t) => from + (to - from) * Curves.easeInOutQuad.transform(t);

  Widget build({
    required VoidCallback onPressed,
    bool disabled = false,
    ElStyle? style,
    double opacity = 0.2,
    Duration delayTouchUp = Duration.zero,
  }) => Directionality(
    textDirection: .ltr,
    child: Center(
      child: ElButtonView(
        onPressed: onPressed,
        disabled: disabled,
        style: ElStyle(width: 100, height: 60).merge(style).withTapFade(opacity),
        event: ElEvent(delayTouchUp: delayTouchUp),
        child: '淡化',
      ),
    ),
  );

  group('withTapFade', () {
    test('保留其他按压属性与过渡，并补齐透明度过渡', () {
      final background = ElTransition.field(.backgroundColor);
      final transform = ElTransition.field(.transform);
      final style = ElStyle(
        transition: [background],
        onTap: ElStyle(width: 80, transition: [transform]),
      ).withTapFade(0.4);

      expect(style.onTap?.opacity, 0.4);
      expect(style.onTap?.width, 80);
      expect(style.transition, [
        background,
        ElTransition.field(.opacity, Duration(milliseconds: 250), Curves.easeInOutQuad),
      ]);
      expect(style.onTap?.transition, [transform, ElTransition.field(.opacity, Duration.zero)]);
    });

    test('保留用户分别声明的进入与恢复过渡，包括 all', () {
      final leave = [ElTransition.all(Duration(milliseconds: 400), Curves.linear)];
      final enter = [ElTransition.field(.opacity, Duration(milliseconds: 120), Curves.linear)];
      final style = ElStyle(
        transition: leave,
        onTap: ElStyle(transition: enter),
      ).withTapFade();

      expect(style.transition, same(leave));
      expect(style.onTap?.transition, same(enter));
    });

    test('继承常态的其他过渡，透明度默认立即变化且重复调用不增添重复项', () {
      final all = ElTransition.all(Duration(milliseconds: 400), Curves.linear);
      final style = ElStyle(transition: [all]).withTapFade().withTapFade(0.4);

      expect(style.transition, [all]);
      expect(style.onTap?.transition, [all, ElTransition.field(.opacity, Duration.zero)]);
      expect(style.onTap?.opacity, 0.4);
    });
  });

  testWidgets('关闭反馈保持后，轻触松手立即开始 250ms 恢复', (tester) async {
    var taps = 0;
    var builds = 0;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          builds++;
          return build(onPressed: () => taps++);
        },
      ),
    );
    final render = renderOf(tester);
    expect(render.committedResolvedStyle.box.opacity, isNull);

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(render.committedResolvedStyle.box.opacity, 0.2);
    expect(taps, 0);

    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    expect(render.committedResolvedStyle.box.opacity, 0.2);

    await tester.pump(Duration(milliseconds: 50));
    expect(render.committedResolvedStyle.box.opacity, closeTo(recovered(0.2, 1, 0.2), 0.00001));
    await tester.pump(Duration(milliseconds: 75));
    expect(render.committedResolvedStyle.box.opacity, closeTo(recovered(0.2, 1, 0.5), 0.00001));
    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, isNull);
    expect(builds, 1, reason: '淡化帧由样式引擎处理，不触发 Widget 重建');
  });

  testWidgets('默认触摸保持仍由事件机制管理，不延迟点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++, delayTouchUp: Duration(milliseconds: 100)));
    final render = renderOf(tester);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 50));
    expect(render.committedResolvedStyle.box.opacity, 0.2);
    await tester.pump(Duration(milliseconds: 50));
    await tester.pump(Duration(milliseconds: 250));
    expect(render.committedResolvedStyle.box.opacity, isNull);
  });

  testWidgets('移出恢复，重新移入立即变淡，松手后恢复', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++));
    final render = renderOf(tester);
    final center = tester.getCenter(button);
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveTo(center + Offset(100, 0));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 250));
    expect(render.committedResolvedStyle.box.opacity, isNull);

    await gesture.moveTo(center);
    await tester.pump();
    expect(render.committedResolvedStyle.box.opacity, 0.2);
    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, closeTo(recovered(0.2, 1, 0.5), 0.00001));
    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, isNull);
  });

  testWidgets('取消不触发点击，250ms 恢复用户的常态透明度', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++, style: ElStyle(opacity: 0.7)));
    final render = renderOf(tester);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(render.committedResolvedStyle.box.opacity, 0.2);
    await gesture.cancel();
    await tester.pump();
    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, closeTo(recovered(0.2, 0.7, 0.5), 0.00001));
    await tester.pump(Duration(milliseconds: 125));
    expect(render.committedResolvedStyle.box.opacity, 0.7);
    expect(taps, 0);
  });

  testWidgets('恢复中再次按下立即变淡，按住不自动恢复', (tester) async {
    await tester.pumpWidget(build(onPressed: () {}));
    final render = renderOf(tester);
    final center = tester.getCenter(button);
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
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pumpWidget(build(onPressed: () => taps++, disabled: true));
    await tester.pump(Duration(milliseconds: 250));
    expect(renderOf(tester).committedResolvedStyle.box.opacity, isNull);
    await gesture.up();
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('使用自定义按压透明度和恢复过渡', (tester) async {
    await tester.pumpWidget(
      build(
        onPressed: () {},
        opacity: 0.4,
        style: ElStyle(
          opacity: 0.8,
          transition: [ElTransition.field(.opacity, Duration(milliseconds: 100), Curves.linear)],
        ),
      ),
    );
    final render = renderOf(tester);
    final gesture = await tester.startGesture(tester.getCenter(button));
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
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(renderOf(tester).committedResolvedStyle.box.opacity, isNull);
    await gesture.up();
    await tester.pump();
    expect(taps, 0);
  });

  for (final fadeFirst in [true, false]) {
    testWidgets('淡化与缩放按任意顺序组合都保留过渡：fadeFirst=$fadeFirst', (tester) async {
      final base = ElStyle(width: 100, height: 60);
      final style = fadeFirst ? base.withTapFade().withTapScale(0.9) : base.withTapScale(0.9).withTapFade();
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Center(
            child: ElButtonView(
              style: style,
              event: ElEvent(delayTouchUp: Duration.zero),
            ),
          ),
        ),
      );
      final render = renderOf(tester);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      expect(render.committedResolvedStyle.box.opacity, 0.2);
      await tester.pump(Duration(milliseconds: 50));
      final pressingScale = render.committedResolvedStyle.box.transform!.toMatrix4().entry(0, 0);
      expect(pressingScale, allOf(greaterThan(0.9), lessThan(1)));
      await tester.pump(Duration(milliseconds: 50));
      expect(render.committedResolvedStyle.box.transform, ElTransform.scale(0.9));
      await gesture.up();
      await tester.pump();
      await tester.pump(Duration(milliseconds: 50));
      final box = render.committedResolvedStyle.box;
      expect(box.transform!.toMatrix4().entry(0, 0), allOf(greaterThan(0.9), lessThan(1)));
      expect(box.opacity, allOf(greaterThan(0.2), lessThan(1)));
      await tester.pumpAndSettle();
      expect(render.committedResolvedStyle.box.opacity, isNull);
      expect(render.committedResolvedStyle.box.transform, isNull);
    });
  }
}
