import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart'
    show Drag, GestureBinding, PointerDeviceKind, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';

import 'nested/nested_scroll_chain.dart' show ElNestedScrollParent, NestedScrollChain, NestedScrollNode;
import 'nested/scroll_delta_source.dart' show ElScrollDeltaSource;
import 'smooth/smooth_pointer_scroll.dart' show SmoothPointerScrollController;
import 'smooth/smooth_scroll.dart' show ElSmoothScroll;
import 'nested/nested_scroll.dart' show nestedScrollNodeOf;

/// ElScroll 的滚动位置：只在官方的拖动、松手、惯性三个入口上加逻辑，其余沿用官方实现。
///
/// - 拖动开始时决定这次手势归谁（同轴嵌套接力）。
/// - 拖动和惯性的每段位移按「协作方 pre → 正文 → 协作方 post」分配。
/// - 松手时协作方先分走速度。
///
/// 协作链统一使用手指方向的位移，正值表示内容向起点方向回退，与像素增长方向相反。
final class ScrollHostPosition extends ScrollPositionWithSingleContext {
  /// 创建由 ElScroll 内部控制器使用的滚动位置。
  ScrollHostPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  /// 当前拖动及其惯性使用的协作链；没有协作方时为 null，全部走官方路径。
  NestedScrollChain? _chain;
  _RelayDrag? _relay;
  bool _disposed = false;
  bool _endingByRelease = false;
  bool _rawPointerCanceled = false;

  SmoothPointerScrollController? _smooth;
  PointerScrollEvent? _wheelEvent;
  bool _dispatchingSmooth = false;

  /// 设置当前 Scrollable 的平滑滚轮策略；null 表示交给官方直接滚动。
  void configureSmooth(ElSmoothScroll? algorithm) {
    if (algorithm == null) {
      _smooth?.reset();
      if (_smooth != null) _smooth!.algorithm = null;
      return;
    }
    (_smooth ??= SmoothPointerScrollController(
      position: () => this,
      targetOffsetForDelta: (delta, {from}) =>
          ((from ?? pixels) + delta).clamp(minScrollExtent, maxScrollExtent).toDouble(),
    )).algorithm = algorithm;
  }

