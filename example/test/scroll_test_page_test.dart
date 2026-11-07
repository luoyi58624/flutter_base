import 'package:example/src/pages/setting/scroll_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _articleText(String start) => find.byWidgetPredicate(
  (widget) => widget is ElView && widget.child is String && (widget.child as String).startsWith(start),
);

void main() {
  testWidgets('文章标题横跨卡片，带图和纯文字摘要均限制为两行', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final (width, scale) in [(320.0, 1.6), (1280.0, 1.0)]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.mobileComponents,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ScrollTestPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = _articleText('列表一滑就掉帧');
      final withCover = _articleText('同一组卡片');
      final textOnly = _articleText('上周我试着');
      expect(tester.getSize(title).width, greaterThan(tester.getSize(withCover).width));
      expect(tester.getSize(textOnly).width, closeTo(tester.getSize(title).width, .01));
      for (final summary in [withCover, textOnly]) {
        final style = tester.widget<ElView>(summary).style!;
        expect(style.maxLines, 2);
        expect(style.textOverflow, TextOverflow.ellipsis);
        expect(tester.getSize(summary).height, lessThan(3 * 15 * 1.45 * scale));
      }
      expect(tester.widget<ElListView>(find.byType(ElListView)).itemCount, 10000);
      expect(find.byType(ElCardView).evaluate().length, lessThan(50));
      expect(tester.takeException(), isNull);
    }
  });
}
