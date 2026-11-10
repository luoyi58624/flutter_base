import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart' show Drag;
import 'package:flutter/widgets.dart';

import '../../views/scroll/common/nested/nested_scroll.dart' show NestedScrollChain;
import '../../views/scroll/common/nested/scroll_delta_interceptor.dart' show ElScrollDeltaSource;
import 'nested_scroll.dart' show nestedScrollNodeOf;

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
  bool _disposed = false;

  BuildContext? get _hostContext {
    final host = context;
    return host is ScrollableState && host.mounted ? host.context : null;
  }

  // ───────────────────────── 拖动归属 ─────────────────────────

  // 官方 drag 入口没有方向信息，先返回代理，等第一段位移再决定由谁真正开始拖动。
  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) => _RelayDrag(this, details, dragCancelCallback);

  Drag _startDrag(DragUpdateDetails first, DragStartDetails start, VoidCallback onCancelled) {
    final delta = first.primaryDelta ?? 0;
    final forward = axisDirectionIsReversed(axisDirection) ? delta > 0 : delta < 0;
    if (!_canScroll(forward)) {
      final ancestor = _ancestor();
      if (ancestor != null) {
        _releaseHold();
        // 祖先若也是本类型，会用同一段位移继续向外判定。
        return ancestor.drag(start, onCancelled);
      }
    }
    final drag = super.drag(start, onCancelled);
    final host = _hostContext;
    _chain = host == null ? null : NestedScrollChain.fromNode(nestedScrollNodeOf(host), axis: axis);
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
    if (rest != 0) super.applyUserOffset(rest);
  }

  // ───────────────────────── 松手与惯性 ─────────────────────────

  @override
  void goBallistic(double velocity) {
    final chain = _chain;
    if (chain == null) {
      super.goBallistic(velocity);
      return;
    }
    // 拖动刚结束：协作方先分走速度，零速也通知，供吸附等收尾使用。
    if (activity is DragScrollActivity) velocity = -chain.preFling(-velocity);
    final simulation = physics.createBallisticSimulation(this, velocity);
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
    // 松手、取消、被新命令接管都算拖动结束；链只在随后的惯性里继续使用。
    if (wasDragging) _chain?.end();
    if (newActivity is! DragScrollActivity && newActivity is! _ChainBallisticActivity) _chain = null;
  }

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
    if (other is ScrollHostPosition) _chain = other._chain;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 逐帧把惯性位移交给协作链的惯性活动。
///
/// 模拟由物理在起飞时按真实位置创建；协作方消费位移后，真实像素会落后于模拟位置，
/// 所以这里按帧差推进。Bouncing 这类自带边界的模拟在这种情况下仍按起飞时的位置判断边界。
final class _ChainBallisticActivity extends BallisticScrollActivity {
  _ChainBallisticActivity(
    ScrollHostPosition super.delegate,
    super.simulation,
    super.vsync,
    super.shouldIgnorePointer,
  ) : _last = delegate.pixels;

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
      target = _target = _origin._startDrag(details, _start, _close);
    }
    target.update(details);
  }

  @override
  void end(DragEndDetails details) {
    final target = _target;
    if (target == null) {
      _origin._releaseHold();
    } else {
      target.end(details);
    }
    _close();
  }

  @override
  void cancel() {
    final target = _target;
    if (target == null) {
      _origin._releaseHold();
    } else {
      target.cancel();
    }
    _close();
  }
}
