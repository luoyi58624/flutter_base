import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('itemWidth 按旧版断点自适应，容器变窄时至少保留一列', (tester) async {
    Widget build(double width) => Directionality(
      textDirection: .ltr,
      child: Align(
        alignment: .topLeft,
        child: SizedBox(
          width: width,
          child: ElGridView(
            key: ValueKey('grid'),
            itemWidth: 150,
            aspectRatio: 2,
            columnGap: 10,
            rowGap: 6,
            children: [for (var i = 0; i < 5; i++) SizedBox(key: ValueKey(i))],
          ),
        ),
      ),
    );

    await tester.pumpWidget(build(400));
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(195, 97.5));
    expect(tester.getTopLeft(find.byKey(ValueKey(1))), Offset(205, 0));
    expect(tester.getTopLeft(find.byKey(ValueKey(2))), Offset(0, 103.5));
    expect(tester.getSize(find.byKey(ValueKey('grid'))), Size(400, 304.5));

    await tester.pumpWidget(build(640));
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(152.5, 76.25));
    expect(tester.getTopLeft(find.byKey(ValueKey(4))), Offset(0, 82.25));
    expect(tester.getSize(find.byKey(ValueKey('grid'))), Size(640, 158.5));

    await tester.pumpWidget(build(100));
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(100, 50));
    expect(tester.getTopLeft(find.byKey(ValueKey(1))), Offset(0, 56));
    expect(tester.getSize(find.byKey(ValueKey('grid'))), Size(100, 274));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ElGridView lays out fixed-count cells with spacing', (tester) async {
    final keys = [for (var i = 0; i < 3; i++) ValueKey('cell-$i')];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            child: ElGridView(
              crossAxisCount: 2,
              mainAxisExtent: 10,
              gap: 4,
              children: [for (final key in keys) SizedBox(key: key)],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(keys[0])), const Size(48, 10));
    expect(tester.getTopLeft(find.byKey(keys[0])), Offset.zero);
    expect(tester.getTopLeft(find.byKey(keys[1])), const Offset(52, 0));
    expect(tester.getTopLeft(find.byKey(keys[2])), const Offset(0, 14));
    final bounds = tester
        .getRect(find.byKey(keys[0]))
        .expandToInclude(tester.getRect(find.byKey(keys[1])))
        .expandToInclude(tester.getRect(find.byKey(keys[2])));
    expect(bounds, const Rect.fromLTWH(0, 0, 100, 24));
  });
}