  /// 在官方 Scrollable 前选择滚轮接收者，连续输入停顿满 500ms 才允许换层。
  ///
  /// 返回本次信号是否已登记给某个滚动位置处理。
  bool handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !hasPixels || !hasContentDimensions) return false;
    final input = _pointerScrollInput(event);
    if (input.delta == 0) return false;
    final owner = _WheelScrollChain.ownerAt(this, event, input.axis);
    final target = owner ?? this;
    final amount = axisDirectionIsReversed(target.axisDirection) ? -input.delta : input.delta;
    if (owner == null && !target._canConsumePointerScroll(amount)) return false;
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      if (signal is! PointerScrollEvent || target._disposed) return;
      // 边界处也接住本格并续期，防止持续滚轮被官方 Scrollable 逐格交给外层。
      _WheelScrollChain.claim(target, signal, input.axis);
      signal.respond(allowPlatformDefault: false);
      if (!target._canConsumePointerScroll(amount)) return;
      target._wheelEvent = signal;
      try {
        target.pointerScroll(amount);
      } finally {
        target._wheelEvent = null;
      }
    });
    return true;
  }

  /// 停止进行中的平滑滚轮动画，例如收到触控板惯性取消信号。
  void cancelPointerScroll() {
    _smooth?.reset();
    if (hasPixels) pointerScroll(0);
  }

  ({Axis axis, double delta}) _pointerScrollInput(PointerScrollEvent event) {
    final host = _hostContext;
    final modifiers = host == null ? null : ScrollConfiguration.of(host).pointerAxisModifiers;
    final flip =
        event.kind == PointerDeviceKind.mouse &&
        (modifiers?.any(HardwareKeyboard.instance.logicalKeysPressed.contains) ?? false);
    final inputAxis = flip ? flipAxis(axis) : axis;
    final delta = inputAxis == Axis.vertical ? event.scrollDelta.dy : event.scrollDelta.dx;
    return (axis: inputAxis, delta: delta);
  }

  bool _canConsumePointerScroll(double delta) {
    if (_disposed || !hasPixels || !hasContentDimensions || !physics.shouldAcceptUserOffset(this)) return false;
    // 某些页头（Bibi）在正文边界仍有独立的折叠行程，必须先于正文认领滚轮。
    if (_buildChain()?.canPreScroll(delta, .pointerScroll) ?? false) return true;
    return _smooth?.canConsumeDelta(delta) ??
        ((pixels + delta).clamp(minScrollExtent, maxScrollExtent) - pixels).abs() > precisionErrorTolerance;
  }

  bool _containsPointer(Offset point) {
    final host = context;
    if (_disposed || host is! ScrollableState || !host.mounted || !identical(host.position, this)) return false;
    final box = host.notificationContext?.findRenderObject();
    return box is RenderBox &&
        box.attached &&
        box.hasSize &&
        (Offset.zero & box.size).contains(box.globalToLocal(point));
  }

  bool _isAncestorOf(ScrollHostPosition other) {
    var ancestor = other._hostContext?.findAncestorStateOfType<ScrollableState>();
    while (ancestor != null) {
      if (identical(ancestor, context)) return true;
      ancestor = ancestor.context.findAncestorStateOfType<ScrollableState>();
    }
    return false;
  }

  @override
  void pointerScroll(double delta) {
    final event = _wheelEvent;
    final smooth = _smooth;
    if (event != null && !_dispatchingSmooth) {
      // 一笔原始滚轮事件先让协作页头抽走行程，余量再使用平滑滚轮；
      // 平滑器内部的同步直滚不会第二次调用协作链。
      delta -= _buildChain()?.preScroll(delta, .pointerScroll) ?? 0.0;
      if (delta.abs() <= precisionErrorTolerance) return;
    }
    if (event != null && smooth != null && !_dispatchingSmooth) {
      // 触控板的直滚会再调用 pointerScroll；避免再次进入平滑编排。
      _dispatchingSmooth = true;
      try {
        smooth.applyPointerScroll(event, delta);
      } finally {
        _dispatchingSmooth = false;
      }
      return;
    }
    if (!_dispatchingSmooth) smooth?.reset();
    super.pointerScroll(delta);
  }

  /// 新的物理按压开始，重置上一序列的取消标记。
  void resetRawPointerCancellation() {
    _rawPointerCanceled = false;
    _smooth?.reset();
  }

  /// 原始 PointerCancel 会先于官方识别器合成的零速 onEnd 到达。
  void markRawPointerCanceled() {
    _rawPointerCanceled = true;
    _chain?.cancel();
  }

  /// 当前是否由官方真实 Drag 活动驱动，供刷新物理检查输入来源。
  bool get isDirectDrag => activity is DragScrollActivity;

  /// 视口内部登记的边界协作方（ElSliverRefresh）。
  final _edgeParticipants = <NestedScrollNode>[];

  /// 是否有边界协作方；有的话内容不足一屏也要接受拖动。
  bool get hasEdgeParticipants => _edgeParticipants.isNotEmpty;

  /// 登记一个边界协作方，下一次拖动开始时生效。
  ///
  /// 它排在协作链最外侧：折叠头等其他协作方都走不动了才轮到它消费越界位移，
  /// 反向移动时它最先回收。
  void addEdgeParticipant(ElNestedScrollParent parent) => _edgeParticipants.add(NestedScrollNode(parent: parent));

  /// 注销边界协作方；进行中的手势不再回调它。
  void removeEdgeParticipant(ElNestedScrollParent parent) {
    final index = _edgeParticipants.indexWhere((node) => identical(node.parent, parent));
    if (index >= 0) _edgeParticipants.removeAt(index).detached = true;
  }

  NestedScrollChain? _buildChain() {
    final host = _hostContext;
    return NestedScrollChain.fromNode(
      host == null ? null : nestedScrollNodeOf(host),
      axis: axis,
      outermost: _edgeParticipants,
    );
  }

  BuildContext? get _hostContext {
    final host = context;
    return host is ScrollableState && host.mounted ? host.context : null;
  }

  // ───────────────────────── 拖动归属 ─────────────────────────

  // 官方 drag 入口没有方向信息，先返回代理，等第一段位移再决定由谁真正开始拖动。
  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    // 官方 RawScrollbar 在 drag() 返回前要求已释放 ThumbPress 时取得的 hold。
    // 内容拖动仍待第一段 delta 判定接力归属，但不能让 HoldScrollActivity 一直占着位置。
    if (activity is HoldScrollActivity) goIdle();
    return _RelayDrag(this, details, dragCancelCallback);
  }

  Drag _startDrag(DragUpdateDetails first, DragStartDetails start, _RelayDrag relay) {
    final delta = first.primaryDelta ?? 0;
    final forward = axisDirectionIsReversed(axisDirection) ? delta > 0 : delta < 0;
    if (!_canScroll(forward)) {
      final ancestor = _ancestor();
      if (ancestor != null) {
        _releaseHold();
        // 祖先若也是本类型，会用同一段位移继续向外判定。
        return ancestor.drag(start, relay._targetCanceled);
      }
    }
    final drag = super.drag(start, relay._targetCanceled);
    _relay = relay;
    _chain = _buildChain();
    _chain?.start(axis, .touchDrag);
    return drag;
  }

  bool _canScroll(bool forward) {
    // 越界回弹中的位置仍由自己接住，避免把回弹过程交给祖先。
    if (!hasPixels || !hasContentDimensions || outOfRange) return true;
    // 距边界不足一个物理像素视为贴边，否则惯性停在边界前的残余会锁住整段手势。
    final slack = physics.toleranceFor(this).distance;
    return forward ? pixels < maxScrollExtent - slack : pixels > minScrollExtent + slack;
  }

  ScrollPosition? _ancestor() {
    var state = _hostContext?.findAncestorStateOfType<ScrollableState>();
    while (state != null) {
      final position = state.position;
      if (position.axis == axis && position.hasContentDimensions && position.physics.shouldAcceptUserOffset(position)) {
        return position;
      }
      state = state.context.findAncestorStateOfType<ScrollableState>();
    }
    return null;
  }

  /// 结束按下时留下的 hold；本层不参与本次拖动时回到静止或回弹。
  void _releaseHold() {
    if (!_disposed && hasPixels && activity is HoldScrollActivity) goBallistic(0);
  }

  // ───────────────────────── 位移分配 ─────────────────────────

  /// 把一段手指方向的位移交给协作链，返回留给正文的量。
  double _split(double delta, ElScrollDeltaSource source) {
    final chain = _chain;
    if (chain == null || delta == 0) return delta;
    var rest = delta - chain.preScroll(delta, source);
    // 正文范围内走不完的部分先问协作方，仍有剩余才成为正文自己的越界量。
    final room = math.max(0.0, rest > 0 ? pixels - minScrollExtent : maxScrollExtent - pixels);
    if (rest.abs() > room) rest -= chain.postScroll(rest - rest.sign * room, source);
    return rest;
  }

  @override
  void applyUserOffset(double delta) {
    final rest = _split(delta, .touchDrag);
    if (rest == 0) return;
    final relay = _relay;
    final room = math.max(0.0, rest > 0 ? pixels - minScrollExtent : maxScrollExtent - pixels);
    final ancestor = relay == null || outOfRange || rest.abs() <= room ? null : _ancestor();
    // 普通嵌套仍保持原接收者；只有分页祖先接收本次拖动的边界余量。
    if (ancestor is PageMetrics && ancestor != null) {
      final raw = axisDirectionIsReversed(axisDirection) ? -rest : rest;
      final forward = axisDirectionIsReversed(ancestor.axisDirection) ? raw > 0 : raw < 0;
      final canPage = forward ? ancestor.pixels < ancestor.maxScrollExtent : ancestor.pixels > ancestor.minScrollExtent;
      if (canPage) {
        if (room > 0) super.applyUserOffset(rest.sign * room);
        relay!.handoff(ancestor, rest - rest.sign * room);
        return;
      }
    }
    super.applyUserOffset(rest);
  }

  // ───────────────────────── 松手与惯性 ─────────────────────────

  @override
  void goBallistic(double velocity) {
    final chain = _chain;
    if (chain == null) {
      super.goBallistic(velocity);
      return;
    }
    // DragScrollController.cancel 同样会调用 goBallistic(0)，只有真实 Drag.end
    // 才能触发 armed 刷新；取消必须撤销协作输入而不是当作零速松手。
    if (activity is DragScrollActivity) {
      if (_endingByRelease && !_rawPointerCanceled) {
        velocity = -chain.preFling(-velocity);
      } else {
        chain.cancel();
      }
    }
    var simulation = physics.createBallisticSimulation(this, velocity);
    if (simulation == null && velocity.abs() > physics.toleranceFor(this).velocity && !outOfRange) {
      // 正文在边界时官方 Clamping 不会启动弹道，但折叠头等协作方可能仍有行程。
      // 只在协作链存在且有有效速度时使用虚拟位置采样，实际像素仍服从正文边界。
      simulation = ClampingScrollSimulation(
        position: pixels,
        velocity: velocity,
        tolerance: physics.toleranceFor(this),
      );
    }
    if (simulation == null) {
      goIdle();
    } else {
      beginActivity(_ChainBallisticActivity(this, simulation, context.vsync, shouldIgnorePointer));
    }
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    final wasDragging = activity is DragScrollActivity;
    super.beginActivity(newActivity);
    if (newActivity == null) return;
    if (newActivity is! DragScrollActivity) _relay = null;
    // 松手、取消、被新命令接管都算拖动结束；链只在随后的惯性里继续使用。
    if (wasDragging) _chain?.end();
    if (newActivity is! DragScrollActivity && newActivity is! _ChainBallisticActivity) _chain = null;
  }

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
    if (other is ScrollHostPosition) {
      _chain = other._chain;
      _WheelScrollChain.replace(other, this);
    }
  }

  @override
  void dispose() {
    _WheelScrollChain.release(this);
    _disposed = true;
    _smooth?.dispose();
    super.dispose();
  }
}

