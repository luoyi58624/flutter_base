import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('侧栏从右侧滑入，自身不裁断阴影并保留布局', (tester) async {
    Widget scene(bool value) => animationScene(
      ElSlideAnimation(value, child: SizedBox(width: 80, height: 40)),
    );
    Offset offset() => tester
        .widget<SlideTransition>(find.byType(SlideTransition))
        .position
        .value;
    await tester.pumpWidget(scene(false));
    expect(offset(), Offset(1, 0));
    expect(find.byType(ClipRect), findsNothing);
    expect(
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value,
      0,
    );
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 110));
    expect(offset().dx, inExclusiveRange(0, 0.5));
    expect(offset().dy, 0);
    expect(tester.getSize(find.byType(ElSlideAnimation)), Size(80, 40));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(offset(), Offset.zero);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 80));
    expect(offset().dx, inExclusiveRange(0, 1));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(offset(), Offset(1, 0));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
