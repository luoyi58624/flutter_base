import 'package:flutter_base/src/flutter/views/view/event/press.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(GestureTeam.debugReset);

  testWidgets('垂直driver收编自由轴成员，唯一Start和End，普通Update只送driver', (tester) async {
    final parent = _Node('parent');
    final child = _Node('child', parent: parent, axis: Axis.vertical);
    addTearDown(() => _dispose([child, parent]));
    child.transform.dragCooperation = (_, _) => DragCooperation([parent.transform]);
    final finger = TestPointer(3100);
    _down(finger.down(Offset.zero), [child, parent]);
    _input(finger.move(Offset(0, 10)), [child, parent]);
    expect(child.events, ['start']);
    expect(parent.events, ['start']);
    expect(parent.transform.receivesDragUpdates(finger.pointer), isFalse);
    _input(finger.move(Offset(0, 20)), [child, parent]);
    _input(finger.up(), [child, parent]);
    expect(child.events, ['start', 'update', 'end']);
    expect(parent.events, ['start', 'end']);
    expect(parent.transform.hasActiveInput, isFalse);
  });

  testWidgets('承接名单在同轴无proxy竞争者之前截断，外层不能激活主键手势', (tester) async {
    final outer = _Node('outer');
    final latch = _Node('latch', parent: outer, axis: Axis.vertical);
    final proxy = _Node('proxy', parent: latch);
    final child = _Node('child', parent: proxy, axis: Axis.vertical);
    final nodes = [child, proxy, latch, outer];
    addTearDown(() => _dispose(nodes));
    child.transform.dragCooperation = (_, _) => DragCooperation([proxy.transform], cutoff: latch.team);
    final first = TestPointer(3101);
    _down(first.down(Offset.zero), nodes);
    _input(first.move(Offset(0, 10)), nodes);
    expect(latch.events, isEmpty);
    expect(outer.events, isEmpty);
    final second = TestPointer(3102);
    _down(second.down(Offset(20, 0)), nodes);
    _input(second.move(Offset(20, 15)), nodes);
    _input(first.up(), nodes);
    _input(second.move(Offset(20, 25)), nodes);
    _input(second.up(), nodes);
    expect(latch.events, isEmpty);
    expect(outer.events, isEmpty);
    expect(proxy.events, ['start', 'end']);
    expect(child.events.where((event) => event == 'start'), hasLength(1));
    expect(child.events.where((event) => event == 'end'), hasLength(1));
  });

  testWidgets('显式Start.stop高于内部承接豁免，不制造祖先终态', (tester) async {
    final parent = _Node('parent');
    final child = _Node('child', parent: parent, axis: Axis.vertical);
    addTearDown(() => _dispose([child, parent]));
    child.transform
      ..dragCooperation = ((_, _) => DragCooperation([parent.transform]))
      ..callbacks[.dragStart] = (event) {
        child.events.add('start');
        event.stopPropagation();
      };
    final finger = TestPointer(3103);
    _down(finger.down(Offset.zero), [child, parent]);
    _input(finger.move(Offset(0, 10)), [child, parent]);
    _input(finger.move(Offset(0, 20)), [child, parent]);
    expect(child.transform.dragCooperationMembers(finger.pointer), isEmpty);
    _input(finger.up(), [child, parent]);
    expect(child.events, ['start', 'update', 'end']);
    expect(parent.events, isEmpty);
  });

  testWidgets('承接成员提供Scale时，第二指可升级且减少为单指后继续', (tester) async {
    final parent = _Node('parent');
    final child = _Node('child', parent: parent, axis: Axis.vertical);
    addTearDown(() => _dispose([child, parent]));
    final scales = <String>[];
    child.transform
      ..cancelDragOnScale = true
      ..dragCooperation = (_, _) => DragCooperation([parent.transform]);
    parent.transform
      ..cancelDragOnScale = true
      ..callbacks[.scaleStart] = ((_) => scales.add('start'))
      ..callbacks[.scaleUpdate] = ((_) => scales.add('update'))
      ..callbacks[.scaleEnd] = (_) => scales.add('end');
    final first = TestPointer(3104);
    final second = TestPointer(3105);
    _down(first.down(Offset.zero), [child, parent]);
    _input(first.move(Offset(0, 10)), [child, parent]);
    _down(second.down(Offset(100, 10)), [child, parent]);
    expect(scales, ['start']);
    _input(second.move(Offset(140, 20)), [child, parent]);
    _input(second.up(), [child, parent]);
    final before = scales.length;
    _input(first.move(Offset(0, 30)), [child, parent]);
    expect(scales.length, greaterThan(before));
    _input(first.up(), [child, parent]);
    expect(scales.where((event) => event == 'start'), hasLength(1));
    expect(scales.where((event) => event == 'end'), hasLength(1));
    expect(child.events.where((event) => event == 'cancel'), hasLength(1));
    expect(parent.events.where((event) => event == 'cancel'), hasLength(1));
  });

  testWidgets('没有承接名单时，各被动成员仍收到普通Update', (tester) async {
    final parent = _Node('parent', axis: Axis.vertical);
    final child = _Node('child', parent: parent, axis: Axis.vertical);
    addTearDown(() => _dispose([child, parent]));
    final finger = TestPointer(3106);
    _down(finger.down(Offset.zero), [child, parent]);
    _input(finger.move(Offset(0, 10)), [child, parent]);
    _input(finger.move(Offset(0, 20)), [child, parent]);
    expect(child.transform.receivesDragUpdates(finger.pointer), isTrue);
    expect(parent.transform.receivesDragUpdates(finger.pointer), isTrue);
    _input(finger.up(), [child, parent]);
    expect(child.events, ['start', 'update', 'end']);
    expect(parent.events, ['start', 'update', 'end']);
  });

  for (final subscription in ['start', 'update', 'end']) {
    testWidgets('owner原始输入失权后，同路线祖先的$subscription订阅继续接收位移与唯一End', (tester) async {
      final parent = _Node('parent', axis: Axis.vertical);
      final child = _Node('child', parent: parent, axis: Axis.vertical);
      addTearDown(() => _dispose([child, parent]));
      for (final node in [child, parent]) {
        node.team.deferPointerMoves = true;
      }
      Offset? finalOffset;
      parent.transform.callbacks[.dragEnd] = (event) {
        parent.events.add('end');
        finalOffset = event.dragOffset;
      };
      if (subscription == 'start') {
        parent.transform.callbacks[.dragStart] = (event) {
          parent.events.add('start');
          parent.team.claimPointer(event.pointer);
        };
      } else {
        parent.transform.callbacks[.dragStart] = null;
      }
      if (subscription == 'end') parent.transform.callbacks[.dragUpdate] = null;
      final finger = TestPointer(3440);
      _down(finger.down(Offset.zero), [child, parent]);
      _input(finger.move(Offset(0, 10)), [child, parent]);
      if (subscription != 'start') parent.team.claimPointer(finger.pointer);
      _input(finger.move(Offset(0, 20)), [child, parent]);
      _input(finger.up(), [child, parent]);
      expect(child.events, ['start', 'cancel']);
      expect(parent.events, [if (subscription == 'start') 'start', if (subscription != 'end') 'update', 'end']);
      expect(finalOffset, Offset(0, 10));
    });
  }

  testWidgets('没有自身raw登记的代理不能独自维持失权driver，已公开终态仍唯一结清', (tester) async {
    final parent = _Node('proxy', axis: Axis.vertical);
    final child = _Node('child', parent: parent, axis: Axis.vertical);
    addTearDown(() => _dispose([child, parent]));
    parent.team.onPointerEvent = null;
    child.team.deferPointerMoves = true;
    final finger = TestPointer(3441);
    final down = finger.down(Offset.zero);
    child.team.observePointer(down);
    child.transform.addPointer(down);
    parent.transform.addPointer(down);
    GestureBinding.instance.gestureArena.close(down.pointer);
    _route(down);
    _input(finger.move(Offset(0, 10)), [child]);
    child.team.cancel();
    _input(finger.move(Offset(0, 20)), [child]);
    _input(finger.up(), [child]);
    expect(child.events, ['start', 'cancel']);
    expect(parent.events, ['start', 'end']);
  });

  testWidgets('祖先先起拖的提案不解析后代承接名单', (tester) async {
    final parent = _Node('parent', axis: Axis.vertical);
    final child = _Node('child', parent: parent, axis: Axis.vertical);
    addTearDown(() => _dispose([child, parent]));
    child.transform.startDistance = 30;
    var plans = 0;
    child.transform.dragCooperation = (_, _) {
      plans++;
      return DragCooperation([parent.transform]);
    };
    final finger = TestPointer(3107);
    _down(finger.down(Offset.zero), [child, parent]);
    _input(finger.move(Offset(0, 10)), [child, parent]);
    expect(plans, 0);
    expect(child.events, ['proposal']);
    _input(finger.move(Offset(0, 40)), [child, parent]);
    expect(plans, 1);
    _input(finger.up(), [child, parent]);
    expect(parent.events.where((event) => event == 'start'), hasLength(1));
    expect(parent.events.where((event) => event == 'end'), hasLength(1));
  });

  testWidgets('移除判断使用冻结祖先，当前parent改变不影响存活者续接', (tester) async {
    final parent = _Node('parent', axis: Axis.vertical);
    final child = _Node('child', parent: parent, axis: Axis.vertical);
    final other = _Node('other');
    addTearDown(() => _dispose([child, parent, other]));
    final finger = TestPointer(3108);
    _down(finger.down(Offset.zero), [child, parent]);
    _input(finger.move(Offset(0, 10)), [child, parent]);
    child.transform.parent = other.transform;
    child.team.parent = other.team;
    child.team.terminateOwnedInputs(survives: (team) => identical(team, parent.team));
    expect(child.events, ['start']);
    child.transform.dispose();
    _input(finger.move(Offset(0, 20)), [parent]);
    _input(finger.up(), [parent]);
    expect(child.events, ['start', 'cancel']);
    expect(parent.events, ['start', 'update', 'end']);
  });

  testWidgets('冻结祖先均失效时终止owner并且没有重复终态', (tester) async {
    final parent = _Node('parent', axis: Axis.vertical);
    final child = _Node('child', parent: parent, axis: Axis.vertical);
    addTearDown(() => _dispose([child, parent]));
    final finger = TestPointer(3109);
    _down(finger.down(Offset.zero), [child, parent]);
    _input(finger.move(Offset(0, 10)), [child, parent]);
    parent.transform.cancelMember(null);
    child.team.terminateOwnedInputs(survives: (_) => true);
    expect(child.events, ['start', 'cancel']);
    expect(child.transform.hasActiveInput, isFalse);
    _input(finger.up(), [child, parent]);
    expect(child.events, ['start', 'cancel']);
  });

  testWidgets('Scale等全部已投递候选获准后公开，来源为本次真实Move', (tester) async {
    final node = _Node('scale');
    addTearDown(() => _dispose([node]));
    TransformGestureDetails? start;
    node.transform
      ..startDistance = 1000
      ..callbacks[.scaleStart] = (event) => start = event;
    final first = TestPointer(3300);
    final second = TestPointer(3301);
    _down(first.down(Offset.zero), [node]);
    _down(second.down(Offset(100, 0)), [node]);
    final move = second.move(Offset(160, 0));
    _input(move, [node]);
    expect(start!.pointerCount, 2);
    expect(start!.pointerIds, containsAll([3300, 3301]));
    expect(start!.originalEvent, same(move));
    _input(first.up(), [node]);
    _input(second.up(), [node]);
  });

  testWidgets('普通双指Down只报名，Scale等待真实Move阈值且参数按会话冻结', (tester) async {
    final node = _Node('scale');
    addTearDown(() => _dispose([node]));
    TransformGestureDetails? start;
    node.transform
      ..callbacks[.dragStart] = null
      ..callbacks[.dragUpdate] = null
      ..callbacks[.dragEnd] = null
      ..callbacks[.dragCancel] = null
      ..startScaleOnPointerDown = false
      ..callbacks[.scaleStart] = (event) => start = event;
    final first = TestPointer(3310);
    final second = TestPointer(3311);
    _down(first.down(Offset.zero), [node]);
    _input(first.move(Offset(10, 0)), [node]);
    node.transform.startScaleOnPointerDown = true;
    _down(second.down(Offset(100, 0)), [node]);
    expect(start, isNull);
    final move = second.move(Offset(150, 0));
    _input(move, [node]);
    expect(start!.originalEvent, same(move));
    expect(start!.pointerCount, 2);
    _input(first.up(), [node]);
    _input(second.up(), [node]);
  });

  testWidgets('自动Scale-only与祖先轴向Drag保持独立参数，单指两通道同时推进', (tester) async {
    final parent = _Node('parent', axis: Axis.vertical);
    final child = _Node('child', parent: parent);
    addTearDown(() => _dispose([child, parent]));
    final counts = <int>[];
    child.transform
      ..cancelDragOnScale = true
      ..callbacks[.dragStart] = null
      ..callbacks[.dragUpdate] = null
      ..callbacks[.dragEnd] = null
      ..callbacks[.dragCancel] = null
      ..callbacks[.scaleStart] = (event) => counts.add(event.pointerCount);
    final finger = TestPointer(3312);
    _down(finger.down(Offset.zero), [child, parent]);
    _input(finger.move(Offset(0, 50)), [child, parent]);
    _input(finger.move(Offset(0, 80)), [child, parent]);
    expect(counts, [1]);
    expect(parent.events, ['start', 'update']);
    _input(finger.up(), [child, parent]);
    expect(parent.events.last, 'end');
  });

  for (final prevent in [false, true]) {
    testWidgets('Scale预提交通知先结清Tap，祖先仍可否决排他默认动作：$prevent', (tester) async {
      final trace = <String>[];
      final parent = _Node('parent');
      final child = _Node('child', parent: parent);
      final press = PressRecognizer()
        ..team = child.team
        ..tapSlopTolerance = double.infinity
        ..callbacks[.tapDown] = ((_) => trace.add('tap.down'))
        ..callbacks[.tapCancel] = (_) => trace.add('tap.cancel');
      addTearDown(press.dispose);
      addTearDown(() => _dispose([child, parent]));
      for (final node in [child, parent]) {
        node.transform
          ..callbacks[.dragStart] = null
          ..callbacks[.dragUpdate] = null
          ..callbacks[.dragEnd] = null
          ..callbacks[.dragCancel] = null;
      }
      child.transform
        ..beforeScaleStart = (pointers) {
          for (final pointer in pointers) {
            press.rejectTap(pointer, reason: PressCancelReason.longPressAccepted);
          }
        }
        ..callbacks[.scaleStart] = ((_) => trace.add('child.scale'))
        ..onScaleStartDefault = (_) => trace.add('default');
      parent.transform.callbacks[.scaleStart] = (event) {
        trace.add('parent.scale');
        if (prevent) event.preventDefault();
      };
      final finger = TestPointer(3302);
      final down = finger.down(Offset.zero);
      child.team.observePointer(down);
      parent.team.observePointer(down);
      press.addPointer(down);
      child.transform.addPointer(down);
      parent.transform.addPointer(down);
      GestureBinding.instance.gestureArena.close(down.pointer);
      _route(down);
      _input(finger.move(Offset(50, 0)), [child, parent]);
      expect(trace, ['tap.down', 'tap.cancel', 'child.scale', 'parent.scale', if (!prevent) 'default']);
      _input(finger.up(), [child, parent]);
    });
  }

  testWidgets('成员取消保留异指针来源身份和buttons，报名仍按原物理指针结清', (tester) async {
    final node = _Node('scale');
    addTearDown(() => _dispose([node]));
    TransformGestureDetails? canceled;
    node.transform
      ..startDistance = 1000
      ..callbacks[.scaleStart] = (_) {}
      ..callbacks[.scaleCancel] = (event) => canceled = event;
    final finger = TestPointer(3303);
    _down(finger.down(Offset.zero), [node]);
    _input(finger.move(Offset(50, 0)), [node]);
    final takeover = PointerMoveEvent(pointer: 9, kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
    node.transform.cancelMember(finger.pointer, event: takeover);
    expect(canceled!.originalEvent, same(takeover));
    expect(canceled!.buttons, kSecondaryButton);
    _input(finger.up(), [node]);
  });

  testWidgets('团队已有官方归属时补挂Transform，直接复用席位且不复活已取消输入', (tester) async {
    final node = _Node('late');
    final press = PressRecognizer()
      ..team = node.team
      ..callbacks[.tapDown] = (_) {};
    addTearDown(press.dispose);
    addTearDown(() => _dispose([node]));
    node.transform
      ..callbacks[.dragStart] = null
      ..callbacks[.dragUpdate] = null
      ..callbacks[.dragEnd] = null
      ..callbacks[.dragCancel] = null;
    final first = TestPointer(3304);
    final down = first.down(Offset.zero);
    node.team.observePointer(down);
    press.addPointer(down);
    GestureBinding.instance.gestureArena.close(down.pointer);
    _route(down);
    await tester.pump();
    node.transform
      ..callbacks[.dragStart] = ((_) => node.events.add('start'))
      ..callbacks[.dragUpdate] = ((_) => node.events.add('update'))
      ..callbacks[.dragEnd] = (_) => node.events.add('end');
    node.transform.resumeFromTeam();
    _input(first.move(Offset(10, 0)), [node]);
    _input(first.move(Offset(20, 0)), [node]);
    _input(first.up(), [node]);
    expect(node.events, ['start', 'update', 'end']);
    node.transform
      ..callbacks[.dragStart] = null
      ..callbacks[.dragUpdate] = null
      ..callbacks[.dragEnd] = null;
    final second = TestPointer(3305);
    final secondDown = second.down(Offset.zero);
    node.team.observePointer(secondDown);
    press.addPointer(secondDown);
    GestureBinding.instance.gestureArena.close(second.pointer);
    _route(secondDown);
    await tester.pump();
    node.team.cancel();
    node.transform.callbacks[.dragStart] = (_) => node.events.add('revived');
    node.transform.resumeFromTeam();
    _input(second.move(Offset(30, 0)), [node]);
    _input(second.up(), [node]);
    expect(node.events, ['start', 'update', 'end']);
  });

  testWidgets('祖先晚挂Transform沿委托Press的原生来源推进，不越过其他竞技场抢位', (tester) async {
    final trace = <String>[];
    final outer = GestureTeam()..matchParentGestures = true;
    final middle = GestureTeam(parent: outer)..matchParentGestures = true;
    final inner = GestureTeam(parent: middle)..matchParentGestures = true;
    for (final team in [inner, middle, outer]) {
      team
        ..deferPointerMoves = true
        ..onPointerEvent = ((_, _) => true);
      addTearDown(team.dispose);
    }
    final ancestorPress = PressRecognizer()
      ..team = middle
      ..tapSlopTolerance = double.infinity
      ..callbacks[.tap] = (_) {};
    final childPress = PressRecognizer()
      ..team = inner
      ..parent = ancestorPress
      ..tapSlopTolerance = double.infinity
      ..callbacks[.tap] = (_) {};
    final outerDrag = TransformRecognizer()
      ..team = outer
      ..startDistance = 3
      ..callbacks[.dragStart] = (_) {
        trace.add('outer.start');
        outer.claimPointer(3430);
      };
    final lateDrag = TransformRecognizer()
      ..team = middle
      ..parent = outerDrag
      ..startDistance = 3;
    for (final recognizer in [childPress, ancestorPress, lateDrag, outerDrag]) {
      addTearDown(recognizer.dispose);
    }
    final finger = TestPointer(3430);
    final down = finger.down(Offset.zero);
    inner.observePointer(down);
    childPress.addPointer(down);
    middle.observePointer(down);
    ancestorPress.addPointer(down);
    outer.observePointer(down);
    outerDrag.addPointer(down);
    GestureBinding.instance.gestureArena.close(down.pointer);
    _route(down);
    childPress.acceptPointer(down.pointer);
    lateDrag
      ..callbacks[.dragStart] = (_) {
        trace.add('middle.start');
        middle.claimPointer(down.pointer, cancelTap: true);
      }
      ..callbacks[.dragUpdate] = ((_) => trace.add('middle.update'))
      ..resumeFromTeam();
    final move = finger.move(Offset(20, 0));
    for (final team in [inner, middle, outer]) {
      team.observePointer(move);
    }
    _route(move);
    expect(trace, ['middle.start']);
    final next = finger.move(Offset(30, 0));
    for (final team in [inner, middle, outer]) {
      team.observePointer(next);
    }
    _route(next);
    expect(trace, ['middle.start', 'middle.update']);
    final up = finger.up();
    for (final team in [inner, middle, outer]) {
      team.observePointer(up);
    }
    _route(up);
  });

  testWidgets('旧会话的全部订阅已取消时新Down建立新会话，旧指后续终态不重复结算', (tester) async {
    final node = _Node('restart');
    addTearDown(() => _dispose([node]));
    final first = TestPointer(3431);
    final second = TestPointer(3432);
    _down(first.down(Offset.zero), [node]);
    _input(first.move(Offset(10, 0)), [node]);
    node.transform.cancelMember(null);
    _down(second.down(Offset.zero), [node]);
    _input(second.move(Offset(10, 0)), [node]);
    _input(second.up(), [node]);
    _input(first.up(), [node]);
    expect(node.events, ['start', 'cancel', 'start', 'end']);
  });

  testWidgets('同设备鼠标的新主指针替换旧序列，不能当作触摸追加指合并', (tester) async {
    final node = _Node('mouse');
    addTearDown(() => _dispose([node]));
    final first = TestPointer(3435, PointerDeviceKind.mouse, 65);
    final second = TestPointer(3436, PointerDeviceKind.mouse, 65);
    _down(first.down(Offset.zero), [node]);
    _input(first.move(Offset(10, 0)), [node]);
    _down(second.down(Offset.zero), [node]);
    _input(second.move(Offset(10, 0)), [node]);
    _input(second.up(), [node]);
    _input(first.up(), [node]);
    expect(node.events, ['start', 'cancel', 'start', 'end']);
  });

  testWidgets('追加触点被独占拒绝时保留首指的既有Drag和唯一终态', (tester) async {
    final parent = _Node('parent');
    final child = _Node('child', parent: parent);
    addTearDown(() => _dispose([child, parent]));
    child.transform
      ..callbacks[.dragStart] = null
      ..callbacks[.dragUpdate] = null
      ..callbacks[.dragEnd] = null
      ..callbacks[.dragCancel] = null;
    final first = TestPointer(3433);
    final second = TestPointer(3434);
    child.team.onPointerEvent = (event, _) {
      if (event is PointerDownEvent && event.pointer == second.pointer) child.team.claimPointer(event.pointer);
      return true;
    };
    _down(first.down(Offset.zero), [parent]);
    _input(first.move(Offset(10, 0)), [parent]);
    _down(second.down(Offset(100, 0)), [child, parent]);
    _input(second.up(), [child, parent]);
    _input(first.move(Offset(20, 0)), [parent]);
    _input(first.up(), [parent]);
    expect(parent.events, ['start', 'update', 'end']);
  });

  testWidgets('祖先在另一个sibling落指后继续同会话Update，A释放不提前结束祖先', (tester) async {
    final parent = _Node('parent');
    final a = _Node('a', parent: parent);
    final b = _Node('b', parent: parent);
    addTearDown(() => _dispose([a, b, parent]));
    a.transform.startDistance = 20;
    b.transform
      ..callbacks[.dragStart] = null
      ..callbacks[.dragUpdate] = null
      ..callbacks[.dragEnd] = null
      ..callbacks[.dragCancel] = null;
    final first = TestPointer(3306);
    final second = TestPointer(3307);
    _down(first.down(Offset(50, 50)), [a, parent]);
    _input(first.move(Offset(55, 50)), [a, parent]);
    final down = second.down(Offset(150, 50));
    b.team.observePointer(down);
    parent.team.observePointer(down);
    parent.transform.addPointer(down);
    GestureBinding.instance.gestureArena.close(second.pointer);
    _route(down);
    _input(second.move(Offset(160, 50)), [b, parent]);
    expect(parent.events.where((event) => event == 'update'), hasLength(1));
    _input(first.up(), [a, parent]);
    expect(a.events, ['proposal', 'end']);
    expect(parent.events.where((event) => event == 'end'), isEmpty);
    _input(second.up(), [b, parent]);
    expect(parent.events.where((event) => event == 'end'), hasLength(1));
  });

  testWidgets('Drag owner无Scale而祖先声明Scale，兄弟触点仍按物理来源参赛并执行祖先hook', (tester) async {
    final parent = _Node('parent');
    final a = _Node('a', parent: parent);
    final b = _Node('b', parent: parent);
    addTearDown(() => _dispose([a, b, parent]));
    final hooks = <String>[];
    final scales = <String>[];
    var canStart = false;
    for (final node in [a, b, parent]) {
      node.team.deferPointerMoves = true;
      node.transform.cancelDragOnScale = true;
    }
    a.transform
      ..startScaleOnPointerDown = false
      ..canStartScale = ((_) => throw StateError('Drag owner不能替祖先裁决Scale'))
      ..beforeScaleStart = (_) => throw StateError('Drag owner不能替祖先结算Tap');
    parent.transform
      ..canStartScale = ((pointers) => canStart && parent.team.canClaimPointers(pointers))
      ..beforeScaleStart = ((_) => hooks.add('before'))
      ..callbacks[.scaleStart] = ((_) => scales.add('start'))
      ..callbacks[.scaleUpdate] = ((_) => scales.add('update'))
      ..callbacks[.scaleEnd] = ((_) => scales.add('end'))
      ..onScaleStartDefault = (event) {
        hooks.add('default');
        expect(parent.team.claimPointers(event.pointerIds, cancelTap: true), isTrue);
      };
    b.transform
      ..callbacks[.dragStart] = null
      ..callbacks[.dragUpdate] = null
      ..callbacks[.dragEnd] = null
      ..callbacks[.dragCancel] = null;
    final first = TestPointer(3322);
    final second = TestPointer(3323);
    _down(first.down(Offset.zero), [a, parent]);
    _input(first.move(Offset(4, 0)), [a, parent]);
    final down = second.down(Offset(100, 0));
    b.team.observePointer(down);
    parent.team.observePointer(down);
    parent.transform.addPointer(down);
    GestureBinding.instance.gestureArena.close(second.pointer);
    _route(down);
    await tester.pump();
    canStart = true;
    _input(second.move(Offset(160, 0)), [b, parent]);
    expect(hooks, ['before', 'default']);
    expect(scales, ['start']);
    _input(first.move(Offset(10, 0)), [a, parent]);
    _input(second.move(Offset(180, 0)), [b, parent]);
    expect(scales.where((event) => event == 'update'), hasLength(2));
    _input(first.up(), [a, parent]);
    _input(second.up(), [b, parent]);
    expect(scales.last, 'end');
  });

  testWidgets('让渡成员不在第二指命中链时沿原session补指，原始来源失权后仍收到ScaleUpdate', (tester) async {
    final outer = _Node('outer');
    final winner = _Node('winner', parent: outer, axis: Axis.vertical);
    final zoom = _Node('zoom', parent: winner);
    final nodes = [zoom, winner, outer];
    addTearDown(() => _dispose(nodes));
    var outerStarts = 0;
    final scales = <TransformGestureDetails>[];
    outer.transform
      ..callbacks[.dragStart] = null
      ..callbacks[.dragUpdate] = null
      ..callbacks[.dragEnd] = null
      ..callbacks[.dragCancel] = null
      ..callbacks[.scaleStart] = (_) => outerStarts++;
    for (final node in nodes) {
      node.team.deferPointerMoves = true;
      node.transform.cancelDragOnScale = true;
    }
    winner.transform.callbacks[.dragStart] = (event) {
      winner.team.claimPointer(event.pointer, allowScaleUpgrade: true);
    };
    zoom.transform
      ..canStartScale = zoom.team.canClaimPointers
      ..callbacks[.scaleStart] = scales.add
      ..callbacks[.scaleUpdate] = scales.add
      ..onScaleStartDefault = (event) {
        expect(zoom.team.claimPointers(event.pointerIds, cancelTap: true), isTrue);
      };
    final first = TestPointer(3437);
    final second = TestPointer(3438);
    _down(first.down(Offset.zero), nodes);
    _input(first.move(Offset(0, 10)), nodes);
    _down(second.down(Offset(100, 0)), [winner]);
    await tester.pump();
    expect(scales.single.phase, ElEventPhase.scaleStart);
    _input(second.move(Offset(104, 0)), [winner]);
    expect(scales, hasLength(2));
    expect(scales.last.phase, ElEventPhase.scaleUpdate);
    expect(scales.last.scale, greaterThan(1));
    expect(outerStarts, 0);
    _input(first.up(), nodes);
    _input(second.up(), [winner]);
  });

  testWidgets('staged输入中Drag升级Scale使用第二指真实Move，源记录始终跟随物理报名', (tester) async {
    final node = _Node('staged')..team.deferPointerMoves = true;
    addTearDown(() => _dispose([node]));
    TransformGestureDetails? start;
    var canStart = false;
    node.transform
      ..cancelDragOnScale = true
      ..startScaleOnPointerDown = false
      ..canStartScale = ((pointers) => canStart && node.team.canClaimPointers(pointers))
      ..callbacks[.scaleStart] = (event) => start = event;
    final first = TestPointer(3320);
    final second = TestPointer(3321);
    _down(first.down(Offset.zero), [node]);
    _input(first.move(Offset(4, 0)), [node]);
    _down(second.down(Offset(100, 0)), [node]);
    await tester.pump();
    canStart = true;
    final move = second.move(Offset(160, 0));
    _input(move, [node]);
    expect(start, isNotNull);
    expect(start!.originalEvent, same(move));
    _input(first.up(), [node]);
    _input(second.up(), [node]);
  });

  for (final distance in [5.0, -16.0]) {
    testWidgets('短扫救援独立阈值冻结，5px微移拒绝、16px反向24ms起拖：$distance', (tester) async {
      final node = _Node('child', axis: Axis.vertical);
      addTearDown(() => _dispose([node]));
      TransformGestureDetails? end;
      node.transform
        ..startDistance = 40
        ..preAcceptFlingDistance = 5
        ..callbacks[.dragEnd] = (event) => end = event;
      final finger = TestPointer(3110);
      _down(finger.down(Offset.zero), [node]);
      node.transform.preAcceptFlingDistance = 100;
      _input(finger.move(Offset(0, distance / 2), timeStamp: Duration(milliseconds: 8)), [node]);
      _input(finger.move(Offset(0, distance), timeStamp: Duration(milliseconds: 16)), [node]);
      expect(node.events, isEmpty);
      _input(finger.up(timeStamp: Duration(milliseconds: 24)), [node]);
      if (distance == 5) {
        expect(node.events, ['cancel']);
        expect(end, isNull);
      } else {
        expect(node.events, ['start']);
        expect(end, isNotNull);
        expect(end!.velocity.pixelsPerSecond.dy, lessThan(0));
        expect(end!.dragOffset, Offset.zero);
      }
    });
  }

  testWidgets('短扫速度与净位移相反时不救起拖', (tester) async {
    final node = _Node('child', axis: Axis.vertical);
    addTearDown(() => _dispose([node]));
    node.transform
      ..startDistance = 40
      ..preAcceptFlingDistance = 5
      ..velocityTrackerBuilder = (_) => _OppositeVelocity();
    final finger = TestPointer(3111);
    _down(finger.down(Offset.zero), [node]);
    _input(finger.move(Offset(0, -8), timeStamp: Duration(milliseconds: 8)), [node]);
    _input(finger.move(Offset(0, -16), timeStamp: Duration(milliseconds: 16)), [node]);
    _input(finger.up(timeStamp: Duration(milliseconds: 24)), [node]);
    expect(node.events, ['cancel']);
  });

  testWidgets('刷新待定配置沿用原指针，配置取消的订阅可按仍有效的官方资格恢复', (tester) async {
    final node = _Node('pending', axis: Axis.vertical);
    addTearDown(() => _dispose([node]));
    node.transform.startDistance = 30;
    final finger = TestPointer(3410);
    _down(finger.down(Offset.zero), [node]);
    node.transform.acceptPointer(finger.pointer);
    _input(finger.move(Offset(0, -8), timeStamp: Duration(milliseconds: 8)), [node]);
    node.transform.cancelMember(null);
    node.events.clear();
    node.transform.resumeFromTeam();
    _input(finger.move(Offset(0, -10), timeStamp: Duration(milliseconds: 10)), [node]);
    expect(node.events, isEmpty, reason: '补挂入口不能擅自恢复手工取消的家族。');
    node.transform
      ..startDistance = 12
      ..resumeFromTeam()
      ..refreshPendingConfiguration();
    expect(node.events, isEmpty, reason: '刷新配置不能同步公开开始阶段。');
    _input(finger.move(Offset(0, -16), timeStamp: Duration(milliseconds: 16)), [node]);
    _input(finger.move(Offset(0, -24), timeStamp: Duration(milliseconds: 24)), [node]);
    _input(finger.up(timeStamp: Duration(milliseconds: 32)), [node]);
    expect(node.events, ['start', 'update', 'end']);
  });

  testWidgets('明确刷新也不复活已经失去原始输入资格的触点', (tester) async {
    final node = _Node('canceled');
    addTearDown(() => _dispose([node]));
    final finger = TestPointer(3423);
    _down(finger.down(Offset.zero), [node]);
    node.transform.acceptPointer(finger.pointer);
    node.team.cancel();
    node.events.clear();
    node.transform
      ..startDistance = 1
      ..resumeFromTeam()
      ..refreshPendingConfiguration();
    _input(finger.move(Offset(0, 20)), [node]);
    _input(finger.up(), [node]);
    expect(node.events, isEmpty);
    expect(node.transform.hasActiveInput, isFalse);
  });

  testWidgets('已公开起拖后显式刷新仍保留本轮轴和速度门限', (tester) async {
    final node = _Node('active', axis: Axis.vertical);
    addTearDown(() => _dispose([node]));
    final updates = <TransformGestureDetails>[];
    node.transform.callbacks[.dragUpdate] = updates.add;
    final finger = TestPointer(3411);
    _down(finger.down(Offset.zero), [node]);
    _input(finger.move(Offset(0, 10), timeStamp: Duration(milliseconds: 10)), [node]);
    node.transform
      ..axis = Axis.horizontal
      ..startDistance = 1000
      ..resumeFromTeam()
      ..refreshPendingConfiguration();
    _input(finger.move(Offset(10, 20), timeStamp: Duration(milliseconds: 20)), [node]);
    expect(updates.single.dragAxis, Axis.vertical);
    expect(updates.single.delta, Offset(0, 10));
    _input(finger.up(timeStamp: Duration(milliseconds: 22)), [node]);
    expect(node.events, ['start', 'end']);
  });

  for (final continues in [false, true]) {
    testWidgets('原始Move内刷新只沉降当前输入，后续${continues ? 'Move补Start和增量' : 'Up不补开始终态'}', (tester) async {
      final node = _Node('deferred', axis: Axis.vertical);
      addTearDown(() => _dispose([node]));
      node.transform.startDistance = 12;
      node.team.deferPointerMoves = true;
      var replaced = false;
      node.team.onPointerEvent = (event, _) {
        if (event is PointerMoveEvent && !replaced) {
          replaced = true;
          node.transform
            ..resumeFromTeam()
            ..refreshPendingConfiguration(deferStartFor: event);
        }
        return true;
      };
      final deltas = <Offset>[];
      node.transform.callbacks[.dragUpdate] = (event) {
        node.events.add('update');
        deltas.add(event.delta);
      };
      final finger = TestPointer(continues ? 3412 : 3413);
      _down(finger.down(Offset.zero), [node]);
      _input(finger.move(Offset(0, -16), timeStamp: Duration(milliseconds: 16)), [node]);
      expect(node.events, isEmpty);
      if (continues) {
        _input(finger.move(Offset(0, -28), timeStamp: Duration(milliseconds: 32)), [node]);
        expect(node.events, ['start', 'update']);
        expect(deltas, [Offset(0, -12)]);
      }
      _input(finger.up(timeStamp: Duration(milliseconds: 48)), [node]);
      expect(node.events, continues ? ['start', 'update', 'end'] : ['cancel']);
    });
  }

  testWidgets('祖先已公开纵轴后同一触点不得再补启动子级横轴', (tester) async {
    final parent = _Node('parent', axis: Axis.vertical);
    final child = _Node('child', parent: parent, axis: Axis.horizontal);
    addTearDown(() => _dispose([child, parent]));
    final finger = TestPointer(3414);
    _down(finger.down(Offset.zero), [child, parent]);
    _input(finger.move(Offset(0, 10)), [child, parent]);
    expect(parent.events, ['start']);
    _input(finger.move(Offset(10, 10)), [child, parent]);
    _input(finger.move(Offset(20, 10)), [child, parent]);
    expect(child.events, isNot(contains('start')));
    _input(finger.up(), [child, parent]);
    expect(child.events, ['cancel']);
    expect(parent.events.last, 'end');
  });

  testWidgets('正负45度边界优先水平轴，不受tan浮点误差影响', (tester) async {
    final node = _Node('angle');
    addTearDown(() => _dispose([node]));
    final axes = <Axis?>[];
    node.transform
      ..lockAxis = true
      ..callbacks[.dragStart] = (event) => axes.add(event.dragAxis);
    for (final sign in [1.0, -1.0]) {
      final finger = TestPointer(sign > 0 ? 3415 : 3416);
      _down(finger.down(Offset.zero), [node]);
      _input(finger.move(Offset(80 * sign, 80 * sign)), [node]);
      _input(finger.up(), [node]);
    }
    expect(axes, [Axis.horizontal, Axis.horizontal]);
  });

  testWidgets('最小甩动速度可高于最大输出速度，先筛选实际速度再限幅', (tester) async {
    final node = _Node('velocity');
    addTearDown(() => _dispose([node]));
    final ends = <Velocity>[];
    node.transform
      ..minFlingVelocity = 1000000
      ..maxFlingVelocity = 100
      ..callbacks[.dragEnd] = (event) => ends.add(event.velocity);
    final finger = TestPointer(3417);
    _down(finger.down(Offset.zero), [node]);
    for (var step = 1; step <= 3; step++) {
      _input(finger.move(Offset(step * 20, 0), timeStamp: Duration(milliseconds: step * 10)), [node]);
    }
    _input(finger.up(timeStamp: Duration(milliseconds: 32)), [node]);
    expect(ends.single, Velocity.zero);
    final next = TestPointer(3418);
    node.transform.minFlingVelocity = 1000;
    _down(next.down(Offset.zero), [node]);
    for (var step = 1; step <= 3; step++) {
      _input(next.move(Offset(step * 20, 0), timeStamp: Duration(milliseconds: step * 10)), [node]);
    }
    _input(next.up(timeStamp: Duration(milliseconds: 32)), [node]);
    expect(ends.last.pixelsPerSecond.dx, closeTo(100, 0.001));
  });

  testWidgets('缩放降单指后仅两个连续真实样本时用末段速度，不把Up加入拟合', (tester) async {
    final node = _Node('scale');
    addTearDown(() => _dispose([node]));
    TransformGestureDetails? end;
    node.transform
      ..callbacks[.dragStart] = null
      ..callbacks[.dragUpdate] = null
      ..callbacks[.dragEnd] = null
      ..callbacks[.dragCancel] = null
      ..callbacks[.scaleStart] = ((_) {})
      ..callbacks[.scaleEnd] = (event) => end = event;
    final first = TestPointer(3419);
    final second = TestPointer(3420);
    _down(first.down(Offset.zero), [node]);
    _down(second.down(Offset(100, 0)), [node]);
    _input(second.move(Offset(140, 0), timeStamp: Duration(milliseconds: 10)), [node]);
    _input(second.move(Offset(160, 0), timeStamp: Duration(milliseconds: 20)), [node]);
    _input(second.up(timeStamp: Duration(milliseconds: 21)), [node]);
    _input(first.move(Offset(10, 0), timeStamp: Duration(milliseconds: 30)), [node]);
    _input(PointerUpEvent(pointer: first.pointer, position: Offset(70, 0), timeStamp: Duration(milliseconds: 32)), [
      node,
    ]);
    expect(end!.velocity.pixelsPerSecond.dx, closeTo(1000 / 3, 0.001));
    expect(end!.logScaleVelocity, 0);
  });

  for (final reconfigureAt in ['dragCancel', 'scaleStart']) {
    testWidgets('Scale起手在$reconfigureAt重配后不继续旧阶段的公开或默认动作', (tester) async {
      final node = _Node('scale');
      addTearDown(() => _dispose([node]));
      var starts = 0;
      var defaults = 0;
      var canStart = false;
      node.transform
        ..cancelDragOnScale = true
        ..startScaleOnPointerDown = false
        ..canStartScale = ((_) => canStart)
        ..onScaleStartDefault = ((_) => defaults++)
        ..callbacks[.scaleStart] = (_) {
          starts++;
          if (reconfigureAt == 'scaleStart') node.transform.refreshPendingConfiguration();
        }
        ..callbacks[.dragCancel] = (_) {
          if (reconfigureAt == 'dragCancel') {
            node.transform
              ..callbacks[.scaleStart] = ((_) => starts++)
              ..refreshPendingConfiguration();
          }
        };
      final first = TestPointer(3421);
      final second = TestPointer(3422);
      _down(first.down(Offset.zero), [node]);
      _input(first.move(Offset(0, 10)), [node]);
      _down(second.down(Offset(100, 10)), [node]);
      await tester.pump();
      canStart = true;
      _input(second.move(Offset(160, 10)), [node]);
      expect(starts, reconfigureAt == 'dragCancel' ? 0 : 1);
      expect(defaults, 0);
      node.team.cancel();
    });
  }

  for (final terminal in ['cancel', 'terminate', 'removed']) {
    testWidgets('PanZoom $terminal结清raw End与typed Cancel，保留最后pan全局位置', (tester) async {
      final rawEnds = <PointerPanZoomEndEvent>[];
      final reasons = <PressCancelReason?>[];
      final team = GestureTeam()
        ..onPointerEvent = (event, reason) {
          if (event is PointerPanZoomEndEvent) {
            rawEnds.add(event);
            reasons.add(reason);
          }
          return true;
        };
      final typed = <String>[];
      final transform = TransformRecognizer()
        ..team = team
        ..callbacks[.scaleStart] = ((_) => typed.add('start'))
        ..callbacks[.scaleCancel] = (_) => typed.add('cancel');
      addTearDown(transform.dispose);
      addTearDown(team.dispose);
      final start = PointerPanZoomStartEvent(pointer: 3200, device: 42, position: Offset(4, 5));
      team.observePointer(start);
      transform.addPointerPanZoom(start);
      GestureBinding.instance.gestureArena.close(start.pointer);
      _route(start);
      final update = PointerPanZoomUpdateEvent(
        pointer: 3200,
        device: 42,
        position: Offset(4, 5),
        pan: Offset(10, 20),
        panDelta: Offset(10, 20),
        scale: 1.2,
      );
      team.observePointer(update);
      _route(update);
      if (terminal == 'cancel') {
        team.cancel();
      } else if (terminal == 'terminate') {
        team.terminateOwnedInputs(survives: (_) => false);
      } else {
        _route(PointerRemovedEvent(device: 42, kind: PointerDeviceKind.trackpad));
      }
      expect(rawEnds, hasLength(1));
      expect(rawEnds.single.position, Offset(14, 25));
      expect(rawEnds.single.device, 42);
      expect(rawEnds.single.pointer, 3200);
      expect(reasons.single, terminal == 'removed' ? PressCancelReason.pointerCanceled : PressCancelReason.canceled);
      expect(typed, ['start', 'cancel']);
      expect(transform.hasActiveInput, isFalse);
      team.cancel();
      expect(rawEnds, hasLength(1));
    });
  }
}

