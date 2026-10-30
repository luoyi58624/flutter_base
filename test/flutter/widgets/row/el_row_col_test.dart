import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 600}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    // ElView 的显式宽度会被祖先 tight 约束 enforce，先用 Align 松开约束再收窄
    child: Align(
      alignment: Alignment.topLeft,
      child: ElView(
        style: ElStyle(width: width),
        child: child,
      ),
    ),
  );
}

Iterable<ElView> _cols(WidgetTester tester) =>
    tester.widgetList<ElView>(find.descendant(of: find.byType(ElCol), matching: find.byType(ElView)));

void main() {
  testWidgets('span 换算成 24 栅格百分比宽度', (tester) async {
    await tester.pumpWidget(
      _host(
        const ElRow(
          children: [
            ElCol(span: 12, child: 'A'),
            ElCol(span: 6, child: 'B'),
            ElCol(span: 24, child: 'C'),
          ],
        ),
      ),
    );

    final widths = _cols(tester).map((v) => v.style?.width).toList();
    expect(widths, ['50.0%', '25.0%', '100.0%']);
  });

  testWidgets('实际布局宽度按父容器换算，超出一行自动折行', (tester) async {
    await tester.pumpWidget(
      _host(
        const ElRow(
          children: [
            ElCol(span: 12, child: 'A'),
            ElCol(span: 12, child: 'B'),
            ElCol(span: 12, child: 'C'),
          ],
        ),
      ),
    );

    final first = tester.getRect(find.byType(ElCol).at(0));
    final second = tester.getRect(find.byType(ElCol).at(1));
    final third = tester.getRect(find.byType(ElCol).at(2));

    expect(first.width, closeTo(300, 0.5));
    // 前两列同一行，第三列折到下一行
    expect(second.top, first.top);
    expect(third.top, greaterThan(first.top));
    expect(third.left, first.left);
  });

  testWidgets('gutter 走官方口径：行负外边距抵消列内边距', (tester) async {
    await tester.pumpWidget(
      _host(
        const ElRow(
          gutter: 20,
          children: [
            ElCol(span: 12, child: 'A'),
            ElCol(span: 12, child: 'B'),
          ],
        ),
      ),
    );

    final row = tester.widgetList<ElView>(find.descendant(of: find.byType(ElRow), matching: find.byType(ElView))).first;
    expect(row.style?.margin, const EdgeInsets.symmetric(horizontal: -10));
    expect(_cols(tester).first.style?.padding, const EdgeInsets.symmetric(horizontal: 10));
  });

  testWidgets('offset 按实际行宽换算为原生边距，父宽变化后重新计算', (tester) async {
    await tester.pumpWidget(_host(const ElRow(children: [ElCol(span: 6, offset: 6, child: 'A')])));

    expect(_cols(tester).first.style?.margin, const EdgeInsets.only(left: 150));
    final column = find.descendant(of: find.byType(ElCol), matching: find.byType(ElView)).first;
    final render = tester.renderObject<ElRenderView>(column);
    expect(render.localToGlobal(render.boxOrigin).dx - tester.getTopLeft(find.byType(ElRow)).dx, 150);
    await tester.pumpWidget(_host(const ElRow(children: [ElCol(span: 6, offset: 6, child: 'A')]), width: 400));
    expect(_cols(tester).first.style?.margin, const EdgeInsets.only(left: 100));
  });

  testWidgets('span: 0 的列不渲染', (tester) async {
    await tester.pumpWidget(
      _host(
        const ElRow(
          children: [
            ElCol(span: 0, child: 'A'),
            ElCol(span: 12, child: 'B'),
          ],
        ),
      ),
    );

    expect(_cols(tester).any((v) => v.child == 'A'), isFalse);
    expect(_cols(tester).any((v) => v.child == 'B'), isTrue);
  });

  testWidgets('响应式取命中的最小档：窄屏用 xs、中屏用 md、宽屏回落 span', (tester) async {
    // 断点读的是视口尺寸（继承 size），必须真的改测试视口，套一层窄 ElView 无效
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    Future<Object?> widthAt(double viewport) async {
      tester.view.physicalSize = Size(viewport, 600);
      await tester.pumpWidget(
        _host(
          const ElRow(children: [ElCol(span: 6, xs: 24, md: 12, child: 'A')]),
          width: viewport,
        ),
      );
      return _cols(tester).first.style?.width;
    }

    // ElView 断点是上界语义：300 命中 xs，800 命中 md，1500 三档都不中
    expect(await widthAt(300), '100.0%');
    expect(await widthAt(800), '50.0%');
    expect(await widthAt(1500), '25.0%');
  });

  testWidgets('justify / align 映射到 Wrap 的对齐', (tester) async {
    await tester.pumpWidget(
      _host(
        const ElRow(
          justify: ElRowJustify.spaceBetween,
          align: ElRowAlign.middle,
          children: [
            ElCol(span: 6, child: 'A'),
            ElCol(span: 6, child: 'B'),
          ],
        ),
      ),
    );

    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap.alignment, WrapAlignment.spaceBetween);
    expect(wrap.crossAxisAlignment, WrapCrossAlignment.center);
  });
}
