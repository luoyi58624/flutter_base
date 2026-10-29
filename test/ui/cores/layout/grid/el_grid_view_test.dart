import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
