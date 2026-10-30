import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _textKey = ValueKey('handle-pointer-text');

Widget _app(ElSelectionController controller, SelectionControls controls) {
  return MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: Padding(
        padding: EdgeInsets.all(80),
        child: SizedBox(
          width: 480,
          height: 180,
          child: SelectionView(
            controller: controller,
            controls: controls,
            child: ElView(
              key: _textKey,
              style: ElStyle(width: 460, height: 120, fontSize: 20, lineHeight: 1.4),
              child: 'alpha beta gamma delta epsilon zeta',
            ),
          ),
        ),
      ),
    ),
  );
}

Future<RenderSelectionView> _selectWord(
  WidgetTester tester,
  ElSelectionController controller,
  SelectionControls controls,
) async {
  await tester.pumpWidget(_app(controller, controls));
  await tester.pumpAndSettle();
  final gesture = await tester.createGesture(kind: .touch);
  addTearDown(gesture.removePointer);
  await gesture.down(tester.getTopLeft(find.byKey(_textKey)) + Offset(18, 14));
  await tester.pump(Duration(milliseconds: 550));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
  expect(controller.text, 'alpha');
  expect(find.byKey(selectionHandleVisualKey), findsNWidgets(2));
  RenderObject? render = tester.renderObject(find.byKey(_textKey));
  while (render is! RenderSelectionView) {
    render = render!.parent;
  }
  return render;
}

Future<TestGesture> _grabEndHandle(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: .touch);
  addTearDown(gesture.removePointer);
  await gesture.down(tester.getCenter(find.byKey(selectionHandleVisualKey).last));
  await tester.pump();
  return gesture;
}

void main() {
  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  });

  for (final platform in ['Android', 'iOS']) {
    SelectionControls controls() => platform == 'Android' ? AndroidSelectionControls() : IosSelectionControls();

    testWidgets('$platform 默认句柄隐藏后继续接收触摸移动，抬手保留扩展选区', (tester) async {
      final controller = ElSelectionController();
      addTearDown(controller.dispose);
      final render = await _selectWord(tester, controller, controls());
      final before = controller.text!;
      final gesture = await _grabEndHandle(tester);
      expect(render.isHandleDragInProgress, isTrue, reason: '隐藏被拖句柄的一帧不能取消拖动会话');
      expect((render.isHandleDragInProgress || render.isSelectionDragging), isTrue);

      for (var step = 0; step < 3; step++) {
        await gesture.moveBy(Offset(45, 0));
        await tester.pump(Duration(milliseconds: 16));
        expect(render.isHandleDragInProgress, isTrue);
      }
      expect(controller.text!.length, greaterThan(before.length), reason: '通过真实句柄事件扩展选区');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(render.isHandleDragInProgress, isFalse);
      expect((render.isHandleDragInProgress || render.isSelectionDragging), isFalse);
      expect(controller.text!.length, greaterThan(before.length));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform 句柄真实取消与选区宿主卸载仍清理指针路由', (tester) async {
      final controller = ElSelectionController();
      addTearDown(controller.dispose);
      final render = await _selectWord(tester, controller, controls());
      final canceled = await _grabEndHandle(tester);
      expect(render.isHandleDragInProgress, isTrue);
      await canceled.moveBy(Offset(45, 0));
      await tester.pump(Duration(milliseconds: 16));
      await canceled.cancel();
      await tester.pumpAndSettle();
      expect(render.isHandleDragInProgress, isFalse);
      expect((render.isHandleDragInProgress || render.isSelectionDragging), isFalse);

      final detached = await _grabEndHandle(tester);
      expect(render.isHandleDragInProgress, isTrue);
      await tester.pumpWidget(MaterialApp(home: SizedBox.shrink()));
      expect((render.isHandleDragInProgress || render.isSelectionDragging), isFalse);
      await detached.moveBy(Offset(40, 0));
      await detached.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
