import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show RefreshIndicatorStatus;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../scroll/nested/nested_scroll_chain.dart' show ElNestedScrollParent;
import '../scroll/nested/scroll_delta_source.dart' show ElScrollDeltaSource;
import '../scroll/refresh/refresher.dart' show ElRefreshDetails, ElRefreshSnapshot, ElRefresher;
import '../views/view/provider.dart' show ElViewProvider;
import '../scroll/scroll_position.dart' show ScrollHostPosition;

/// Sliver 形式的下拉刷新，放在 ElScroll.sliver 的 slivers 里，通常是第一个。
///
/// 刷新绑定在滚动起点一侧（普通列表的顶部，reverse 列表的底部）；终点一侧的刷新使用 ElRefresh。
/// 内容让位式刷新器（[ElRefresher.movesContent]）由本 Sliver 占出真实间隙，把后面的 Sliver 推开，
/// 滚动位置本身不越界；悬浮式刷新器不占位，指示器盖在视口上。
/// 只有手指拖动能拉出刷新，松手时仍在触发距离之外才执行 [onRefresh]。
///
/// 这里只使用刷新器的 buildIndicator 与策略参数；指示器铺满视口且不参与命中，
/// 覆写 [ElRefresher.build] 接管整体层级的刷新器请使用 ElRefresh。
class ElSliverRefresh extends HookWidget {
  /// 创建挂在所在 ElScroll 起点边缘的刷新 Sliver。
  const ElSliverRefresh({super.key, required this.onRefresh, this.refresher});

  /// 刷新回调，返回的 Future 完成后指示器收起。
  final Future<void> Function() onRefresh;

  /// 刷新器的外观与策略；null 继承 ElViewProvider。
  final ElRefresher? refresher;

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.of(context);
    final position = scrollable.position;
    assert(position is ScrollHostPosition, 'ElSliverRefresh 需要放在 ElScroll.sliver 的 slivers 中');
    final refresher = this.refresher ?? ElViewProvider.refresherOf(context);

    final vsync = useSingleTickerProvider();
    final motion = useMemoized(() => _RefreshMotion(vsync));
    motion
      ..refresher = refresher
      ..onRefresh = onRefresh
      ..axisDirection = scrollable.axisDirection
      ..position = position;
    useEffect(() => motion.dispose, const []);
    // Scrollable 更换物理或控制器时会重建位置，协作方要跟着重新登记。
    useEffect(() {
      if (position is! ScrollHostPosition) return null;
      position.addEdgeParticipant(motion);
      return () => position.removeEdgeParticipant(motion);
    }, [position]);

    return _SliverRefresh(
      motion: motion,
      behind: refresher.behindContent(motion),
      child: refresher.buildIndicator(context, motion),
    );
  }
}

/// 刷新状态：作为滚动协作方接收越界位移，维护拉出距离与官方刷新状态。
///
/// 位移使用协作链的手指方向：正值朝滚动起点外侧拉出，负值收回。
final class _RefreshMotion extends ElNestedScrollParent implements ElRefreshDetails {
  _RefreshMotion(TickerProvider vsync) : _settle = AnimationController.unbounded(vsync: vsync) {
    _settle.addListener(() {
      _pulled = math.max(0.0, _settle.value);
      _publish();
    });
  }

  late ElRefresher refresher;
  late Future<void> Function() onRefresh;
  late AxisDirection axisDirection;
  late ScrollPosition position;

  /// 正文实际让出的可见间隙，由渲染对象在布局时写入。
  double visibleGap = 0;

  final AnimationController _settle;
  Timer? _finishHold;
  RefreshIndicatorStatus? _status;
  double _pulled = 0;

  // 首次读取时字段已由 build 赋值；之后方向或刷新器变化在下一次状态变化时进入快照。
  late final _snapshot = ValueNotifier(_compose());

  /// 本 Sliver 需要占出的真实滚动范围。
  double get gap => refresher.movesContent ? _pulled : 0;

  /// 是否需要绘制指示器。
  bool get active => _status != null;

  bool get _pulling => _status == .drag || _status == .armed;

  // ───────────────────────── 滚动协作 ─────────────────────────

  @override
  double onNestedPostScroll(double unconsumed, ElScrollDeltaSource source) {
    // 只有手指拖动能拉出刷新，惯性撞到边界不算；刷新进行中多余的位移交还正文物理。
    final idle = _status == null || _status == .canceled;
    if (unconsumed <= 0 || source != .touchDrag || refresher.triggerExtent <= 0 || !(idle || _pulling)) return 0;
    _dragTo(_pulledAfter(unconsumed));
    return unconsumed;
  }

