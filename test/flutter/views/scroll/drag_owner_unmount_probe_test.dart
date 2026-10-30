import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final nested in [false, true]) {
    testWidgets('持续拖动期间首按项卸载 nested=$nested', (tester) async {
      tester.view.physicalSize = Size(420, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      var rawMoves = 0;
      var rawTerminals = 0;
      void observe(PointerEvent event) {
        if (event.pointer != 913) return;
        if (event is PointerMoveEvent) rawMoves++;
        if (event is PointerUpEvent || event is PointerCancelEvent) rawTerminals++;
      }

      GestureBinding.instance.pointerRouter.addGlobalRoute(observe);
      addTearDown(() => GestureBinding.instance.pointerRouter.removeGlobalRoute(observe));
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: ElScrollView(
            controller: controller,
            cacheExtent: 0,
            physics: ElClampingScrollPhysics(),
            scrollbar: ElNoScrollBar(),
            children: [
              ElListView.builder(
                itemCount: 1000,
                fixedSize: true,
                itemBuilder: (context, index) => RepaintBoundary(
                  key: ValueKey('row-$index'),
                  child: ElView(
                    style: ElStyle(height: 64, width: 420),
                    event: ElEvent(onTap: (_) {}),
                    child: nested
                        ? ElView(
                            style: ElStyle(height: 64, width: 420),
                            event: ElEvent(onLongPress: (_) {}),
                            child: '消息 $index',
                          )
                        : '消息 $index',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      var timestamp = tester.binding.currentSystemFrameTimeStamp;
      final gesture = await tester.createGesture(pointer: 913, kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byKey(ValueKey('row-1'))), timeStamp: timestamp);
      final samples = <double>[];
      int? unmountedAt;
      for (var i = 0; i < 100; i++) {
        timestamp += Duration(milliseconds: 16);
        await gesture.moveBy(Offset(0, -12), timeStamp: timestamp);
        await tester.pump(Duration(milliseconds: 16));
        samples.add(controller.offset);
        if (unmountedAt == null && find.byKey(ValueKey('row-1')).evaluate().isEmpty) unmountedAt = i;
      }
      final beforeUp = (rawMoves: rawMoves, rawTerminals: rawTerminals);
      final forwardTail = samples.last - samples[79];
      final beforeReverse = controller.offset;
      for (var i = 0; i < 20; i++) {
        timestamp += Duration(milliseconds: 16);
        await gesture.moveBy(Offset(0, 12), timeStamp: timestamp);
        await tester.pump(Duration(milliseconds: 16));
      }
      final reverseDistance = beforeReverse - controller.offset;
      await gesture.up(timeStamp: timestamp + Duration(milliseconds: 100));
      await gesture.removePointer();
      await tester.pumpAndSettle();
      debugPrint(
        'DRAG_OWNER_PROBE nested=$nested unmountedAt=$unmountedAt '
        'raw=$beforeUp forwardTail=$forwardTail reverse=$reverseDistance '
        'sampleEvery10=${[for (var i = 0; i < samples.length; i += 10) samples[i]]}',
      );
      expect(beforeUp.rawMoves, 100, reason: '持续拖拽的真实移动必须逐条分发，且不得提前终结');
      expect(beforeUp.rawTerminals, 0);
      expect(unmountedAt, isNotNull);
      expect(forwardTail, greaterThan(180), reason: '首按项卸载后，同一指针仍应持续消费正向输入');
      expect(reverseDistance, greaterThan(180), reason: '不抬手反向拖动也必须持续消费输入');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(ElView());
    });
  }
}