class _Node {
  _Node(this.name, {_Node? parent, Axis? axis}) {
    team = GestureTeam(parent: parent?.team)
      ..matchParentGestures = true
      ..onPointerEvent = ((_, _) => true);
    transform = TransformRecognizer()
      ..team = team
      ..parent = parent?.transform
      ..axis = axis
      ..startDistance = 3
      ..callbacks[.dragStart] = ((event) => events.add(event.isProposal ? 'proposal' : 'start'))
      ..callbacks[.dragUpdate] = ((_) => events.add('update'))
      ..callbacks[.dragEnd] = ((_) => events.add('end'))
      ..callbacks[.dragCancel] = (_) => events.add('cancel');
  }

  final String name;
  late final GestureTeam team;
  late final TransformRecognizer transform;
  final events = <String>[];
}

void _down(PointerDownEvent event, List<_Node> nodes) {
  for (final node in nodes) {
    node.team.observePointer(event);
    node.transform.addPointer(event);
  }
  GestureBinding.instance.gestureArena.close(event.pointer);
  _route(event);
}

void _input(PointerEvent event, List<_Node> nodes) {
  for (final node in nodes) {
    node.team.observePointer(event);
  }
  _route(event);
}

void _route(PointerEvent event) {
  GestureBinding.instance.pointerRouter.route(event);
  if (event is PointerUpEvent || event is PointerPanZoomEndEvent) {
    GestureBinding.instance.gestureArena.sweep(event.pointer);
  }
}

void _dispose(List<_Node> nodes) {
  for (final node in nodes) {
    node.transform.dispose();
    node.team.dispose();
  }
}

class _OppositeVelocity extends VelocityTracker {
  _OppositeVelocity() : super.withKind(PointerDeviceKind.touch);

  @override
  VelocityEstimate getVelocityEstimate() => VelocityEstimate(
    pixelsPerSecond: Offset(0, 1000),
    confidence: 1,
    duration: Duration(milliseconds: 16),
    offset: Offset(0, -16),
  );
}
