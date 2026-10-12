import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('侧栏从右侧减速滑入，越界裁剪且保留布局', (tester) async {
    Widget scene(bool value) => animationScene(
      ElSlideAnimation(value, child: SizedBox(width: 80, height: 40)),
    );
    Offset offset() => tester
        .widget<SlideTransition>(find.byType(SlideTransition))
        .position
        .value;
    await tester.pumpWidget(scene(false));
    expect(offset(), Offset(1, 0));
    expect(find.byType(ClipRect), findsOneWidget);
    await tester.pumpWidget(scene(true));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 140));
    expect(offset().dx, inExclusiveRange(0, 0.06));
    expect(offset().dy, 0);
    expect(tester.getSize(find.byType(ElSlideAnimation)), Size(80, 40));
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(offset(), Offset.zero);
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    expect(offset(), Offset(1, 0));
  });
}
