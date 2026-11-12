import 'package:example/src/pages/settings/scroll_test/index.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _item(int index) => find.byWidgetPredicate((widget) {
  final child = widget is ElView ? widget.child : null;
  return child is ValueListenable<int> && child.value == index;
});

void main() {
  testWidgets('滚动测试使用 ElSliverList 并在滚动后换绑序号', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: ScrollTestPage()),
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ElSliverList>(find.byWidgetPredicate((widget) => widget is ElSliverList));
    expect(list.itemCount, 1000);
    expect(_item(0), findsOneWidget);
    expect(find.byType(ElView).evaluate().length, lessThan(30));

    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(_item(999), findsOneWidget);
    expect(_item(0), findsNothing);

    await tester.tap(find.byKey(ValueKey('scroll-test-official-switch')));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((widget) => widget is ElSliverList), findsNothing);
    expect(find.byType(SliverList), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is ElView && widget.child == 0), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
