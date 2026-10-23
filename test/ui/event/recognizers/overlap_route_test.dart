import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _overlap({
  required GestureRecognizer parent,
  required GestureRecognizer back,
  required GestureRecognizer front,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: parent.addPointer,
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 子树本身不命中，让 Stack 将同一指针送到前后两个透明分支。
            for (final recognizer in [back, front])
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: recognizer.addPointer,
                child: const SizedBox.expand(),
              ),
          ],
        ),
      ),
    ),
  ),
);

ElPressGestureRecognizer _press(
  List<String> events,
  String name, {
  ElPressGestureRecognizer? parent,
}) {
  final recognizer = ElPressGestureRecognizer(parent: parent);
  recognizer.onTapDown = (_) => events.add('$name.down');
  recognizer.onTapUp = (_) => events.add('$name.up');
  recognizer.onTap = (_) => events.add('$name.tap');
  recognizer.onTapCancel = (_) => events.add('$name.cancel');
  return recognizer;
}

ElTransformGestureRecognizer _drag(
  List<String> events,
  String name, {
  ElTransformGestureRecognizer? parent,
}) {
  final recognizer = ElTransformGestureRecognizer(
    parent: parent,
    axis: Axis.horizontal,
    config: const ElEventConfig(dragStartDistance: 6),
  );
  recognizer.onDragDown = (_) => events.add('$name.down');
  recognizer.onDragStart = (_) => events.add('$name.start');
  recognizer.onDragUpdate = (_) => events.add('$name.update');
  recognizer.onDragEnd = (_) => events.add('$name.end');
  recognizer.onDragCancel = (_) => events.add('$name.cancel');
  return recognizer;
}

void main() {
  testWidgets('透明重叠点击分支分别参赛，共享 El 父只订阅首次命中的路线', (tester) async {
    final events = <String>[];
    final parent = _press(events, 'parent');
    final back = _press(events, 'back', parent: parent);
    final front = _press(events, 'front', parent: parent);
    addTearDown(parent.dispose);
    addTearDown(back.dispose);
    addTearDown(front.dispose);
    await tester.pumpWidget(
      GestureDetector(
        onTapDown: (_) => events.add('official.down'),
        onTap: () => events.add('official.tap'),
        onTapCancel: () => events.add('official.cancel'),
        child: _overlap(parent: parent, back: back, front: front),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    // 两个分支都必须收到 Down，保证没有误将测试简化成单一命中。
    expect(
      events,
      containsAllInOrder(['front.down', 'parent.down', 'back.down']),
    );
    expect(events.where((event) => event.startsWith('front.')), [
      'front.down',
      'front.up',
      'front.tap',
    ]);
    expect(events.where((event) => event.startsWith('back.')), [
      'back.down',
      'back.cancel',
    ]);
    expect(events.where((event) => event.startsWith('parent.')), [
      'parent.down',
      'parent.up',
      'parent.tap',
    ]);
    expect(events.where((event) => event.startsWith('official.')), [
      'official.down',
      'official.cancel',
    ]);
  });

  testWidgets('透明重叠拖拽失败分支不向共享 El 父泄漏取消', (tester) async {
    final events = <String>[];
    final parent = _drag(events, 'parent');
    final back = _drag(events, 'back', parent: parent);
    final front = _drag(events, 'front', parent: parent);
    addTearDown(parent.dispose);
    addTearDown(back.dispose);
    addTearDown(front.dispose);
    await tester.pumpWidget(
      GestureDetector(
        onHorizontalDragDown: (_) => events.add('official.down'),
        onHorizontalDragStart: (_) => events.add('official.start'),
        onHorizontalDragCancel: () => events.add('official.cancel'),
        child: _overlap(parent: parent, back: back, front: front),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.moveBy(const Offset(14, 0));
    await gesture.up();
    await tester.pump();

    expect(
      events,
      containsAllInOrder(['front.down', 'parent.down', 'back.down']),
    );
    expect(events.where((event) => event.startsWith('front.')), [
      'front.down',
      'front.start',
      'front.update',
      'front.end',
    ]);
    expect(events.where((event) => event.startsWith('back.')), [
      'back.down',
      'back.cancel',
    ]);
    expect(events.where((event) => event.startsWith('parent.')), [
      'parent.down',
      'parent.start',
      'parent.update',
      'parent.end',
    ]);
    expect(events.where((event) => event.startsWith('official.')), [
      'official.down',
      'official.cancel',
    ]);
  });
}
