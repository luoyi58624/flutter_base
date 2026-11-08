import 'package:example/src/pages/setting/scroll_test2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RecyclerView 色块列表可滚动并按需挂载', (tester) async {
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

    final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
    expect(list.getAdapter()!.getItemCount(), 200);
    final first = find.ancestor(of: find.text('0'), matching: find.byType(ColoredBox)).first;
    expect(tester.getSize(first).height, 64);
    expect(find.textContaining(RegExp(r'^\d+$')).evaluate().length, lessThan(30));

    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('199'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
