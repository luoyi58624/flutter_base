import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(GestureRecognizer recognizer, {Widget? child}) => Listener(
  behavior: HitTestBehavior.opaque,
  onPointerDown: recognizer.addPointer,
  child: child ?? const SizedBox(width: 200, height: 200),
);

Widget _shell(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

void main() {
  for (final stopCancel in [false, true]) {
    testWidgets('Down 内同步取消不向祖先补发孤立候选：stopCancel=$stopCancel', (tester) async {
      final trace = <String>[];
      final parent = ElPressGestureRecognizer()
        ..onTapDown = (_) {
          trace.add('parent.down');
        }
        ..onTapCancel = (_) {
          trace.add('parent.cancel');
        }
        ..onTapUp = (_) => trace.add('parent.up');
      final child = ElPressGestureRecognizer(parent: parent)
        ..onTapDown = (event) {
          trace.add('child.down');
          event.eagerGesture(cancelSelfTap: true);
        }
        ..onTapCancel = (event) {
          trace.add('child.cancel');
          if (stopCancel) event.stopPropagation();
        }
        ..onTapUp = (_) => trace.add('child.up');
      addTearDown(parent.dispose);
      addTearDown(child.dispose);
      await tester.pumpWidget(_shell(_host(parent, child: _host(child))));

      await tester.tapAt(const Offset(50, 50));
      expect(trace, ['child.down', 'child.cancel', 'child.up']);
    });
  }

  testWidgets('拖拽 Start 内销毁所有者时祖先不会在 Cancel 后又收到 Start', (tester) async {
    final trace = <String>[];
    final parent = ElTransformGestureRecognizer()
      ..onDragDown = (_) {
        trace.add('parent.down');
      }
      ..onDragStart = (_) {
        trace.add('parent.start');
      }
      ..onDragCancel = (_) => trace.add('parent.cancel');
    late ElTransformGestureRecognizer child;
    child = ElTransformGestureRecognizer(
      parent: parent,
      config: const ElEventConfig(dragStartDistance: 6),
    )..onDragStart = (_) => child.dispose();
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(_shell(_host(parent, child: _host(child))));

    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.up();
    expect(trace, ['parent.down', 'parent.cancel']);
  });

  testWidgets('订阅者坐标函数异常不会截断父回调或遗留指针路线', (tester) async {
    final trace = <String>[];
    final parent = ElPressGestureRecognizer()
      ..onTap = (_) => trace.add('parent');
    final child = ElPressGestureRecognizer(
      parent: parent,
      globalToLocal: (_) => throw StateError('坐标函数失败'),
    )..onTap = (_) => trace.add('child');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(_shell(_host(parent, child: _host(child))));

    await tester.tapAt(const Offset(50, 50));
    expect(tester.takeException(), isA<StateError>());
    expect(trace, ['parent']);

    child.globalToLocal = null;
    await tester.tapAt(const Offset(50, 50));
    expect(trace, ['parent', 'child', 'parent']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('子回调销毁委托父级后继续自身点击，父级不再收到事件', (tester) async {
    final trace = <String>[];
    final parent = ElPressGestureRecognizer()
      ..onTapDown = (_) {
        trace.add('parent.down');
      }
      ..onTap = (_) => trace.add('parent.tap');
    final child = ElPressGestureRecognizer(parent: parent)
      ..onTapDown = (_) {
        trace.add('child.down');
        parent.dispose();
      }
      ..onTap = (_) => trace.add('child.tap');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(_shell(_host(parent, child: _host(child))));

    await tester.tapAt(const Offset(50, 50));
    expect(trace, ['child.down', 'child.tap']);
  });

  testWidgets('位移消费向父传播时重新换算余量，结束回调后保留本地余量', (tester) async {
    final remaining = <Offset>[];
    ElEventCallback? last;
    final parent =
        ElTransformGestureRecognizer(
            axis: Axis.horizontal,
            globalToLocal: (position) => position * 2,
          )
          ..onDragUpdate = (event) {
            remaining.add(event.remainingLocalDelta);
            last = event;
          };
    final child = ElTransformGestureRecognizer(
      parent: parent,
      axis: Axis.horizontal,
      config: const ElEventConfig(dragStartDistance: 6),
    )..onDragUpdate = (event) => event.consumeDelta(const Offset(4, 0));
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(_shell(_host(parent, child: _host(child))));

    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.up();

    expect(remaining, [const Offset(12, 0)]);
    expect(last!.delta, const Offset(10, 0));
    expect(last!.remainingDelta, const Offset(6, 0));
    expect(last!.localDelta, const Offset(20, 0));
    expect(last!.remainingLocalDelta, const Offset(12, 0));
  });
}
