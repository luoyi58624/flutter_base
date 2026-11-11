// 测试沿用项目内部相对路径约定。
// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/pages/examples/preview2/index.dart';

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(home: Preview2Page()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('缩略图打开画廊，横滑切到下一张，计数栏随当前项更新', (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.byKey(ValueKey('preview2-thumb-1')));
    await tester.pumpAndSettle();
    expect(find.byType(ElPreview2View), findsOneWidget);
    expect(find.text('2 / ${preview2Images.length}'), findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElPreview2View)));
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(Offset(-20, 0), timeStamp: Duration(milliseconds: i * 16));
    }
    await gesture.moveBy(Offset.zero, timeStamp: Duration(milliseconds: 600));
    await gesture.up(timeStamp: Duration(milliseconds: 616));
    await tester.pumpAndSettle();
    expect(find.text('3 / ${preview2Images.length}'), findsOneWidget);
  });

  testWidgets('单击切换外观，下拉超过阈值关闭画廊', (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.byKey(ValueKey('preview2-thumb-0')));
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.byType(ElPreview2View));

    await tester.tapAt(center);
    await tester.pump(Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0);

    final gesture = await tester.startGesture(center);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, 20), timeStamp: Duration(milliseconds: i * 16));
    }
    await gesture.moveBy(Offset.zero, timeStamp: Duration(milliseconds: 600));
    await gesture.up(timeStamp: Duration(milliseconds: 616));
    await tester.pumpAndSettle();
    expect(find.byType(ElPreview2View), findsNothing);
    expect(find.byKey(ValueKey('preview2-thumb-0')), findsOneWidget);
  });
}
