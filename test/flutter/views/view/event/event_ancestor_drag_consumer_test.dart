import 'package:flutter/gestures.dart';
import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

PointerDownEvent _down(int pointer) =>
    PointerDownEvent(pointer: pointer, position: Offset(20, 20), buttons: kPrimaryButton);

PointerMoveEvent _move(int pointer, double x) => PointerMoveEvent(
  pointer: pointer,
  position: Offset(x, 20),
  delta: Offset(4, 0),
  buttons: kPrimaryButton,
  timeStamp: Duration(milliseconds: x.toInt()),
);

void _end(DispatcherTestHost host, int pointer) =>
    host.dispatch(PointerUpEvent(pointer: pointer, position: Offset(28, 20)));

void main() {
  setUp(EventDispatcher.debugReset);

  testWidgets('顶层拖拽没有祖先消费者，旧详情不会借用复用编号的新路线', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    ElEventDetails? previous;
    host.leafDispatcher.event = ElEvent(dragStartDistance: 3, onHorizontalDragStart: (event) => previous = event);
    host.dispatch(_down(1));
    host.dispatch(_move(1, 24));
    expect(previous!.hasAncestorDragConsumer, isFalse);
    _end(host, 1);

    host.rootDispatcher.event = ElEvent(onHorizontalDragStart: (_) {});
    host.leafDispatcher.event = ElEvent(dragStartDistance: 3, onHorizontalDragStart: (_) {});
    host.dispatch(_down(1));
    host.dispatch(_move(1, 24));
    expect(previous!.hasAncestorDragConsumer, isFalse);
    _end(host, 1);
  });

  testWidgets('普通嵌套只报告同轴或自由拖拽祖先，只有DragDown不算消费者', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final answers = <bool>[];
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onHorizontalDragStart: (event) => answers.add(event.hasAncestorDragConsumer),
      onHorizontalDragUpdate: (event) => answers.add(event.hasAncestorDragConsumer),
    );
    final parents = [
      ElEvent(onHorizontalDragStart: (_) {}),
      ElEvent(onDragStart: (_) {}),
      ElEvent(onVerticalDragStart: (_) {}),
      ElEvent(onDragDown: (_) {}),
      ElEvent(disabled: true, onHorizontalDragStart: (_) {}),
    ];
    for (var i = 0; i < parents.length; i++) {
      host.rootDispatcher.event = parents[i];
      host.dispatch(_down(i + 2));
      host.dispatch(_move(i + 2, 24));
      host.dispatch(_move(i + 2, 28));
      _end(host, i + 2);
    }
    expect(answers, [true, true, true, true, false, false, false, false, false, false]);
  });

  testWidgets('DragStart截断后的祖先已退出本次拖拽，后续查询不再报告', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final answers = <bool>[];
    var parentStarts = 0;
    host.rootDispatcher.event = ElEvent(onHorizontalDragStart: (_) => parentStarts++);
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onHorizontalDragStart: (event) {
        answers.add(event.hasAncestorDragConsumer);
        event.stopPropagation();
      },
      onHorizontalDragUpdate: (event) => answers.add(event.hasAncestorDragConsumer),
    );
    host.dispatch(_down(8));
    host.dispatch(_move(8, 24));
    host.dispatch(_move(8, 28));
    _end(host, 8);
    expect(answers, [true, false]);
    expect(parentStarts, 0);
  });

  testWidgets('显式认领立即排除失权祖先，保留Scale升级也不保留Drag资格', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    final answers = <bool>[];
    host.rootDispatcher.event = ElEvent(onHorizontalDragStart: (_) {}, onScaleStart: (_) {});
    host.leafDispatcher.event = ElEvent(
      dragStartDistance: 3,
      onHorizontalDragStart: (event) {
        answers.add(event.hasAncestorDragConsumer);
        event.eagerGesture(allowScaleUpgrade: true);
        answers.add(event.hasAncestorDragConsumer);
      },
      onHorizontalDragUpdate: (event) => answers.add(event.hasAncestorDragConsumer),
    );
    host.dispatch(_down(9));
    host.dispatch(_move(9, 24));
    host.dispatch(_move(9, 28));
    _end(host, 9);
    expect(answers, [true, false, false]);
  });
}