// 新版位置不持有旧版 RenderBox 视口，按相同的原始输入轴维护滚轮归属。
final class _WheelScrollChain {
  static final _states = <Axis, _WheelScrollClaim>{};

  static ScrollHostPosition? ownerAt(ScrollHostPosition querier, PointerScrollEvent event, Axis axis) {
    final state = _states[axis];
    if (state == null || state.timer == null) return null;
    final owner = state.owner;
    final related = identical(owner, querier) || owner._isAncestorOf(querier) || querier._isAncestorOf(owner);
    if (!owner._containsPointer(event.position) ||
        !owner.physics.shouldAcceptUserOffset(owner) ||
        (!related && (event.position - state.startPosition).distanceSquared >= 100)) {
      release(owner, axis: axis);
      owner._smooth?.reset();
      return null;
    }
    return owner;
  }

  static void claim(ScrollHostPosition owner, PointerScrollEvent event, Axis axis) {
    final state = _states.putIfAbsent(axis, () => _WheelScrollClaim(owner, event.position));
    if (!identical(state.owner, owner)) {
      state.owner._smooth?.reset();
      state
        ..owner = owner
        ..startPosition = event.position;
    }
    state.timer?.cancel();
    // 到期只解除命中锁，真正更换接收者时才停止旧接收者的长动画。
    state.timer = Timer(const Duration(milliseconds: 500), () => state.timer = null);
  }

