import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('数字只在测量区内对齐，测量区独立居中且配置可动态切换', (tester) async {
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = <ElOrdinalGutterEntry>[
      for (final (i, number) in [1, 10, 10000].indexed)
        (
          viewIndex: i,
          ordinal: number,
          referenceOrdinal: 1,
          active: false,
          isLast: i == 2,
          top: i * 20.0,
          height: 20,
          baseline: null,
        ),
    ];
    Iterable<ElOrdinalGutterEntry> buildEntries(Size size) => entries;
    Widget host({
      TextAlign textAlign = TextAlign.right,
      AlignmentGeometry alignment = Alignment.center,
      TextDirection direction = TextDirection.ltr,
      int totalRows = 10000,
      int minChars = 8,
      TextScaler scaler = TextScaler.noScaling,
    }) => Align(
      alignment: .topLeft,
      child: SizedBox(
        width: 140,
        height: 60,
        child: ElOrdinalGutterHost(
          totalRows: totalRows,
          minChars: minChars,
          styles: [TextStyle(fontSize: 10)],
          textDirection: direction,
          textScaler: scaler,
          padding: .symmetric(horizontal: 10),
          textAlign: textAlign,
          alignment: alignment,
          entriesBuilder: buildEntries,
        ),
      ),
    );
    ElRenderOrdinalGutter render() => tester.renderObject(find.byType(ElOrdinalGutterHost));
    List<Rect> boxes() => render().debugPaintEntries.map((e) => e.textBounds!).toList();

    await tester.pumpWidget(host());
    final original = render();
    expect(boxes().map((b) => b.right), everyElement(closeTo(95, .001)));
    expect(boxes().last.center.dx, closeTo(70, .001));
    expect(boxes().last.width, closeTo(50, .001));
    expect(render().preferredWidth, 100, reason: 'minChars 影响外层宽度，不扩大实际五位数字区');

    await tester.pumpWidget(host(textAlign: .left));
    expect(render(), same(original));
    expect(boxes().map((b) => b.left), everyElement(closeTo(45, .001)));
    await tester.pumpWidget(host(textAlign: .center));
    expect(boxes().map((b) => b.center.dx), everyElement(closeTo(70, .001)));
    await tester.pumpWidget(host(alignment: .centerLeft));
    expect(boxes().map((b) => b.right), everyElement(closeTo(60, .001)));
    await tester.pumpWidget(host(alignment: .centerRight));
    expect(boxes().map((b) => b.right), everyElement(closeTo(130, .001)));
    await tester.pumpWidget(host(textAlign: .start, direction: .rtl, alignment: AlignmentDirectional.centerStart));
    expect(boxes().map((b) => b.right), everyElement(closeTo(130, .001)));
    await tester.pumpWidget(host(textAlign: .end, direction: .rtl));
    expect(boxes().map((b) => b.left), everyElement(closeTo(45, .001)));
    await tester.pumpWidget(host(scaler: TextScaler.linear(1.3)));
    expect(boxes().last.width, closeTo(65, .001));
    expect(boxes().last.center.dx, closeTo(70, .001));
    await tester.pumpWidget(host(totalRows: 100000));
    expect(boxes().first.right, closeTo(100, .001), reason: '跨位数变化必须刷新数字区缓存');
  });

  testWidgets('统一按最大序号、minChars、样式和缩放解析宽度', (tester) async {
    const style = TextStyle(fontSize: 10);
    final oneDigit = ElRenderOrdinalGutter.measureWidth(
      totalRows: 9,
      styles: const [style],
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      padding: const EdgeInsets.only(right: 8),
    );
    final twoDigits = ElRenderOrdinalGutter.measureWidth(
      totalRows: 10,
      styles: const [style],
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      padding: const EdgeInsets.only(right: 8),
    );
    final minChars = ElRenderOrdinalGutter.measureWidth(
      totalRows: 9,
      minChars: 5,
      styles: const [style],
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      padding: const EdgeInsets.only(right: 8),
    );
    final scaled = ElRenderOrdinalGutter.measureWidth(
      totalRows: 9,
      styles: const [style],
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(2),
      padding: const EdgeInsets.only(right: 8),
    );

    expect(twoDigits, greaterThan(oneDigit));
    expect(minChars, greaterThan(twoDigits));
    expect(scaled, greaterThan(oneDigit));
  });

  testWidgets('Render gutter 统一生成 absolute、relative 与 interval 标签', (tester) async {
    List<ElOrdinalGutterPaintEntry> snapshot = const [];

    Widget host(int mode) => Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 60,
        child: ElOrdinalGutterHost(
          totalRows: 3,
          styles: const [TextStyle(fontSize: 12)],
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          mode: mode,
          entriesBuilder: (_) => const [
            (
              viewIndex: 0,
              ordinal: 1,
              referenceOrdinal: 2,
              active: false,
              isLast: false,
              top: 0,
              height: 20,
              baseline: null,
            ),
            (
              viewIndex: 1,
              ordinal: 2,
              referenceOrdinal: 2,
              active: true,
              isLast: false,
              top: 20,
              height: 20,
              baseline: null,
            ),
            (
              viewIndex: 2,
              ordinal: 3,
              referenceOrdinal: 2,
              active: false,
              isLast: true,
              top: 40,
              height: 20,
              baseline: null,
            ),
          ],
          onPaint: (value) => snapshot = value,
        ),
      ),
    );

    await tester.pumpWidget(host(ElRenderOrdinalGutter.absolute));
    await tester.pump();
    final render = tester.renderObject<ElRenderOrdinalGutter>(find.byType(ElOrdinalGutterHost));
    expect(render.hitTestSelf(Offset.zero), isFalse, reason: '序号 gutter 不参与命中或文本选择');
    expect(snapshot.map((entry) => entry.label), ['1', '2', '3']);

    await tester.pumpWidget(host(ElRenderOrdinalGutter.relative));
    await tester.pump();
    expect(snapshot.map((entry) => entry.label), ['1', '2', '1']);

    await tester.pumpWidget(host(ElRenderOrdinalGutter.interval));
    await tester.pump();
    expect(snapshot.map((entry) => entry.label), ['', '2', '3']);
  });
}