  @override
  double onNestedPreScroll(double delta, ElScrollDeltaSource source) {
    // 反向移动先收回拉距，收完之前正文不动。
    if (delta >= 0 || !_pulling) return 0;
    final consumed = math.max(delta, -_pulled);
    _dragTo(_pulled + consumed);
    return consumed;
  }

  @override
  double onNestedPreFling(double velocity) {
    if (!_pulling) return velocity;
    if (_status == .armed) {
      _startRefresh(byGesture: true);
    } else {
      _cancelPull();
    }
    // 拉出状态下松手，速度不再推动正文。
    return 0;
  }

  @override
  void onNestedScrollCancel() => _cancelPull();

  // 拖动被其他滚动命令接管时没有松手信号，按取消处理；正常松手到这里时状态已经离开拉出。
  @override
  void onNestedScrollEnd() => _cancelPull();

  double _pulledAfter(double delta) {
    if (!refresher.movesContent) return _pulled + delta;
    // 让位式沿用官方 Bouncing 的越界阻尼：拉得越深越重，并受刷新器的上限约束。
    final depth = (_pulled / position.viewportDimension).clamp(0.0, 1.0);
    final next = _pulled + delta * 0.52 * (1 - depth) * (1 - depth);
    return math.min(next, refresher.maxPullExtent ?? double.infinity);
  }

  // ───────────────────────── 状态 ─────────────────────────

  /// 手指直接决定拉距：状态随距离在未激活、drag、armed 之间切换。
  void _dragTo(double pulled) {
    _settle.stop();
    _pulled = math.max(0.0, pulled);
    _status = _pulled <= precisionErrorTolerance
        ? null
        : _pulled >= refresher.triggerExtent
        ? .armed
        : .drag;
    _publish();
  }

  void _cancelPull() {
    if (!_pulling) return;
    _status = .canceled;
    _settleTo(0);
  }

  void _startRefresh({required bool byGesture}) {
    if (byGesture && refresher.hapticOnTrigger) HapticFeedback.mediumImpact();
    _status = .refresh;
    _settleTo(refresher.refreshingExtent);
    Future<void>.sync(onRefresh).whenComplete(() {
      if (_status != .refresh) return;
      _status = .done;
      _publish();
      // 完成视觉先停留 finishDelay，再收起。
      _finishHold = Timer(refresher.finishDelay, () => _settleTo(0, finishing: true));
    });
  }

  /// 把拉距送到 [target]；回到 0 后回到未激活。
  void _settleTo(double target, {bool finishing = false}) {
    _settle.value = _pulled;
    final spring = refresher.movesContent ? refresher.settleSpring : null;
    final run = spring != null
        ? _settle.animateWith(SpringSimulation(spring, _pulled, target, 0))
        : _settle.animateTo(
            target,
            duration: finishing ? refresher.finishDuration : refresher.settleDuration,
            curve: finishing ? refresher.finishCurve : refresher.settleCurve,
          );
    // 被新的拖动打断时这个 Future 不会完成，状态交给打断它的一方。
    run.then((_) {
      _pulled = target;
      if (target == 0) _status = null;
      _publish();
    });
  }

  ElRefreshSnapshot _compose() => ElRefreshSnapshot(
    status: _status,
    pulledExtent: _pulled,
    triggerExtent: refresher.triggerExtent,
    edge: .leading,
    axisDirection: axisDirection,
  );

  void _publish() => _snapshot.value = _compose();

  void dispose() {
    // 置空状态让仍在进行的 onRefresh 完成后不再回写。
    _status = null;
    _finishHold?.cancel();
    _settle.dispose();
    _snapshot.dispose();
  }

  // ───────────────────────── ElRefreshDetails ─────────────────────────

  @override
  ValueListenable<ElRefreshSnapshot> get snapshot => _snapshot;

  // 刷新停靠期间滚动正文会改变可见间隙而快照不变，所以把滚动位置一并作为重绘信号。
  @override
  Listenable get repaint => Listenable.merge([_snapshot, position]);

  @override
  ScrollPhysics get physics => position.physics;

  @override
  double? get contentGap => visibleGap;

  @override
  Rect? get contentViewportRect => null;

  @override
  Listenable? get contentLayoutChanges => null;

  @override
  void requestRefresh() {
    if (_status == null && refresher.triggerExtent > 0) _startRefresh(byGesture: false);
  }
}

