import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

const _textStyle = TextStyle(fontSize: 10, height: 1, color: Color(0xff000000));

Widget _host({
  required EditableController controller,
  required ElEvent ancestorEvent,
  ScrollController? scrollController,
  double editorHeight = 200,
}) {
  return MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: ElView(
        style: const ElStyle(width: 300, height: 200),
        event: ancestorEvent,
        child: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: 300,
            height: editorHeight,
            child: EditableView(
              controller: controller,
              scrollController: scrollController,
              style: EditableConfiguration(textStyle: _textStyle),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  for (final kind in <PointerDeviceKind>[PointerDeviceKind.mouse, PointerDeviceKind.stylus]) {
    testWidgets(
      '${kind.name} 拖选成立时先淘汰祖先，再修改选区且后续事件只归 winner',
      (tester) async {
        final controller = EditableController(text: List.generate(80, (index) => 'line $index').join('\n'));
        addTearDown(controller.dispose);
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        addTearDown(() => _unmount(tester));
        final trace = <String>[];
        final ancestorRaw = <ElEventPhase>[];
        final ancestorDrag = <ElEventPhase>[];
        final selectionDuringCancel = <TextSelection>[];
        final scrollDuringCancel = <double>[];
        var ancestorTaps = 0;

        await tester.pumpWidget(
          _host(
            controller: controller,
            scrollController: scrollController,
            editorHeight: 100,
            ancestorEvent: ElEvent(
              onPointerMove: (event) => ancestorRaw.add(event.phase),
              onPointerUp: (event) => ancestorRaw.add(event.phase),
              onTap: (_) => ancestorTaps++,
              onTapCancel: (_) {
                trace.add('cancel');
                selectionDuringCancel.add(controller.selection);
                scrollDuringCancel.add(scrollController.position.pixels);
              },
              onDragStart: (event) => ancestorDrag.add(event.phase),
              onDragUpdate: (event) => ancestorDrag.add(event.phase),
              onDragEnd: (event) => ancestorDrag.add(event.phase),
              onDragCancel: (event) => ancestorDrag.add(event.phase),
            ),
          ),
        );
        await tester.pump();
        final origin = tester.getTopLeft(find.byType(EditableView));
        final gesture = await tester.createGesture(kind: kind);
        addTearDown(gesture.removePointer);

        await gesture.down(origin + const Offset(2, 5));
        await tester.pump(const Duration(milliseconds: 16));
        final selectionBeforeDrag = controller.selection;
        controller.addListener(() => trace.add('selection'));

        await gesture.moveTo(origin + const Offset(62, 150));
        await tester.pump(const Duration(milliseconds: 16));

        expect(selectionDuringCancel, <TextSelection>[selectionBeforeDrag]);
        expect(scrollDuringCancel, <double>[0], reason: '认领结算前不得启动边缘自动滚动');
        expect(trace.take(2), <String>['cancel', 'selection'], reason: 'loser 取消必须早于拖选与边缘滚动等 winner 副作用');
        expect(controller.selection, isNot(selectionBeforeDrag), reason: '认领后 winner 仍须完成本次拖选');
        expect(scrollController.position.pixels, greaterThan(0), reason: '认领后 winner 仍须启动边缘自动滚动');
        expect(ancestorRaw, isEmpty, reason: '同一 move 内尚未执行及之后的祖先 raw 回调必须失效');
        expect(ancestorDrag, isEmpty, reason: 'Editable 独占后祖先 Drag 全流必须为零');

        await gesture.moveTo(origin + const Offset(82, 170));
        await tester.pump(const Duration(milliseconds: 16));
        final winnerSelection = controller.selection;
        await gesture.up();
        await tester.pump();

        expect(controller.selection, winnerSelection, reason: 'winner 必须自行走完拖选终态');
        expect(ancestorRaw, isEmpty);
        expect(ancestorDrag, isEmpty);
        expect(ancestorTaps, 0);
        await _unmount(tester);
      },
    );
  }

  testWidgets(
    '触摸长按先 eager 淘汰竞争者，再选词且只认领一次',
    (tester) async {
      final controller = EditableController(text: 'alpha beta gamma');
      addTearDown(controller.dispose);
      addTearDown(() => _unmount(tester));
      final trace = <String>[];
      final selectionDuringCancel = <TextSelection>[];
      var ancestorCancels = 0;
      var ancestorUps = 0;
      var ancestorTaps = 0;

      await tester.pumpWidget(
        _host(
          controller: controller,
          ancestorEvent: ElEvent(
            onPointerUp: (_) => ancestorUps++,
            onTap: (_) => ancestorTaps++,
            onTapCancel: (_) {
              ancestorCancels++;
              trace.add('cancel');
              selectionDuringCancel.add(controller.selection);
            },
          ),
        ),
      );
      await tester.pump();
      final rect = tester.getRect(find.byType(EditableView));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);

      await gesture.down(Offset(rect.left + 72, rect.top + 5));
      await tester.pump(const Duration(milliseconds: 16));
      final selectionBeforeLongPress = controller.selection;
      controller.addListener(() => trace.add('selection'));

      await tester.pump(const Duration(milliseconds: 600));

      expect(selectionDuringCancel, <TextSelection>[selectionBeforeLongPress]);
      expect(trace.take(2), <String>['cancel', 'selection'], reason: '长按成功后的 eager 必须早于 selectWord');
      expect(ancestorCancels, 1, reason: '同一长按只允许一次有效认领/取消结算');
      expect(controller.selection, const TextSelection(baseOffset: 6, extentOffset: 10));

      await gesture.up();
      await tester.pump();
      expect(ancestorUps, 0);
      expect(ancestorTaps, 0);
      expect(ancestorCancels, 1);
      await _unmount(tester);
    },
  );
}
