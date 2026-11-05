/// 检查组件实际 glyph 的尺寸和全局中心，避免只验证外层包装。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/ui/mobile/components/loading/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/progress/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/cores/glyph.dart' as skin;

Widget _host(Widget child, {double? progressSize}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: true),
    child: ElComponentProvider(
      components: el.mobileComponents,
      child: ElView(
        style: ElStyle(vars: {skin.Progress.$size: ?progressSize}),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 320, child: child),
        ),
      ),
    ),
  ),
);

void _expectGlyph(WidgetTester tester, Finder component, double extent, {double? circleSize}) {
  final glyph = find.descendant(of: component, matching: find.byType(skin.Glyph));
  expect(glyph, findsOneWidget);
  final rect = tester.getRect(glyph);
  expect(rect.width, closeTo(extent, .000001));
  expect(rect.height, closeTo(extent, .000001));
  final frame = find.descendant(
    of: component,
    matching: find.byWidgetPredicate((w) => w is ElView && w.style?.width == extent && w.style?.height == extent),
  );
  expect(frame, findsOneWidget);
  final frameRect = tester.getRect(frame);
  expect((rect.topLeft - frameRect.topLeft).distance, closeTo(0, .000001));
  expect((rect.center - frameRect.center).distance, closeTo(0, .000001));
  if (circleSize != null) {
    // skin.Progress 的内联宿主可占满父宽，应与实际圆环比较中心。
    final ring = find.descendant(
      of: component,
      matching: find.byWidgetPredicate(
        (w) => w is ElView && w.style?.width == circleSize && w.style?.height == circleSize,
      ),
    );
    expect(ring, findsOneWidget);
    expect((rect.center - tester.getCenter(ring)).distance, closeTo(0, .000001));
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Loading 三档实际 glyph 随同一实例尺寸更新并居中', (tester) async {
    for (final size in [
      skin.LoadingSize.small,
      skin.LoadingSize.medium,
      skin.LoadingSize.large,
      skin.LoadingSize.small,
    ]) {
      await tester.pumpWidget(_host(skin.Loading(size: size)));
      await tester.pumpAndSettle();
      _expectGlyph(tester, find.byType(skin.Loading), size.pixels);
    }
  });
  for (final status in [skin.ProgressStatus.success, skin.ProgressStatus.error]) {
    testWidgets('Progress line ${status.name} 实际 glyph 为18且居中', (tester) async {
      await tester.pumpWidget(_host(skin.Progress(value: 100, status: status)));
      await tester.pumpAndSettle();
      _expectGlyph(tester, find.byType(skin.Progress), 18);
    });
    testWidgets('Progress circle ${status.name} 在40/64/96/128切换时保持0.28比例与圆心', (tester) async {
      for (final size in [40.0, 64.0, 96.0, 128.0, 40.0]) {
        await tester.pumpWidget(
          _host(
            skin.Progress(value: 100, type: skin.ProgressType.circle, status: status),
            progressSize: size,
          ),
        );
        await tester.pumpAndSettle();
        _expectGlyph(tester, find.byType(skin.Progress), size * .28, circleSize: size);
      }
    });
  }
}
