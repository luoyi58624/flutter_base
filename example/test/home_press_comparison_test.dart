import 'dart:ui' show PointerDeviceKind;

import 'package:example/src/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('首页切换实现后保留计数和卡片尺寸', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.byType(Switch);
    final elButtons = find.byWidgetPredicate(
      (widget) =>
          widget is ElButtonView &&
          ((widget.child is String && (widget.child as String).startsWith('count:')) ||
              ['清理存储', '安全检查', '运行状态', '应用管理'].contains(widget.semantics?.properties.label)),
    );
    final flutterButtons = find.byType(AnimatedContainer);
    expect(elButtons, findsNWidgets(5));

    await tester.tap(elButtons.first);
    await tester.pumpAndSettle();
    expect(tester.widget<ElButtonView>(elButtons.first).child, 'count: 1');
    final counterSize = tester.getSize(elButtons.first);
    final cardSize = tester.getSize(elButtons.at(1));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(elButtons, findsNothing);
    expect(flutterButtons, findsNWidgets(5));
    expect(tester.getSize(flutterButtons.first), counterSize);
    expect(tester.getSize(flutterButtons.at(1)), cardSize);
    expect(find.text('count: 1'), findsOneWidget);

    await tester.tap(find.text('count: 1'));
    await tester.pumpAndSettle();
    expect(find.text('count: 2'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(flutterButtons, findsNothing);
    expect(tester.widget<ElButtonView>(elButtons.first).child, 'count: 2');
  });

  testWidgets('Flutter 卡片按下时同时过渡缩放和背景色', (tester) async {
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final card = find.ancestor(of: find.text('清理存储'), matching: find.byType(AnimatedContainer));
    final container = find.descendant(of: card, matching: find.byType(Container)).first;
    final gesture = await tester.startGesture(tester.getCenter(card), kind: PointerDeviceKind.mouse);
    await tester.pump(Duration(milliseconds: 100));
    await tester.pump(Duration(milliseconds: 50));

    final target = tester.widget<AnimatedContainer>(card);
    final frame = tester.widget<Container>(container);
    expect(target.transform!.entry(0, 0), 0.9);
    expect(frame.transform!.entry(0, 0), allOf(greaterThan(0.9), lessThan(1)));
    expect((frame.decoration as BoxDecoration).color, isNot(anyOf(Colors.white, Colors.white.deepen(10))));

    await gesture.up();
    await tester.pumpAndSettle();
    final restored = tester.widget<Container>(container);
    expect(restored.transform!.entry(0, 0), 1);
    expect((restored.decoration as BoxDecoration).color, Colors.white);
  });
}
