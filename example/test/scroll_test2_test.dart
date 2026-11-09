import 'package:example/src/pages/setting/scroll_test2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sliver 色块列表可滚动并按需挂载', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: ScrollTest2()),
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ElSliverRecyclerList>(find.byType(ElSliverRecyclerList));
    expect(list.itemCount, 10000);
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    scroll.controller!.jumpTo(scroll.controller!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(scroll.controller!.offset, greaterThan(100000));
    expect(tester.takeException(), isNull);
  });
}
