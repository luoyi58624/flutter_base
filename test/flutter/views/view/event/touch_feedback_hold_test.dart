import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

void main() {
  DispatcherTestHost host({ElEventConfig? config, ElEventHandler? onTap, ElEventHandler? onTapUp}) {
    final result = DispatcherTestHost.chain();
    addTearDown(result.dispose);
    result.leafDispatcher.event = ElEvent(config: config, onTap: onTap ?? (_) {}, onTapUp: onTapUp);
    return result;
  }

  testWidgets('轻触从按下补足 100ms，Tap 和 TapUp 在抬手时执行且指针跟踪结束', (tester) async {
    var taps = 0, ups = 0;
    final target = host(onTap: (_) => taps++, onTapUp: (_) => ups++);
    final dispatcher = target.leafDispatcher;
    target.dispatch(PointerDownEvent(pointer: 1));
    expect(dispatcher.isTapPressed, isTrue);
    await tester.pump(Duration(milliseconds: 20));
    target.dispatch(PointerUpEvent(pointer: 1));
    expect(taps, 1);
    expect(ups, 1);
    expect(dispatcher.hasActivePointerSequence, isFalse);
    expect(dispatcher.isTapPressed, isTrue);
    await tester.pump(Duration(milliseconds: 79));
    expect(dispatcher.isTapPressed, isTrue);
    await tester.pump(Duration(milliseconds: 1));
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('按住超过最短反馈时间后抬起立即恢复', (tester) async {
    final target = host();
    target.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 150));
    expect(target.leafDispatcher.isTapPressed, isTrue);
    target.dispatch(PointerUpEvent(pointer: 1));
    expect(target.leafDispatcher.isTapPressed, isFalse);
  });

  testWidgets('按下等待与最短反馈共用最初按下时刻，没有拖拽也遵循配置', (tester) async {
    var taps = 0;
    final target = host(
      config: ElEventConfig(delayTouchDown: Duration(milliseconds: 40), delayTouchUp: Duration(milliseconds: 100)),
      onTap: (_) => taps++,
    );
    target.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 39));
    expect(target.leafDispatcher.isTapPressed, isFalse);
    await tester.pump(Duration(milliseconds: 1));
    expect(target.leafDispatcher.isTapPressed, isTrue);
    await tester.pump(Duration(milliseconds: 10));
    target.dispatch(PointerUpEvent(pointer: 1));
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 49));
    expect(target.leafDispatcher.isTapPressed, isTrue);
    await tester.pump(Duration(milliseconds: 1));
    expect(target.leafDispatcher.isTapPressed, isFalse);
  });

  testWidgets('未达到按下延迟的轻触不在抬手后补播', (tester) async {
    var taps = 0;
    final target = host(
      config: ElEventConfig(delayTouchDown: Duration(milliseconds: 40)),
      onTap: (_) => taps++,
    );
    final changes = <bool>[];
    target.leafDispatcher.onTapChanged = changes.add;
    target.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 20));
    target.dispatch(PointerUpEvent(pointer: 1));
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 200));
    expect(changes, isEmpty);
  });

  testWidgets('连续轻触会取消旧计时，并从第二次按下重新计算', (tester) async {
    var taps = 0;
    final target = host(onTap: (_) => taps++);
    target.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 20));
    target.dispatch(PointerUpEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 30));
    target.dispatch(PointerDownEvent(pointer: 2));
    await tester.pump(Duration(milliseconds: 20));
    target.dispatch(PointerUpEvent(pointer: 2));
    await tester.pump(Duration(milliseconds: 30));
    expect(target.leafDispatcher.isTapPressed, isTrue, reason: '第一次反馈的截止时刻不能清理第二次反馈');
    await tester.pump(Duration(milliseconds: 49));
    expect(target.leafDispatcher.isTapPressed, isTrue);
    await tester.pump(Duration(milliseconds: 1));
    expect(target.leafDispatcher.isTapPressed, isFalse);
    expect(taps, 2);
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus]) {
    testWidgets('$kind 不使用触摸的进入延迟或抬手保留', (tester) async {
      final target = host(
        config: ElEventConfig(delayTouchDown: Duration(milliseconds: 50), delayTouchUp: Duration(milliseconds: 200)),
      );
      target.dispatch(PointerDownEvent(pointer: 1, kind: kind));
      expect(target.leafDispatcher.isTapPressed, isTrue);
      target.dispatch(PointerUpEvent(pointer: 1, kind: kind));
      expect(target.leafDispatcher.isTapPressed, isFalse);
    });
  }

  for (final released in [false, true]) {
    for (final terminal in ['cancel', 'disable', 'removeEvent', 'detach', 'dispose']) {
      testWidgets('$terminal 立即清理${released ? '已抬起保留' : '按住'}的反馈且没有迟到回调', (tester) async {
        final target = host();
        final dispatcher = target.leafDispatcher;
        target.dispatch(PointerDownEvent(pointer: 1));
        await tester.pump(Duration(milliseconds: 20));
        if (released) target.dispatch(PointerUpEvent(pointer: 1));
        expect(dispatcher.isTapPressed, isTrue);
        switch (terminal) {
          case 'cancel':
            dispatcher.cancelAllPendingAtLastPosition();
          case 'disable':
            dispatcher.event = dispatcher.event!.copyWith(disabled: true);
          case 'removeEvent':
            dispatcher.event = null;
          case 'detach':
            dispatcher.detach();
          case 'dispose':
            dispatcher.dispose();
        }
        expect(dispatcher.isTapPressed, isFalse);
        await tester.pump(Duration(milliseconds: 200));
        expect(dispatcher.isTapPressed, isFalse);
      });
    }
  }

  testWidgets('抬手坐标越界时立即熄灭，不补足反馈也不触发 Tap', (tester) async {
    var taps = 0;
    final target = host(onTap: (_) => taps++);
    target.leafDispatcher.hitBoundsContainsGlobal = (position) => position.dx < 50;
    target.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 20));
    target.dispatch(PointerUpEvent(pointer: 1, position: Offset(80, 0)));
    expect(target.leafDispatcher.isTapPressed, isFalse);
    expect(taps, 0);
  });

  testWidgets('临时移出后移回仍按最初按下时刻补足', (tester) async {
    final target = host();
    target.leafDispatcher.hitBoundsContainsGlobal = (position) => position.dx < 50;
    target.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 20));
    target.dispatch(PointerMoveEvent(pointer: 1, position: Offset(80, 0), delta: Offset(80, 0)));
    expect(target.leafDispatcher.isTapPressed, isFalse);
    await tester.pump(Duration(milliseconds: 20));
    target.dispatch(PointerMoveEvent(pointer: 1, position: Offset.zero, delta: Offset(-80, 0)));
    target.dispatch(PointerUpEvent(pointer: 1));
    expect(target.leafDispatcher.isTapPressed, isTrue);
    await tester.pump(Duration(milliseconds: 60));
    expect(target.leafDispatcher.isTapPressed, isFalse);
  });

  testWidgets('配置更新作用于下一次按下，不打断已保留的反馈', (tester) async {
    final target = host();
    final dispatcher = target.leafDispatcher;
    target.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 20));
    target.dispatch(PointerUpEvent(pointer: 1));
    dispatcher.event = dispatcher.event!.copyWith(config: ElEventConfig(delayTouchUp: Duration(milliseconds: 200)));
    await tester.pump(Duration(milliseconds: 80));
    expect(dispatcher.isTapPressed, isFalse);
    target.dispatch(PointerDownEvent(pointer: 2));
    target.dispatch(PointerUpEvent(pointer: 2));
    await tester.pump(Duration(milliseconds: 199));
    expect(dispatcher.isTapPressed, isTrue);
    await tester.pump(Duration(milliseconds: 1));
    expect(dispatcher.isTapPressed, isFalse);
  });

  testWidgets('纯 onTap 样式无需事件声明也能保留轻触，滚动接管立即清理', (tester) async {
    final key = UniqueKey();
    await pumpEventView(
      tester,
      ElView(
        style: ElStyle(width: 200, height: 200),
        child: ElScrollView(
          children: [
            ElView(
              key: key,
              style: ElStyle(
                width: 200,
                height: 600,
                backgroundColor: Color(0xff00ff00),
                onTap: ElStyle(backgroundColor: Color(0xffff0000)),
              ),
            ),
          ],
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final first = await tester.startGesture(Offset(50, 100));
    await tester.pump(Duration(milliseconds: 20));
    await first.up();
    await tester.pump();
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xffff0000));
    await tester.pump(Duration(milliseconds: 80));
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff00ff00));
    final second = await tester.startGesture(Offset(50, 100));
    await tester.pump(Duration(milliseconds: 10));
    await second.moveBy(Offset(0, -60));
    await second.moveBy(Offset(0, -30));
    await tester.pump();
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff00ff00));
    await second.cancel();
    await tester.pumpAndSettle();
  });
}
