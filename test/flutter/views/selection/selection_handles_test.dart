import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

RenderSelectionView _selectionRender(WidgetTester tester) {
  return tester.allRenderObjects.whereType<RenderSelectionView>().first;
}

void main() {
  group('ElSelectionView endpoint geometry', () {
    testWidgets('endpoints null when no selection', (tester) async {
      await tester.pumpWidget(_app(const ElSelectionView(child: ElView(child: 'hello world'))));
      expect(_selectionRender(tester).endpoints, isNull);
    });

    testWidgets('selectAll exposes start/end endpoint global positions', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'hello world'),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final info = _selectionRender(tester).endpoints;
      expect(info, isNotNull);
      expect(info!.start.side, SelectionHandleSide.start);
      expect(info.end.side, SelectionHandleSide.end);
      expect(info.start.lineHeight, greaterThan(0));
      expect(info.end.lineHeight, greaterThan(0));
      // start 应该在 end 左侧（同一行）。
      expect(info.start.globalPosition.dx, lessThan(info.end.globalPosition.dx));
      // y 大致一致（同一行）。
      expect((info.start.globalPosition.dy - info.end.globalPosition.dy).abs(), lessThan(1.0));
    });

    testWidgets('RTL endpoints keep logical direction and expose RTL metadata', (tester) async {
      final controller = ElSelectionController();
      const text = 'الثعلب البني السريع يقفز فوق الكلب الكسول.';
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(
              child: text,
              style: ElStyle(fontSize: 24, textDirection: TextDirection.rtl),
            ),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final info = _selectionRender(tester).endpoints;
      expect(info, isNotNull);
      expect(info!.start.side, SelectionHandleSide.start);
      expect(info.end.side, SelectionHandleSide.end);
      expect(info.start.textDirection, TextDirection.rtl);
      expect(info.end.textDirection, TextDirection.rtl);
      // RTL 的逻辑起点在视觉右侧，逻辑终点在视觉左侧。
      expect(info.start.globalPosition.dx, greaterThan(info.end.globalPosition.dx));
    });

    testWidgets('endpoints become null again after clear', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'hello world'),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();
      expect(_selectionRender(tester).endpoints, isNotNull);

      controller.clear();
      await tester.pump();
      expect(_selectionRender(tester).endpoints, isNull);
    });
  });

  group('ElSelectionView handle drag', () {
    testWidgets('beginHandleDrag exposes drag info with handle kind', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'hello world'),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      final info = render.endpoints!;
      render.beginHandleDrag(SelectionHandleSide.end, info.end.globalPosition);

      // **T2** — dragInfo 走独立 `dragInfoListenable` 通道，不再挂在 endpoints 值对象里。
      final drag = render.dragInfoListenable.value;
      expect(drag, isNotNull);
      expect(drag!.kind, SelectionDragKind.handle);
      expect(drag.side, SelectionHandleSide.end);
    });

    testWidgets('updateHandleDrag shrinks selection toward dragged position', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'hello world'),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      final initialEndX = render.endpoints!.end.globalPosition.dx;
      // 拖动右 handle 朝左移动一点，选区应该收缩。
      render.beginHandleDrag(SelectionHandleSide.end, render.endpoints!.end.globalPosition);
      final shrunk = render.endpoints!.end.globalPosition - const Offset(20, 0);
      render.updateHandleDrag(shrunk);
      await tester.pump();

      expect(controller.text, isNotNull);
      // 收缩后选区文本是 'hello world' 的前缀（end 端被拉近 start）。
      expect(controller.text!.length, lessThan('hello world'.length));
      expect(render.endpoints!.end.globalPosition.dx, lessThan(initialEndX));
    });

    testWidgets('RTL end handle shrinks selection from visual left edge', (tester) async {
      final controller = ElSelectionController();
      const text = 'الثعلب البني السريع يقفز فوق الكلب الكسول.';
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(
              child: text,
              style: ElStyle(fontSize: 24, textDirection: TextDirection.rtl),
            ),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      final initialEndX = render.endpoints!.end.globalPosition.dx;
      render.beginHandleDrag(SelectionHandleSide.end, render.endpoints!.end.globalPosition);
      final shrunk = render.endpoints!.end.globalPosition + const Offset(40, 0);
      render.updateHandleDrag(shrunk);
      await tester.pump();

      expect(controller.text, isNotNull);
      expect(controller.text!.length, lessThan(text.length));
      expect(render.endpoints!.end.globalPosition.dx, greaterThan(initialEndX));
    });

    testWidgets('endHandleDrag clears drag info', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'hello world'),
          ),
        ),
      );
      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      render.beginHandleDrag(SelectionHandleSide.end, render.endpoints!.end.globalPosition);
      expect(render.dragInfoListenable.value, isNotNull);

      render.endHandleDrag();
      expect(render.dragInfoListenable.value, isNull);
    });

    testWidgets('pointer removed during handle drag clears drag info', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'hello world'),
          ),
        ),
      );
      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      const pointer = 31;
      render.beginHandleDrag(SelectionHandleSide.end, render.endpoints!.end.globalPosition, pointer: pointer);
      expect(render.dragInfoListenable.value, isNotNull);

      GestureBinding.instance.pointerRouter.route(
        PointerRemovedEvent(
          pointer: pointer,
          kind: PointerDeviceKind.touch,
          position: render.endpoints!.end.globalPosition,
        ),
      );
      await tester.pump();

      expect(render.dragInfoListenable.value, isNull);
    });
  });

  group('ElSelectionView long-press drag info', () {
    testWidgets('touch long-press drag exposes drag info with longPress kind', (tester) async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(_app(const ElSelectionView(child: ElView(child: 'hello world'))));

      final render = tester.renderObject<ElRenderView>(find.byType(ElView).last);
      final center = render.localToGlobal(render.size.center(Offset.zero));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(center);
      // **G2** — 长按延时 500→400ms（AOSP DEFAULT_LONG_PRESS_TIMEOUT 对齐）。
      await tester.pump(const Duration(milliseconds: 399));
      // 长按未触发前 drag info 还没设置。
      expect(_selectionRender(tester).dragInfoListenable.value, isNull);

      await tester.pump(const Duration(milliseconds: 1));
      // 长按触发后选区出现，drag info 标 longPress。
      expect(_selectionRender(tester).isSelectionDragging, isTrue);
      final drag = _selectionRender(tester).dragInfoListenable.value;
      expect(drag, isNotNull);
      expect(drag!.kind, SelectionDragKind.longPress);
      expect(drag.side, isNull);

      await gesture.up();
      await tester.pump();

      // 抬起后 drag info 清空。
      expect(_selectionRender(tester).dragInfoListenable.value, isNull);
    });

    testWidgets('pointer removed during pending long press clears selection pointer state', (tester) async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(_app(const ElSelectionView(child: ElView(child: 'hello world'))));

      final render = tester.renderObject<ElRenderView>(find.byType(ElView).last);
      final center = render.localToGlobal(render.size.center(Offset.zero));

      const pointer = 77;
      final gesture = await tester.createGesture(pointer: pointer, kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(center);
      await tester.pump(const Duration(milliseconds: 100));

      GestureBinding.instance.pointerRouter.route(
        PointerRemovedEvent(pointer: pointer, kind: PointerDeviceKind.touch, position: center),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(_selectionRender(tester).isSelectionDragging, isFalse);
      expect(_selectionRender(tester).dragInfoListenable.value, isNull);
    });

    testWidgets('mouse drag does not set drag info', (tester) async {
      await tester.pumpWidget(_app(const ElSelectionView(child: ElView(child: 'hello world'))));

      final render = tester.renderObject<ElRenderView>(find.byType(ElView).last);
      final center = render.localToGlobal(render.size.center(Offset.zero));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.down(center);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();

      expect(_selectionRender(tester).dragInfoListenable.value, isNull);

      await gesture.up();
      await tester.pump();
    });
  });
}
