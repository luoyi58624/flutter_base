import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/src/ui/event/callback.dart';
import 'package:flutter_base/src/ui/event/config.dart';
import 'package:flutter_base/src/ui/event/recognizers/recognizers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('El 拖拽先过阈值后，官方拖拽和 Tap 都不能激活', (tester) async {
    final phases = <ElEventPhase>[];
    var officialDrag = 0;
    var officialTap = 0;
    final transform =
        ElTransformGestureRecognizer(
            axis: Axis.horizontal,
            config: const ElEventConfig(dragStartDistance: 4),
          )
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
      ElEventPhase.dragStart,
      ElEventPhase.dragUpdate,
      ElEventPhase.dragEnd,
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
        ElTransformGestureRecognizer(
            axis: Axis.vertical,
            config: const ElEventConfig(dragStartDistance: 60),
          )
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
    final values = <ElEventCallback>[];
    final vertical = ElTransformGestureRecognizer(
      axis: Axis.vertical,
      config: const ElEventConfig(dragStartDistance: 3),
    )..onDragStart = values.add;
    final lock =
        ElTransformGestureRecognizer(
            lockAxis: true,
            config: const ElEventConfig(dragStartDistance: 3),
          )
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
    final values = <ElEventCallback>[];
    final transform =
        ElTransformGestureRecognizer(
            axis: Axis.horizontal,
            config: const ElEventConfig(dragStartDistance: 5),
          )
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
    final transform =
        ElTransformGestureRecognizer(
            config: const ElEventConfig(dragStartDistance: 2),
          )
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
    final transform =
        ElTransformGestureRecognizer(
            config: const ElEventConfig(dragStartDistance: 2),
          )
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
    final transform =
        ElTransformGestureRecognizer(
            config: const ElEventConfig(dragStartDistance: 2),
          )
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
    final scales = <ElEventCallback>[];
    final transform =
        ElTransformGestureRecognizer(
            config: const ElEventConfig(dragStartDistance: 2),
          )
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
    ElEventCallback? end;
    final transform =
        ElTransformGestureRecognizer(
            axis: Axis.horizontal,
            config: const ElEventConfig(
              dragStartDistance: 2,
              dragMinFlingDistance: 4,
              dragMinFlingVelocity: 10,
              dragMaxFlingVelocity: 300,
            ),
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
            config: const ElEventConfig(dragStartDistance: 20),
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
    transform.config = const ElEventConfig(dragStartDistance: 2);
    _route(pointer.move(const Offset(5, 0)));
    expect(starts, 0);
    final mouse = TestPointer(16, PointerDeviceKind.mouse);
    _down(mouse.down(Offset.zero), [transform]);
    _route(mouse.up());
    _route(pointer.move(const Offset(25, 0)));
    expect((starts, cancels), (1, 0));
    _route(pointer.up());
  });

  testWidgets('开始回调重入 dispose 只结算一次取消，不再发送更新', (tester) async {
    var cancels = 0;
    var updates = 0;
    late ElTransformGestureRecognizer transform;
    transform =
        ElTransformGestureRecognizer(
            config: const ElEventConfig(dragStartDistance: 2),
          )
          ..onDragStart = (_) {
            transform.dispose();
          }
          ..onDragUpdate = (_) {
            updates++;
          }
          ..onDragCancel = (_) {
            cancels++;
            transform.dispose();
          };
    final pointer = TestPointer(17);
    _down(pointer.down(Offset.zero), [transform]);
    _route(pointer.move(const Offset(10, 0)));
    _route(pointer.move(const Offset(20, 0)));
    _route(pointer.up());
    expect((cancels, updates), (1, 0));
  });

  testWidgets('终态回调可以开始新序列，旧清理不能删除新序列', (tester) async {
    var starts = 0;
    final next = TestPointer(19);
    final transform =
        ElTransformGestureRecognizer(
            config: const ElEventConfig(dragStartDistance: 2),
          )
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
    final updates = <ElEventCallback>[];
    final transform =
        ElTransformGestureRecognizer(
            config: const ElEventConfig(dragStartDistance: 2),
          )
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
    ElEventCallback? end;
    final transform =
        ElTransformGestureRecognizer(
            config: const ElEventConfig(
              dragStartDistance: 1,
              dragMinFlingDistance: 100,
              dragMinFlingVelocity: 10,
            ),
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