  static void replace(ScrollHostPosition previous, ScrollHostPosition next) {
    for (final state in _states.values) {
      if (identical(state.owner, previous)) state.owner = next;
    }
  }

  static void release(ScrollHostPosition owner, {Axis? axis}) {
    for (final inputAxis in axis == null ? Axis.values : [axis]) {
      final state = _states[inputAxis];
      if (state == null || !identical(state.owner, owner)) continue;
      state.timer?.cancel();
      _states.remove(inputAxis);
    }
  }
}

final class _WheelScrollClaim {
  _WheelScrollClaim(this.owner, this.startPosition);

  ScrollHostPosition owner;
  Offset startPosition;
  Timer? timer;
}

/// ElScroll 固定叠在调用方物理之上的一层：有边界协作方时，内容不足一屏也接受拖动。
///
/// 官方物理在内容不足一屏时会关闭拖动识别，刷新就无法从短列表拉出；
/// 调用方显式禁止用户滚动（NeverScrollableScrollPhysics）时仍然尊重。
final class ScrollHostPhysics extends ScrollPhysics {
  /// 创建叠加层，[parent] 是调用方或环境提供的物理。
  const ScrollHostPhysics({super.parent});

  @override
  ScrollHostPhysics applyTo(ScrollPhysics? ancestor) => ScrollHostPhysics(parent: buildParent(ancestor));

