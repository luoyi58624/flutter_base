// 双指缩放判别测试（2026-07-06 补缺口）：
// - 缺口 1：此前 scale 覆盖全是生命周期面（替换/取消/reentrancy），起步一律走
//   debugHandleScaleStartForTest 合成入口——"真双指喂送自然起步 + scale 值等于
//   跨度比 + rotation 弧度 + 指针增减 rebaseline 连续性"从未被验证。
// - 缺口 2：scaleEnd 的 velocity 此前恒为 Velocity.zero（_endVelocityFor 占位）。
// - 随缺口修复引入的多指独占语义（双指捏合成立 → 参与序列全部 eager）与
//   单指起步不独占（让祖先滚动）在 SCALE-6/7 锚定。
import 'dart:math' as math;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  testWidgets('SCALE-1: 真双指相离自然触发 scaleStart，scaleUpdate 的 scale 等于跨度比', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final phases = <ElEventPhase>[];
    final scales = <double>[];
    final rotations = <double>[];
    final pointerCounts = <int>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onScaleStart: (e) {
          phases.add(e.phase);
          pointerCounts.add(e.pointerCount);
        },
        onScaleUpdate: (e) {
          phases.add(e.phase);
          scales.add(e.scale);
          rotations.add(e.rotation);
        },
        onScaleEnd: (e) => phases.add(e.phase),
      );
    addTearDown(dispatcher.dispose);

    // 双指落下：span = 平均到焦点距离 = 50。
    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(100, 100)), entry);
    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 2, position: Offset(200, 100)), entry);
    expect(phases, isEmpty, reason: '落指本身不得触发 scaleStart');

    // 指 2 外移 60：span 50 → 80，跨度变化 30 > scale slop(touch 18) → 自然起步。
    // 起步帧只 fire scaleStart（重定基线），不产生 update。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(260, 100), delta: Offset(60, 0)),
      entry,
    );
    expect(phases, <ElEventPhase>[ElEventPhase.scaleStart]);
    expect(pointerCounts, <int>[2]);

    // 继续外移：起步基线 span=80。span 100 → scale=1.25；span 120 → scale=1.5。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(300, 100), delta: Offset(40, 0)),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(340, 100), delta: Offset(40, 0)),
      entry,
    );
    expect(scales, hasLength(2));
    expect(scales[0], closeTo(1.25, 1e-9));
    expect(scales[1], closeTo(1.5, 1e-9));
    expect(rotations.every((r) => r.abs() < 1e-9), isTrue, reason: '共线外移不产生旋转');

    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(100, 100)), entry);
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 2, position: Offset(340, 100)), entry);
    expect(phases.last, ElEventPhase.scaleEnd);
  });

  testWidgets('SCALE-2: 双指旋转产生 rotation 弧度，onRotationUpdate 同步派发', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final updateRotations = <double>[];
    final rotationPhaseRotations = <double>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onScaleStart: (_) {},
        onScaleUpdate: (e) => updateRotations.add(e.rotation),
        onRotationUpdate: (e) => rotationPhaseRotations.add(e.rotation),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(100, 100)), entry);
    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 2, position: Offset(200, 100)), entry);
    // 起步（共线外移，基线角度 = atan2(0, 160) = 0）。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(260, 100), delta: Offset(60, 0)),
      entry,
    );
    // 指 2 转到指 1 正下方：连线角度 atan2(200, 0) = π/2。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(100, 300), delta: Offset(-160, 200)),
      entry,
    );

    expect(updateRotations, hasLength(1));
    expect(updateRotations.single, closeTo(1.5707963, 1e-6));
    expect(rotationPhaseRotations, hasLength(1));
    expect(rotationPhaseRotations.single, closeTo(1.5707963, 1e-6));

    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(100, 100)), entry);
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 2, position: Offset(100, 300)), entry);
  });

  testWidgets('SCALE-2b: 旋转跨越 atan2 正负 π 分界时保持最短角连续', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final rotations = <double>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(onScaleStart: (_) {}, onScaleUpdate: (event) => rotations.add(event.rotation));
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(200, 200)), entry);
    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 2, position: Offset(100, 200)), entry);
    // 左侧连线略向下，跨度变化越阈并把起步角定在 +π 一侧。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(40, 201), delta: Offset(-60, 1)),
      entry,
    );
    // 仅向上跨 2px，atan2 从 +π 跳到 -π；对外应是约 +0.0125rad 的连续增量。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(40, 199), delta: Offset(0, -2)),
      entry,
    );

    expect(rotations, hasLength(1));
    expect(rotations.single, closeTo(0.0124998, 1e-5));
  });

  testWidgets('SCALE-3: 一指抬起 rebaseline，scale 从累计值连续不跳变', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    final scales = <double>[];
    final deltas = <Offset>[];
    final phases = <ElEventPhase>[];
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(
        onScaleStart: (e) => phases.add(e.phase),
        onScaleUpdate: (e) {
          phases.add(e.phase);
          scales.add(e.scale);
          deltas.add(e.delta);
        },
        onScaleEnd: (e) => phases.add(e.phase),
      );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 1, position: Offset(100, 100)), entry);
    dispatcher.dispatchTestPointer(const PointerDownEvent(pointer: 2, position: Offset(200, 100)), entry);
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(260, 100), delta: Offset(60, 0)),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(300, 100), delta: Offset(40, 0)),
      entry,
    );
    expect(scales.last, closeTo(1.25, 1e-9));

    // 指 1 抬起：rebaseline，累计 scale=1.25 保留为基线；剩单指（span=0）。
    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 1, position: Offset(100, 100)), entry);
    expect(phases, isNot(contains(ElEventPhase.scaleEnd)), reason: '非末指抬起不得 end');

    // 单指移动：焦点平移，scale 必须停在 1.25（基线续算，不跳回 1.0）。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(pointer: 2, position: Offset(320, 120), delta: Offset(20, 20)),
      entry,
    );
    expect(scales.last, closeTo(1.25, 1e-9));
    expect(deltas.last, const Offset(20, 20), reason: '2→1 后首个单指 move 必须只报告 rebaseline 后的真实焦点增量');

    dispatcher.dispatchTestPointer(const PointerUpEvent(pointer: 2, position: Offset(320, 120)), entry);
    expect(phases.last, ElEventPhase.scaleEnd);
  });

  testWidgets('SCALE-4: 末指快甩抬起，scaleEnd velocity 为 tracker 末端估计', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    Velocity? endVelocity;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(onScaleStart: (_) {}, onScaleUpdate: (_) {}, onScaleEnd: (e) => endVelocity = e.velocity);
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset(100, 100), timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 2, position: Offset(200, 100), timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(260, 100),
        delta: Offset(60, 0),
        timeStamp: Duration(milliseconds: 100),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(300, 100),
        delta: Offset(40, 0),
        timeStamp: Duration(milliseconds: 200),
      ),
      entry,
    );
    // 慢指先抬，快指殿后。
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 1, position: Offset(100, 100), timeStamp: Duration(milliseconds: 900)),
      entry,
    );

    // 快甩段：+24px / 12ms = 2000 px/s，4 个样本全部落在 LSQ 100ms horizon 内，
    // 匀速直线数据的二次 LSQ 末端导数 = 精确 2000。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(324, 100),
        delta: Offset(24, 0),
        timeStamp: Duration(milliseconds: 1000),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(348, 100),
        delta: Offset(24, 0),
        timeStamp: Duration(milliseconds: 1012),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(372, 100),
        delta: Offset(24, 0),
        timeStamp: Duration(milliseconds: 1024),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(396, 100),
        delta: Offset(24, 0),
        timeStamp: Duration(milliseconds: 1036),
      ),
      entry,
    );
    // up 位置与最后 move 相同（up 不喂 tracker 契约下也不影响估计）。
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 2, position: Offset(396, 100), timeStamp: Duration(milliseconds: 1044)),
      entry,
    );

    expect(endVelocity, isNotNull);
    expect(endVelocity!.pixelsPerSecond.dx, closeTo(2000, 1.0));
    expect(endVelocity!.pixelsPerSecond.dy, closeTo(0, 1.0));
  });

  testWidgets('SCALE-5: 末指缓慢挪动后抬起，scaleEnd velocity 归零（min 门限）', (tester) async {
    final box = _attachedBox();
    final entry = BoxHitTestEntry(box, Offset.zero);
    Velocity? endVelocity;
    final dispatcher = EventDispatcher(box)
      ..event = ElEvent(onScaleStart: (_) {}, onScaleUpdate: (_) {}, onScaleEnd: (e) => endVelocity = e.velocity);
    addTearDown(dispatcher.dispose);

    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 1, position: Offset(100, 100), timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerDownEvent(pointer: 2, position: Offset(200, 100), timeStamp: Duration.zero),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(260, 100),
        delta: Offset(60, 0),
        timeStamp: Duration(milliseconds: 100),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 1, position: Offset(100, 100), timeStamp: Duration(milliseconds: 500)),
      entry,
    );
    // 蠕动段：+2px / 100ms = 20 px/s < kMinFlingVelocity(50) → 必须归零。
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(262, 100),
        delta: Offset(2, 0),
        timeStamp: Duration(milliseconds: 1000),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(264, 100),
        delta: Offset(2, 0),
        timeStamp: Duration(milliseconds: 1100),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(266, 100),
        delta: Offset(2, 0),
        timeStamp: Duration(milliseconds: 1200),
      ),
      entry,
    );
    dispatcher.dispatchTestPointer(
      const PointerUpEvent(pointer: 2, position: Offset(266, 100), timeStamp: Duration(milliseconds: 1210)),
      entry,
    );

    expect(endVelocity, Velocity.zero);
  });

  testWidgets('SCALE-V1: scaleEnd 输出最后一段 d(log(scale))/dt 与双指焦点', (tester) async {
    final result = _runLogScaleVelocityGesture(terminalMillis: 64);
    expect(result.velocity, closeTo(math.log(1.5 / 1.25) / 0.016, 1e-9));
    expect(result.focal, const Offset(220, 100));
  });

  testWidgets('SCALE-V2: log-scale velocity 在 80ms 有效，81ms 严格失效', (tester) async {
    expect(_runLogScaleVelocityGesture(terminalMillis: 128).velocity, isNonZero);
    expect(_runLogScaleVelocityGesture(terminalMillis: 129).velocity, 0);
  });

  testWidgets('SCALE-V3: 2→1 后首个单指 pan 清空旧 log-scale velocity', (tester) async {
    expect(_runLogScaleVelocityGesture(terminalMillis: 64, singlePan: true).velocity, 0);
  });

  testWidgets('SCALE-V4: 双指跨度归零后不得沿用旧 log-scale velocity', (tester) async {
    expect(_runLogScaleVelocityGesture(terminalMillis: 64, collapseSpan: true).velocity, 0);
  });

  testWidgets('SCALE-6: 双指捏合成立后，祖先纵向拖拽（滚动同款）被整体独占压制', (tester) async {
    var parentDragStarts = 0;
    var parentDragUpdates = 0;
    var childScaleStarts = 0;
    double? lastScale;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ElView(
            style: const ElStyle(width: 400, height: 400),
            event: ElEvent(
              onVerticalDragStart: (_) => parentDragStarts++,
              onVerticalDragUpdate: (_) => parentDragUpdates++,
            ),
            child: ElView(
              style: const ElStyle(width: 400, height: 400),
              event: ElEvent(onScaleStart: (_) => childScaleStarts++, onScaleUpdate: (e) => lastScale = e.scale),
            ),
          ),
        ),
      ),
    );

    final g1 = await tester.createGesture();
    final g2 = await tester.createGesture();
    await g1.down(const Offset(200, 100));
    await g2.down(const Offset(200, 200));
    // 纵向撑开：单次 +80，同帧同时越过 scale slop（span 50→90，Δ40 > 18）与
    // 祖先拖拽 slop（80 > 18）。子级（owner）先处理 → 捏合起步 + 双序列
    // eager → 祖先同一 move 的成员喂送已被压制，dragStart 不得触发。
    await g2.moveTo(const Offset(200, 280));
    await g2.moveTo(const Offset(200, 320));
    await tester.pump();

    expect(childScaleStarts, 1);
    expect(lastScale, isNotNull);
    expect(lastScale!, greaterThan(1.0));
    expect(parentDragStarts, 0, reason: '双指捏合成立后祖先拖拽不得并行接受（多指独占）');
    expect(parentDragUpdates, 0);

    await g1.up();
    await g2.up();
    await tester.pump();
  });

  testWidgets('SCALE-7: 单指焦点平移起步不独占，祖先拖拽照常消费', (tester) async {
    var parentDragStarts = 0;
    var parentDragUpdates = 0;
    final scaleStartCounts = <int>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ElView(
            style: const ElStyle(width: 400, height: 400),
            event: ElEvent(
              onVerticalDragStart: (_) => parentDragStarts++,
              onVerticalDragUpdate: (_) => parentDragUpdates++,
            ),
            child: ElView(
              style: const ElStyle(width: 400, height: 400),
              event: ElEvent(onScaleStart: (e) => scaleStartCounts.add(e.pointerCount), onScaleUpdate: (_) {}),
            ),
          ),
        ),
      ),
    );

    final g1 = await tester.createGesture();
    await g1.down(const Offset(200, 100));
    // 单指下滑 +50：越过 pan slop(36) → 子级 scale 起步（pointerCount=1），
    // 但不 eager——祖先纵向拖拽必须照常接受并推进（未缩放场景让给滚动）。
    await g1.moveTo(const Offset(200, 150));
    await g1.moveTo(const Offset(200, 180));
    await tester.pump();

    expect(scaleStartCounts, <int>[1]);
    expect(parentDragStarts, 1, reason: '单指 scale 起步不得抢占祖先拖拽');
    expect(parentDragUpdates, greaterThan(0));

    await g1.up();
    await tester.pump();
  });
}

