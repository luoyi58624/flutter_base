import 'package:example/src/pages/examples.dart';
import 'package:example/src/pages/examples/imperative_view/rectangles.dart';
import 'package:example/src/utils/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_base/view.dart' as view;
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(navigatorKey: el.navigatorKey, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('示例目录有命令式View分组，点击打开颜色矩形，深度路由也登记', (tester) async {
    await _open(tester, ExamplesPage());
    expect(tester.widgetList<ElListGroup>(find.byType(ElListGroup)).map((group) => group.title), [
      '交互与视图',
      'RecyclerView',
      '命令式View',
    ]);
    final entry = find.byKey(ValueKey('advanced-imperative-rectangles'));
    await tester.drag(find.byKey(PageStorageKey('advanced-examples')), Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(ImperativeRectanglesPage), findsOneWidget);
    expect(find.byType(rv.RecyclerView), findsOneWidget);
    expect(RouterUtil.exampleRoutes().map((route) => route.path), contains('imperative-rectangles'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('三种容器按需绘制相同矩形，滚动与切换后从首行重新开始', (tester) async {
    await _open(tester, ImperativeRectanglesPage());
    for (final mode in ['recyclerView', 'listView', 'elScrollView', 'recyclerView']) {
      await tester.tap(find.byKey(ValueKey('imperative-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('imperative-mode-$mode')));
      await tester.pumpAndSettle();
      final rows = find.byType(view.ElRootView);
      expect(rows.evaluate().length, inExclusiveRange(0, 50));
      final root = tester.widget<view.ElRootView>(rows.first).root;
      expect(root.childCount, 3);
      expect(root.children.first.width, 72);
      expect(root.padding, EdgeInsets.all(12));
      expect(root.margin, EdgeInsets.symmetric(horizontal: 16, vertical: 6));
      final key = switch (mode) {
        'recyclerView' => 'imperative-recycler-list',
        'listView' => 'imperative-official-list',
        _ => 'imperative-el-list',
      };
      await tester.drag(find.byKey(ValueKey(key)), Offset(0, -500));
      await tester.pumpAndSettle();
      if (mode == 'elScrollView') {
        expect(tester.widget<ElScrollView>(find.byType(ElScrollView)).controller!.offset, greaterThan(0));
      } else if (mode == 'listView') {
        expect(tester.widget<ListView>(find.byType(ListView)).controller!.offset, greaterThan(0));
      } else {
        final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
        expect(list.getAdapter()!.getItemCount(), 10000);
        list.scrollToPosition(9999);
        await tester.pumpAndSettle();
        final holder = list.findViewHolderForAdapterPosition(9999)!;
        final last = (holder.itemView as view.ElRootView).root;
        expect(last.children.first.width, 128);
        expect(last.children.first.bgColor, Colors.purple);
      }
      expect(rows.evaluate().length, lessThan(50));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('官方组件开关在三个容器中切换子项，保留矩形颜色、尺寸和间距', (tester) async {
    await _open(tester, ImperativeRectanglesPage());
    final toggle = find.byKey(ValueKey('imperative-flutter-items'));
    for (final mode in ['recyclerView', 'listView', 'elScrollView']) {
      await tester.tap(find.byKey(ValueKey('imperative-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('imperative-mode-$mode')));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(toggle).value, isFalse);
      final rows = find.byType(view.ElRootView);
      final root = tester.widget<view.ElRootView>(rows.first).root;
      final outerRect = tester.getRect(rows.first);
      final first = root.children.first;
      final firstRect = (outerRect.topLeft + root.offset + first.offset) & first.size;
      final firstColor = first.bgColor;

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(rows, findsNothing);
      final official = find.byKey(ValueKey('imperative-flutter-row-0'));
      expect(tester.getRect(official), outerRect);
      final boxes = find.descendant(of: official, matching: find.byType(ColoredBox));
      expect(boxes, findsNWidgets(4));
      expect(tester.getRect(boxes.at(1)), firstRect);
      expect(tester.widget<ColoredBox>(boxes.at(1)).color, firstColor);

      if (mode == 'recyclerView') {
        final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
        list.scrollToPosition(9999);
        await tester.pumpAndSettle();
        final last = find.byKey(ValueKey('imperative-flutter-row-9999'));
        expect(last, findsOneWidget);
        final lastBoxes = find.descendant(of: last, matching: find.byType(ColoredBox));
        expect(tester.getSize(lastBoxes.at(1)).width, 128);
        expect(tester.widget<ColoredBox>(lastBoxes.at(1)).color, Colors.purple);
      }
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(rows.evaluate().length, inExclusiveRange(0, 50));
      expect(find.byType(ColoredBox).evaluate().length, lessThan(50));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });
}
