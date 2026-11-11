import 'package:example/src/pages/components/event/basic/examples/drag.dart';
import 'package:example/src/pages/components/event/demo_surface.dart';
import 'package:example/src/pages/components/event/drag/examples/drag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _show(WidgetTester tester, Widget example) async {
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 248, child: example)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final examples = <(String, Widget Function(), String, String, String)>[
    ('基础拖拽', ElDragEventExample.new, 'event-basic-drag', 'event-basic-drag-block', 'event-basic-drag-reset'),
    ('拖拽交互', ElEventDragExample.new, 'event-drag-area', 'event-drag-block', 'event-drag-reset'),
  ];

  for (final (label, example, areaKey, blockKey, resetKey) in examples) {
    testWidgets('$label 保留四边越界偏移，双轴独立夹持且新拖拽清理旧偏移', (tester) async {
      await _show(tester, example());
      final block = _key(blockKey);
      final bounds = tester.getRect(_key(areaKey));
      final initial = tester.getTopLeft(block);
      final size = tester.getSize(block);

      // 沿用旧 el_docs：累计位移不截断，只有显示位置受边界限制。
      for (final direction in [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1)]) {
        await tester.tap(_key(resetKey));
        await tester.pumpAndSettle();
        final edge = Offset(
          direction.dx > 0 ? bounds.right - size.width : (direction.dx < 0 ? bounds.left : initial.dx),
          direction.dy > 0 ? bounds.bottom - size.height : (direction.dy < 0 ? bounds.top : initial.dy),
        );
        final drag = await tester.startGesture(tester.getCenter(block));
        await drag.moveBy(direction * 8);
        await drag.moveBy(direction * 300);
        await tester.pump();
        expect(tester.getTopLeft(block), edge);

        await drag.moveBy(direction * -5);
        await tester.pump();
        expect(tester.getTopLeft(block), edge, reason: '指针累计偏移仍在范围外时，卡片继续显示在边界');
        await drag.moveBy(direction * -275);
        await tester.pump();
        expect(tester.getTopLeft(block), initial + direction * 20, reason: '回到有效范围后恢复完整累计位移对应的位置');

        await drag.moveBy(direction * 300);
        await drag.up();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(block), edge);
        expect(find.text('onDragEnd'), findsOneWidget);

        final next = await tester.startGesture(tester.getCenter(block));
        await next.moveBy(direction * -8);
        await tester.pump();
        expect(tester.getTopLeft(block), edge);
        await next.moveBy(direction * -4);
        await tester.pump();
        expect(tester.getTopLeft(block), edge - direction * 4, reason: '新拖拽从当前显示位置开始，不继承上次越界偏移');
        await next.up();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(block), edge - direction * 4);
      }

      await tester.tap(_key(resetKey));
      await tester.pumpAndSettle();
      final start = tester.getCenter(block);
      final drag = await tester.startGesture(start, pointer: 1);
      await drag.moveBy(Offset(8, 8));
      await drag.moveBy(Offset(300, 300));
      await tester.pump();
      final atEdge = tester.getRect(block);
      expect(atEdge.right, closeTo(bounds.right, 0.001));
      expect(atEdge.bottom, closeTo(bounds.bottom, 0.001));

      await drag.moveBy(Offset(-5, -6));
      await tester.pump();
      expect(tester.getTopLeft(block), atEdge.topLeft);
      await drag.moveBy(Offset(-275, 0));
      await tester.pump();
      expect(tester.getTopLeft(block), Offset(initial.dx + 20, atEdge.top), reason: 'X 先回到有效区，Y 继续停在下边界');
      await drag.moveBy(Offset(0, -270));
      await tester.pump();
      expect(tester.getTopLeft(block), initial + Offset(20, 24));

      // 抬手点与最后一个 Move 相差 2/1px，验证 End 只补最终增量。
      await tester.sendEventToBinding(PointerUpEvent(pointer: 1, position: start + Offset(30, 31)));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(block), initial + Offset(22, 23));
      expect(find.text('onDragEnd'), findsOneWidget);

      await tester.tap(_key(resetKey));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(block), initial);
      final canceled = await tester.startGesture(tester.getCenter(block), pointer: 2);
      await canceled.moveBy(Offset(8, 8));
      await canceled.moveBy(Offset(12, 12));
      await tester.pump();
      final beforeCancel = tester.getTopLeft(block);
      expect(beforeCancel, initial + Offset(12, 12));
      await canceled.cancel();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(block), beforeCancel);
      expect(find.text('onDragCancel'), findsOneWidget);
      await tester.tap(_key(resetKey));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(block), initial);
      await tester.pumpWidget(SizedBox());
    });
  }

  testWidgets('水平和垂直拖拽保持单轴限制，回到边界内和松手都不影响另一轴', (tester) async {
    await _show(tester, ElDragEventExample());
    final block = _key('event-basic-drag-block');
    for (final horizontal in [true, false]) {
      await tester.tap(_key('event-basic-drag-${horizontal ? 'horizontal' : 'vertical'}'));
      await tester.pumpAndSettle();
      final initial = tester.getTopLeft(block);
      final bounds = tester.getRect(_key('event-basic-drag'));
      final drag = await tester.startGesture(tester.getCenter(block));
      await drag.moveBy(horizontal ? Offset(8, 0) : Offset(0, 8));
      await drag.moveBy(horizontal ? Offset(300, 60) : Offset(60, 300));
      await tester.pump();
      final atEdge = tester.getRect(block);
      if (horizontal) {
        expect(atEdge.right, closeTo(bounds.right, 0.001));
        expect(atEdge.top, initial.dy);
      } else {
        expect(atEdge.bottom, closeTo(bounds.bottom, 0.001));
        expect(atEdge.left, initial.dx);
      }
      await drag.moveBy(Offset(-4, -4));
      await tester.pump();
      expect(tester.getTopLeft(block), atEdge.topLeft);
      await drag.moveBy(horizontal ? Offset(-275, 13) : Offset(13, -275));
      await tester.pump();
      final returned = tester.getTopLeft(block);
      expect(returned, initial + (horizontal ? Offset(21, 0) : Offset(0, 21)));
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(block), returned);
      expect(find.text(horizontal ? 'onHorizontalDragEnd' : 'onVerticalDragEnd'), findsOneWidget);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('两种拖拽示例连续移动时只刷新动态内容，舞台与按钮不重新构建', (tester) async {
    for (final (_, example, _, blockKey, resetKey) in examples) {
      await _show(tester, example());
      final block = _key(blockKey);
      final drag = await tester.startGesture(tester.getCenter(block));
      await drag.moveBy(Offset(8, 0));
      await tester.pumpAndSettle();
      final surface = tester.widget<ElEventDemoSurface>(find.byType(ElEventDemoSurface));
      final reset = tester.widget<ElButton>(_key(resetKey));
      final buttons = tester.widgetList<ElButton>(find.byType(ElButton)).toList();
      final card = tester.widget<ElView>(block);
      final previousCallback = debugOnRebuildDirtyWidget;
      var builds = 0, surfaceBuilds = 0, buttonBuilds = 0;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previousCallback?.call(element, builtOnce);
        builds++;
        if (element.widget is ElEventDemoSurface) surfaceBuilds++;
        if (element.widget is ElButton) buttonBuilds++;
      };
      try {
        for (var move = 0; move < 6; move++) {
          final previous = tester.getTopLeft(block);
          await drag.moveBy(Offset(3, 2));
          await tester.pump();
          expect(tester.getTopLeft(block), previous + Offset(3, 2));
          expect(tester.widget<ElEventDemoSurface>(find.byType(ElEventDemoSurface)), same(surface));
          expect(tester.widget<ElButton>(_key(resetKey)), same(reset));
          expect(tester.widget<ElView>(block), same(card));
          final currentButtons = tester.widgetList<ElButton>(find.byType(ElButton)).toList();
          expect(currentButtons.length, buttons.length);
          for (var index = 0; index < buttons.length; index++) {
            expect(currentButtons[index], same(buttons[index]));
          }
        }
      } finally {
        debugOnRebuildDirtyWidget = previousCallback;
      }
      expect(builds, greaterThan(0), reason: '确实经历了动态内容的重建');
      expect(surfaceBuilds, 0);
      expect(buttonBuilds, 0);
      expect(find.text('onDragUpdate'), findsOneWidget);
      await drag.up();
      await tester.pumpAndSettle();
      await tester.pumpWidget(SizedBox());
    }
  });
}