  // allowUserScrolling 不会沿 parent 传递，需要自己走一遍物理链。
  bool get _userCanScroll {
    for (var physics = parent; physics != null; physics = physics.parent) {
      if (!physics.allowUserScrolling) return false;
    }
    return true;
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (position is ScrollHostPosition && position.hasEdgeParticipants && _userCanScroll) return true;
    return super.shouldAcceptUserOffset(position);
  }
}

/// 逐帧把惯性位移交给协作链的惯性活动。
///
/// 模拟由物理在起飞时按真实位置创建；协作方消费位移后，真实像素会落后于模拟位置，
/// 所以这里按帧差推进。Bouncing 这类自带边界的模拟在这种情况下仍按起飞时的位置判断边界。
final class _ChainBallisticActivity extends BallisticScrollActivity {
  _ChainBallisticActivity(ScrollHostPosition super.delegate, super.simulation, super.vsync, super.shouldIgnorePointer)
    : _last = delegate.pixels;

  double _last;

  @override
  bool applyMoveTo(double value) {
    final delta = _last - value;
    _last = value;
    final position = delegate as ScrollHostPosition;
    final rest = position._split(delta, .fling);
    return rest == 0 || position.setPixels(position.pixels - rest).abs() < precisionErrorTolerance;
  }
}

/// 交给 [Scrollable] 的拖动代理，首段位移确定归属后原样转发。
final class _RelayDrag implements Drag {
  _RelayDrag(this._origin, this._start, this._onCancelled);

  final ScrollHostPosition _origin;
  final DragStartDetails _start;
  final VoidCallback _onCancelled;
  Drag? _target;
  bool _closed = false;
  bool _transferring = false;
  DragUpdateDetails? _update;

  void _targetCanceled() {
    if (!_transferring) _close();
  }

  // 只换官方 Drag 的接收位置，识别器仍持有原来的指针序列。
  void handoff(ScrollPosition position, double remaining) {
    final details = _update!;
    final raw = axisDirectionIsReversed(_origin.axisDirection) ? -remaining : remaining;
    final delta = _origin.axis == Axis.horizontal ? Offset(raw, 0) : Offset(0, raw);
    _transferring = true;
    try {
      _origin._chain?.cancel();
      _target?.cancel();
      _target = position.drag(
        DragStartDetails(
          sourceTimeStamp: details.sourceTimeStamp,
          globalPosition: details.globalPosition - delta,
          localPosition: details.localPosition - delta,
          kind: _start.kind,
        ),
        _targetCanceled,
      );
    } finally {
      _transferring = false;
    }
    _target?.update(
      DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        delta: delta,
        primaryDelta: raw,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ),
    );
  }

  // Scrollable 要求 end / cancel 返回前已收到取消回调，这里保证只通知一次。
  void _close() {
    _target = null;
    if (_closed) return;
    _closed = true;
    _onCancelled();
  }

  @override
  void update(DragUpdateDetails details) {
    if (_closed) return;
    var target = _target;
    if (target == null) {
      if (_origin._disposed) {
        _close();
        return;
      }
      if ((details.primaryDelta ?? 0) == 0) return;
      target = _target = _origin._startDrag(details, _start, this);
    }
    _update = details;
    try {
      target.update(details);
    } finally {
      _update = null;
    }
  }

  @override
  void end(DragEndDetails details) {
    final target = _target;
    if (target == null) {
      _origin._releaseHold();
    } else {
      _origin._endingByRelease = true;
      try {
        target.end(details);
      } finally {
        _origin._endingByRelease = false;
      }
    }
    _close();
  }

  @override
  void cancel() {
    final target = _target;
    if (target == null) {
      _origin._releaseHold();
    } else {
      // Cancel 与 Drag.end 不同：先让刷新等参与者撤销 armed，
      // 否则官方 cancel -> goBallistic(0) 会被错当成松手触发刷新。
      _origin._chain?.cancel();
      target.cancel();
    }
    _close();
  }
}
