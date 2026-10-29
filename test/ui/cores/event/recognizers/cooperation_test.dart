import 'package:flutter_base/src/ui/cores/view/event/press.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recognizer_test_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(GestureTeam.debugReset);

  testWidgets('两个已接受触点原子独占，全部资格提交后才通知取消', (tester) async {
    final pair = _pair();
    addTearDown(() => _disposePair(pair));
    _start(PointerDownEvent(pointer: 1800), pair);
    _start(PointerDownEvent(pointer: 1801, position: Offset(20, 0)), pair);
    await tester.pump();
    expect(pair.owner.canClaimPointers([1800, 1801]), isTrue);
    expect(pair.other.pointerCount, 2);
    expect(pair.raw, isEmpty);
    expect(pair.typed, isEmpty);

    expect(pair.owner.claimPointers([1800, 1801]), isTrue);
    expect(pair.owner.pointerCount, 2);
    expect(pair.other.pointerCount, 0);
    expect(pair.raw, ['other:1800', 'other:1801']);
    expect(pair.typed, ['other.dragCancel']);
    expect(pair.other.canClaimPointers([1800, 1801]), isFalse);
    _input(PointerUpEvent(pointer: 1801), pair);
    _input(PointerUpEvent(pointer: 1800), pair);
    await tester.pump();
  });

  testWidgets('多指请求中缺少任一触点时零提交且不改变取消计数', (tester) async {
    final pair = _pair();
    addTearDown(() => _disposePair(pair));
    _start(PointerDownEvent(pointer: 1802), pair);
    await tester.pump();
    expect(pair.owner.canClaimPointers([1802]), isTrue);
    final counts = (pair.owner.pointerCount, pair.other.pointerCount);
    final raw = [...pair.raw];
    final typed = [...pair.typed];

    expect(pair.owner.claimPointers([1802, 99999]), isFalse);
    expect((pair.owner.pointerCount, pair.other.pointerCount), counts);
    expect(pair.raw, raw);
    expect(pair.typed, typed);
    expect(pair.other.hasActiveInput, isTrue);
    _input(PointerUpEvent(pointer: 1802), pair);
    await tester.pump();
  });

  testWidgets('多指请求包含已被官方拒绝触点时零提交，原触点继续有效', (tester) async {
    final pair = _pair();
    final official = EagerGestureRecognizer();
    addTearDown(() => _disposePair(pair));
    addTearDown(official.dispose);
    _start(PointerDownEvent(pointer: 1803), pair);
    await tester.pump();
    final rejected = PointerDownEvent(pointer: 1804, position: Offset(20, 0));
    official.addPointer(rejected);
    _start(rejected, pair);
    await tester.pump();
    expect(pair.owner.canClaimPointers([1803]), isTrue);
    expect(pair.owner.canClaimPointers([1804]), isFalse);
    final counts = (pair.owner.pointerCount, pair.other.pointerCount);
    final raw = [...pair.raw];
    final typed = [...pair.typed];

    expect(pair.owner.claimPointers([1803, 1804]), isFalse);
    expect((pair.owner.pointerCount, pair.other.pointerCount), counts);
    expect(pair.raw, raw);
    expect(pair.typed, typed);
    expect(pair.other.hasActiveInput, isTrue);
    _input(PointerUpEvent(pointer: 1804), pair);
    _input(PointerUpEvent(pointer: 1803), pair);
    await tester.pump();
  });

  testWidgets('取消回调重入时两根触点已经同时失权，不会部分抢回', (tester) async {
    final pair = _pair();
    addTearDown(() => _disposePair(pair));
    final snapshots = <(int, bool, bool)>[];
    pair.other.onPointerEvent = (event, _) {
      if (event is PointerCancelEvent) {
        pair.raw.add('other:${event.pointer}');
        snapshots.add((
          pair.other.pointerCount,
          pair.other.canClaimPointers([1805, 1806]),
          pair.owner.canClaimPointers([1805, 1806]),
        ));
        pair.other.claimPointer(event.pointer == 1805 ? 1806 : 1805);
        pair.other.cancel();
      }
      return true;
    };
    _start(PointerDownEvent(pointer: 1805), pair);
    _start(PointerDownEvent(pointer: 1806, position: Offset(20, 0)), pair);
    await tester.pump();

    expect(pair.owner.claimPointers([1805, 1806]), isTrue);
    expect(snapshots, [(0, false, true), (0, false, true)]);
    expect(pair.raw, ['other:1805', 'other:1806']);
    expect(pair.typed, ['other.dragCancel']);
    expect(pair.owner.pointerCount, 2);
    _input(PointerUpEvent(pointer: 1806), pair);
    _input(PointerUpEvent(pointer: 1805), pair);
    await tester.pump();
  });

  for (final prevent in [false, true]) {
    testWidgets('ScaleStart 整条路线处理后才执行默认动作：prevent=$prevent', (tester) async {
      final trace = <String>[];
      final parent = TransformRecognizer()
        ..callbacks[.scaleStart] = (details) {
          trace.add('parent.start');
          if (prevent) details.preventDefault();
        };
      final child = TransformRecognizer()
        ..parent = parent
        ..callbacks[.scaleStart] = ((_) => trace.add('child.start'))
        ..onScaleStartDefault = (_) => trace.add('default');
      addTearDown(child.dispose);
      addTearDown(parent.dispose);
      final first = TestPointer(1807);
      final second = TestPointer(1808);
      _recognizerDown(first.down(Offset.zero), [child, parent]);
      _recognizerDown(second.down(Offset(100, 0)), [child, parent]);
      _route(second.move(Offset(150, 0)));
      expect(trace, ['child.start', 'parent.start', if (!prevent) 'default']);
      _route(second.up());
      _route(first.up());
    });
  }

  testWidgets('Scale 起手预检失败时不能先取消现有 Drag', (tester) async {
    final trace = <String>[];
    var checks = 0;
    final recognizer = TransformRecognizer()
      ..startDistance = 2
      ..cancelDragOnScale = true
      ..canStartScale = (_) {
        checks++;
        return false;
      }
      ..callbacks[.dragStart] = ((_) => trace.add('drag.start'))
      ..callbacks[.dragUpdate] = ((_) => trace.add('drag.update'))
      ..callbacks[.dragEnd] = ((_) => trace.add('drag.end'))
      ..callbacks[.dragCancel] = ((_) => trace.add('drag.cancel'))
      ..callbacks[.scaleStart] = ((_) => trace.add('scale.start'))
      ..onScaleStartDefault = (_) => trace.add('default');
    addTearDown(recognizer.dispose);
    final first = TestPointer(1809);
    final second = TestPointer(1810);
    _recognizerDown(first.down(Offset.zero), [recognizer]);
    _route(first.move(Offset(10, 0)));
    _recognizerDown(second.down(Offset(30, 0)), [recognizer]);
    _route(second.move(Offset(60, 0)));
    expect(checks, greaterThan(0));
    expect(trace, ['drag.start', 'drag.update']);
    _route(second.up());
    _route(first.up());
    expect(trace, ['drag.start', 'drag.update', 'drag.end']);
  });

  for (final eager in [false, true]) {
    testWidgets('低阈值祖先起拖前先由高阈值后代提案拦截：eager=$eager', (tester) async {
      final parentTeam = GestureTeam()..matchParentGestures = true;
      final childTeam = GestureTeam()
        ..parent = parentTeam
        ..matchParentGestures = true;
      final trace = <String>[];
      final parent = TransformRecognizer()
        ..team = parentTeam
        ..axis = Axis.vertical
        ..startDistance = 0
        ..callbacks[.dragStart] = ((_) => trace.add('parent.start'))
        ..callbacks[.dragUpdate] = ((_) => trace.add('parent.update'))
        ..callbacks[.dragEnd] = (_) => trace.add('parent.end');
      final child = TransformRecognizer()
        ..team = childTeam
        ..parent = parent
        ..startDistance = 20
        ..callbacks[.dragStart] = (details) {
          trace.add('child.proposal');
          if (eager) {
            childTeam.claimPointer(details.pointer);
          } else {
            details.stopPropagation();
          }
        }
        ..callbacks[.dragEnd] = ((_) => trace.add('child.end'))
        ..callbacks[.dragCancel] = (_) => trace.add('child.cancel');
      addTearDown(child.dispose);
      addTearDown(parent.dispose);
      addTearDown(childTeam.dispose);
      addTearDown(parentTeam.dispose);
      final down = PointerDownEvent(pointer: 1811);
      childTeam.observePointer(down);
      parentTeam.observePointer(down);
      _recognizerDown(down, [child, parent]);
      final move = PointerMoveEvent(
        pointer: 1811,
        position: Offset(0, 10),
        delta: Offset(0, 10),
        buttons: kPrimaryButton,
      );
      childTeam.observePointer(move);
      parentTeam.observePointer(move);
      _route(move);
      expect(trace, ['child.proposal'], reason: '后代尚未过20px，但祖先公开Start前必须先允许后代截断');
      final up = PointerUpEvent(pointer: 1811, position: Offset(0, 10));
      childTeam.observePointer(up);
      parentTeam.observePointer(up);
      _route(up);
      expect(trace.where((value) => value.startsWith('parent.')), isEmpty);
      expect(trace.where((value) => value == 'child.end' || value == 'child.cancel'), hasLength(1));
      await tester.pump();
    });
  }

  testWidgets('被动祖先 Drag 不隐式取消同路线 Press 的释放和点击', (tester) async {
    final parentTeam = GestureTeam();
    final childTeam = GestureTeam()..parent = parentTeam;
    final trace = <String>[];
    final press = PressRecognizer()
      ..team = childTeam
      ..tapSlopTolerance = double.infinity
      ..callbacks[.tapDown] = ((_) => trace.add('down'))
      ..callbacks[.tapUp] = ((_) => trace.add('up'))
      ..callbacks[.tap] = ((_) => trace.add('tap'))
      ..callbacks[.tapCancel] = (_) => trace.add('cancel');
    final drag = TransformRecognizer()
      ..team = parentTeam
      ..startDistance = 2
      ..callbacks[.dragStart] = ((_) => trace.add('drag.start'))
      ..callbacks[.dragUpdate] = ((_) => trace.add('drag.update'))
      ..callbacks[.dragEnd] = (_) => trace.add('drag.end');
    addTearDown(press.dispose);
    addTearDown(drag.dispose);
    addTearDown(childTeam.dispose);
    addTearDown(parentTeam.dispose);
    final pointer = TestPointer(1812);
    final down = pointer.down(Offset.zero);
    childTeam.observePointer(down);
    parentTeam.observePointer(down);
    _recognizerDown(down, [press, drag]);
    for (final x in [10.0, 20.0]) {
      final move = pointer.move(Offset(x, 0));
      childTeam.observePointer(move);
      parentTeam.observePointer(move);
      _route(move);
    }
    final up = pointer.up();
    childTeam.observePointer(up);
    parentTeam.observePointer(up);
    _route(up);
    await tester.pump(afterGesture);
    expect(trace.where((value) => value == 'cancel'), isEmpty);
    for (final phase in ['down', 'up', 'tap', 'drag.start', 'drag.update', 'drag.end']) {
      expect(trace.where((value) => value == phase), hasLength(1));
    }
  });

  testWidgets('移除最深所有者后存活祖先继续同次拖拽且只有唯一终态', (tester) async {
    final trace = <String>[];
    final parent = recordingDrag(trace, 'parent', distance: 2);
    final child = recordingDrag(trace, 'child', parent: parent, distance: 2);
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    await tester.pumpWidget(gestureShell(gestureHost(parent, child: gestureHost(child))));
    final pointer = await tester.startGesture(Offset(50, 50));
    await pointer.moveBy(Offset(10, 0));
    expect(trace.where((value) => value == 'parent.start'), hasLength(1));
    expect(trace.where((value) => value == 'child.start'), hasLength(1));
    await tester.pumpWidget(gestureShell(gestureHost(parent)));
    child.dispose();
    expect(trace.where((value) => value == 'child.cancel'), hasLength(1));
    expect(trace.where((value) => value == 'parent.cancel'), isEmpty);
    await pointer.moveBy(Offset(12, 0));
    await pointer.up();
    expect(trace.where((value) => value == 'parent.update'), hasLength(1));
    expect(trace.where((value) => value == 'parent.end'), hasLength(1));
    expect(trace.where((value) => value == 'parent.start'), hasLength(1));
    expect(trace.where((value) => value == 'parent.cancel'), isEmpty);
    expect(parent.hasActiveInput, isFalse);
  });
}

