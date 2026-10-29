import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

/// 用于 dispatcher 单元测试的最简 RenderBox。
class _DummyBox extends RenderBox {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(10, 10));
  }
}

/// 最简父级 RenderBox（持有一个子）。
class _DummyParent extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  @override
  void performLayout() {
    final c = child;
    if (c != null) {
      c.layout(constraints, parentUsesSize: true);
      size = c.size;
    } else {
      size = constraints.biggest;
    }
  }
}

({_DummyParent parent, _DummyBox child}) _attachedPair() {
  final pipelineOwner = PipelineOwner();
  final parent = _DummyParent();
  final child = _DummyBox();
  parent.child = child;
  pipelineOwner.rootNode = parent;
  parent.layout(BoxConstraints.tight(const Size(1000, 1000)));
  return (parent: parent, child: child);
}

({_DummyParent grandparent, _DummyParent parent, _DummyBox child}) _attachedTriple() {
  final pipelineOwner = PipelineOwner();
  final grandparent = _DummyParent();
  final parent = _DummyParent();
  final child = _DummyBox();
  parent.child = child;
  grandparent.child = parent;
  pipelineOwner.rootNode = grandparent;
  grandparent.layout(BoxConstraints.tight(const Size(1000, 1000)));
  return (grandparent: grandparent, parent: parent, child: child);
}

const _down1 = PointerDownEvent(pointer: 1, position: Offset.zero, timeStamp: Duration.zero);

PointerMoveEvent _move({required int pointer, required Offset position, required Offset delta, int millis = 16}) =>
    PointerMoveEvent(
      pointer: pointer,
      position: position,
      delta: delta,
      timeStamp: Duration(milliseconds: millis),
    );

