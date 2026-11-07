import 'package:example/src/pages/examples/recycler_view/rectangles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('一万条叶子矩形在三种容器中等高滚动并按需挂载', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: ElRecyclerRectanglesPage()),
      ),
    );
    await tester.pumpAndSettle();
    final recycler = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
    expect(recycler.getAdapter()!.getItemCount(), 10000);
    final first = recycler.findViewHolderForAdapterPosition(0)!.itemView;
    expect(first, isA<LeafRenderObjectWidget>());
    final rows = find.byType(first.runtimeType);

    for (final mode in ['recyclerView', 'listView', 'elScrollView', 'recyclerView']) {
      await tester.tap(find.byKey(ValueKey('comparison-mode-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('comparison-mode-$mode')));
      await tester.pumpAndSettle();

      final controller = switch (mode) {
        'listView' => tester.widget<ListView>(find.byKey(ValueKey('comparison-official-list'))).controller!,
        'elScrollView' => tester.widget<ElScrollView>(find.byKey(ValueKey('comparison-el-list'))).controller!,
        _ => recycler.controller!,
      };
      final position = controller.position;
      expect(position.pixels, 0);
      expect(position.maxScrollExtent + position.viewportDimension, closeTo(640000, .01));
      controller.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(position.extentAfter, closeTo(0, .01));
      expect(rows, findsWidgets);
      expect(rows.evaluate().length, lessThan(100));
      expect(tester.renderObjectList<RenderBox>(rows).every((row) => row.size.height == 64), isTrue);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });
}