typedef _Pair = ({
  GestureTeam owner,
  GestureTeam other,
  TransformRecognizer child,
  TransformRecognizer parent,
  List<String> raw,
  List<String> typed,
});

_Pair _pair() {
  final raw = <String>[];
  final typed = <String>[];
  final other = GestureTeam()
    ..onPointerEvent = (event, _) {
      if (event is PointerCancelEvent) raw.add('other:${event.pointer}');
      return true;
    };
  final owner = GestureTeam()
    ..parent = other
    ..onPointerEvent = (event, _) {
      if (event is PointerCancelEvent) raw.add('owner:${event.pointer}');
      return true;
    };
  final parent = TransformRecognizer()
    ..team = other
    ..callbacks[.dragDown] = (_) {}
    ..callbacks[.dragCancel] = (_) => typed.add('other.dragCancel');
  final child = TransformRecognizer()
    ..team = owner
    ..parent = parent
    ..callbacks[.dragDown] = (_) {}
    ..callbacks[.dragCancel] = (_) => typed.add('owner.dragCancel');
  return (owner: owner, other: other, child: child, parent: parent, raw: raw, typed: typed);
}

void _disposePair(_Pair pair) {
  pair.child.dispose();
  pair.parent.dispose();
  pair.owner.dispose();
  pair.other.dispose();
}

void _start(PointerDownEvent event, _Pair pair) {
  pair.owner.observePointer(event);
  pair.other.observePointer(event);
  _recognizerDown(event, [pair.child, pair.parent]);
}

void _input(PointerEvent event, _Pair pair) {
  pair.owner.observePointer(event);
  pair.other.observePointer(event);
  _route(event);
}

void _recognizerDown(PointerDownEvent event, List<GestureRecognizer> recognizers) {
  for (final recognizer in recognizers) {
    recognizer.addPointer(event);
  }
  GestureBinding.instance.gestureArena.close(event.pointer);
  _route(event);
}

void _route(PointerEvent event) {
  GestureBinding.instance.pointerRouter.route(event);
  if (event is PointerUpEvent || event is PointerPanZoomEndEvent) {
    GestureBinding.instance.gestureArena.sweep(event.pointer);
  }
}