PointerUpEvent _up({required int pointer, required Offset position, int millis = 32}) => PointerUpEvent(
  pointer: pointer,
  position: position,
  timeStamp: Duration(milliseconds: millis),
);

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  // -------------------------------------------------------------------------
  // §6.1-1: roster 形成 —— child driver 接受后 parent(proxy) 自机钝化。
  // -------------------------------------------------------------------------
  testWidgets('roster forms: parent drag machine passivated after child accepts', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    final parentEvents = <String>[];
    final childEvents = <String>[];

    parentDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onDragStart: (e) => parentEvents.add('start:${e.dragOffset.dy}'),
      onDragUpdate: (e) => parentEvents.add('update:${e.delta.dy}'),
      onDragEnd: (e) => parentEvents.add('end'),
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) {}, onDragOverflow: (_) {}),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (e) => childEvents.add('start'),
      onVerticalDragUpdate: (_) => childEvents.add('update'),
      onVerticalDragEnd: (_) => childEvents.add('end'),
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // Accept drag on child (10 > threshold 3).
    final move = _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10));
    childDispatcher.dispatchTestPointer(move, BoxHitTestEntry(pair.child, const Offset(0, 10)));

    expect(childEvents, ['start']);
    // parent got the bubbled dragStart (from child), NOT its own self-fire.
    expect(parentEvents.length, 1);
    expect(parentEvents.first.startsWith('start:'), isTrue);

    // Now dispatch move to parent (member direct hit) — parent's drag machine
    // must remain passivated (not fire its own dragStart on the second move).
    parentDispatcher.dispatchTestPointer(move, BoxHitTestEntry(pair.parent, const Offset(0, 10)));
    expect(parentEvents.length, 1, reason: 'parent drag machine is passivated; no independent start');

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-2: pre 记账 —— pre 消费 3px → driver update 收到 remaining 减 3
  // -------------------------------------------------------------------------
  testWidgets('pre stage consumes; driver sees reduced remaining', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    final driverRemaining = <double>[];
    var preSeen = 0.0;

    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragPreUpdate: (e) {
          preSeen = e.remainingPrimaryDelta(Axis.vertical);
          e.consumePrimaryDelta(Axis.vertical, 3);
        },
      ),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (e) => driverRemaining.add(e.remainingPrimaryDelta(Axis.vertical)),
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // Cross threshold with 10px so we reach the update path.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );

    // dragUpdate frame: delta=10, pre consumes 3 → driver sees remaining 7.
    expect(preSeen, 10);
    expect(driverRemaining, [7]);

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-3: overflow 记账 —— driver 消费 4/10 → overflow 收到 6；
  //         driver 全消费 → overflow 不被调用。
  // -------------------------------------------------------------------------
  testWidgets('overflow receives what driver leaves; skipped when driver drains all', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    final overflowSeen = <double>[];
    var driverBudget = 4.0; // toggleable

    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragOverflow: (e) => overflowSeen.add(e.remainingPrimaryDelta(Axis.vertical)),
      ),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (e) => e.consumePrimaryDelta(Axis.vertical, driverBudget),
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // dragStart frame（零基契约：accept 前 10px 丢弃，种子归零）:
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    overflowSeen.clear();
    // dragUpdate frame: delta=10, driver takes 4 → overflow sees 6.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );
    expect(overflowSeen, [6]);

    // Driver drains everything → overflow not called on next frame.
    driverBudget = 999;
    overflowSeen.clear();
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 30), delta: const Offset(0, 10), millis: 48),
      BoxHitTestEntry(pair.child, const Offset(0, 30)),
    );
    expect(overflowSeen, isEmpty);

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-4: 帧内分割 + 台账守恒。
  // -------------------------------------------------------------------------
  testWidgets('per-frame split: pre + main + overflow sum <= frame delta', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    var preConsumed = 0.0;
    var mainConsumed = 0.0;
    var overflowConsumed = 0.0;

    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragPreUpdate: (e) {
          preConsumed = 3.0;
          e.consumePrimaryDelta(Axis.vertical, 3);
        },
        onDragOverflow: (e) {
          overflowConsumed = e.remainingPrimaryDelta(Axis.vertical);
          e.consumeAllDelta();
        },
      ),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (e) {
        mainConsumed = 2.0;
        e.consumePrimaryDelta(Axis.vertical, 2);
      },
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    preConsumed = mainConsumed = overflowConsumed = 0.0;
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );

    // frame delta = 10; pre 3 + main 2 + overflow 5 = 10.
    expect(preConsumed, 3);
    expect(mainConsumed, 2);
    expect(overflowConsumed, 5);
    expect(preConsumed + mainConsumed + overflowConsumed, lessThanOrEqualTo(10));

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-5: 方向反转 —— 同手势先下后上。
  // -------------------------------------------------------------------------
  testWidgets('direction reversal: pre/overflow alternate polarity within a gesture', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    final preDeltas = <double>[];
    final overflowDeltas = <double>[];

    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragPreUpdate: (e) => preDeltas.add(e.remainingPrimaryDelta(Axis.vertical)),
        onDragOverflow: (e) => overflowDeltas.add(e.remainingPrimaryDelta(Axis.vertical)),
      ),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // Downward: dragStart frame.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    preDeltas.clear();
    overflowDeltas.clear();
    // Downward update.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );
    // Upward update.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 5), delta: const Offset(0, -15), millis: 48),
      BoxHitTestEntry(pair.child, const Offset(0, 5)),
    );

    expect(preDeltas, [10, -15]);
    expect(overflowDeltas, [10, -15]);

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-6: dragStart 帧为纯生命周期信号，管线种子归零；pre/overflow 帧内
  // `_pipelineDeltaExhausted` 早退不触达（无量可分）；分账实际从首个
  // dragUpdate 帧开始（对齐 Flutter DragStartBehavior.start 契约，避免首帧事
  // 件合并把 30+ px 一次性 apply 到 driver）。
  // -------------------------------------------------------------------------
  testWidgets('dragStart frame is a pure lifecycle signal — pipeline seed is zero', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    var preCallsAtStart = 0;
    var overflowCallsAtStart = 0;
    var preSeenAtUpdate = -1.0;
    var overflowSeenAtUpdate = -1.0;

    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragPreUpdate: (e) {
          if (e.phase == ElEventPhase.dragStart) {
            preCallsAtStart++;
          } else if (e.phase == ElEventPhase.dragUpdate) {
            preSeenAtUpdate = e.remainingPrimaryDelta(Axis.vertical);
          }
        },
        onDragOverflow: (e) {
          if (e.phase == ElEventPhase.dragStart) {
            overflowCallsAtStart++;
          } else if (e.phase == ElEventPhase.dragUpdate) {
            overflowSeenAtUpdate = e.remainingPrimaryDelta(Axis.vertical);
          }
        },
      ),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // 首个 accept move：位移 10（threshold=3）按零基契约丢弃，dragStart 种子归零。
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );

    // seed=0 → `_pipelineDeltaExhausted` 早退，pre/overflow 在 dragStart 帧
    // 完全不触达（有量才分账的语义）。
    expect(preCallsAtStart, 0, reason: 'dragStart 帧 seed=0 → pre 早退不触达');
    expect(overflowCallsAtStart, 0, reason: 'dragStart 帧 seed=0 → overflow 早退不触达');

    // 首个 dragUpdate 帧：正常分账 delta=10，driver 不消费 → pre/overflow 都能看到 10。
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );
    expect(preSeenAtUpdate, 10, reason: 'dragUpdate 帧 pre 拿到 frame delta');
    expect(overflowSeenAtUpdate, 10, reason: 'driver 未消费，overflow 收全部余量');

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-7: 轴过滤 —— horizontal proxy 不入 vertical driver roster；
  //         axis == null 入任意。
  // -------------------------------------------------------------------------
  testWidgets('horizontal proxy rejected by vertical driver roster', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    var preCalls = 0;

    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(axis: Axis.horizontal, onDragPreUpdate: (_) => preCalls++),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );

    expect(preCalls, 0, reason: 'horizontal proxy skipped by vertical driver');

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  testWidgets('axis-null proxy enters vertical driver roster', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    var preCalls = 0;

    parentDispatcher.event = ElEvent(dragProxy: ElDragProxy(onDragPreUpdate: (_) => preCalls++));
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // 首帧 accept → dragStart 纯信号 (seed=0，pre 早退不触达)。
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    // 首个 dragUpdate 帧 → 分账管线上线，pre 拿到 frame delta。
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );

    expect(preCalls, 1);

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  testWidgets('free-form driver only admits axis-null proxies', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    var preCalls = 0;

    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) => preCalls++),
    );
    childDispatcher.event = ElEvent(
      // Free-form (no axial drag callbacks).
      config: const ElEventConfig(dragStartDistance: 3),
      onDragStart: (_) {},
      onDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );

    expect(preCalls, 0, reason: 'axis-specified proxy skipped by free-form driver');

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-8: 热替换 —— 拖拽中 shape 相等替换，管线存续、新闭包生效。
  // -------------------------------------------------------------------------
  testWidgets('shape-equal hot swap: pipeline persists and new closures effective', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    var preV1Calls = 0;
    var preV2Calls = 0;

    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) => preV1Calls++),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // 首帧 accept → dragStart 纯信号 (seed=0，pre 早退不触达)。
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    // 首个 dragUpdate 帧 → 分账管线上线，v1 pre 拿到 frame delta。
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );
    expect(preV1Calls, 1);

    // Shape-equal replacement: same axis, same proxy handler slots non-null,
    // but new closures.
    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) => preV2Calls++),
    );

    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 30), delta: const Offset(0, 10), millis: 48),
      BoxHitTestEntry(pair.child, const Offset(0, 30)),
    );

    expect(preV1Calls, 1, reason: 'v1 closure not called after swap');
    expect(preV2Calls, 1, reason: 'v2 closure called via live proxy resolution');

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-9: 结构替换 driver 配置 —— 管线解散、roster 成员下一手势恢复独立语义。
  // -------------------------------------------------------------------------
  testWidgets('driver config structural replacement dissolves pipeline; roster recovers next gesture', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    final parentStarts = <String>[];

    parentDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onDragStart: (_) => parentStarts.add('bubbled-or-self'),
      onDragUpdate: (_) {},
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) {}),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    // Parent got bubbled dragStart from child.
    expect(parentStarts.length, 1);

    // Structural replacement: strip child's drag → cancels driver drag →
    // resetSilently → pipeline dissolves.
    childDispatcher.event = const ElEvent();
    // Up to release the pointer.
    childDispatcher.dispatchTestPointer(
      _up(pointer: 1, position: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    parentDispatcher.dispatchTestPointer(
      _up(pointer: 1, position: const Offset(0, 10)),
      BoxHitTestEntry(pair.parent, const Offset(0, 10)),
    );

    // Next gesture: only parent drags now. Parent's drag machine must have
    // recovered from passivation and fire onDragStart on threshold cross.
    parentStarts.clear();
    const down2 = PointerDownEvent(pointer: 2, position: Offset.zero, timeStamp: Duration(milliseconds: 100));
    parentDispatcher.dispatchTestPointer(down2, BoxHitTestEntry(pair.parent, Offset.zero));
    parentDispatcher.dispatchTestPointer(
      _move(pointer: 2, position: const Offset(0, 20), delta: const Offset(0, 20), millis: 116),
      BoxHitTestEntry(pair.parent, const Offset(0, 20)),
    );
    expect(parentStarts.length, 1, reason: 'parent drag machine revived after pipeline dissolution');

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-10b: eager 压制 driver → 管线解散
  // (via 正常 dragEnd 也覆盖这条; 这里显式测 dragCancel 也解散)。
  // -------------------------------------------------------------------------
  testWidgets('dragCancel dissolves pipeline; passive member reverts', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    var parentPreCalls = 0;
    final parentStarts = <String>[];

    parentDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onDragStart: (_) => parentStarts.add('start'),
      onDragUpdate: (_) {},
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) => parentPreCalls++),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
      onVerticalDragCancel: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // 首帧 accept → dragStart 纯信号 (seed=0，pre 早退不触达)。
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    // 首个 dragUpdate 帧 → 管线记账，pre 触达一次。
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );
    expect(parentPreCalls, 1, reason: 'first dragUpdate frame runs pre through pipeline');

    // Cancel: pointer cancel.
    const cancel = PointerCancelEvent(pointer: 1, position: Offset(0, 10), timeStamp: Duration(milliseconds: 32));
    childDispatcher.dispatchTestPointer(cancel, BoxHitTestEntry(pair.child, const Offset(0, 10)));
    parentDispatcher.dispatchTestPointer(cancel, BoxHitTestEntry(pair.parent, const Offset(0, 10)));

    // Next independent drag on parent alone (child has no down).
    parentStarts.clear();
    const down2 = PointerDownEvent(pointer: 2, position: Offset.zero, timeStamp: Duration(milliseconds: 100));
    parentDispatcher.dispatchTestPointer(down2, BoxHitTestEntry(pair.parent, Offset.zero));
    parentDispatcher.dispatchTestPointer(
      _move(pointer: 2, position: const Offset(0, 20), delta: const Offset(0, 20), millis: 116),
      BoxHitTestEntry(pair.parent, const Offset(0, 20)),
    );
    expect(parentStarts, ['start'], reason: 'parent drag machine reactivated after cancel dissolves pipeline');

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-11: proxy handler 内 stopPropagation 被忽略（复位防护）。
  // -------------------------------------------------------------------------
  testWidgets('stopPropagation inside proxy handler is reset; subsequent stages still run', (tester) async {
    final triple = _attachedTriple();
    final grandparentDispatcher = EventDispatcher(triple.grandparent);
    final parentDispatcher = EventDispatcher(triple.parent);
    final childDispatcher = EventDispatcher(triple.child);
    var grandparentPreCalls = 0;
    var parentPreCalls = 0;
    var driverUpdateCalls = 0;

    grandparentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        // Outermost pre runs FIRST (pre is outer→inner). Try to break pipeline
        // with stopPropagation — must be ignored.
        onDragPreUpdate: (e) {
          grandparentPreCalls++;
          e.stopPropagation();
          e.eagerGesture();
        },
      ),
    );
    parentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) => parentPreCalls++),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) => driverUpdateCalls++,
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(triple.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(triple.parent, Offset.zero));
    grandparentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(triple.grandparent, Offset.zero));
    // Cross threshold.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(triple.child, const Offset(0, 10)),
    );
    grandparentPreCalls = parentPreCalls = driverUpdateCalls = 0;
    // dragUpdate frame.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(triple.child, const Offset(0, 20)),
    );

    expect(grandparentPreCalls, 1);
    expect(parentPreCalls, 1, reason: 'inner pre not blocked by outer proxy stopPropagation');
    expect(driverUpdateCalls, 1, reason: 'driver main not blocked by proxy stopPropagation');

    grandparentDispatcher.dispose();
    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-12: 多指（latestPointer 策略）：第二指落下不复活钝化成员。
  // -------------------------------------------------------------------------
  testWidgets('multitouch: second pointer down does not revive passive parent drag machine', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    final parentDragStarts = <String>[];
    var parentPreCalls = 0;

    parentDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onDragStart: (_) => parentDragStarts.add('start'),
      onDragUpdate: (_) {},
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) => parentPreCalls++),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // Accept.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    // Parent got bubbled dragStart.
    expect(parentDragStarts.length, 1);
    parentDragStarts.clear();

    // Second pointer down.
    const down2 = PointerDownEvent(pointer: 2, position: Offset(20, 0), timeStamp: Duration(milliseconds: 20));
    childDispatcher.dispatchTestPointer(down2, BoxHitTestEntry(pair.child, const Offset(20, 0)));
    parentDispatcher.dispatchTestPointer(down2, BoxHitTestEntry(pair.parent, const Offset(20, 0)));
    // Move pointer 2 past threshold — parent must NOT fire its own dragStart.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 2, position: const Offset(20, 10), delta: const Offset(0, 10), millis: 40),
      BoxHitTestEntry(pair.child, const Offset(20, 10)),
    );
    parentDispatcher.dispatchTestPointer(
      _move(pointer: 2, position: const Offset(20, 10), delta: const Offset(0, 10), millis: 40),
      BoxHitTestEntry(pair.parent, const Offset(20, 10)),
    );

    expect(parentDragStarts, isEmpty, reason: 'parent stays passive; new pointer does not revive its machine');

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-13: 显式 Drag route 边界高于管线内部 cutoff 豁免。
  // -------------------------------------------------------------------------
  testWidgets('dragStart stop keeps roster member outside the terminal route', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    Velocity? parentEndVelocity;
    var parentEndCalls = 0;

    parentDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onDragEnd: (e) {
        parentEndCalls++;
        parentEndVelocity = e.velocity;
      },
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) {}, onDragOverflow: (_) {}),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (e) => e.stopPropagation(),
      onVerticalDragUpdate: (_) {},
      onVerticalDragEnd: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // Cross threshold.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );
    // Additional move for velocity signal.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );
    // Up.
    childDispatcher.dispatchTestPointer(
      _up(pointer: 1, position: const Offset(0, 20), millis: 48),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );
    parentDispatcher.dispatchTestPointer(
      _up(pointer: 1, position: const Offset(0, 20), millis: 48),
      BoxHitTestEntry(pair.parent, const Offset(0, 20)),
    );

    expect(parentEndCalls, 0, reason: '管线豁免只作用于内部协调 cutoff，不能越过显式 Drag route stop');
    expect(parentEndVelocity, isNull);

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-15: latch 截断 —— 三层（driver + 竞争滚动 + 更外层 proxy）中
  //          外层 proxy 不入 roster、收不到任何 pre/overflow。
  // -------------------------------------------------------------------------
  testWidgets('latch cut: intermediate drag-shape no-proxy terminates roster collection', (tester) async {
    final triple = _attachedTriple();
    final grandparentDispatcher = EventDispatcher(triple.grandparent);
    final parentDispatcher = EventDispatcher(triple.parent);
    final childDispatcher = EventDispatcher(triple.child);
    var grandparentPreCalls = 0;
    var grandparentOverflowCalls = 0;

    // Outer: proxy holder.
    grandparentDispatcher.event = ElEvent(
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragPreUpdate: (_) => grandparentPreCalls++,
        onDragOverflow: (_) => grandparentOverflowCalls++,
      ),
    );
    // Middle: competing consumer (drag callbacks, NO proxy).
    parentDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );
    // Inner: driver (drag callbacks, no proxy needed).
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(triple.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(triple.parent, Offset.zero));
    grandparentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(triple.grandparent, Offset.zero));
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(triple.child, const Offset(0, 10)),
    );
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(triple.child, const Offset(0, 20)),
    );

    // Middle has drag shape but no proxy → latch break AT middle → grandparent
    // not admitted to roster.
    expect(grandparentPreCalls, 0, reason: 'grandparent proxy not in roster (latch cut)');
    expect(grandparentOverflowCalls, 0);

    grandparentDispatcher.dispose();
    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // §6.1-16: latch 保持 —— driver 组不成管线时（roster 空），
  //          到边界后余量吞掉不外流、eager 独占如旧；
  //          同手势内外层竞争机器始终不 fire。
  // -------------------------------------------------------------------------
  testWidgets('latch preserved: no pipeline when roster empty; outer non-proxy competitor stays silent', (
    tester,
  ) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    var parentUpdates = 0;
    var parentStarts = 0;

    // Outer: competing drag consumer, NO proxy.
    parentDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) => parentStarts++,
      onVerticalDragUpdate: (_) => parentUpdates++,
    );
    // Inner: driver.
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
      includeAncestors: false,
    );
    // Additional update frame directly to child.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
      includeAncestors: false,
    );

    // Parent gets bubbled dragStart from child (as always).
    expect(parentStarts, 1);
    // But parent's own dragUpdate (would come from its own machine) doesn't
    // fire — child owns the sequence; roster empty; no pipeline.
    expect(parentUpdates, 0, reason: 'no pipeline; parent has no self-update since child owns the sequence');

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // 修复回归：多指第二指的新序列也要拿到截断与豁免 —— 外层竞争机器在
  // 第二指序列上不得复活；dragEnd 最终在第二指序列上 fire 时 roster 成员
  // 仍能收到。
  // -------------------------------------------------------------------------
  testWidgets('second pointer sequence gets cutoff and exemption while pipeline active', (tester) async {
    final triple = _attachedTriple();
    final grandparentDispatcher = EventDispatcher(triple.grandparent);
    final parentDispatcher = EventDispatcher(triple.parent);
    final childDispatcher = EventDispatcher(triple.child);
    var grandparentStarts = 0;
    var parentEndCalls = 0;

    // Outer: competing consumer (drag shape, no proxy) — the latch break point.
    grandparentDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) => grandparentStarts++,
      onVerticalDragUpdate: (_) {},
    );
    // Middle: roster member (proxy + dragEnd lifecycle listener).
    parentDispatcher.event = ElEvent(
      onDragEnd: (_) => parentEndCalls++,
      dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) {}),
    );
    // Inner: driver.
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
      onVerticalDragEnd: (_) {},
    );

    // First finger: down + accept → pipeline forms, latch break at grandparent.
    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(triple.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(triple.parent, Offset.zero));
    grandparentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(triple.grandparent, Offset.zero));
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(triple.child, const Offset(0, 10)),
    );
    expect(grandparentStarts, 0, reason: 'formation cutoff suppresses competitor on the first sequence');

    // Second finger down while pipeline is active — its sequence is a fresh
    // object and must receive the same cutoff/exemption.
    const down2 = PointerDownEvent(pointer: 2, position: Offset(20, 0), timeStamp: Duration(milliseconds: 20));
    childDispatcher.dispatchTestPointer(down2, BoxHitTestEntry(triple.child, const Offset(20, 0)));
    parentDispatcher.dispatchTestPointer(down2, BoxHitTestEntry(triple.parent, const Offset(20, 0)));
    grandparentDispatcher.dispatchTestPointer(down2, BoxHitTestEntry(triple.grandparent, const Offset(20, 0)));
    // Second finger crosses the competitor's own threshold — competitor must
    // NOT accept a parallel drag on the new sequence.
    final move2 = _move(pointer: 2, position: const Offset(20, 10), delta: const Offset(0, 10), millis: 40);
    childDispatcher.dispatchTestPointer(move2, BoxHitTestEntry(triple.child, const Offset(20, 10)));
    parentDispatcher.dispatchTestPointer(move2, BoxHitTestEntry(triple.parent, const Offset(20, 10)));
    grandparentDispatcher.dispatchTestPointer(move2, BoxHitTestEntry(triple.grandparent, const Offset(20, 10)));
    expect(grandparentStarts, 0, reason: 'competitor stays suppressed on the second pointer sequence');

    // First finger lifts (latestPointer already switched to pointer 2);
    // gesture continues on the second finger.
    final up1 = _up(pointer: 1, position: const Offset(0, 10), millis: 56);
    childDispatcher.dispatchTestPointer(up1, BoxHitTestEntry(triple.child, const Offset(0, 10)));
    parentDispatcher.dispatchTestPointer(up1, BoxHitTestEntry(triple.parent, const Offset(0, 10)));
    grandparentDispatcher.dispatchTestPointer(up1, BoxHitTestEntry(triple.grandparent, const Offset(0, 10)));
    childDispatcher.dispatchTestPointer(
      _move(pointer: 2, position: const Offset(20, 20), delta: const Offset(0, 10), millis: 72),
      BoxHitTestEntry(triple.child, const Offset(20, 20)),
    );

    // Second finger lifts → dragEnd fires on the SECOND pointer's sequence.
    final up2 = _up(pointer: 2, position: const Offset(20, 20), millis: 88);
    childDispatcher.dispatchTestPointer(up2, BoxHitTestEntry(triple.child, const Offset(20, 20)));
    parentDispatcher.dispatchTestPointer(up2, BoxHitTestEntry(triple.parent, const Offset(20, 20)));
    grandparentDispatcher.dispatchTestPointer(up2, BoxHitTestEntry(triple.grandparent, const Offset(20, 20)));

    expect(parentEndCalls, 1, reason: 'dragEnd on the second sequence still reaches the roster member');
    expect(grandparentStarts, 0);

    grandparentDispatcher.dispose();
    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // 修复回归：pre 扣光余量不得吞掉主段投递 —— dragStart / dragUpdate 是
  // 语义生命周期投递，driver 与冒泡链（roster 成员）必须照常收到；
  // 余量归零的短路只作用于 overflow 记账阶段。
  // -------------------------------------------------------------------------
  testWidgets('pre draining all delta does not suppress main delivery', (tester) async {
    final pair = _attachedPair();
    final parentDispatcher = EventDispatcher(pair.parent);
    final childDispatcher = EventDispatcher(pair.child);
    final childStartRemaining = <double>[];
    final childUpdateRemaining = <double>[];
    var parentBubbledStarts = 0;
    var overflowCalls = 0;

    parentDispatcher.event = ElEvent(
      onDragStart: (_) => parentBubbledStarts++,
      dragProxy: ElDragProxy(
        axis: Axis.vertical,
        onDragPreUpdate: (e) => e.consumeAllDelta(),
        onDragOverflow: (_) => overflowCalls++,
      ),
    );
    childDispatcher.event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 3),
      onVerticalDragStart: (e) => childStartRemaining.add(e.remainingPrimaryDelta(Axis.vertical)),
      onVerticalDragUpdate: (e) => childUpdateRemaining.add(e.remainingPrimaryDelta(Axis.vertical)),
    );

    childDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.child, Offset.zero));
    parentDispatcher.dispatchTestPointer(_down1, BoxHitTestEntry(pair.parent, Offset.zero));
    // dragStart 帧种子归零（纯生命周期信号），pre 无量可分同样耗尽；driver
    // 还是收到 remaining=0 的 dragStart（形状不变，只是原因由"pre 榨干"变成
    // "种子本就为 0"）。
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 10), delta: const Offset(0, 10)),
      BoxHitTestEntry(pair.child, const Offset(0, 10)),
    );

    expect(childStartRemaining, [0], reason: 'driver still receives dragStart with remaining 0');
    expect(parentBubbledStarts, 1, reason: 'roster member still receives the bubbled dragStart');
    expect(overflowCalls, 0, reason: 'exhausted short-circuit still skips overflow');

    // dragUpdate frame: pre drains the whole 10 again.
    childDispatcher.dispatchTestPointer(
      _move(pointer: 1, position: const Offset(0, 20), delta: const Offset(0, 10), millis: 32),
      BoxHitTestEntry(pair.child, const Offset(0, 20)),
    );
    expect(childUpdateRemaining, [0], reason: 'driver still receives dragUpdate with remaining 0');
    expect(overflowCalls, 0);

    parentDispatcher.dispose();
    childDispatcher.dispose();
  });

  // -------------------------------------------------------------------------
  // ElDragProxy equality / identicalHandlers sanity
  // -------------------------------------------------------------------------
  test('ElDragProxy shape equality: axis + handler nullness', () {
    void a(ElEventDetails e) {}
    void b(ElEventDetails e) {}
    expect(ElDragProxy(axis: Axis.vertical, onDragPreUpdate: a), ElDragProxy(axis: Axis.vertical, onDragPreUpdate: b));
    expect(
      ElDragProxy(axis: Axis.vertical, onDragPreUpdate: a),
      isNot(ElDragProxy(axis: Axis.horizontal, onDragPreUpdate: a)),
    );
    expect(ElDragProxy(axis: Axis.vertical, onDragPreUpdate: a), isNot(const ElDragProxy(axis: Axis.vertical)));
    expect(ElDragProxy(onDragOverflow: a).identicalHandlers(ElDragProxy(onDragOverflow: a)), isTrue);
    expect(ElDragProxy(onDragOverflow: a).identicalHandlers(ElDragProxy(onDragOverflow: b)), isFalse);
  });

  test('ElEvent.copyWith(dragProxy: null) removes proxy', () {
    final event = ElEvent(dragProxy: const ElDragProxy(axis: Axis.vertical));
    expect(event.copyWith().dragProxy, isNotNull);
    expect(event.copyWith(dragProxy: null).dragProxy, isNull);
  });

  test('ElEvent.hasAnyCallback ignores dragProxy alone', () {
    expect(ElEvent(dragProxy: const ElDragProxy(axis: Axis.vertical)).hasAnyCallback, isFalse);
    expect(
      ElEvent(
        dragProxy: ElDragProxy(axis: Axis.vertical, onDragPreUpdate: (_) {}),
      ).hasAnyCallback,
      isFalse,
      reason: 'proxy-only nodes do not need to be hit-testable; chain snapshot brings them in',
    );
  });
}