class _SliverRefresh extends SingleChildRenderObjectWidget {
  const _SliverRefresh({required this.motion, required this.behind, super.child});

  final _RefreshMotion motion;
  final bool behind;

  @override
  _RenderSliverRefresh createRenderObject(BuildContext context) => _RenderSliverRefresh(motion, behind);

  // motion 在组件生命周期内是同一个实例，只有层级会变。
  @override
  void updateRenderObject(BuildContext context, _RenderSliverRefresh renderObject) => renderObject.behind = behind;
}

/// 刷新 Sliver 的几何：滚动范围等于让出的间隙，指示器铺满视口并钉在本 Sliver 的可见起点。
class _RenderSliverRefresh extends RenderSliverSingleBoxAdapter {
  _RenderSliverRefresh(this._motion, this._behind);

  final _RefreshMotion _motion;
  final _clip = LayerHandle<ClipRectLayer>();

  bool _behind;
  set behind(bool value) {
    if (value == _behind) return;
    _behind = value;
    markNeedsPaint();
  }

  // 上一次布局用到的状态；指示器自己监听快照重绘，本对象只关心影响几何的这两项。
  double _gap = 0;
  bool _active = false;
  AxisDirection _direction = .down;

  void _handleMotion() {
    if (_motion.gap != _gap || _motion.active != _active) markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion.snapshot.addListener(_handleMotion);
  }

  @override
  void detach() {
    _motion.snapshot.removeListener(_handleMotion);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  // 指示器不随滚动偏移移动，始终贴着本 Sliver 的可见起点。
  @override
  double childMainAxisPosition(RenderBox child) => 0;

  @override
  void performLayout() {
    final constraints = this.constraints;
    final gap = _motion.gap;
    final change = gap - _gap;
    _gap = gap;
    _active = _motion.active;
    if (change != 0 && constraints.scrollOffset > precisionErrorTolerance) {
      // 间隙在已经滚过的位置变化（刷新完成时正文已上滚、滚动途中程序触发刷新）：
      // 同步修正滚动偏移，屏幕上的正文不跟着跳。
      geometry = SliverGeometry(scrollOffsetCorrection: math.max(change, -constraints.scrollOffset));
      return;
    }

    final viewport = constraints.viewportMainAxisExtent;
    final child = this.child!..layout(constraints.asBoxConstraints(minExtent: viewport, maxExtent: viewport));
    final visible = math.max(0.0, math.min(gap - constraints.scrollOffset, constraints.remainingPaintExtent));
    // overlap 为负表示正文按物理越界，这段距离同样是露出的间隙。
    _motion.visibleGap = visible - math.min(0.0, constraints.overlap);
    geometry = SliverGeometry(
      scrollExtent: gap,
      // 越界时本 Sliver 被整体推离视口起点，前面有固定头时又会被盖住，按 overlap 钉回可见起点。
      paintOrigin: constraints.overlap,
      paintExtent: visible,
      layoutExtent: visible,
      maxPaintExtent: gap,
      // 悬浮式不占位，仍然需要绘制，并交给视口裁剪。
      visible: _active,
      hasVisualOverflow: _active,
    );

    _direction = applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection);
    // 反向时绘制区域的起点在远端，把铺满视口的指示器对齐到滚动起点一侧。
    (child.parentData! as SliverPhysicalParentData).paintOffset = switch (_direction) {
      AxisDirection.up => Offset(0, visible - viewport),
      AxisDirection.left => Offset(visible - viewport, 0),
      AxisDirection.down || AxisDirection.right => Offset.zero,
    };
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final gap = _motion.visibleGap;
    if (child == null || !geometry!.visible || (_behind && gap <= 0)) {
      _clip.layer = null;
      return;
    }
    final origin = offset + (child.parentData! as SliverPhysicalParentData).paintOffset;
    if (!_behind) {
      _clip.layer = null;
      context.paintChild(child, origin);
      return;
    }
    // 本 Sliver 画在后续 Sliver 之上；指示器要显得在正文之下，就只画正文让出的那一条。
    final size = child.size;
    final strip = switch (_direction) {
      AxisDirection.down => Rect.fromLTWH(0, 0, size.width, gap),
      AxisDirection.up => Rect.fromLTWH(0, size.height - gap, size.width, gap),
      AxisDirection.right => Rect.fromLTWH(0, 0, gap, size.height),
      AxisDirection.left => Rect.fromLTWH(size.width - gap, 0, gap, size.height),
    };
    _clip.layer = context.pushClipRect(
      needsCompositing,
      origin,
      strip,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _clip.layer,
    );
  }
}
