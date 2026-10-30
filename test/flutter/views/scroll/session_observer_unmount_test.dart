import 'package:flutter_base/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Observer extends StatefulWidget {
  const _Observer({required this.onDispose, required this.observeSessions});
  final VoidCallback onDispose;
  final bool observeSessions;
  @override
  State<_Observer> createState() => _ObserverState();
}

class _ObserverState extends State<_Observer> with ElScrollMixin<_Observer> {
  @override
  bool get observesScrollSessions => widget.observeSessions;
  @override
  Widget build(BuildContext context) => ElView(style: ElStyle(height: 64), child: '被动观察者');
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}

void main() {
  for (final observeSessions in <bool?>[false, true, null]) {
    testWidgets('最后一个被动观察者离屏不应取消未抬手的拖动 sessions=$observeSessions image=${observeSessions == null}', (tester) async {
      tester.view.physicalSize = Size(420, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scroll = ElScrollController();
      addTearDown(scroll.dispose);
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
        0,
        0,
        0,
        0x0d,
        0x49,
        0x48,
        0x44,
        0x52,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        0x1f,
        0x15,
        0xc4,
        0x89,
        0,
        0,
        0,
        0x0a,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9c,
        0x63,
        0,
        1,
        0,
        0,
        5,
        0,
        1,
        0x0d,
        0x0a,
        0x2d,
        0xb4,
        0,
        0,
        0,
        0,
        0x49,
        0x45,
        0x4e,
        0x44,
        0xae,
        0x42,
        0x60,
        0x82,
      ]);
      var disposed = false;
      var moves = 0;
      var terminals = 0;
      void raw(PointerEvent event) {
        if (event.pointer != 735) return;
        if (event is PointerMoveEvent) moves++;
        if (event is PointerUpEvent || event is PointerCancelEvent) terminals++;
      }

      GestureBinding.instance.pointerRouter.addGlobalRoute(raw);
      addTearDown(() => GestureBinding.instance.pointerRouter.removeGlobalRoute(raw));
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: ElScrollView(
            controller: scroll,
            cacheExtent: 0,
            physics: ElClampingScrollPhysics(),
            scrollbar: ElNoScrollBar(),
            children: [
              ElListView.builder(
                itemCount: 1000,
                fixedSize: true,
                itemBuilder: (context, index) => RepaintBoundary(
                  key: ValueKey(index),
                  child: index == 2
                      ? (observeSessions == null
                            ? ElImageView.memory(png, width: 64, height: 64)
                            : _Observer(onDispose: () => disposed = true, observeSessions: observeSessions))
                      : ElView(style: ElStyle(height: 64), child: '普通行 $index'),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: 20)));
      await tester.pump();
      var timestamp = tester.binding.currentSystemFrameTimeStamp;
      final gesture = await tester.createGesture(pointer: 735);
      await gesture.down(Offset(200, 608), timeStamp: timestamp);
      double? atDisposal;
      final samples = <double>[];
      for (var step = 0; step < 140; step++) {
        timestamp += Duration(milliseconds: 16);
        await gesture.moveBy(Offset(0, -4), timeStamp: timestamp);
        await tester.pump(Duration(milliseconds: 16));
        if (observeSessions == null && find.byType(ElImageView).evaluate().isEmpty) disposed = true;
        if (disposed) atDisposal ??= scroll.offset;
        samples.add(scroll.offset);
      }
      final beforeUp = (moves: moves, terminals: terminals, activity: scroll.position.isScrollingNotifier.value);
      final afterDisposal = scroll.offset - (atDisposal ?? scroll.offset);
      final tail = samples.last - samples[119];
      await gesture.up(timeStamp: timestamp + Duration(milliseconds: 100));
      await gesture.removePointer();
      await tester.pumpAndSettle();
      final resumeStart = scroll.offset;
      var nextTime = tester.binding.currentSystemFrameTimeStamp;
      final nextGesture = await tester.createGesture(pointer: 736);
      await nextGesture.down(Offset(200, 608), timeStamp: nextTime);
      for (var step = 0; step < 20; step++) {
        nextTime += Duration(milliseconds: 16);
        await nextGesture.moveBy(Offset(0, -4), timeStamp: nextTime);
        await tester.pump(Duration(milliseconds: 16));
      }
      final resumedDistance = scroll.offset - resumeStart;
      await nextGesture.up(timeStamp: nextTime + Duration(milliseconds: 100));
      await nextGesture.removePointer();
      await tester.pumpAndSettle();
      await tester.pumpWidget(ElView());
      debugPrint(
        'OBSERVER_UNMOUNT sessions=$observeSessions disposed=$disposed at=$atDisposal '
        'afterDisposal=$afterDisposal tail=$tail resumed=$resumedDistance raw=$beforeUp '
        'samples=${[for (var i = 0; i < samples.length; i += 10) samples[i]]}',
      );
      expect(disposed, isTrue);
      expect(beforeUp.moves, 140, reason: '真实移动必须逐条分发，观察者卸载不得终止输入');
      expect(beforeUp.terminals, 0);
      expect(resumedDistance, greaterThan(40), reason: '下一条手势同方向仍能滚，排除内容终点');
      expect(afterDisposal, greaterThan(200), reason: '观察者卸载不是手势结束，后续输入必须继续消费');
      expect(tail, greaterThan(60));
      expect(tester.takeException(), isNull);
    });
  }
}
