import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _action(Key key) => find
    .descendant(
      of: find.byKey(key),
      matching: find.byWidgetPredicate((widget) => widget is ElView && widget.event?.onTap != null),
    )
    .first;

void main() {
  testWidgets('按钮和卡片使用各自的缩放比例，并按局部令牌过渡和回弹', (tester) async {
    final buttonKey = ValueKey('button');
    final cardKey = ValueKey('card');
    final duration = Duration(milliseconds: 200);
    final half = Duration(milliseconds: 100);
    final cardColor = Color(0xffeeeeee);
    final cardPressColor = Color(0xffbbbbbb);
    var activations = 0;
    var overrideMotion = false;
    late StateSetter update;

    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElComponentProvider(
          components: el.mobileComponents,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElView(
                style: ElStyle(
                  vars: {
                    ElTokens.$cardColor: cardColor,
                    ElTokens.$cardPressColor: cardPressColor,
                    if (overrideMotion) ...{
                      ElTokens.$buttonPressScale: .8,
                      ElTokens.$cardPressScale: .94,
                      ElTokens.$pressDuration: duration,
                      ElTokens.$pressCurve: Curves.linear,
                    },
                  },
                ),
                child: Center(
                  child: SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisSize: .min,
                      spacing: 24,
                      children: [
                        ElButton(key: buttonKey, child: '确定', onPressed: () => activations++),
                        ElCard(key: cardKey, child: SizedBox(height: 60), onTap: () => activations++),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = _action(buttonKey);
    final card = _action(cardKey);
    final buttonStyle = tester.widget<ElView>(button).style!;
    final cardStyle = tester.widget<ElView>(card).style!;
    expect(tester.getSize(button), Size(64, 40));
    expect(buttonStyle.borderRadius, BorderRadius.circular(6));
    expect(cardStyle.borderRadius, BorderRadius.circular(20));
    expect(cardStyle.padding, EdgeInsets.all(16));
    expect(buttonStyle.onTap!.transform, ElTransform.scale(.9));
    expect(cardStyle.onTap!.transform, ElTransform.scale(.96));
    expect(buttonStyle.transition!.single.duration, Duration(milliseconds: 100));
    expect(cardStyle.transition!.single.curve, Curves.easeOut);

    update(() => overrideMotion = true);
    await tester.pumpAndSettle();
    for (final (target, scale, isCard) in [(button, .8, false), (card, .94, true)]) {
      final render = tester.renderObject<ElRenderView>(target);
      double renderedScale() => render.committedResolvedStyle.box.transform?.toMatrix4().entry(0, 0) ?? 1;
      final initialColor = render.committedResolvedStyle.box.backgroundColor;
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      await tester.pump(half);
      expect(renderedScale(), closeTo((1 + scale) / 2, .001));
      expect(
        render.committedResolvedStyle.box.backgroundColor,
        isCard ? Color.lerp(cardColor, cardPressColor, .5) : initialColor,
      );
      await tester.pump(half);
      expect(renderedScale(), closeTo(scale, .001));
      await gesture.up();
      await tester.pump();
      await tester.pump(half);
      expect(renderedScale(), closeTo((1 + scale) / 2, .001));
      await tester.pump(half);
      expect(renderedScale(), 1);
      expect(render.committedResolvedStyle.box.backgroundColor, initialColor);
    }
    expect(activations, 2);
  });
}
