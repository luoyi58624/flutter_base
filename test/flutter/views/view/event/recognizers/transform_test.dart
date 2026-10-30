import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/views/view/event/press.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recognizer_test_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('拖拽升级缩放由识别器结清每个成员，无需 Render 补发 Cancel', (tester) async {
    final trace = <String>[];
    final parent = TransformRecognizer()
      ..cancelDragOnScale = true
      ..callbacks[ElEventPhase.dragStart] = ((_) => trace.add('parent.drag'))
      ..callbacks[ElEventPhase.dragCancel] = ((_) => trace.add('parent.cancel'))
      ..callbacks[ElEventPhase.dragEnd] = ((_) => trace.add('parent.end'))
      ..callbacks[ElEventPhase.scaleStart] = (_) => trace.add('parent.scale');
    final child = TransformRecognizer()
      ..parent = parent
      ..cancelDragOnScale = true
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = ((_) => trace.add('child.drag'))
      ..callbacks[ElEventPhase.dragCancel] = ((_) => trace.add('child.cancel'))
      ..callbacks[ElEventPhase.dragEnd] = ((_) => trace.add('child.end'))
      ..callbacks[ElEventPhase.scaleStart] = (_) => trace.add('child.scale');
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    final first = TestPointer(1900);
    final second = TestPointer(1901);
    _down(first.down(Offset.zero), [child, parent]);
    _route(first.move(const Offset(10, 0)));
    _down(second.down(const Offset(30, 0)), [child, parent]);
    expect(trace, ['child.drag', 'parent.drag', 'child.cancel', 'parent.cancel', 'child.scale', 'parent.scale']);
    expect([child.isDragging, parent.isDragging], [false, false]);
    _route(second.up());
    _route(first.up());
    expect(trace, hasLength(6));
  });

  testWidgets('升级取消回调重入整体 cancel，已公开的拖拽各有且只有一个终态', (tester) async {
    final trace = <String>[];
    final parent = TransformRecognizer()
      ..cancelDragOnScale = true
      ..callbacks[ElEventPhase.dragStart] = ((_) => trace.add('parent.start'))
      ..callbacks[ElEventPhase.dragCancel] = (_) => trace.add('parent.cancel');
    late TransformRecognizer child;
    child = TransformRecognizer()
      ..parent = parent
      ..cancelDragOnScale = true
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = ((_) => trace.add('child.start'))
      ..callbacks[ElEventPhase.dragCancel] = (_) {
        trace.add('child.cancel');
        child.cancel();
      }
      ..callbacks[ElEventPhase.scaleStart] = (_) => trace.add('scale');
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    final first = TestPointer(1902);
    final second = TestPointer(1903);
    _down(first.down(Offset.zero), [child, parent]);
    _route(first.move(const Offset(10, 0)));
    _down(second.down(const Offset(30, 0)), [child, parent]);
    _route(second.up());
    _route(first.up());
    expect(trace, ['child.start', 'parent.start', 'child.cancel', 'parent.cancel']);
  });

  testWidgets('取消 Drag 不使同次 Scale 回调失效，禁用 Scale 后不得误取消 Drag', (tester) async {
    final trace = <String>[];
    late TransformRecognizer drag;
    drag = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = ((_) => trace.add('drag'))
      ..callbacks[ElEventPhase.dragCancel] = ((_) => trace.add('cancel'))
      ..callbacks[ElEventPhase.dragEnd] = ((_) => trace.add('end'))
      ..callbacks[ElEventPhase.scaleStart] = (event) {
        trace.add('scale');
        drag.cancelMember(event.pointer, cancelScale: false);
        expect(event.isActive, isTrue);
      };
    addTearDown(drag.dispose);
    final first = TestPointer(1904);
    final second = TestPointer(1905);
    _down(first.down(Offset.zero), [drag]);
    _route(first.move(const Offset(10, 0)));
    _down(second.down(const Offset(30, 0)), [drag]);
    _route(second.up());
    _route(first.up());
    expect(trace, ['drag', 'scale', 'cancel']);

    trace.clear();
    drag
      ..cancelDragOnScale = true
      ..callbacks[ElEventPhase.dragStart] = (event) {
        trace.add('drag');
        drag.cancelMember(event.pointer, cancelDrag: false);
      };
    final third = TestPointer(1906);
    final fourth = TestPointer(1907);
    _down(third.down(Offset.zero), [drag]);
    _route(third.move(const Offset(10, 0)));
    _down(fourth.down(const Offset(30, 0)), [drag]);
    _route(fourth.up());
    _route(third.up());
    expect(trace, ['drag', 'end']);
  });

  testWidgets('属性更新从下一轮生效，清空启动距离恢复设备容差', (tester) async {
    var starts = 0;
    final drag = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (_) => starts++;
    addTearDown(drag.dispose);
    final first = TestPointer(1800);
    _down(first.down(Offset.zero), [drag]);
    drag.startDistance = null;
    _route(first.move(const Offset(3, 0)));
    expect(starts, 1);
    _route(first.up());
    final second = TestPointer(1801);
    _down(second.down(Offset.zero), [drag]);
    _route(second.move(const Offset(3, 0)));
    expect(starts, 1);
    _route(second.move(const Offset(60, 0)));
    expect(starts, 2);
    _route(second.up());
  });

  testWidgets('拖拽和变换各业务回调均可独立停止冒泡', (tester) async {
    var nextPointer = 450;
    for (final phase in [
      ElEventPhase.dragDown,
      ElEventPhase.dragStart,
      ElEventPhase.dragUpdate,
      ElEventPhase.scaleStart,
      ElEventPhase.scaleUpdate,
      ElEventPhase.rotationUpdate,
    ]) {
      final trace = <(bool, ElEventPhase)>[];
      final parent = TransformRecognizer();
      final child = TransformRecognizer()
        ..parent = parent
        ..startDistance = 2;
      void wire(TransformRecognizer recognizer, bool isChild) {
        void record(TransformGestureDetails details) {
          trace.add((isChild, details.phase));
          if (isChild && details.phase == phase) details.stopPropagation();
        }

        recognizer
          ..callbacks[ElEventPhase.dragDown] = record
          ..callbacks[ElEventPhase.dragStart] = record
          ..callbacks[ElEventPhase.dragUpdate] = record
          ..callbacks[ElEventPhase.dragEnd] = record
          ..callbacks[ElEventPhase.dragCancel] = record
          ..callbacks[ElEventPhase.scaleStart] = record
          ..callbacks[ElEventPhase.scaleUpdate] = record
          ..callbacks[ElEventPhase.scaleEnd] = record
          ..callbacks[ElEventPhase.scaleCancel] = record
          ..callbacks[ElEventPhase.rotationUpdate] = record;
      }

      wire(parent, false);
      wire(child, true);
      final pointer = nextPointer++;
      final p = TestPointer(pointer, PointerDeviceKind.trackpad);
      final start = p.panZoomStart(Offset.zero);
      child.addPointerPanZoom(start);
      parent.addPointerPanZoom(start);
      GestureBinding.instance.gestureArena.close(pointer);
      _route(start);
      _route(p.panZoomUpdate(Offset.zero, pan: const Offset(10, 0), scale: 1.2));
      _route(p.panZoomUpdate(Offset.zero, pan: const Offset(20, 0), scale: 1.5, rotation: 0.2));
      _route(p.panZoomEnd());
      expect(trace, contains((true, phase)), reason: phase.name);
      expect(trace, isNot(contains((false, phase))), reason: phase.name);
      child.dispose();
      parent.dispose();
    }
  });

  testWidgets('主动取消单指保留其他指针，整体取消唯一结清后可再次识别', (tester) async {
    final phases = <ElEventPhase>[];
    final drag = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (event) {
        phases.add(event.phase);
      }
      ..callbacks[ElEventPhase.dragEnd] = (event) {
        phases.add(event.phase);
      }
      ..callbacks[ElEventPhase.dragCancel] = (event) {
        phases.add(event.phase);
      }
      ..callbacks[ElEventPhase.scaleStart] = (event) {
        phases.add(event.phase);
      }
      ..callbacks[ElEventPhase.scaleCancel] = (event) {
        phases.add(event.phase);
      };
    final p = TestPointer(420);
    final q = TestPointer(421);
    _down(p.down(Offset.zero), [drag]);
    _route(p.move(const Offset(10, 0)));
    _down(q.down(const Offset(30, 0)), [drag]);
    drag.cancelPointer(421);
    expect(phases, [ElEventPhase.dragStart, ElEventPhase.scaleStart]);
    drag.cancel();
    drag.cancel();
    _route(q.up());
    _route(p.up());
    expect(phases.last, ElEventPhase.dragCancel);
    expect(phases.where((phase) => phase == ElEventPhase.dragCancel), hasLength(1));
    expect(phases.where((phase) => phase == ElEventPhase.scaleCancel), hasLength(1));
    final next = TestPointer(422);
    _down(next.down(Offset.zero), [drag]);
    _route(next.move(const Offset(10, 0)));
    _route(next.up());
    expect(phases.last, ElEventPhase.dragEnd);
    drag.dispose();
  });

  testWidgets('截断清理中祖先销毁所有者，仍结清更外层已公开的候选', (tester) async {
    final trace = <String>[];
    final root = recordingDrag(trace, 'root');
    final middle = recordingDrag(trace, 'middle', parent: root);
    final child = recordingDrag(trace, 'child', parent: middle)
      ..callbacks[ElEventPhase.dragStart] = (event) {
        trace.add('child.start');
        event.stopPropagation();
      };
    middle.callbacks[ElEventPhase.dragCancel] = (_) {
      trace.add('middle.cancel');
      child.dispose();
    };
    addTearDown(root.dispose);
    addTearDown(middle.dispose);
    addTearDown(child.dispose);
    final p = TestPointer(360);
    _down(p.down(Offset.zero), [child, middle, root]);
    _route(p.move(const Offset(12, 0)));
    _route(p.up());
    expect(trace, [
      'child.down',
      'middle.down',
      'root.down',
      'child.start',
      'middle.cancel',
      'child.cancel',
      'root.cancel',
    ]);
  });

  testWidgets('最新 driver 尚未移动就释放时，End 使用该指针坐标且忽略 Up 跳变', (tester) async {
    TransformGestureDetails? end;
    final drag = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragEnd] = (event) => end = event;
    addTearDown(drag.dispose);
    final first = TestPointer(350);
    final second = TestPointer(351);
    _down(first.down(Offset.zero), [drag]);
    _route(first.move(const Offset(10, 0)));
    _down(second.down(const Offset(100, 0)), [drag]);
    _route(first.up());
    _route(const PointerUpEvent(pointer: 351, position: Offset(1000, 0)));
    expect(end!.globalPosition, const Offset(100, 0));
    expect(end!.dragOffset, Offset.zero);
    expect(end!.velocity, Velocity.zero);
  });

  testWidgets('ScaleEnd 内销毁仍向祖先结清 Scale 与 Drag 两个已开始家族', (tester) async {
    final trace = <String>[];
    final parent = recordingDrag(trace, 'parent');
    parent.callbacks[ElEventPhase.scaleStart] = (_) => trace.add('parent.scaleStart');
    parent.callbacks[ElEventPhase.scaleEnd] = (_) => trace.add('parent.scaleEnd');
    late TransformRecognizer child;
    child = recordingDrag(trace, 'child', parent: parent);
    child.callbacks[ElEventPhase.scaleStart] = (_) => trace.add('child.scaleStart');
    child.callbacks[ElEventPhase.scaleEnd] = (_) {
      trace.add('child.scaleEnd');
      child.dispose();
    };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    final p = TestPointer(340, PointerDeviceKind.trackpad);
    final start = p.panZoomStart(Offset.zero);
    child.addPointerPanZoom(start);
    parent.addPointerPanZoom(start);
    GestureBinding.instance.gestureArena.close(340);
    _route(start);
    _route(p.panZoomUpdate(Offset.zero, pan: const Offset(12, 0), scale: 1.2));
    _route(p.panZoomEnd());
    expect(trace, [
      'child.down',
      'parent.down',
      'child.start',
      'parent.start',
      'child.scaleStart',
      'parent.scaleStart',
      'child.scaleEnd',
      'parent.scaleEnd',
      'parent.end',
    ]);
  });

  for (final cancel in [false, true]) {
    testWidgets('终态停止冒泡仍向已开始的祖先结清唯一终态：cancel=$cancel', (tester) async {
      final trace = <String>[];
      final parent = recordingDrag(trace, 'parent');
      final child = recordingDrag(trace, 'child', parent: parent);
      void stop(TransformGestureDetails event) {
        trace.add('child.${cancel ? 'cancel' : 'end'}');
        event.stopPropagation();
      }

      child.callbacks[ElEventPhase.dragEnd] = stop;
      child.callbacks[ElEventPhase.dragCancel] = stop;
      addTearDown(child.dispose);
      addTearDown(parent.dispose);
      final p = TestPointer(301);
      _down(p.down(Offset.zero), [child, parent]);
      _route(p.move(const Offset(12, 0)));
      _route(cancel ? p.cancel() : p.up());
      child.dispose();
      expect(trace, [
        'child.down',
        'parent.down',
        'child.start',
        'parent.start',
        'child.${cancel ? 'cancel' : 'end'}',
        'parent.${cancel ? 'cancel' : 'end'}',
      ]);
    });
  }

  testWidgets('Start 截断时同步取消已经收到 Down 的祖先，之后不重复结算', (tester) async {
    final trace = <String>[];
    final parent = recordingDrag(trace, 'parent');
    final child = recordingDrag(trace, 'child', parent: parent)
      ..callbacks[ElEventPhase.dragStart] = (event) {
        trace.add('child.start');
        event.stopPropagation();
      };
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    final p = TestPointer(302);
    _down(p.down(Offset.zero), [child, parent]);
    _route(p.move(const Offset(12, 0)));
    expect(trace, ['child.down', 'parent.down', 'child.start', 'parent.cancel']);
    _route(p.up());
    expect(trace.last, 'child.end');
    expect(trace.where((e) => e == 'parent.cancel'), hasLength(1));
    expect(trace, isNot(contains('parent.end')));
  });

  for (final timing in ['continuous', 'paused', 'deliveryDelay', 'synthesized', 'sparse']) {
    testWidgets('甩出速度使用真实采样与事件时间：$timing', (tester) async {
      TransformGestureDetails? end;
      final drag = TransformRecognizer()
        ..axis = Axis.horizontal
        ..startDistance = 2
        ..minFlingDistance = 3
        ..callbacks[ElEventPhase.dragStart] = (_) {}
        ..callbacks[ElEventPhase.dragEnd] = (event) => end = event;
      addTearDown(drag.dispose);
      final p = TestPointer(310);
      _down(p.down(Offset.zero), [drag]);
      final samples = timing == 'sparse' ? 1 : 3;
      for (var i = 1; i <= samples; i++) {
        _route(p.move(Offset(i * 20.0, 0), timeStamp: Duration(milliseconds: i * 10)));
      }
      if (timing == 'deliveryDelay') {
        await tester.pump(const Duration(milliseconds: 150));
      }
      final releaseMs = timing == 'paused' ? 500 : samples * 10 + 2;
      if (timing == 'synthesized' || timing == 'paused') {
        _route(
          PointerMoveEvent(
            pointer: 310,
            position: const Offset(1000, 0),
            delta: const Offset(940, 0),
            buttons: kPrimaryButton,
            synthesized: true,
            timeStamp: Duration(milliseconds: releaseMs),
          ),
        );
      }
      _route(p.up(timeStamp: Duration(milliseconds: releaseMs)));
      expect(
        end!.velocity.pixelsPerSecond.dx,
        closeTo(timing == 'paused' ? 0 : (timing == 'sparse' ? 3333.333333 : 2000), 0.01),
      );
      if (timing == 'synthesized') {
        expect(end!.dragOffset, const Offset(980, 0));
      }
    });
  }

  testWidgets('取消其中一根已接受指针不结束 Drag，最后一指释放才发 End', (tester) async {
    final phases = <ElEventPhase>[];
    final drag = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (e) {
        phases.add(e.phase);
      }
      ..callbacks[ElEventPhase.dragEnd] = (e) {
        phases.add(e.phase);
      }
      ..callbacks[ElEventPhase.dragCancel] = (e) {
        phases.add(e.phase);
      };
    addTearDown(drag.dispose);
    final first = TestPointer(320);
    final second = TestPointer(321);
    _down(first.down(Offset.zero), [drag]);
    _route(first.move(const Offset(10, 0)));
    _down(second.down(const Offset(100, 0)), [drag]);
    _route(second.cancel());
    expect(phases, [ElEventPhase.dragStart]);
    _route(first.move(const Offset(15, 0)));
    _route(first.up());
    expect(phases, [ElEventPhase.dragStart, ElEventPhase.dragEnd]);
  });

  testWidgets('Scale 终态停止冒泡仍结清祖先，指针增减重基准不跳比例', (tester) async {
    final trace = <String>[];
    final values = <double>[];
    final parent = TransformRecognizer()
      ..callbacks[ElEventPhase.scaleStart] = (_) {
        trace.add('parent.start');
      }
      ..callbacks[ElEventPhase.scaleEnd] = (_) {
        trace.add('parent.end');
      };
    final child = TransformRecognizer()
      ..parent = parent
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.scaleStart] = (_) {
        trace.add('child.start');
      }
      ..callbacks[ElEventPhase.scaleUpdate] = (event) {
        values.add(event.scale);
      }
      ..callbacks[ElEventPhase.scaleEnd] = (event) {
        trace.add('child.end');
        event.stopPropagation();
      };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    final p = TestPointer(330);
    final q = TestPointer(331);
    final r = TestPointer(332);
    _down(p.down(Offset.zero), [child, parent]);
    _route(p.move(const Offset(10, 0)));
    _down(q.down(const Offset(30, 0)), [child, parent]);
    _route(q.move(const Offset(50, 0)));
    expect(values.single, 2);
    _down(r.down(const Offset(100, 0)), [child, parent]);
    _route(r.move(const Offset(100, 0)));
    expect(values.last, closeTo(2, 0.0001));
    _route(r.up());
    _route(q.move(const Offset(50, 0)));
    expect(values.last, closeTo(2, 0.0001));
    _route(q.up());
    _route(p.up());
    expect(trace, ['child.start', 'parent.start', 'child.end', 'parent.end']);
  });

  testWidgets('El 拖拽先过阈值后，官方拖拽和 Tap 都不能激活', (tester) async {
    final phases = <ElEventPhase>[];
    var officialDrag = 0;
    var officialTap = 0;
    final transform = TransformRecognizer()
      ..axis = Axis.horizontal
      ..startDistance = 4
      ..callbacks[ElEventPhase.dragStart] = (event) {
        phases.add(event.phase);
      }
      ..callbacks[ElEventPhase.dragUpdate] = (event) {
        phases.add(event.phase);
      }
      ..callbacks[ElEventPhase.dragEnd] = (event) {
        phases.add(event.phase);
      };
    final drag = HorizontalDragGestureRecognizer()
      ..onStart = (_) {
        officialDrag++;
      };
    final tap = TapGestureRecognizer()
      ..onTap = () {
        officialTap++;
      };
    addTearDown(transform.dispose);
    addTearDown(drag.dispose);
    addTearDown(tap.dispose);
    final pointer = TestPointer(1);
    _down(pointer.down(Offset.zero), [transform, drag, tap]);
    _route(pointer.move(const Offset(8, 0)));
    _route(pointer.move(const Offset(80, 0)));
    _route(pointer.up());
    expect(phases, [ElEventPhase.dragStart, ElEventPhase.dragUpdate, ElEventPhase.dragEnd]);
    expect(officialDrag, 0);
    expect(officialTap, 0);
  });

  testWidgets('官方拖拽获胜后 El 立即取消，下一轮可以重新识别', (tester) async {
    var starts = 0;
    var updates = 0;
    var cancels = 0;
    var officialStarts = 0;
    final transform = TransformRecognizer()
      ..axis = Axis.vertical
      ..startDistance = 60
      ..callbacks[ElEventPhase.dragStart] = (_) {
        starts++;
      }
      ..callbacks[ElEventPhase.dragUpdate] = (_) {
        updates++;
      }
      ..callbacks[ElEventPhase.dragCancel] = (_) {
        cancels++;
      };
    final official = VerticalDragGestureRecognizer()
      ..onStart = (_) {
        officialStarts++;
      };
    addTearDown(transform.dispose);
    addTearDown(official.dispose);
    final pointer = TestPointer(2);
    _down(pointer.down(Offset.zero), [official, transform]);
    _route(pointer.move(const Offset(0, 30)));
    _route(pointer.move(const Offset(0, 100)));
    _route(pointer.up());
    expect((starts, updates, cancels, officialStarts), (0, 0, 1, 1));
    final next = TestPointer(3);
    _down(next.down(Offset.zero), [transform]);
    _route(next.move(const Offset(0, 80)));
    _route(next.up());
    expect(starts, 1);
  });

  testWidgets('单轴尊重起手方向，双轴锁定只输出胜出轴', (tester) async {
    final values = <TransformGestureDetails>[];
    final vertical = TransformRecognizer()
      ..axis = Axis.vertical
      ..startDistance = 3
      ..callbacks[ElEventPhase.dragStart] = values.add;
    final lock = TransformRecognizer()
      ..lockAxis = true
      ..startDistance = 3
      ..callbacks[ElEventPhase.dragStart] = values.add
      ..callbacks[ElEventPhase.dragUpdate] = values.add;
    addTearDown(vertical.dispose);
    addTearDown(lock.dispose);
    final p = TestPointer(4);
    _down(p.down(Offset.zero), [vertical]);
    _route(p.move(const Offset(20, 2)));
    expect(values, isEmpty);
    _route(p.move(const Offset(20, 30)));
    expect(values.single.dragAxis, Axis.vertical);
    _route(p.up());
    values.clear();
    final q = TestPointer(5);
    _down(q.down(Offset.zero), [lock]);
    _route(q.move(const Offset(8, 2)));
    _route(q.move(const Offset(10, 30)));
    expect(values.first.dragAxis, Axis.horizontal);
    expect(values.last.delta, const Offset(2, 0));
    expect(values.last.dragOffset, const Offset(2, 0));
    _route(q.up());
  });

  testWidgets('正式拖拽首帧不追补 slop，坐标按官方变换回到本地', (tester) async {
    final values = <TransformGestureDetails>[];
    final transform = TransformRecognizer()
      ..axis = Axis.horizontal
      ..startDistance = 5
      ..callbacks[ElEventPhase.dragStart] = values.add
      ..callbacks[ElEventPhase.dragUpdate] = values.add;
    addTearDown(transform.dispose);
    final matrix = Matrix4.diagonal3Values(0.5, 0.5, 1);
    final pointer = TestPointer(6);
    _down(pointer.down(const Offset(10, 10)).transformed(matrix), [transform]);
    _route(pointer.move(const Offset(30, 10)));
    expect(values.single.localPosition, const Offset(15, 5));
    expect(values.single.dragOffset, Offset.zero);
    _route(pointer.move(const Offset(38, 12)));
    expect(values.last.localDelta, const Offset(4, 0));
    expect(values.last.delta, const Offset(8, 0));
    expect(values.last.dragOffset, const Offset(8, 0));
    _route(pointer.up());
  });

  testWidgets('拖拽中追加指针落败，不切换 driver 或触发幽灵缩放', (tester) async {
    var scaleStarts = 0;
    final updates = <Offset>[];
    final transform = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragUpdate] = (event) {
        updates.add(event.delta);
      }
      ..callbacks[ElEventPhase.scaleStart] = (_) {
        scaleStarts++;
      };
    final eager = EagerGestureRecognizer();
    addTearDown(transform.dispose);
    addTearDown(eager.dispose);
    final p = TestPointer(7);
    _down(p.down(Offset.zero), [transform]);
    _route(p.move(const Offset(10, 0)));
    final q = TestPointer(8);
    _down(q.down(const Offset(100, 0)), [eager, transform]);
    _route(q.move(const Offset(300, 0)));
    _route(p.move(const Offset(14, 0)));
    expect(updates, [const Offset(4, 0)]);
    expect(scaleStarts, 0);
    _route(q.up());
    _route(p.up());
  });

  testWidgets('latestPointer 只由已获胜的新指针接管，抬起无位移跳变', (tester) async {
    final updates = <Offset>[];
    final transform = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragUpdate] = (event) {
        updates.add(event.delta);
      };
    addTearDown(transform.dispose);
    final p = TestPointer(9);
    _down(p.down(Offset.zero), [transform]);
    _route(p.move(const Offset(10, 0)));
    final q = TestPointer(10);
    _down(q.down(const Offset(100, 0)), [transform]);
    _route(p.move(const Offset(20, 0)));
    _route(q.move(const Offset(106, 0)));
    _route(q.up());
    _route(p.move(const Offset(23, 0)));
    expect(updates, [const Offset(6, 0), const Offset(3, 0)]);
    _route(p.up());
  });

  testWidgets('单指拖拽升级缩放，剩余单指继续同一拖拽生命周期', (tester) async {
    var dragStarts = 0;
    var scaleStarts = 0;
    final scales = <double>[];
    final ends = <int>[];
    final transform = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (_) {
        dragStarts++;
      }
      ..callbacks[ElEventPhase.dragUpdate] = (_) {}
      ..callbacks[ElEventPhase.scaleStart] = (_) {
        scaleStarts++;
      }
      ..callbacks[ElEventPhase.scaleUpdate] = (event) {
        scales.add(event.scale);
      }
      ..callbacks[ElEventPhase.scaleEnd] = (event) {
        ends.add(event.pointerCount);
      };
    addTearDown(transform.dispose);
    final p = TestPointer(11);
    _down(p.down(Offset.zero), [transform]);
    _route(p.move(const Offset(10, 0)));
    final q = TestPointer(12);
    _down(q.down(const Offset(30, 0)), [transform]);
    _route(q.move(const Offset(50, 0)));
    expect(scaleStarts, 1);
    expect(scales.single, closeTo(2, 0.0001));
    _route(q.up());
    _route(p.move(const Offset(13, 0)));
    expect(dragStarts, 1);
    expect(scales, [closeTo(2, 0.0001), closeTo(2, 0.0001)]);
    expect(ends, isEmpty);
    _route(p.up());
    expect(ends, [0]);
  });

  testWidgets('触控板平移缩放共用官方竞技场，并保留连续旋转', (tester) async {
    var officialStarts = 0;
    final rotations = <double>[];
    final scales = <TransformGestureDetails>[];
    final transform = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.scaleStart] = scales.add
      ..callbacks[ElEventPhase.scaleUpdate] = scales.add
      ..callbacks[ElEventPhase.rotationUpdate] = (event) {
        rotations.add(event.rotation);
      };
    final official = PanGestureRecognizer()
      ..onStart = (_) {
        officialStarts++;
      };
    addTearDown(transform.dispose);
    addTearDown(official.dispose);
    final p = TestPointer(13, PointerDeviceKind.trackpad);
    final start = p.panZoomStart(const Offset(20, 20));
    transform.addPointerPanZoom(start);
    official.addPointerPanZoom(start);
    GestureBinding.instance.gestureArena.close(13);
    _route(start);
    _route(p.panZoomUpdate(const Offset(20, 20), pan: const Offset(5, 0)));
    _route(p.panZoomUpdate(const Offset(20, 20), pan: const Offset(8, 0), scale: 2, rotation: 3));
    _route(p.panZoomUpdate(const Offset(20, 20), pan: const Offset(10, 0), scale: 3, rotation: 6));
    expect(officialStarts, 0);
    expect(scales.last.scale, closeTo(3, 0.0001));
    expect(scales.last.pointerCount, 2);
    expect(rotations.last, closeTo(6, 0.0001));
    _route(p.panZoomEnd());
  });

  testWidgets('结束速度过滤最小距离并限幅，旋转宿主 primaryVelocity 使用本地轴', (tester) async {
    TransformGestureDetails? end;
    final transform = TransformRecognizer()
      ..axis = Axis.horizontal
      ..startDistance = 2
      ..minFlingDistance = 4
      ..minFlingVelocity = 10
      ..maxFlingVelocity = 300
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragEnd] = (event) {
        end = event;
      };
    addTearDown(transform.dispose);
    final matrix = Matrix4.rotationZ(-math.pi / 2);
    final pointer = TestPointer(14);
    _down(pointer.down(Offset.zero).transformed(matrix), [transform]);
    for (var index = 1; index <= 8; index++) {
      _route(pointer.move(Offset(0, index * 10.0), timeStamp: Duration(milliseconds: index * 10)));
    }
    _route(pointer.up(timeStamp: const Duration(milliseconds: 80)));
    expect(end!.primaryVelocity, closeTo(300, 0.01));
    expect(end!.velocity.pixelsPerSecond.dx, closeTo(0, 0.01));
    expect(end!.velocity.pixelsPerSecond.dy, closeTo(300, 0.01));
  });

  testWidgets('配置只影响下一轮，额外不支持设备不会取消现有拖拽', (tester) async {
    var starts = 0;
    var cancels = 0;
    final transform = TransformRecognizer(supportedDevices: {PointerDeviceKind.touch})
      ..startDistance = 20
      ..callbacks[ElEventPhase.dragStart] = (_) {
        starts++;
      }
      ..callbacks[ElEventPhase.dragCancel] = (_) {
        cancels++;
      };
    addTearDown(transform.dispose);
    final pointer = TestPointer(15);
    _down(pointer.down(Offset.zero), [transform]);
    transform.startDistance = 2;
    _route(pointer.move(const Offset(5, 0)));
    expect(starts, 0);
    final mouse = TestPointer(16, PointerDeviceKind.mouse);
    _down(mouse.down(Offset.zero), [transform]);
    _route(mouse.up());
    _route(pointer.move(const Offset(25, 0)));
    expect((starts, cancels), (1, 0));
    _route(pointer.up());
  });

  testWidgets('终态回调可以开始新序列，旧清理不能删除新序列', (tester) async {
    var starts = 0;
    final next = TestPointer(19);
    final transform = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (_) {
        starts++;
      };
    transform.callbacks[ElEventPhase.dragEnd] = (_) {
      transform.callbacks[ElEventPhase.dragEnd] = null;
      _down(next.down(Offset.zero), [transform]);
    };
    addTearDown(transform.dispose);
    final pointer = TestPointer(18);
    _down(pointer.down(Offset.zero), [transform]);
    _route(pointer.move(const Offset(10, 0)));
    _route(pointer.up());
    _route(next.move(const Offset(10, 0)));
    expect(starts, 2);
    _route(next.up());
  });

  testWidgets('落败新指针的宿主变换不能覆盖旧 driver 的冻结坐标', (tester) async {
    final updates = <TransformGestureDetails>[];
    final transform = TransformRecognizer()
      ..startDistance = 2
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragUpdate] = updates.add;
    final eager = EagerGestureRecognizer();
    addTearDown(transform.dispose);
    addTearDown(eager.dispose);
    final pointer = TestPointer(20);
    _down(pointer.down(Offset.zero), [transform]);
    _route(pointer.move(const Offset(10, 0)));
    final next = TestPointer(21);
    _down(next.down(const Offset(100, 0)).transformed(Matrix4.diagonal3Values(0.5, 0.5, 1)), [eager, transform]);
    _route(pointer.move(const Offset(20, 0)));
    expect(updates.single.delta, const Offset(10, 0));
    expect(updates.single.localDelta, const Offset(10, 0));
    _route(next.up());
    _route(pointer.up());
  });

  testWidgets('纯缩放候选失去新增指针后，后来的静止指针不能幽灵启动', (tester) async {
    var starts = 0;
    final transform = TransformRecognizer()
      ..callbacks[ElEventPhase.scaleStart] = (_) {
        starts++;
      };
    final eager = EagerGestureRecognizer();
    addTearDown(transform.dispose);
    addTearDown(eager.dispose);
    final p = TestPointer(22);
    _down(p.down(Offset.zero), [transform]);
    await tester.pump();
    final rejected = TestPointer(23);
    _down(rejected.down(const Offset(20, 0)), [eager, transform]);
    _route(rejected.move(const Offset(200, 0)));
    final q = TestPointer(24);
    _down(q.down(const Offset(20, 0)), [transform]);
    await tester.pump();
    expect(starts, 0);
    _route(q.move(const Offset(60, 0)));
    expect(starts, 1);
    _route(q.up());
    _route(rejected.up());
    _route(p.up());
  });

  testWidgets('未满足最小 fling 距离时高速释放仍输出零速度', (tester) async {
    TransformGestureDetails? end;
    final transform = TransformRecognizer()
      ..startDistance = 1
      ..minFlingDistance = 100
      ..minFlingVelocity = 10
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragEnd] = (event) {
        end = event;
      };
    addTearDown(transform.dispose);
    final pointer = TestPointer(25);
    _down(pointer.down(Offset.zero), [transform]);
    for (var index = 1; index <= 5; index++) {
      _route(pointer.move(Offset(index * 5.0, 0), timeStamp: Duration(milliseconds: index * 5)));
    }
    _route(pointer.up(timeStamp: const Duration(milliseconds: 25)));
    expect(end!.velocity, Velocity.zero);
  });

  testWidgets('仅旋转订阅不会因触控板纯缩放认领，纯旋转也不启动仅缩放订阅', (tester) async {
    var rotations = 0;
    var zoomStarts = 0;
    final rotate = TransformRecognizer()
      ..callbacks[ElEventPhase.rotationUpdate] = (_) {
        rotations++;
      };
    final zoom = TransformRecognizer()
      ..callbacks[ElEventPhase.scaleStart] = (_) {
        zoomStarts++;
      };
    addTearDown(rotate.dispose);
    addTearDown(zoom.dispose);
    final p = TestPointer(26, PointerDeviceKind.trackpad);
    final first = p.panZoomStart(Offset.zero);
    rotate.addPointerPanZoom(first);
    GestureBinding.instance.gestureArena.close(26);
    _route(first);
    _route(p.panZoomUpdate(Offset.zero, scale: 2));
    _route(p.panZoomUpdate(Offset.zero, scale: 3));
    expect(rotations, 0);
    _route(p.panZoomUpdate(Offset.zero, scale: 3, rotation: 0.2));
    _route(p.panZoomUpdate(Offset.zero, scale: 3, rotation: 0.3));
    expect(rotations, 1);
    _route(p.panZoomEnd());
    final q = TestPointer(27, PointerDeviceKind.trackpad);
    final second = q.panZoomStart(Offset.zero);
    zoom.addPointerPanZoom(second);
    GestureBinding.instance.gestureArena.close(27);
    _route(second);
    _route(q.panZoomUpdate(Offset.zero, rotation: 1));
    expect(zoomStarts, 0);
    _route(q.panZoomUpdate(Offset.zero, scale: 1.2, rotation: 1));
    expect(zoomStarts, 1);
    _route(q.panZoomEnd());
  });

  testWidgets('官方子拖拽先激活后，El 外层仅取消且不继续更新', (tester) async {
    final events = <String>[];
    final drag = recordingDrag(events, 'el', distance: 60);
    addTearDown(drag.dispose);
    await tester.pumpWidget(
      gestureShell(
        gestureHost(
          drag,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => events.add('official.start'),
            onHorizontalDragUpdate: (_) => events.add('official.update'),
            onHorizontalDragEnd: (_) => events.add('official.end'),
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(80, 0));
    await gesture.up();
    await tester.pump(afterGesture);

    expect(events, containsAllInOrder(['official.start', 'official.update', 'official.end']));
    expect(events.where((event) => event.startsWith('el.')), ['el.down', 'el.cancel']);
  });

  testWidgets('同一宿主的 El 拖拽获胜会取消 El 点击', (tester) async {
    final events = <String>[];
    final press = recordingPress(events, 'press');
    final drag = recordingDrag(events, 'drag');
    addTearDown(press.dispose);
    addTearDown(drag.dispose);
    await tester.pumpWidget(
      gestureShell(
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            press.addPointer(event);
            drag.addPointer(event);
          },
          child: const SizedBox(width: 200, height: 200),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.moveBy(const Offset(14, 0));
    await gesture.up();
    await tester.pump(afterGesture);

    expect(events.where((event) => event.startsWith('press.')), ['press.down', 'press.cancel']);
    expect(events, containsAllInOrder(['drag.start', 'drag.update', 'drag.end']));
  });

  testWidgets('El 多指缩放获胜后外层官方 Scale 不跟随更新', (tester) async {
    final events = <String>[];
    final transform = TransformRecognizer()..startDistance = 4;
    transform.callbacks[ElEventPhase.scaleStart] = (_) => events.add('el.start');
    transform.callbacks[ElEventPhase.scaleUpdate] = (_) => events.add('el.update');
    transform.callbacks[ElEventPhase.scaleEnd] = (_) => events.add('el.end');
    addTearDown(transform.dispose);
    await tester.pumpWidget(
      gestureShell(
        GestureDetector(
          onScaleStart: (_) => events.add('official.start'),
          onScaleUpdate: (_) => events.add('official.update'),
          onScaleEnd: (_) => events.add('official.end'),
          child: gestureHost(transform),
        ),
      ),
    );
    final first = await tester.startGesture(const Offset(80, 100), pointer: 1);
    final second = await tester.startGesture(const Offset(120, 100), pointer: 2);
    await first.moveTo(const Offset(40, 100));
    await second.moveTo(const Offset(160, 100));
    await first.moveTo(const Offset(30, 100));
    await second.up();
    await first.up();
    await tester.pump(afterGesture);

    expect(events, containsAllInOrder(['el.start', 'el.update', 'el.end']));
    expect(events.where((event) => event.startsWith('official.')), isEmpty);
  });

  testWidgets('官方 Scale 先获胜后 El 缩放候选失权，继续移动也不复活', (tester) async {
    final events = <String>[];
    final transform = TransformRecognizer()..startDistance = 100;
    transform.callbacks[ElEventPhase.scaleStart] = (_) => events.add('el.start');
    transform.callbacks[ElEventPhase.scaleUpdate] = (_) => events.add('el.update');
    transform.callbacks[ElEventPhase.scaleEnd] = (_) => events.add('el.end');
    transform.callbacks[ElEventPhase.scaleCancel] = (_) => events.add('el.cancel');
    addTearDown(transform.dispose);
    await tester.pumpWidget(
      gestureShell(
        gestureHost(
          transform,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => events.add('official.start'),
            onScaleUpdate: (_) => events.add('official.update'),
            onScaleEnd: (_) => events.add('official.end'),
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    final first = await tester.startGesture(const Offset(80, 100), pointer: 1);
    final second = await tester.startGesture(const Offset(120, 100), pointer: 2);
    await first.moveTo(const Offset(40, 100));
    await second.moveTo(const Offset(160, 100));
    await first.moveTo(const Offset(5, 100));
    await second.moveTo(const Offset(195, 100));
    await second.up();
    await first.up();
    await tester.pump(afterGesture);

    expect(events, containsAllInOrder(['official.start', 'official.update', 'official.end']));
    // Scale 没有对外 Down 候选通知，尚未开始的候选失权不制造取消生命周期。
    expect(events.where((event) => event.startsWith('el.')), isEmpty);
  });

  testWidgets('透明重叠拖拽失败分支不向共享 El 父泄漏取消', (tester) async {
    final events = <String>[];
    final parent = recordingDrag(events, 'parent');
    final back = recordingDrag(events, 'back', parent: parent);
    final front = recordingDrag(events, 'front', parent: parent);
    addTearDown(parent.dispose);
    addTearDown(back.dispose);
    addTearDown(front.dispose);
    await tester.pumpWidget(
      GestureDetector(
        onHorizontalDragDown: (_) => events.add('official.down'),
        onHorizontalDragStart: (_) => events.add('official.start'),
        onHorizontalDragCancel: () => events.add('official.cancel'),
        child: overlapHost(parent: parent, back: back, front: front),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.moveBy(const Offset(14, 0));
    await gesture.up();
    await tester.pump();

    expect(events, containsAllInOrder(['front.down', 'parent.down', 'back.down']));
    expect(events.where((event) => event.startsWith('front.')), [
      'front.down',
      'front.start',
      'front.update',
      'front.end',
    ]);
    expect(events.where((event) => event.startsWith('back.')), ['back.down', 'back.cancel']);
    expect(events.where((event) => event.startsWith('parent.')), [
      'parent.down',
      'parent.start',
      'parent.update',
      'parent.end',
    ]);
    expect(events.where((event) => event.startsWith('official.')), ['official.down', 'official.cancel']);
  });

  testWidgets('拖拽 Start 内销毁所有者时祖先不会在 Cancel 后又收到 Start', (tester) async {
    final trace = <String>[];
    final parent = TransformRecognizer()
      ..callbacks[ElEventPhase.dragDown] = (_) {
        trace.add('parent.down');
      }
      ..callbacks[ElEventPhase.dragStart] = (_) {
        trace.add('parent.start');
      }
      ..callbacks[ElEventPhase.dragCancel] = (_) => trace.add('parent.cancel');
    late TransformRecognizer child;
    child = TransformRecognizer()
      ..parent = parent
      ..startDistance = 6
      ..callbacks[ElEventPhase.dragStart] = (_) => child.dispose();
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(gestureShell(gestureHost(parent, child: gestureHost(child))));

    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.up();
    expect(trace, ['parent.down', 'parent.cancel']);
  });

  testWidgets('冒泡按各成员的官方坐标变换换算位移', (tester) async {
    final deltas = <(String, Offset)>[];
    final parent = TransformRecognizer()
      ..axis = Axis.horizontal
      ..callbacks[ElEventPhase.dragUpdate] = (event) {
        deltas.add(('parent', event.localDelta));
      };
    final child = TransformRecognizer()
      ..parent = parent
      ..axis = Axis.horizontal
      ..startDistance = 6
      ..callbacks[ElEventPhase.dragUpdate] = (event) {
        deltas.add(('child', event.localDelta));
      };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      gestureShell(
        Transform.scale(
          scale: 0.5,
          alignment: Alignment.topLeft,
          child: gestureHost(
            parent,
            child: Transform.scale(scale: 4, alignment: Alignment.topLeft, child: gestureHost(child)),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.up();
    expect(deltas, [('child', const Offset(5, 0)), ('parent', const Offset(20, 0))]);
  });
  testWidgets('协作团队允许长按获胜后继续拖拽，外部官方点击不能同时触发', (tester) async {
    final trace = <String>[];
    final team = GestureTeam();
    final press = PressRecognizer()
      ..longPressDelay = const Duration(milliseconds: 20)
      ..team = team
      ..callbacks[.longPress] = (_) => trace.add('long');
    final transform = TransformRecognizer()
      ..startDistance = 3
      ..team = team
      ..callbacks[ElEventPhase.dragStart] = (_) {
        trace.add('drag');
      }
      ..callbacks[ElEventPhase.dragEnd] = (_) => trace.add('end');
    final official = TapGestureRecognizer()..onTap = () => trace.add('official');
    addTearDown(press.dispose);
    addTearDown(transform.dispose);
    addTearDown(official.dispose);
    _down(const PointerDownEvent(pointer: 1600), [press, transform, official]);
    await tester.pump(const Duration(milliseconds: 20));
    _route(
      const PointerMoveEvent(
        pointer: 1600,
        position: Offset(10, 0),
        delta: Offset(10, 0),
        timeStamp: Duration(milliseconds: 30),
      ),
    );
    _route(const PointerUpEvent(pointer: 1600, position: Offset(10, 0), timeStamp: Duration(milliseconds: 40)));
    expect(trace, ['long', 'drag', 'end']);
  });

  testWidgets('官方拖拽获胜同步拒绝整个协作团队，主动退出成员不被重新接受', (tester) async {
    final trace = <String>[];
    final team = GestureTeam();
    final press = PressRecognizer()
      ..team = team
      ..callbacks[.tap] = (_) {
        trace.add('tap');
      }
      ..callbacks[.tapCancel] = (_) => trace.add('press.cancel');
    final transform = TransformRecognizer()
      ..startDistance = 100
      ..team = team
      ..callbacks[ElEventPhase.dragDown] = (_) {}
      ..callbacks[ElEventPhase.dragStart] = (_) {
        trace.add('el.drag');
      }
      ..callbacks[ElEventPhase.dragCancel] = (_) => trace.add('drag.cancel');
    final official = VerticalDragGestureRecognizer()..onStart = (_) => trace.add('official.drag');
    addTearDown(press.dispose);
    addTearDown(transform.dispose);
    addTearDown(official.dispose);
    _down(const PointerDownEvent(pointer: 1601), [press, transform, official]);
    press.cancel();
    _route(const PointerMoveEvent(pointer: 1601, position: Offset(0, 30), delta: Offset(0, 30)));
    _route(const PointerUpEvent(pointer: 1601, position: Offset(0, 30)));
    expect(trace, ['press.cancel', 'drag.cancel', 'official.drag']);
  });

  for (final enabled in [false, true]) {
    testWidgets('纯旋转启动开关对仅 Scale 订阅生效：$enabled', (tester) async {
      var starts = 0;
      final recognizer = TransformRecognizer()
        ..rotationStartEnabled = enabled
        ..callbacks[ElEventPhase.scaleStart] = (_) => starts++;
      addTearDown(recognizer.dispose);
      final first = TestPointer(1700);
      final second = TestPointer(1701);
      _down(first.down(Offset(-50, 0)), [recognizer]);
      _down(second.down(Offset(50, 0)), [recognizer]);
      _route(first.move(Offset(-50 * math.cos(0.5), -50 * math.sin(0.5))));
      _route(second.move(Offset(50 * math.cos(0.5), 50 * math.sin(0.5))));
      expect(starts, enabled ? 1 : 0);
      _route(second.up());
      _route(first.up());
    });
  }

  testWidgets('仅 Scale 订阅可以单指平移，最后释放提供真实平移速度', (tester) async {
    final updates = <TransformGestureDetails>[];
    TransformGestureDetails? end;
    var starts = 0;
    final recognizer = TransformRecognizer()
      ..callbacks[ElEventPhase.scaleStart] = (_) {
        starts++;
      }
      ..callbacks[ElEventPhase.scaleUpdate] = updates.add
      ..callbacks[ElEventPhase.scaleEnd] = (event) => end = event;
    addTearDown(recognizer.dispose);
    final pointer = TestPointer(1702);
    _down(pointer.down(Offset.zero), [recognizer]);
    for (var index = 1; index <= 4; index++) {
      _route(pointer.move(Offset(index * 20.0, 0), timeStamp: Duration(milliseconds: index * 10)));
    }
    expect(starts, 1);
    expect(updates.map((event) => event.pointerCount), [1, 1]);
    expect(updates.map((event) => event.delta), [Offset(20, 0), Offset(20, 0)]);
    expect(updates.every((event) => event.scale == 1), isTrue);
    _route(pointer.up(timeStamp: Duration(milliseconds: 42)));
    expect(end!.pointerCount, 0);
    expect(end!.velocity.pixelsPerSecond.dx, closeTo(2000, 0.01));
  });

  testWidgets('自定义速度估计器只接真实输入，运行中替换从下一轮生效', (tester) async {
    final tracker = _FixedVelocityTracker(Offset(321, 45));
    final unused = _FixedVelocityTracker(Offset(999, 0));
    TransformGestureDetails? end;
    var created = 0;
    final recognizer = TransformRecognizer()
      ..axis = Axis.horizontal
      ..startDistance = 2
      ..minFlingDistance = 1
      ..velocityTrackerBuilder = (_) {
        created++;
        return tracker;
      }
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragEnd] = (event) => end = event;
    addTearDown(recognizer.dispose);
    final pointer = TestPointer(1703);
    _down(pointer.down(Offset.zero), [recognizer]);
    recognizer.velocityTrackerBuilder = (_) => unused;
    _route(pointer.move(Offset(10, 0), timeStamp: Duration(milliseconds: 10)));
    _route(
      PointerMoveEvent(
        pointer: 1703,
        position: Offset(100, 0),
        buttons: kPrimaryButton,
        synthesized: true,
        timeStamp: Duration(milliseconds: 11),
      ),
    );
    _route(pointer.move(Offset(20, 0), timeStamp: Duration(milliseconds: 20)));
    _route(pointer.up(timeStamp: Duration(milliseconds: 22)));
    expect(created, 1);
    expect(tracker.positions, [Offset.zero, Offset(10, 0), Offset(20, 0)]);
    expect(unused.positions, isEmpty);
    expect(end!.velocity.pixelsPerSecond, Offset(321, 0));
  });

  for (final strategy in MultitouchDragStrategy.values) {
    testWidgets('多指策略保留各自位移且触点抬起不跳变：$strategy', (tester) async {
      final updates = <Offset>[];
      final recognizer = TransformRecognizer()
        ..axis = Axis.horizontal
        ..startDistance = 2
        ..multitouchDragStrategy = strategy
        ..callbacks[ElEventPhase.dragStart] = (_) {}
        ..callbacks[ElEventPhase.dragUpdate] = (event) => updates.add(event.delta);
      addTearDown(recognizer.dispose);
      final first = TestPointer(1704);
      final second = TestPointer(1705);
      _down(first.down(Offset.zero), [recognizer]);
      _route(first.move(Offset(10, 0), timeStamp: Duration(milliseconds: 10)));
      _down(second.down(Offset(30, 0), timeStamp: Duration(milliseconds: 20)), [recognizer]);
      _route(first.move(Offset(14, 0), timeStamp: Duration(milliseconds: 32)));
      _route(second.move(Offset(36, 0), timeStamp: Duration(milliseconds: 33)));
      final beforeRelease = switch (strategy) {
        MultitouchDragStrategy.latestPointer => [Offset(6, 0)],
        MultitouchDragStrategy.sumAllPointers => [Offset(4, 0), Offset(6, 0)],
        MultitouchDragStrategy.averageBoundaryPointers => [Offset(4, 0), Offset(2, 0)],
      };
      expect(updates, beforeRelease);
      _route(second.up(timeStamp: Duration(milliseconds: 40)));
      _route(first.move(Offset(17, 0), timeStamp: Duration(milliseconds: 48)));
      expect(updates, [...beforeRelease, Offset(3, 0)]);
      _route(first.up(timeStamp: Duration(milliseconds: 50)));
    });
  }

  testWidgets('边界平均的空闲帧桶遵循注入刷新率', (tester) async {
    final deltas = <Offset>[];
    final recognizer = TransformRecognizer()
      ..axis = Axis.horizontal
      ..startDistance = 2
      ..multitouchDragStrategy = MultitouchDragStrategy.averageBoundaryPointers
      ..displayRefreshRate = (() => 120)
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragUpdate] = (event) => deltas.add(event.delta);
    addTearDown(recognizer.dispose);
    final first = TestPointer(1706);
    final second = TestPointer(1707);
    _down(first.down(Offset.zero), [recognizer]);
    _route(first.move(Offset(10, 0), timeStamp: Duration(milliseconds: 10)));
    _down(second.down(Offset(30, 0), timeStamp: Duration(milliseconds: 20)), [recognizer]);
    _route(first.move(Offset(14, 0), timeStamp: Duration(milliseconds: 32)));
    _route(second.move(Offset(36, 0), timeStamp: Duration(milliseconds: 42)));
    expect(deltas, [Offset(4, 0), Offset(6, 0)]);
    _route(second.up());
    _route(first.up());
  });

  testWidgets('短促轻扫未过起拖距离也补零位移 Start 和 End', (tester) async {
    final phases = <ElEventPhase>[];
    TransformGestureDetails? end;
    final recognizer = TransformRecognizer()
      ..axis = Axis.horizontal
      ..startDistance = 100
      ..minFlingDistance = 1
      ..minFlingVelocity = 10
      ..callbacks[ElEventPhase.dragStart] = (event) {
        phases.add(event.phase);
      }
      ..callbacks[ElEventPhase.dragUpdate] = (event) {
        phases.add(event.phase);
      }
      ..callbacks[ElEventPhase.dragEnd] = (event) {
        phases.add(event.phase);
        end = event;
      };
    addTearDown(recognizer.dispose);
    final pointer = TestPointer(1708);
    _down(pointer.down(Offset.zero), [recognizer]);
    _route(pointer.move(Offset(4, 0), timeStamp: Duration(milliseconds: 8)));
    _route(pointer.move(Offset(8, 0), timeStamp: Duration(milliseconds: 16)));
    expect(phases, isEmpty);
    _route(pointer.up(timeStamp: Duration(milliseconds: 20)));
    expect(phases, [ElEventPhase.dragStart, ElEventPhase.dragEnd]);
    expect(end!.dragOffset, Offset.zero);
    expect(end!.velocity.pixelsPerSecond.dx, greaterThan(10));
    expect(end!.dragAxis, Axis.horizontal);
  });

  for (final age in [80, 81]) {
    testWidgets('缩放速度跨单指释放保留且严格按输入时间过期：${age}ms', (tester) async {
      TransformGestureDetails? end;
      final recognizer = TransformRecognizer()
        ..callbacks[ElEventPhase.scaleStart] = (_) {}
        ..callbacks[ElEventPhase.scaleEnd] = (event) => end = event;
      addTearDown(recognizer.dispose);
      final first = TestPointer(1709);
      final second = TestPointer(1710);
      _down(first.down(Offset.zero), [recognizer]);
      _down(second.down(Offset(100, 0)), [recognizer]);
      _route(second.move(Offset(140, 0), timeStamp: Duration(milliseconds: 10)));
      _route(second.move(Offset(160, 0), timeStamp: Duration(milliseconds: 20)));
      _route(second.up(timeStamp: Duration(milliseconds: 21)));
      expect(end, isNull);
      _route(first.up(timeStamp: Duration(milliseconds: 20 + age)));
      expect(end!.logScaleVelocity, closeTo(age == 80 ? math.log(8 / 7) / 0.01 : 0, 0.0001));
      expect(end!.globalPosition, age == 80 ? Offset(80, 0) : Offset.zero, reason: '缩放惯性沿最后一次有效双指焦点继续，速度过期后使用剩余触点位置');
    });
  }

  testWidgets('缩放降单指后的真实平移清除旧缩放惯性', (tester) async {
    TransformGestureDetails? end;
    final recognizer = TransformRecognizer()
      ..callbacks[ElEventPhase.scaleStart] = (_) {}
      ..callbacks[ElEventPhase.scaleUpdate] = (_) {}
      ..callbacks[ElEventPhase.scaleEnd] = (event) => end = event;
    addTearDown(recognizer.dispose);
    final first = TestPointer(1711);
    final second = TestPointer(1712);
    _down(first.down(Offset.zero), [recognizer]);
    _down(second.down(Offset(100, 0)), [recognizer]);
    _route(second.move(Offset(140, 0), timeStamp: Duration(milliseconds: 10)));
    _route(second.move(Offset(160, 0), timeStamp: Duration(milliseconds: 20)));
    _route(second.up(timeStamp: Duration(milliseconds: 21)));
    _route(first.move(Offset(10, 0), timeStamp: Duration(milliseconds: 30)));
    _route(first.up(timeStamp: Duration(milliseconds: 32)));
    expect(end!.scale, closeTo(8 / 7, 0.0001));
    expect(end!.logScaleVelocity, 0);
    expect(end!.velocity.pixelsPerSecond.dx, greaterThan(0));
  });

  for (final distance in [9.0, 72.0, 73.0]) {
    testWidgets('稀疏轻扫只信任有界 Up 终点且不污染真实采样：$distance', (tester) async {
      final tracker = _FixedVelocityTracker(Offset.zero);
      TransformGestureDetails? end;
      final recognizer = TransformRecognizer()
        ..axis = Axis.horizontal
        ..startDistance = 100
        ..minFlingDistance = 1
        ..velocityTrackerBuilder = ((_) => tracker)
        ..callbacks[ElEventPhase.dragStart] = (_) {}
        ..callbacks[ElEventPhase.dragEnd] = (event) => end = event;
      addTearDown(recognizer.dispose);
      _down(PointerDownEvent(pointer: 1713), [recognizer]);
      _route(PointerMoveEvent(pointer: 1713, buttons: kPrimaryButton, timeStamp: Duration(milliseconds: 10)));
      _route(PointerUpEvent(pointer: 1713, position: Offset(distance, 0), timeStamp: Duration(milliseconds: 20)));
      expect(tracker.positions, [Offset.zero, Offset.zero]);
      if (distance <= 72) {
        expect(end!.velocity.pixelsPerSecond.dx, closeTo(distance * 100, 0.01));
        expect(end!.globalPosition, Offset.zero);
        expect(end!.dragOffset, Offset.zero);
      } else {
        expect(end, isNull);
      }
    });
  }

  testWidgets('设备 slop 在会话开始时冻结，更新只影响下一轮', (tester) async {
    var starts = 0;
    final recognizer = TransformRecognizer()
      ..gestureSettings = DeviceGestureSettings(touchSlop: 5)
      ..callbacks[ElEventPhase.dragStart] = (_) => starts++;
    addTearDown(recognizer.dispose);
    final first = TestPointer(1714);
    _down(first.down(Offset.zero), [recognizer]);
    recognizer.gestureSettings = DeviceGestureSettings(touchSlop: 100);
    _route(first.move(Offset(12, 0)));
    expect(starts, 1);
    _route(first.up());
    final second = TestPointer(1715);
    _down(second.down(Offset.zero), [recognizer]);
    _route(second.move(Offset(12, 0)));
    _route(second.up());
    expect(starts, 1);
  });

  testWidgets('自由拖拽的边界平均按全部有效触点分配同帧位移', (tester) async {
    final deltas = <Offset>[];
    final recognizer = TransformRecognizer()
      ..startDistance = 2
      ..multitouchDragStrategy = MultitouchDragStrategy.averageBoundaryPointers
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragUpdate] = (event) => deltas.add(event.delta);
    addTearDown(recognizer.dispose);
    final first = TestPointer(1716);
    final second = TestPointer(1717);
    _down(first.down(Offset.zero), [recognizer]);
    _route(first.move(Offset(10, 0), timeStamp: Duration(milliseconds: 10)));
    _down(second.down(Offset(30, 0), timeStamp: Duration(milliseconds: 20)), [recognizer]);
    _route(first.move(Offset(14, 0), timeStamp: Duration(milliseconds: 32)));
    _route(second.move(Offset(36, 0), timeStamp: Duration(milliseconds: 33)));
    expect(deltas, [Offset(2, 0), Offset(3, 0)]);
    _route(first.up(timeStamp: Duration(milliseconds: 40)));
    _route(second.move(Offset(39, 0), timeStamp: Duration(milliseconds: 48)));
    expect(deltas, [Offset(2, 0), Offset(3, 0), Offset(3, 0)]);
    _route(second.up(timeStamp: Duration(milliseconds: 50)));
  });

  testWidgets('真实同帧输入不因指针时间戳不同重复消费边界位移', (tester) async {
    final deltas = <Offset>[];
    final recognizer = TransformRecognizer()
      ..axis = Axis.horizontal
      ..startDistance = 2
      ..multitouchDragStrategy = MultitouchDragStrategy.averageBoundaryPointers
      ..displayRefreshRate = (() => 120)
      ..callbacks[ElEventPhase.dragStart] = (_) {}
      ..callbacks[ElEventPhase.dragUpdate] = (event) => deltas.add(event.delta);
    addTearDown(recognizer.dispose);
    final first = TestPointer(1718);
    final second = TestPointer(1719);
    _down(first.down(Offset.zero), [recognizer]);
    _route(first.move(Offset(10, 0), timeStamp: Duration(milliseconds: 10)));
    _down(second.down(Offset(30, 0), timeStamp: Duration(milliseconds: 20)), [recognizer]);
    tester.binding.addPostFrameCallback((_) {
      _route(first.move(Offset(14, 0), timeStamp: Duration(milliseconds: 32)));
      _route(second.move(Offset(36, 0), timeStamp: Duration(milliseconds: 42)));
    });
    tester.binding.scheduleFrame();
    await tester.pump(Duration(milliseconds: 16));
    expect(deltas, [Offset(4, 0), Offset(2, 0)]);
    _route(second.up());
    _route(first.up());
  });

  testWidgets('ScaleEnd 使用自定义估计器的二维速度并忽略 Drag 距离门限', (tester) async {
    final tracker = _FixedVelocityTracker(Offset(321, 45));
    TransformGestureDetails? end;
    final recognizer = TransformRecognizer()
      ..minFlingDistance = 1000
      ..velocityTrackerBuilder = ((_) => tracker)
      ..callbacks[ElEventPhase.scaleStart] = (_) {}
      ..callbacks[ElEventPhase.scaleEnd] = (event) => end = event;
    addTearDown(recognizer.dispose);
    final pointer = TestPointer(1720);
    _down(pointer.down(Offset.zero), [recognizer]);
    _route(pointer.move(Offset(40, 0), timeStamp: Duration(milliseconds: 10)));
    _route(pointer.move(Offset(60, 0), timeStamp: Duration(milliseconds: 20)));
    _route(pointer.up(timeStamp: Duration(milliseconds: 22)));
    expect(end!.velocity.pixelsPerSecond, Offset(321, 45));
    expect(tracker.positions, [Offset.zero, Offset(40, 0), Offset(60, 0)]);
  });

  testWidgets('新增指针落败不清除原有缩放速度', (tester) async {
    TransformGestureDetails? end;
    final recognizer = TransformRecognizer()
      ..callbacks[ElEventPhase.scaleStart] = (_) {}
      ..callbacks[ElEventPhase.scaleEnd] = (event) => end = event;
    final eager = EagerGestureRecognizer();
    addTearDown(recognizer.dispose);
    addTearDown(eager.dispose);
    final first = TestPointer(1721);
    final second = TestPointer(1722);
    final rejected = TestPointer(1723);
    _down(first.down(Offset.zero), [recognizer]);
    _down(second.down(Offset(100, 0)), [recognizer]);
    _route(second.move(Offset(140, 0), timeStamp: Duration(milliseconds: 10)));
    _route(second.move(Offset(160, 0), timeStamp: Duration(milliseconds: 20)));
    _down(rejected.down(Offset(300, 0), timeStamp: Duration(milliseconds: 21)), [eager, recognizer]);
    _route(rejected.up(timeStamp: Duration(milliseconds: 22)));
    _route(second.up(timeStamp: Duration(milliseconds: 23)));
    _route(first.up(timeStamp: Duration(milliseconds: 24)));
    expect(end!.logScaleVelocity, closeTo(math.log(8 / 7) / 0.01, 0.0001));
  });
}

void _down(PointerDownEvent event, List<GestureRecognizer> recognizers) {
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

class _FixedVelocityTracker extends VelocityTracker {
  _FixedVelocityTracker(this.speed) : super.withKind(PointerDeviceKind.touch);

  final Offset speed;
  final List<Offset> positions = [];

  @override
  void addPosition(Duration time, Offset position) {
    positions.add(position);
    super.addPosition(time, position);
  }

  @override
  VelocityEstimate? getVelocityEstimate() => VelocityEstimate(
    pixelsPerSecond: speed,
    confidence: 1,
    duration: Duration(milliseconds: 20),
    offset: Offset(40, 0),
  );
}
