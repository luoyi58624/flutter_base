import 'package:flutter_base/src/ui/cores/view/event/press.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('统一阶段保持拖拽家族连续、常量身份和类型名称', () {
    expect(identical(ElEventPhase.tap, ElEventPhase.tap), isTrue);
    expect(ElEventPhase.values, hasLength(47));
    expect(ElEventPhase.values.sublist(ElEventPhase.dragDown.index, ElEventPhase.dragCancel.index + 1), [
      ElEventPhase.dragDown,
      ElEventPhase.dragStart,
      ElEventPhase.dragUpdate,
      ElEventPhase.dragEnd,
      ElEventPhase.dragCancel,
    ]);
    expect(ElEventPhase.tap.toString(), 'ElEventPhase.tap');
  });

  test('同阶段控制共享传播和默认动作，下一阶段使用独立状态', () {
    final source = GestureControl();
    final target = GestureControl(source: source);
    target.preventDefault();
    source.stopPropagation();
    expect(source.defaultPrevented, isTrue);
    expect(target.propagationStopped, isTrue);
    expect(GestureControl().defaultPrevented, isFalse);
  });

  testWidgets('原始Down在各宿主共享默认动作标记，不污染下一次Move', (tester) async {
    final flags = <bool>[];
    final child = GestureTeam();
    final parent = GestureTeam();
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    child.onPointerEvent = (event, _) {
      if (event is PointerDownEvent) child.currentPointerDetails!.preventDefault();
      return true;
    };
    parent.onPointerEvent = (_, _) {
      flags.add(parent.currentPointerDetails!.defaultPrevented);
      return true;
    };
    final down = PointerDownEvent(pointer: 8001);
    child.observePointer(down);
    parent.observePointer(down);
    final move = PointerMoveEvent(pointer: 8001);
    child.observePointer(move);
    parent.observePointer(move);
    expect(flags, [true, false]);
    child.observePointer(PointerUpEvent(pointer: 8001));
    parent.observePointer(PointerUpEvent(pointer: 8001));
    await tester.pump();
  });

  testWidgets('原始Move的stop只截断当前输入，后续帧正常投递', (tester) async {
    var moves = 0;
    final child = GestureTeam();
    final parent = GestureTeam();
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    final down = PointerDownEvent(pointer: 8002);
    child.observePointer(down);
    parent.observePointer(down);
    child.onPointerEvent = (event, _) => event is! PointerMoveEvent;
    parent.onPointerEvent = (event, _) {
      if (event is PointerMoveEvent) moves++;
      return true;
    };
    final blocked = PointerMoveEvent(pointer: 8002);
    child.observePointer(blocked);
    parent.observePointer(blocked);
    expect(moves, 0);
    child.onPointerEvent = (_, _) => true;
    final next = PointerMoveEvent(pointer: 8002, timeStamp: Duration(milliseconds: 10));
    child.observePointer(next);
    parent.observePointer(next);
    expect(moves, 1);
    final up = PointerUpEvent(pointer: 8002);
    child.observePointer(up);
    parent.observePointer(up);
    await tester.pump();
  });

  for (final signal in [false, true]) {
    test('无Down的Hover和Signal同样支持跨宿主截断：signal=$signal', () {
      var ancestors = 0;
      final child = GestureTeam();
      final parent = GestureTeam();
      addTearDown(child.dispose);
      addTearDown(parent.dispose);
      child.onPointerEvent = (_, _) {
        child.currentPointerDetails!.stopPropagation();
        return true;
      };
      parent.onPointerEvent = (_, _) {
        ancestors++;
        return true;
      };
      final PointerEvent event = signal ? PointerScrollEvent(scrollDelta: Offset(0, 24)) : PointerHoverEvent();
      child.observePointer(event);
      parent.observePointer(event);
      expect(ancestors, 0);
      expect(child.pointerCount, 0);
      expect(parent.pointerCount, 0);
    });
  }

  test('滚轮与PanZoom按各自原始位移构造统一数据', () {
    final wheel = PointerGestureDetails(PointerScrollEvent(scrollDelta: Offset(2, 24)));
    expect(wheel.delta, Offset(2, 24));
    final pan = PointerGestureDetails(
      PointerPanZoomUpdateEvent(position: Offset(100, 80), pan: Offset(12, 18), panDelta: Offset(3, 5)),
    );
    expect(pan.globalPosition, Offset(112, 98));
    expect(pan.delta, Offset(3, 5));
  });

  testWidgets('设备Removed无需预先合成Cancel，且只清理该设备的活动触点', (tester) async {
    final trace = <String>[];
    final first = PressRecognizer()
      ..callbacks[.tap] = ((_) => trace.add('first.tap'))
      ..callbacks[.tapCancel] = (_) => trace.add('first.cancel');
    final second = PressRecognizer()
      ..callbacks[.tap] = ((_) => trace.add('second.tap'))
      ..callbacks[.tapCancel] = (_) => trace.add('second.cancel');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final a = PointerDownEvent(pointer: 8011, device: 41);
    final b = PointerDownEvent(pointer: 8012, device: 42);
    first.addPointer(a);
    second.addPointer(b);
    final binding = GestureBinding.instance;
    binding.pointerRouter.route(a);
    binding.gestureArena.close(a.pointer);
    binding.pointerRouter.route(b);
    binding.gestureArena.close(b.pointer);
    await tester.pump();
    binding.pointerRouter.route(PointerRemovedEvent(device: 41));
    expect(trace, ['first.cancel']);
    binding.pointerRouter.route(PointerUpEvent(pointer: b.pointer, device: b.device));
    binding.gestureArena.sweep(b.pointer);
    await tester.pump();
    expect(trace, ['first.cancel', 'second.tap']);
  });

  test('纯原始输入观察也会在设备Removed时结清，并通知实际pointer编号', () {
    final removed = <int>[];
    final team = GestureTeam()..onPointerRemoved = (event) => removed.add(event.pointer);
    addTearDown(team.dispose);
    team.observePointer(PointerDownEvent(pointer: 8013, device: 43));
    GestureBinding.instance.pointerRouter.route(PointerRemovedEvent(device: 43));
    expect(removed, [8013]);
    expect(team.pointerCount, 0);
  });

  test('只剩一个触点也不能把其他设备的Removed错误映射给它', () {
    final removed = <int>[];
    final team = GestureTeam()..onPointerRemoved = (event) => removed.add(event.pointer);
    addTearDown(team.dispose);
    team.observePointer(PointerDownEvent(pointer: 8014, device: 44));
    GestureBinding.instance.pointerRouter.route(PointerRemovedEvent(device: 0));
    GestureBinding.instance.pointerRouter.route(PointerRemovedEvent(device: 45));
    expect(removed, isEmpty);
    expect(team.pointerCount, 1);
    GestureBinding.instance.pointerRouter.route(PointerRemovedEvent(device: 44));
    expect(removed, [8014]);
    expect(team.pointerCount, 0);
  });
}