({double velocity, Offset? focal}) _runLogScaleVelocityGesture({
  required int terminalMillis,
  bool singlePan = false,
  bool collapseSpan = false,
}) {
  final box = _attachedBox();
  final entry = BoxHitTestEntry(box, Offset.zero);
  var velocity = double.nan;
  Offset? focal;
  final dispatcher = EventDispatcher(box)
    ..event = ElEvent(
      onScaleStart: (_) {},
      onScaleUpdate: (_) {},
      onScaleEnd: (event) {
        velocity = event.logScaleVelocity;
        focal = event.localPosition;
      },
    );
  dispatcher.dispatchTestPointer(
    const PointerDownEvent(pointer: 1, position: Offset(100, 100), timeStamp: Duration.zero),
    entry,
  );
  dispatcher.dispatchTestPointer(
    const PointerDownEvent(pointer: 2, position: Offset(200, 100), timeStamp: Duration.zero),
    entry,
  );
  dispatcher.dispatchTestPointer(
    const PointerMoveEvent(
      pointer: 2,
      position: Offset(260, 100),
      delta: Offset(60, 0),
      timeStamp: Duration(milliseconds: 16),
    ),
    entry,
  );
  dispatcher.dispatchTestPointer(
    const PointerMoveEvent(
      pointer: 2,
      position: Offset(300, 100),
      delta: Offset(40, 0),
      timeStamp: Duration(milliseconds: 32),
    ),
    entry,
  );
  dispatcher.dispatchTestPointer(
    const PointerMoveEvent(
      pointer: 2,
      position: Offset(340, 100),
      delta: Offset(40, 0),
      timeStamp: Duration(milliseconds: 48),
    ),
    entry,
  );
  if (collapseSpan) {
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(100, 100),
        delta: Offset(-240, 0),
        timeStamp: Duration(milliseconds: 52),
      ),
      entry,
    );
  }
  dispatcher.dispatchTestPointer(
    const PointerUpEvent(pointer: 1, position: Offset(100, 100), timeStamp: Duration(milliseconds: 56)),
    entry,
  );
  if (singlePan) {
    dispatcher.dispatchTestPointer(
      const PointerMoveEvent(
        pointer: 2,
        position: Offset(348, 100),
        delta: Offset(8, 0),
        timeStamp: Duration(milliseconds: 60),
      ),
      entry,
    );
  }
  dispatcher.dispatchTestPointer(
    PointerUpEvent(
      pointer: 2,
      position: singlePan ? const Offset(348, 100) : const Offset(340, 100),
      timeStamp: Duration(milliseconds: terminalMillis),
    ),
    entry,
  );
  dispatcher.dispose();
  return (velocity: velocity, focal: focal);
}

_EventTestBox _attachedBox() {
  final owner = PipelineOwner();
  final box = _EventTestBox();
  owner.rootNode = box;
  box.layout(BoxConstraints.tight(const Size(1000, 1000)));
  return box;
}

final class _EventTestBox extends RenderBox {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(1000, 1000));
  }
}
