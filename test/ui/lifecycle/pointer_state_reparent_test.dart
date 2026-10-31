import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import '../support/reparent.dart';

/// 按压 / 点击 / 长按都是指针状态，重挂（临时离树再回来）不得把它们打断，
/// 只有元素真销毁时才取消。
void main() {
  Widget host(Widget child) => lifecycleHost(Align(alignment: Alignment.topLeft, child: child));

  Widget target({required ElEvent event, Key? key}) => ElView(
    key: key,
    event: event,
    style: const ElStyle(
      width: 100,
      height: 40,
      backgroundColor: Color(0xFFEFF6FF),
      onTap: ElStyle(backgroundColor: Color(0xFFBFDBFE)),
    ),
  );

  EventDispatcher? dispatcherOf(WidgetTester tester, Key key) =>
      EventDispatcher.of(tester.renderObject(find.byKey(key)) as RenderBox);

  testWidgets('按压状态跨重挂不熄灭', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final key = UniqueKey();
    await tester.pumpWidget(
      host(
        ReparentHarness(
          key: move,
          child: target(
            key: key,
            event: ElEvent(onTap: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(dispatcherOf(tester, key)?.isTapPressed, isFalse);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)), kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 200));
    expect(dispatcherOf(tester, key)?.isTapPressed, isTrue, reason: '按下后应进入按压态');

    await reparent(tester, move, settle: false);
    await tester.pump();
    expect(dispatcherOf(tester, key)?.isTapPressed, isTrue, reason: '重挂不是手势结束，按压态必须保留');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(dispatcherOf(tester, key)?.isTapPressed, isFalse, reason: '抬手后才退出按压态');
  });

  testWidgets('点击跨重挂正常完成', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final key = UniqueKey();
    var taps = 0;
    await tester.pumpWidget(
      host(
        ReparentHarness(
          key: move,
          child: target(
            key: key,
            event: ElEvent(onTap: (_) => taps++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)), kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await reparent(tester, move, settle: false);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1, reason: '重挂不是抬手，down 仍必须能走到 up 并完成点击');
  });

  testWidgets('长按跨重挂仍然触发', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final key = UniqueKey();
    var longs = 0;
    await tester.pumpWidget(
      host(
        ReparentHarness(
          key: move,
          child: target(
            key: key,
            event: ElEvent(onLongPress: (_) => longs++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)), kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await reparent(tester, move, settle: false);
    await tester.pump(const Duration(milliseconds: 800));
    expect(longs, 1, reason: '重挂不得取消长按计时，越过阈值必须触发');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
