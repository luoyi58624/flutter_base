/// 检查组件实际 glyph 的尺寸和全局中心，避免只验证外层包装。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/src/my_ui/index.dart';
import 'package:flutter_base/src/my_ui/cores/glyph.dart';
import 'package:flutter_base/ui.dart';

Widget _host(Widget child, {double? progressSize}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: true),
    child: MyTheme(
      data: MyThemeData(progressSize: progressSize),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 320, child: child),
      ),
    ),
  ),
);

void _expectGlyph(
  WidgetTester tester,
  Finder component,
  double extent, {
  double? circleSize,
}) {
  final glyph = find.descendant(of: component, matching: find.byType(MyGlyph));
  expect(glyph, findsOneWidget);
  final rect = tester.getRect(glyph);
  expect(rect.width, closeTo(extent, .000001));
  expect(rect.height, closeTo(extent, .000001));
  final frame = find.descendant(
    of: component,
    matching: find.byWidgetPredicate(
      (w) =>
          w is ElView && w.style?.width == extent && w.style?.height == extent,
    ),
  );
  expect(frame, findsOneWidget);
  final frameRect = tester.getRect(frame);
  expect((rect.topLeft - frameRect.topLeft).distance, closeTo(0, .000001));
  expect((rect.center - frameRect.center).distance, closeTo(0, .000001));
  if (circleSize != null) {
    // MyProgress 的内联宿主可占满父宽，应与实际圆环比较中心。
    final ring = find.descendant(
      of: component,
      matching: find.byWidgetPredicate(
        (w) =>
            w is ElView &&
            w.style?.width == circleSize &&
            w.style?.height == circleSize,
      ),
    );
    expect(ring, findsOneWidget);
    expect(
      (rect.center - tester.getCenter(ring)).distance,
      closeTo(0, .000001),
    );
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Loading 三档实际 glyph 随同一实例尺寸更新并居中', (tester) async {
    for (final size in [
      MyLoadingSize.small,
      MyLoadingSize.medium,
      MyLoadingSize.large,
      MyLoadingSize.small,
    ]) {
      await tester.pumpWidget(_host(MyLoading(size: size)));
      await tester.pumpAndSettle();
      _expectGlyph(tester, find.byType(MyLoading), size.pixels);
    }
  });
  for (final status in [MyProgressStatus.success, MyProgressStatus.error]) {
    testWidgets('Progress line ${status.name} 实际 glyph 为18且居中', (tester) async {
      await tester.pumpWidget(_host(MyProgress(value: 100, status: status)));
      await tester.pumpAndSettle();
      _expectGlyph(tester, find.byType(MyProgress), 18);
    });
    testWidgets('Progress circle ${status.name} 在40/64/96/128切换时保持0.28比例与圆心', (
      tester,
    ) async {
      for (final size in [40.0, 64.0, 96.0, 128.0, 40.0]) {
        await tester.pumpWidget(
          _host(
            MyProgress(value: 100, type: MyProgressType.circle, status: status),
            progressSize: size,
          ),
        );
        await tester.pumpAndSettle();
        _expectGlyph(
          tester,
          find.byType(MyProgress),
          size * .28,
          circleSize: size,
        );
      }
    });
  }
}
