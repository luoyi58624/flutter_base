import 'package:example/src/pages/examples/bibi/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _row(int index) => find.descendant(of: _key('bibi-feed-1'), matching: _key('bibi-row-$index'));

void main() {
  testWidgets('非虚拟 Bibi 初始 20 张，距底部 200px 延迟 100ms 再追加 10 张', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844), viewPadding: EdgeInsets.only(top: 24, bottom: 16)),
          child: BibiPlainPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));

    expect(_row(0), findsOneWidget);
    expect(_row(9), findsOneWidget);
    expect(_row(10), findsNothing);

    final feed = find.descendant(of: _key('bibi-feed-1'), matching: find.byType(ElScroll));
    final controller = tester.widget<ElScroll>(feed).controller!;
    controller.jumpTo(controller.position.maxScrollExtent - 100);
    await tester.pump();
    expect(_row(10), findsNothing);

    await tester.pump(Duration(milliseconds: 100));
    expect(_row(14), findsOneWidget);
    expect(_row(15), findsNothing);
  });
}
