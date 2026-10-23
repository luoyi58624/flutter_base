import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/cores/event/recognizers/recognizers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recognizer_test_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('拖拽和变换各业务回调均可独立停止冒泡', (tester) async {
    var nextPointer = 450;
    for (final phase in [
      ElGesturePhase.dragDown,
      ElGesturePhase.dragStart,
      ElGesturePhase.dragUpdate,
      ElGesturePhase.scaleStart,
      ElGesturePhase.scaleUpdate,
      ElGesturePhase.rotationUpdate,
    ]) {
      final trace = <(bool, ElGesturePhase)>[];
      final parent = ElTransformGestureRecognizer();
      final child = ElTransformGestureRecognizer(
        parent: parent,
        startDistance: 2,
      );
      void wire(ElTransformGestureRecognizer recognizer, bool isChild) {
        void record(ElTransformGestureDetails details) {
          trace.add((isChild, details.phase));
          if (isChild && details.phase == phase) details.stopPropagation();
        }

        recognizer
          ..onDragDown = record
          ..onDragStart = record
          ..onDragUpdate = record
          ..onDragEnd = record
          ..onDragCancel = record
          ..onScaleStart = record
          ..onScaleUpdate = record
          ..onScaleEnd = record
          ..onScaleCancel = record
          ..onRotationUpdate = record;
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
      _route(
        p.panZoomUpdate(Offset.zero, pan: const Offset(10, 0), scale: 1.2),
      );
      _route(
        p.panZoomUpdate(
          Offset.zero,
          pan: const Offset(20, 0),
          scale: 1.5,
          rotation: 0.2,
        ),
      );
      _route(p.panZoomEnd());
      expect(trace, contains((true, phase)), reason: phase.name);
      expect(trace, isNot(contains((false, phase))), reason: phase.name);
      child.dispose();
      parent.dispose();
    }
  });

  testWidgets('主动取消单指保留其他指针，整体取消唯一结清后可再次识别', (tester) async {
    final phases = <ElGesturePhase>[];
    final drag = ElTransformGestureRecognizer(startDistance: 2)
      ..onDragStart = (event) {
        phases.add(event.phase);
      }
      ..onDragEnd = (event) {
        phases.add(event.phase);
      }
      ..onDragCancel = (event) {
        phases.add(event.phase);
      }
      ..onScaleStart = (event) {
        phases.add(event.phase);
      }
      ..onScaleCancel = (event) {
        phases.add(event.phase);
      };
    final p = TestPointer(420);
    final q = TestPointer(421);
    _down(p.down(Offset.zero), [drag]);
    _route(p.move(const Offset(10, 0)));
    _down(q.down(const Offset(30, 0)), [drag]);
    drag.cancelPointer(421);
    expect(phases, [
      ElGesturePhase.dragStart,
      ElGesturePhase.scaleStart,
      ElGesturePhase.scaleCancel,
    ]);
    drag.cancel();
    drag.cancel();
    _route(q.up());
    _route(p.up());
    expect(phases.last, ElGesturePhase.dragCancel);
    expect(
      phases.where((phase) => phase == ElGesturePhase.dragCancel),
      hasLength(1),
    );
    final next = TestPointer(422);
    _down(next.down(Offset.zero), [drag]);
    _route(next.move(const Offset(10, 0)));
    _route(next.up());
    expect(phases.last, ElGesturePhase.dragEnd);
    drag.dispose();
  });

  testWidgets('截断清理中祖先销毁所有者，仍结清更外层已公开的候选', (tester) async {
    final trace = <String>[];
    final root = recordingDrag(trace, 'root');
    final middle = recordingDrag(trace, 'middle', parent: root);
    final child = recordingDrag(trace, 'child', parent: middle)
      ..onDragStart = (event) {
        trace.add('child.start');
        event.stopPropagation();
      };
    middle.onDragCancel = (_) {
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
    ElTransformGestureDetails? end;
    final drag = ElTransformGestureRecognizer(startDistance: 2)
      ..onDragStart = (_) {}
      ..onDragEnd = (event) => end = event;
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
    parent.onScaleStart = (_) => trace.add('parent.scaleStart');
    parent.onScaleEnd = (_) => trace.add('parent.scaleEnd');
    late ElTransformGestureRecognizer child;
    child = recordingDrag(trace, 'child', parent: parent);
    child.onScaleStart = (_) => trace.add('child.scaleStart');
    child.onScaleEnd = (_) {
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
      void stop(ElTransformGestureDetails event) {
        trace.add('child.${cancel ? 'cancel' : 'end'}');
        event.stopPropagation();
      }

      child.onDragEnd = stop;
      child.onDragCancel = stop;
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
      ..onDragStart = (event) {
        trace.add('child.start');
        event.stopPropagation();
      };
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    final p = TestPointer(302);
    _down(p.down(Offset.zero), [child, parent]);
    _route(p.move(const Offset(12, 0)));
    expect(trace, [
      'child.down',
      'parent.down',
      'child.start',
      'parent.cancel',
    ]);
    _route(p.up());
    expect(trace.last, 'child.end');
    expect(trace.where((e) => e == 'parent.cancel'), hasLength(1));
    expect(trace, isNot(contains('parent.end')));
  });

  for (final timing in [
    'continuous',
    'paused',
    'deliveryDelay',
    'synthesized',
    'sparse',
  ]) {
    testWidgets('甩出速度使用真实采样与事件时间：$timing', (tester) async {
      ElTransformGestureDetails? end;
      final drag =
          ElTransformGestureRecognizer(
              axis: Axis.horizontal,
              startDistance: 2,
              minFlingDistance: 3,
            )
            ..onDragStart = (_) {}
            ..onDragEnd = (event) => end = event;
      addTearDown(drag.dispose);
      final p = TestPointer(310);
      _down(p.down(Offset.zero), [drag]);
      final samples = timing == 'sparse' ? 1 : 3;
      for (var i = 1; i <= samples; i++) {
        _route(
          p.move(
            Offset(i * 20.0, 0),
            timeStamp: Duration(milliseconds: i * 10),
          ),
        );
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
        closeTo(
          timing == 'paused' ? 0 : (timing == 'sparse' ? 3333.333333 : 2000),
          0.01,
        ),
      );
      if (timing == 'synthesized') {
        expect(end!.dragOffset, const Offset(980, 0));
      }
    });
  }

  testWidgets('取消其中一根已接受指针不结束 Drag，最后一指释放才发 End', (tester) async {
    final phases = <ElGesturePhase>[];
    final drag = ElTransformGestureRecognizer(startDistance: 2)
      ..onDragStart = (e) {
        phases.add(e.phase);
      }
      ..onDragEnd = (e) {
        phases.add(e.phase);
      }
      ..onDragCancel = (e) {
        phases.add(e.phase);
      };
    addTearDown(drag.dispose);
    final first = TestPointer(320);
    final second = TestPointer(321);
    _down(first.down(Offset.zero), [drag]);
    _route(first.move(const Offset(10, 0)));
    _down(second.down(const Offset(100, 0)), [drag]);
    _route(second.cancel());
    expect(phases, [ElGesturePhase.dragStart]);
    _route(first.move(const Offset(15, 0)));
    _route(first.up());
    expect(phases, [ElGesturePhase.dragStart, ElGesturePhase.dragEnd]);
  });

  testWidgets('Scale 终态停止冒泡仍结清祖先，指针增减重基准不跳比例', (tester) async {
    final trace = <String>[];
    final values = <double>[];
    final parent = ElTransformGestureRecognizer()
      ..onScaleStart = (_) {
        trace.add('parent.start');
      }
      ..onScaleEnd = (_) {
        trace.add('parent.end');
      };
    final child = ElTransformGestureRecognizer(parent: parent, startDistance: 2)
      ..onDragStart = (_) {}
      ..onScaleStart = (_) {
        trace.add('child.start');
      }
      ..onScaleUpdate = (event) {
        values.add(event.scale);
      }
      ..onScaleEnd = (event) {
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
    final phases = <ElGesturePhase>[];
    var officialDrag = 0;
    var officialTap = 0;
    final transform =
        ElTransformGestureRecognizer(axis: Axis.horizontal, startDistance: 4)
          ..onDragStart = (event) {
            phases.add(event.phase);
          }
          ..onDragUpdate = (event) {
            phases.add(event.phase);
          }
          ..onDragEnd = (event) {
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
    expect(phases, [
      ElGesturePhase.dragStart,
      ElGesturePhase.dragUpdate,
      ElGesturePhase.dragEnd,
    ]);
    expect(officialDrag, 0);
    expect(officialTap, 0);
  });

  testWidgets('官方拖拽获胜后 El 立即取消，下一轮可以重新识别', (tester) async {
    var starts = 0;
    var updates = 0;
    var cancels = 0;
    var officialStarts = 0;
    final transform =
        ElTransformGestureRecognizer(axis: Axis.vertical, startDistance: 60)
          ..onDragStart = (_) {
            starts++;
          }
          ..onDragUpdate = (_) {
            updates++;
          }
          ..onDragCancel = (_) {
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
    final values = <ElTransformGestureDetails>[];
    final vertical = ElTransformGestureRecognizer(
      axis: Axis.vertical,
      startDistance: 3,
    )..onDragStart = values.add;
    final lock = ElTransformGestureRecognizer(lockAxis: true, startDistance: 3)
      ..onDragStart = values.add
      ..onDragUpdate = values.add;
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
    final values = <ElTransformGestureDetails>[];
    final transform =
        ElTransformGestureRecognizer(axis: Axis.horizontal, startDistance: 5)
          ..onDragStart = values.add
          ..onDragUpdate = values.add;
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
    final transform = ElTransformGestureRecognizer(startDistance: 2)
      ..onDragStart = (_) {}
      ..onDragUpdate = (event) {
        updates.add(event.delta);
      }
      ..onScaleStart = (_) {
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
    final transform = ElTransformGestureRecognizer(startDistance: 2)
      ..onDragStart = (_) {}
      ..onDragUpdate = (event) {
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
    final transform = ElTransformGestureRecognizer(startDistance: 2)
      ..onDragStart = (_) {
        dragStarts++;
      }
      ..onDragUpdate = (_) {}
      ..onScaleStart = (_) {
        scaleStarts++;
      }
      ..onScaleUpdate = (event) {
        scales.add(event.scale);
      }
      ..onScaleEnd = (event) {
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
    expect(ends, [1]);
    _route(p.up());
  });

  testWidgets('触控板平移缩放共用官方竞技场，并保留连续旋转', (tester) async {
    var officialStarts = 0;
    final rotations = <double>[];
    final scales = <ElTransformGestureDetails>[];
    final transform = ElTransformGestureRecognizer(startDistance: 2)
      ..onDragStart = (_) {}
      ..onScaleStart = scales.add
      ..onScaleUpdate = scales.add
      ..onRotationUpdate = (event) {
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
    _route(
      p.panZoomUpdate(
        const Offset(20, 20),
        pan: const Offset(8, 0),
        scale: 2,
        rotation: 3,
      ),
    );
    _route(
      p.panZoomUpdate(
        const Offset(20, 20),
        pan: const Offset(10, 0),
        scale: 3,
        rotation: 6,
      ),
    );
    expect(officialStarts, 0);
    expect(scales.last.scale, closeTo(3, 0.0001));
    expect(scales.last.pointerCount, 2);
    expect(rotations.last, closeTo(6, 0.0001));
    _route(p.panZoomEnd());
  });

  testWidgets('结束速度过滤最小距离并限幅，旋转宿主 primaryVelocity 使用本地轴', (tester) async {
    ElTransformGestureDetails? end;
    final transform =
        ElTransformGestureRecognizer(
            axis: Axis.horizontal,
            startDistance: 2,
            minFlingDistance: 4,
            minFlingVelocity: 10,
            maxFlingVelocity: 300,
          )
          ..onDragStart = (_) {}
          ..onDragEnd = (event) {
            end = event;
          };
    addTearDown(transform.dispose);
    final matrix = Matrix4.rotationZ(-math.pi / 2);
    final pointer = TestPointer(14);
    _down(pointer.down(Offset.zero).transformed(matrix), [transform]);
    for (var index = 1; index <= 8; index++) {
      _route(
        pointer.move(
          Offset(0, index * 10.0),
          timeStamp: Duration(milliseconds: index * 10),
        ),
      );
    }
    _route(pointer.up(timeStamp: const Duration(milliseconds: 80)));
    expect(end!.primaryVelocity, closeTo(300, 0.01));
    expect(end!.velocity.pixelsPerSecond.dx, closeTo(0, 0.01));
    expect(end!.velocity.pixelsPerSecond.dy, closeTo(300, 0.01));
  });

  testWidgets('配置只影响下一轮，额外不支持设备不会取消现有拖拽', (tester) async {
    var starts = 0;
    var cancels = 0;
    final transform =
        ElTransformGestureRecognizer(
            startDistance: 20,
            supportedDevices: {PointerDeviceKind.touch},
          )
          ..onDragStart = (_) {
            starts++;
          }
          ..onDragCancel = (_) {
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
    final transform = ElTransformGestureRecognizer(startDistance: 2)
      ..onDragStart = (_) {
        starts++;
      };
    transform.onDragEnd = (_) {
      transform.onDragEnd = null;
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
    final updates = <ElTransformGestureDetails>[];
    final transform = ElTransformGestureRecognizer(startDistance: 2)
      ..onDragStart = (_) {}
      ..onDragUpdate = updates.add;
    final eager = EagerGestureRecognizer();
    addTearDown(transform.dispose);
    addTearDown(eager.dispose);
    final pointer = TestPointer(20);
    _down(pointer.down(Offset.zero), [transform]);
    _route(pointer.move(const Offset(10, 0)));
    final next = TestPointer(21);
    _down(
      next
          .down(const Offset(100, 0))
          .transformed(Matrix4.diagonal3Values(0.5, 0.5, 1)),
      [eager, transform],
    );
    _route(pointer.move(const Offset(20, 0)));
    expect(updates.single.delta, const Offset(10, 0));
    expect(updates.single.localDelta, const Offset(10, 0));
    _route(next.up());
    _route(pointer.up());
  });

  testWidgets('纯缩放候选失去新增指针后，后来的静止指针不能幽灵启动', (tester) async {
    var starts = 0;
    final transform = ElTransformGestureRecognizer()
      ..onScaleStart = (_) {
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
    ElTransformGestureDetails? end;
    final transform =
        ElTransformGestureRecognizer(
            startDistance: 1,
            minFlingDistance: 100,
            minFlingVelocity: 10,
          )
          ..onDragStart = (_) {}
          ..onDragEnd = (event) {
            end = event;
          };
    addTearDown(transform.dispose);
    final pointer = TestPointer(25);
    _down(pointer.down(Offset.zero), [transform]);
    for (var index = 1; index <= 5; index++) {
      _route(
        pointer.move(
          Offset(index * 5.0, 0),
          timeStamp: Duration(milliseconds: index * 5),
        ),
      );
    }
    _route(pointer.up(timeStamp: const Duration(milliseconds: 25)));
    expect(end!.velocity, Velocity.zero);
  });

  testWidgets('仅旋转订阅不会因触控板纯缩放认领，纯旋转也不启动仅缩放订阅', (tester) async {
    var rotations = 0;
    var zoomStarts = 0;
    final rotate = ElTransformGestureRecognizer()
      ..onRotationUpdate = (_) {
        rotations++;
      };
    final zoom = ElTransformGestureRecognizer()
      ..onScaleStart = (_) {
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

    expect(
      events,
      containsAllInOrder(['official.start', 'official.update', 'official.end']),
    );
    expect(events.where((event) => event.startsWith('el.')), [
      'el.down',
      'el.cancel',
    ]);
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

    expect(events.where((event) => event.startsWith('press.')), [
      'press.down',
      'press.cancel',
    ]);
    expect(
      events,
      containsAllInOrder(['drag.start', 'drag.update', 'drag.end']),
    );
  });

  testWidgets('El 多指缩放获胜后外层官方 Scale 不跟随更新', (tester) async {
    final events = <String>[];
    final transform = ElTransformGestureRecognizer(startDistance: 4);
    transform.onScaleStart = (_) => events.add('el.start');
    transform.onScaleUpdate = (_) => events.add('el.update');
    transform.onScaleEnd = (_) => events.add('el.end');
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
    final second = await tester.startGesture(
      const Offset(120, 100),
      pointer: 2,
    );
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
    final transform = ElTransformGestureRecognizer(startDistance: 100);
    transform.onScaleStart = (_) => events.add('el.start');
    transform.onScaleUpdate = (_) => events.add('el.update');
    transform.onScaleEnd = (_) => events.add('el.end');
    transform.onScaleCancel = (_) => events.add('el.cancel');
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
    final second = await tester.startGesture(
      const Offset(120, 100),
      pointer: 2,
    );
    await first.moveTo(const Offset(40, 100));
    await second.moveTo(const Offset(160, 100));
    await first.moveTo(const Offset(5, 100));
    await second.moveTo(const Offset(195, 100));
    await second.up();
    await first.up();
    await tester.pump(afterGesture);

    expect(
      events,
      containsAllInOrder(['official.start', 'official.update', 'official.end']),
    );
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
    child = ElTransformGestureRecognizer(parent: parent, startDistance: 6)
      ..onDragStart = (_) => child.dispose();
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      gestureShell(gestureHost(parent, child: gestureHost(child))),
    );

    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.up();
    expect(trace, ['parent.down', 'parent.cancel']);
  });

  testWidgets('冒泡按各成员的官方坐标变换换算位移', (tester) async {
    final deltas = <(String, Offset)>[];
    final parent = ElTransformGestureRecognizer(axis: Axis.horizontal)
      ..onDragUpdate = (event) {
        deltas.add(('parent', event.localDelta));
      };
    final child =
        ElTransformGestureRecognizer(
            parent: parent,
            axis: Axis.horizontal,
            startDistance: 6,
          )
          ..onDragUpdate = (event) {
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
            child: Transform.scale(
              scale: 4,
              alignment: Alignment.topLeft,
              child: gestureHost(child),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.up();
    expect(deltas, [
      ('child', const Offset(5, 0)),
      ('parent', const Offset(20, 0)),
    ]);
  });
  testWidgets('协作团队允许长按获胜后继续拖拽，外部官方点击不能同时触发', (tester) async {
    final trace = <String>[];
    final team = ElGestureArenaTeam();
    final press =
        ElPressGestureRecognizer(
            longPressDelay: const Duration(milliseconds: 20),
          )
          ..team = team
          ..onLongPress = (_) => trace.add('long');
    final transform = ElTransformGestureRecognizer(startDistance: 3)
      ..team = team
      ..onDragStart = (_) {
        trace.add('drag');
      }
      ..onDragEnd = (_) => trace.add('end');
    final official = TapGestureRecognizer()
      ..onTap = () => trace.add('official');
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
    _route(
      const PointerUpEvent(
        pointer: 1600,
        position: Offset(10, 0),
        timeStamp: Duration(milliseconds: 40),
      ),
    );
    expect(trace, ['long', 'drag', 'end']);
  });

  testWidgets('官方拖拽获胜同步拒绝整个协作团队，主动退出成员不被重新接受', (tester) async {
    final trace = <String>[];
    final team = ElGestureArenaTeam();
    final press = ElPressGestureRecognizer()
      ..team = team
      ..onTap = (_) {
        trace.add('tap');
      }
      ..onTapCancel = (_) => trace.add('press.cancel');
    final transform = ElTransformGestureRecognizer(startDistance: 100)
      ..team = team
      ..onDragDown = (_) {}
      ..onDragStart = (_) {
        trace.add('el.drag');
      }
      ..onDragCancel = (_) => trace.add('drag.cancel');
    final official = VerticalDragGestureRecognizer()
      ..onStart = (_) => trace.add('official.drag');
    addTearDown(press.dispose);
    addTearDown(transform.dispose);
    addTearDown(official.dispose);
    _down(const PointerDownEvent(pointer: 1601), [press, transform, official]);
    press.cancel();
    _route(
      const PointerMoveEvent(
        pointer: 1601,
        position: Offset(0, 30),
        delta: Offset(0, 30),
      ),
    );
    _route(const PointerUpEvent(pointer: 1601, position: Offset(0, 30)));
    expect(trace, ['press.cancel', 'drag.cancel', 'official.drag']);
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
