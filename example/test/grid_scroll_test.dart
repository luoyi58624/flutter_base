import 'package:example/src/pages/setting/grid_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('网格滚动按页挂上 ElGridView', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: GridScrollPage()),
      ),
    );
    expect(find.byType(ElGridView), findsNothing);

    await tester.pump(Duration(milliseconds: 250));
    await tester.pump();

    expect(find.byType(ElGridView), findsOneWidget);
    expect(find.byType(ElImageView), findsWidgets);
    expect(
      find.byWidgetPredicate((widget) => widget is ElView && widget.child == '酱油神小子'),
      findsWidgets,
    );

    await tester.pumpWidget(SizedBox.shrink());
    await tester.pump(Duration(milliseconds: 100));
  });
}
