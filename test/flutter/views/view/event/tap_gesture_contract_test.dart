import 'package:flutter/gestures.dart' show kDoubleTapTimeout, kPressTimeout;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/event_widget_test_host.dart';

void main() {
  testWidgets('Flutter 连击逐次提交点击，第二次和第三次使用原生计数', (tester) async {
    final taps = <int>[];
    final sequence = <String>[];
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: ElEvent(
          config: ElEventConfig(deferTap: true, doubleTapInterval: Duration.zero),
          onTap: (event) => taps.add(event.tapCount),
          onDoubleTapDown: (event) => sequence.add('down ${event.tapCount}'),
          onDoubleTap: (event) => sequence.add('up ${event.tapCount}'),
          onTripleTapDown: (event) => sequence.add('down ${event.tapCount}'),
          onTripleTap: (event) => sequence.add('up ${event.tapCount}'),
        ),
      ),
    );
    for (var i = 1; i <= 4; i++) {
      await tester.tapAt(Offset(20, 20));
      expect(taps.last, i);
      await tester.pump(Duration(milliseconds: 60));
    }
    expect(taps, [1, 2, 3, 4]);
    expect(sequence, ['down 2', 'up 2', 'down 3', 'up 3']);
    await tester.pump(kDoubleTapTimeout);
    await tester.tapAt(Offset(20, 20));
    expect(taps.last, 1);
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('长按由 Flutter 赢得手势，业务默认动作标记可沿祖先传递', (tester) async {
    final phases = <String>[];
    await pumpEventView(
      tester,
      ElView(
        style: eventTestDefaultStyle,
        event: ElEvent(
          onLongPress: (event) {
            expect(event.defaultPrevented, isTrue);
            phases.add('parent longPress');
          },
          onTap: (_) => phases.add('parent tap'),
        ),
        child: ElView(
          style: eventTestDefaultStyle,
          event: ElEvent(
            config: ElEventConfig(longPressDelay: Duration(milliseconds: 180)),
            onLongPress: (event) {
              event.preventDefault();
              phases.add('child longPress');
            },
            onTapDown: (_) => phases.add('child tapDown'),
            onTapCancel: (_) => phases.add('child tapCancel'),
            onTapUp: (_) => phases.add('child tapUp'),
            onTap: (_) => phases.add('child tap'),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(Offset(20, 20));
    await tester.pump(kPressTimeout);
    expect(phases, ['child tapDown']);
    await tester.pump(Duration(milliseconds: 100));
    await gesture.up();
    expect(phases, ['child tapDown', 'child tapCancel', 'child longPress', 'parent longPress']);
  });

  testWidgets('纯样式按压反馈不占用 Flutter 点击席位', (tester) async {
    var taps = 0;
    await pumpEventView(
      tester,
      GestureDetector(
        onTap: () => taps++,
        child: ElView(
          style: eventTestDefaultStyle.merge(ElStyle(onTap: ElStyle(opacity: 0.8))),
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );
    final view = find.byType(ElView);
    final gesture = await tester.startGesture(tester.getCenter(view));
    expect(EventDispatcher.of(tester.renderObject(view))!.isTapPressed, isTrue);
    await gesture.up();
    expect(taps, 1);
    expect(EventDispatcher.of(tester.renderObject(view))!.isTapPressed, isFalse);
  });
}
