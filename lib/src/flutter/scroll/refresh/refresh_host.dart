// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show RefreshIndicatorStatus;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase, TickerCanceled, TickerFuture;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import '../physics/bouncing_scroll_physics.dart';
import '../nested/scroll_delta_source.dart';
import 'refresher.dart';

/// 连接 ElScroll 的输入协作、真实滚动位置与刷新停靠物理。
final class RefreshScrollLink {
  /// 创建当前刷新宿主的输入连接。
  RefreshScrollLink();

  _RefreshHostState? _host;

  /// 宿主滚动视图注入的 position 源；拉出余量判定、bouncing 停靠收口都经它。
  ScrollPosition Function()? position;

  /// 新官方 Scrollable 宿主对当前拖拽活动的只读判断，避免访问受保护的 activity。
  bool Function()? directDragActive;

  /// bouncing 停靠：刷新边缘的外扩量（armed / refreshing 期间 =
  /// refreshingExtent，其余 0）。[RefreshDockPhysics] 据此偏移边界，
  /// 松手 spring 的回弹目标落在指示器下方——内容不完全回位，露出间隙
  /// 即指示器的停靠位。min/max 两侧按 [ElRefreshEdge] 各自生效。
  double dockMinExtension = 0.0;
  double dockMaxExtension = 0.0;

  /// finishing 弹簧送回期间为 true：越界侧的 ballistic 一律用停靠弹簧收到
  /// （外扩后的）边界，禁走 [ElBouncingScrollPhysics] 的动量修正摩擦
  /// 穿越——applyNewDimensions（如刷新完成重置条数）继承速度重建的
  /// ballistic 会借那条路带动量冲过真实边界进内容区（结束"再弹一下"的
  /// 另一形态）。仅收窄这个程序化送回窗口，平时用户越界反甩的动量修正
  /// 不受影响。
  bool finishBallisticDocking = false;

  /// 手指向内甩动仍拥有正文动量，刷新完成不能将它改成停靠回弹。
  bool preservesInwardMomentum = false;

  /// 本 link 服务的刷新边（host 挂载写入）；拉出上限与回弹弹簧只对这一侧
  /// 越界生效，另一侧保持官方物理。
  ElRefreshEdge? refreshEdge;

  /// 刷新边触摸拉出的硬上限（相对**真实边界**的越界像素）；infinity =
  /// 不限（官方橡皮筋渐近界）。min/max 两侧按 [refreshEdge] 各自生效。
  double pullMinLimit = double.infinity;
  double pullMaxLimit = double.infinity;

  /// 刷新边越界回弹的弹簧（停靠 / 取消滑回 / 送回统一）；null = 官方弹簧。
  SpringDescription? refreshSpring;

  /// 已经拉出的拖拽或取消回收状态优先于普通输入参与者。
  bool get hasActivePull =>
      _host != null &&
      _host!._pulled > precisionErrorTolerance &&
      (_host!._status == RefreshIndicatorStatus.drag ||
          _host!._status == RefreshIndicatorStatus.armed ||
          _host!._status == RefreshIndicatorStatus.canceled);

  /// 内容让位与刷新收尾由刷新器决定，不能用基础物理类型推断。
  bool get movesContent => _host?.widget.refresher.movesContent ?? false;

  /// 只有已激活的内容刷新才拥有停靠和回位物理，惯性冲顶不进入此窗口。
  bool get hasContentMotion => movesContent && _host?._status != null;

  /// 统一路线以物理手指方向处理已有拉出，非触摸来源只能回收。
  double consumeActive(double delta, ElScrollDeltaSource source) =>
      hasActivePull && (source == ElScrollDeltaSource.touchDrag || !preservesInwardMomentum)
      ? _host!._handleRefreshDragDelta(delta, allowPull: source == ElScrollDeltaSource.touchDrag)
      : 0;

  /// 新刷新接收本层正文与效果处理后的触摸余量，优先于更外层正文。
  double consumeBoundaryPull(double delta, ElScrollDeltaSource source) => source == ElScrollDeltaSource.touchDrag
      ? (_host?._handleRefreshDragDelta(delta, allowRecovery: false, boundaryRemainder: true) ?? 0)
      : 0;

  /// 只结算本刷新器的释放，不重复调用旧链中的其他参与者。
  double releaseInput(double velocity) => _host?._handleRefreshFlingVelocity(velocity) ?? velocity;

  /// 手势取消时收回当前拉距，不触发刷新。
  void cancelInput() => _host?._cancelRefreshInput();
}

/// 刷新边的输入与停靠适配：触摸时按刷新形态允许内容让位或固定正文，
/// 松手后只为已激活的内容刷新提供停靠弹簧，其余惯性直通容器物理。
/// 停靠边界和拖拽阻尼基准随 dock 外扩，真实正文范围保持不变。
final class RefreshDockPhysics extends ScrollPhysics {
  const RefreshDockPhysics({required this.getLink, super.parent});

  final RefreshScrollLink? Function() getLink;

  @override
  RefreshDockPhysics applyTo(ScrollPhysics? ancestor) {
    return RefreshDockPhysics(getLink: getLink, parent: buildParent(ancestor));
  }

  bool get _directDrag => getLink()?.directDragActive?.call() ?? false;

  bool _onRefreshSide(ScrollMetrics metrics, double value) {
    if (!metrics.hasPixels || !metrics.hasContentDimensions) return false;
    return switch (getLink()?.refreshEdge) {
      ElRefreshEdge.leading =>
        value <= metrics.maxScrollExtent && math.min(metrics.pixels, value) < metrics.minScrollExtent,
      ElRefreshEdge.trailing =>
        value >= metrics.minScrollExtent && math.max(metrics.pixels, value) > metrics.maxScrollExtent,
      null => false,
    };
  }

  ScrollMetrics _docked(ScrollMetrics position) {
    final link = getLink();
    if (link == null) return position;
    final minExt = link.dockMinExtension;
    final maxExt = link.dockMaxExtension;
    if (minExt <= 0.0 && maxExt <= 0.0) return position;
    if (!position.hasContentDimensions) return position;
    return position.copyWith(
      minScrollExtent: position.minScrollExtent - minExt,
      maxScrollExtent: position.maxScrollExtent + maxExt,
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final link = getLink();
    if (link == null ||
        !_directDrag ||
        !_onRefreshSide(position, position.pixels - offset) ||
        (position.pixels > position.minScrollExtent && position.pixels < position.maxScrollExtent)) {
      return super.applyPhysicsToUserOffset(position, offset);
    }
    if (!link.movesContent) return offset;
    final adjusted = const BouncingScrollPhysics().applyPhysicsToUserOffset(_docked(position), offset);
    if (position.hasPixels && position.hasContentDimensions) {
      // 刷新边拉出硬上限（相对真实边界记账；停靠外扩只影响回弹目标）：
      // 越界达到上限后，加深方向的手指增量整笔吃掉；回收方向恒放行。
      // userOffset 正 = pixels 减小 = min 侧越界加深，负则对称作用于 max 侧。
      if (offset > 0 && link.pullMinLimit.isFinite) {
        final over = position.minScrollExtent - position.pixels;
        if (over >= link.pullMinLimit - precisionErrorTolerance) return 0.0;
        if (over >= 0) {
          return math.min(adjusted, link.pullMinLimit - over);
        }
      }
      if (offset < 0 && link.pullMaxLimit.isFinite) {
        final over = position.pixels - position.maxScrollExtent;
        if (over >= link.pullMaxLimit - precisionErrorTolerance) return 0.0;
        if (over >= 0) {
          return math.max(adjusted, -(link.pullMaxLimit - over));
        }
      }
    }
    return adjusted;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final link = getLink();
    if (link != null && (_directDrag || link.hasContentMotion) && _onRefreshSide(position, value)) {
      return link.movesContent ? 0 : const ClampingScrollPhysics().applyBoundaryConditions(position, value);
    }
    return super.applyBoundaryConditions(position, value);
  }

  /// 容器已有的 bouncing 动量修正仍允许用户向内反甩穿回正文。
  ElBouncingScrollPhysics? get _bouncingAncestor {
    for (ScrollPhysics? node = parent; node != null; node = node.parent) {
      if (node is ElBouncingScrollPhysics) return node;
    }
    return null;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final link = getLink();
    if (link?.preservesInwardMomentum == true) {
      // 刷新产生的间隙也允许反甩穿回正文；跨界后由协调器按同一速度续接容器物理。
      if (_onRefreshSide(position, position.pixels)) {
        return (_bouncingAncestor ?? const ElBouncingScrollPhysics()).createBallisticSimulation(position, velocity);
      }
      return super.createBallisticSimulation(position, velocity);
    }
    if (link != null && link.hasContentMotion) {
      final docked = _docked(position);
      final overAtTrailing = docked.pixels > docked.maxScrollExtent;
      final onRefreshSide =
          docked.outOfRange &&
          switch (link.refreshEdge) {
            ElRefreshEdge.leading => !overAtTrailing,
            ElRefreshEdge.trailing => overAtTrailing,
            null => false,
          };
      final bouncing = _bouncingAncestor;
      final spring = link.refreshSpring;
      // finishing 送回窗口恒接管；平时刷新边越界配置了停靠弹簧（WebKit
      // 临界阻尼）也接管——但给动量修正让路（用户越界反甩穿回列表），
      // finishing 窗口除外（继承速度的重建借道会冲进内容区）。
      final capture =
          link.finishBallisticDocking ||
          (onRefreshSide && !(bouncing?.carriesInwardMomentum(docked, velocity) ?? false));
      if (capture && docked.outOfRange) {
        // 临界/过阻尼弹簧带向内初速也不会穿越目标（需 v > λ₂·|x₀| 才可能，
        // 远超本场景量级），回弹全程决不进入内容区。
        return BouncingScrollSimulation(
          spring: spring ?? const BouncingScrollPhysics().spring,
          position: docked.pixels,
          velocity: velocity,
          leadingExtent: docked.minScrollExtent,
          trailingExtent: docked.maxScrollExtent,
          tolerance: toleranceFor(docked),
        );
      }
    }
    return super.createBallisticSimulation(link?.hasContentMotion == true ? _docked(position) : position, velocity);
  }
}

/// 在一个 El 滚动视口之上挂载类式下拉刷新，并保持指示器分层。
///
/// host 刻意位于视口 child 列表之外：指示器独立成层，不污染滚动 extent 与
/// 子项索引。层级按 [ElRefresher.behindContent] 分派：内容让位式默认沉到内容
/// 之下并按露出间隙裁剪（[RefreshGapClip]），悬浮式默认浮在内容之上。
/// 状态机数据源是视口冒泡的标准 [ScrollNotification]（depth == 0
/// 只认直接子视口，嵌套滚动不误触）：
/// - 悬浮式：经 [RefreshScrollLink] 累计和回收手指行程；独立挂载时才用越界通知兜底。
/// - 内容让位式：取 metrics 的真实越界距离，触摸适配和停靠物理负责正文位移。
class RefreshHost extends StatefulWidget {
  const RefreshHost({
    super.key,
    required this.refresher,
    required this.physics,
    required this.onRefresh,
    required this.axisDirection,
    this.edge = ElRefreshEdge.leading,
    this.link,
    required this.child,
  });

  final ElRefresher refresher;

  /// 当前平台最终生效的滚动物理。
  final ScrollPhysics physics;

  /// 刷新回调；返回的 Future 完成后指示器收起。
  final Future<void> Function() onRefresh;

  final AxisDirection axisDirection;

  final ElRefreshEdge edge;

  /// 宿主滚动视图注入 delta 链的接线件；null = 无拦截（独立挂载场景，
  /// 回收退化为"上拖同时滚动列表"）。
  final RefreshScrollLink? link;

  final Widget child;

  @override
  State<RefreshHost> createState() => _RefreshHostState();
}

class _RefreshHostState extends State<RefreshHost> with SingleTickerProviderStateMixin {
  /// 裁剪层重绘信号：滚动通知里内容位移但快照不变的帧（refreshing/finishing
  /// 状态机早退段）由它驱动 [RefreshGapClip] 重算条带。
  final ValueNotifier<int> _gapTick = ValueNotifier<int>(0);

  late final _RefreshDetails _details = _RefreshDetails(
    requestRefresh: _requestRefresh,
    repaint: _gapTick,
    physicsOf: () => widget.physics,
    contentGapOf: _contentGap,
  );

  /// 收起/停靠动画（松手回弹、refreshing 停靠、finishing 收起共用）。
  /// initState 主动创建：late 惰性会让"从未越界"的实例在 dispose 里首次
  /// 初始化，届时 Ticker 创建需查找的 TickerMode 祖先已失活 → 抛错。
  late final AnimationController _settle;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: widget.refresher.settleDuration)
      ..addListener(_handleSettleTick);
    widget.link?._host = this;
    _syncDock();
  }

  @override
  void didUpdateWidget(covariant RefreshHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.link, widget.link)) {
      final old = oldWidget.link;
      if (old != null && identical(old._host, this)) {
        old._host = null;
        old.dockMinExtension = 0.0;
        old.dockMaxExtension = 0.0;
        old.finishBallisticDocking = false;
        old.preservesInwardMomentum = false;
        old.refreshEdge = null;
        old.refreshSpring = null;
        old.pullMinLimit = double.infinity;
        old.pullMaxLimit = double.infinity;
      }
      widget.link?._host = this;
      _syncDock();
    }
    if (!identical(oldWidget.physics, widget.physics) || !identical(oldWidget.refresher, widget.refresher)) {
      _syncDock();
    }
  }

  RefreshIndicatorStatus? _status;
  double _pulled = 0.0;
  bool _dragging = false;
  double _settleFrom = 0.0;
  double _settleTo = 0.0;

  /// finishing 走弹簧送回（bouncing 停靠 + 有露出间隙）时为 true：pulled 不再
  /// 由 [_settle] 补间驱动，而是在滚动通知里逐帧跟随内容真实间隙塌缩，
  /// 间隙归零即 idle 收场；clamping / 无间隙的 finishing 仍走定时补间。
  bool _finishFollowsContent = false;

  /// finishing 起点内容仍在停靠位之外（刷新极快完成、spring 高速飞行中）时
  /// 保持停靠外扩：若立即撤掉，途中任何 goBallistic 重建（如条数重置触发
  /// applyNewDimensions）都会以"目标 0 + 继承高速"造飞掠弹簧，带动量冲过
  /// 真实边界轻微过冲进内容区（用户看到"再弹一下"）。持有到内容飞抵停靠
  /// 位附近再撤，中继弹簧从近静止出发，物理上不会过冲。
  bool _finishDockHold = false;

  /// 最近一次正文越界量；悬浮刷新不能把先前惯性留下的间隙计入自身拉距。
  double _lastOut = 0.0;

  /// 拉出方向在用户 delta 空间的符号：指示器挂视觉起始侧时手指正向
  /// （下/右拖）为拉出，挂末尾侧反之。
  double get _pullSign => switch ((widget.edge, widget.axisDirection)) {
    (ElRefreshEdge.leading, AxisDirection.down || AxisDirection.right) => 1.0,
    (ElRefreshEdge.trailing, AxisDirection.up || AxisDirection.left) => 1.0,
    _ => -1.0,
  };

  /// 拉出方向上列表自身还能滚动的余量（pixels 到刷新边缘的距离）；
  /// 消费只取越过边缘的部分，边缘前的行程留给 position 正常滚动。
  /// position 未接线（独立挂载）视为余量无限 → 不消费。
  double get _pullRoom {
    final m = widget.link?.position?.call();
    if (m == null || !m.hasPixels || !m.hasContentDimensions) return double.infinity;
    return switch (widget.edge) {
      ElRefreshEdge.leading => math.max(0.0, m.pixels - m.minScrollExtent),
      ElRefreshEdge.trailing => math.max(0.0, m.maxScrollExtent - m.pixels),
    };
  }

  /// 内容让位式刷新保留停靠间隙，悬浮式刷新只移动指示器。
  bool get _dockable => widget.refresher.movesContent;

  /// 把当前停靠外扩量同步给 link（供 [RefreshDockPhysics] 读取）：
  /// armed 起即生效——松手瞬间的 ballistic 在状态转 refreshing 之前创建，
  /// 边界必须已外扩，spring 才会停靠在指示器下方。
  void _syncDock() {
    final link = widget.link;
    if (link == null) return;
    final active =
        _dockable &&
        !link.preservesInwardMomentum &&
        (_status == RefreshIndicatorStatus.armed ||
            _status == RefreshIndicatorStatus.refresh ||
            (_status == RefreshIndicatorStatus.done && _finishDockHold));
    final extent = active ? widget.refresher.refreshingExtent : 0.0;
    // 拉出上限与刷新弹簧只约束内容让位；普通惯性不会使用它们。
    link.refreshEdge = widget.edge;
    link.refreshSpring = _dockable ? widget.refresher.settleSpring : null;
    final maxPull = _dockable ? (widget.refresher.maxPullExtent ?? double.infinity) : double.infinity;
    if (widget.edge == ElRefreshEdge.leading) {
      link.dockMinExtension = extent;
      link.dockMaxExtension = 0.0;
      link.pullMinLimit = maxPull;
      link.pullMaxLimit = double.infinity;
    } else {
      link.dockMinExtension = 0.0;
      link.dockMaxExtension = extent;
      link.pullMinLimit = double.infinity;
      link.pullMaxLimit = maxPull;
    }
  }

  /// 官方 nested scrolling 消费语义（touchDrag 专用）：
  /// - 拉出方向（onNestedScroll）：悬浮式刷新器把**越过刷新边缘**的
  ///   增量吃进指示器（边缘前的部分留给列表滚动）；delta 不进 position →
  ///   不派发越界 → stretch 与刷新指示器互斥（官方拉出期无 EdgeEffect）；
  /// - 回收方向（onNestedPreScroll）：先喂指示器回位，完全回位前列表不动。
  /// 返回消费量（与 delta 同号）。
  double _handleRefreshDragDelta(
    double delta, {
    bool allowPull = true,
    bool allowRecovery = true,
    bool boundaryRemainder = false,
  }) {
    if (allowPull) widget.link?.preservesInwardMomentum = false;
    if (_status == RefreshIndicatorStatus.refresh || _status == RefreshIndicatorStatus.done) return 0.0;
    final toward = delta * _pullSign;
    if (toward > 0) {
      if (!allowPull) return 0;
      // 内容让位式刷新器（内容跟手位移）不拦拉出，物理与 metrics 路径负责。
      if (_dockable) return 0.0;
      // post 阶段传入的已经是正文无法消费的余量，不能再次扣掉正文行程。
      final beyond = boundaryRemainder ? toward : toward - _pullRoom;
      if (beyond <= precisionErrorTolerance) return 0.0;
      _settle.stop();
      _resumeDraggingIfCanceling();
      _setPulled(_pulled + beyond);
      return beyond * _pullSign;
    }
    if (toward < 0 && _pulled > precisionErrorTolerance && !_dockable) {
      if (!allowRecovery) return 0;
      final consumedToward = -math.min(_pulled, -toward);
      _settle.stop();
      _resumeDraggingIfCanceling();
      _setPulled(_pulled + consumedToward);
      return consumedToward * _pullSign;
    }
    return 0.0;
  }

  void _cancelRefreshInput() {
    if (_status != RefreshIndicatorStatus.drag && _status != RefreshIndicatorStatus.armed) return;
    _dragging = false;
    _status = RefreshIndicatorStatus.canceled;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // 摘挂时先撤掉输入和停靠，等构建结束再通知仍存活的指示器。
      _syncDock();
      scheduler.addPostFrameCallback((_) {
        if (mounted && _status == RefreshIndicatorStatus.canceled) _settleCanceledPull();
      });
      return;
    }
    _settleCanceledPull();
  }

  void _settleCanceledPull() {
    if (!_dockable || _lastOut <= precisionErrorTolerance) _animatePulledTo(0);
    _publish();
  }

  /// canceling 收回途中重新触摸拖拽：续接回 dragging（官方新手势重新
  /// onInterceptTouchEvent 接管的对应物）。
  void _resumeDraggingIfCanceling() {
    if (_status == RefreshIndicatorStatus.canceled) _status = RefreshIndicatorStatus.drag;
  }

  /// 松手收尾（官方 onStopNestedScroll）：拉出被拦截器全量消费时列表无
  /// 滚动通知可依赖，drag end 必达的 velocity 拦截口就是松手信号——
  /// armed 触发刷新、未达标收回；越界行程不外溢列表 fling（吞掉速度）。
  double _handleRefreshFlingVelocity(double velocity) {
    final link = widget.link;
    final position = link?.position?.call();
    if (position != null && position.hasPixels && position.hasContentDimensions) _lastOut = _outOfRange(position);
    final carriesInward = _lastOut > precisionErrorTolerance && velocity * _pullSign < 0;
    if (link != null) {
      link.preservesInwardMomentum = carriesInward;
      if (carriesInward) {
        _finishDockHold = false;
        link.finishBallisticDocking = false;
      }
      _syncDock();
    }
    final active = _status == RefreshIndicatorStatus.drag || _status == RefreshIndicatorStatus.armed;
    if (!active || _pulled <= precisionErrorTolerance) return velocity;
    _dragging = false;
    if (_status == RefreshIndicatorStatus.armed) {
      _startRefresh();
    } else if (!_settle.isAnimating) {
      // 官方 finishSpinner 取消分支：即刻进入 canceling（指示器视觉在本帧
      // 清空弧与箭头），空指示器滑回视口外。
      _status = RefreshIndicatorStatus.canceled;
      if (!_dockable || _lastOut <= precisionErrorTolerance) _animatePulledTo(0.0);
      _publish();
    }
    return carriesInward || (_dockable && _lastOut > precisionErrorTolerance) ? velocity : 0.0;
  }

  @override
  void dispose() {
    final link = widget.link;
    if (link != null && identical(link._host, this)) {
      link._host = null;
      link.dockMinExtension = 0.0;
      link.dockMaxExtension = 0.0;
      link.finishBallisticDocking = false;
      link.preservesInwardMomentum = false;
      link.refreshEdge = null;
      link.refreshSpring = null;
      link.pullMinLimit = double.infinity;
      link.pullMaxLimit = double.infinity;
    }
    _settle.dispose();
    _details.dispose();
    _gapTick.dispose();
    super.dispose();
  }

  // ---- 状态机 ----

  void _publish() {
    _syncDock();
    _details.update(
      ElRefreshSnapshot(
        status: _status,
        pulledExtent: _pulled,
        triggerExtent: widget.refresher.triggerExtent,
        edge: widget.edge,
        axisDirection: widget.axisDirection,
      ),
    );
  }

  void _setPulled(double value) {
    _pulled = value.clamp(0.0, double.infinity).toDouble();
    if (_status == null || _status == RefreshIndicatorStatus.drag || _status == RefreshIndicatorStatus.armed) {
      _status = _pulled <= precisionErrorTolerance
          ? null
          : (_pulled >= widget.refresher.triggerExtent ? RefreshIndicatorStatus.armed : RefreshIndicatorStatus.drag);
      // 官方 CupertinoSliverRefreshControl 的"armed 即起跑 onRefresh + 震动"
      // 不跟随（用户裁决：不符合用户心智）——armed 拉回阈值内自然降级回
      // dragging 撤销承诺，触觉挪到松手激活刷新的那一刻（_startRefresh）。
    } else if (_status == RefreshIndicatorStatus.canceled && _pulled <= precisionErrorTolerance) {
      // 收回完成；canceling 期间不自动回升 dragging/armed（手势已结束），
      // 重新触摸的续接由拖拽消费入口显式恢复。
      _status = null;
    }
    _publish();
  }

  void _handleSettleTick() {
    // finishing 用专属曲线（安卓 scale-down 是缓起缓收），其余停靠/收回
    // 走 settleCurve；曲线按状态取，避免收起动画前段陡降成"突然消失"。
    final curve = _status == RefreshIndicatorStatus.done ? widget.refresher.finishCurve : widget.refresher.settleCurve;
    final t = curve.transform(_settle.value);
    _pulled = _settleFrom + (_settleTo - _settleFrom) * t;
    if (_settle.isCompleted) {
      _pulled = _settleTo;
      if (_settleTo == 0.0 &&
          (_status == RefreshIndicatorStatus.done ||
              _status == RefreshIndicatorStatus.drag ||
              _status == RefreshIndicatorStatus.canceled)) {
        _status = null;
      }
    }
    _publish();
  }

  TickerFuture _animatePulledTo(double target, {Duration? duration}) {
    _settleFrom = _pulled;
    _settleTo = target;
    _settle
      ..stop()
      ..duration = duration ?? widget.refresher.settleDuration;
    return _settle.forward(from: 0.0);
  }

  void _startRefresh({bool byGesture = true}) {
    if (_status == RefreshIndicatorStatus.refresh || _status == RefreshIndicatorStatus.done) return;
    // 触觉在"松手激活刷新"的这一刻给（用户裁决），程序化触发不震。
    if (byGesture && widget.refresher.hapticOnTrigger) HapticFeedback.mediumImpact();
    _status = RefreshIndicatorStatus.refresh;
    _finishFollowsContent = false;
    _finishDockHold = false;
    widget.link?.finishBallisticDocking = false;
    // bouncing 且内容在停靠位外：停靠段 pulled 由通知跟随驱动（与内容同速
    // 塌缩），不启动补间抢跑；展开场景（requestRefresh / 越界不足）才用
    // 补间把 pulled 送到停靠位。
    TickerFuture? docking;
    if (!_dockable || _lastOut <= widget.refresher.refreshingExtent + precisionErrorTolerance) {
      docking = _animatePulledTo(widget.refresher.refreshingExtent);
    }
    _publish();
    _settleContentToDock(byGesture: byGesture);
    Future<void>(() => widget.onRefresh()).whenComplete(() async {
      if (!mounted) return;
      // 悬浮圆盘必须先完整停靠，快速完成的刷新不能跳过位移动画直接进入原地缩小。
      if (!_dockable && docking != null) {
        try {
          await docking.orCancel;
        } on TickerCanceled {
          return;
        }
      }
      if (!mounted) return;
      _status = RefreshIndicatorStatus.done;
      final pos = _dockable ? widget.link?.position?.call() : null;
      final gap = pos != null && pos.hasPixels && pos.hasContentDimensions ? _outOfRange(pos) : 0.0;
      if (pos != null && gap > precisionErrorTolerance && pos is ScrollActivityDelegate) {
        // 弹簧送回（官方 CupertinoSliverRefreshControl 撤 sliver 占位的口径，
        // 也与"未达阈值取消"的回弹同一手感）：撤掉停靠外扩（_publish →
        // _syncDock）后把越界量交还 bouncing 物理——从静止起步加速度连续，
        // 没有定时补间 easeOut 首帧的猛拽；指示器在通知里逐帧跟随间隙塌缩。
        _finishFollowsContent = true;
        _finishDockHold = !(widget.link?.preservesInwardMomentum ?? false);
        widget.link?.finishBallisticDocking = _finishDockHold;
        _settle.stop();
        _publish();
        final delay = widget.refresher.finishDelay;
        final flying = pos.isScrollingNotifier.value;
        if (!flying && delay > Duration.zero && gap <= widget.refresher.refreshingExtent + precisionErrorTolerance) {
          // 完成态停留：内容钉在停靠位（外扩保持）展示完成视觉，届时再
          // 启动送回；停留期间用户拖拽经 follow 分支撤 hold = 打断提前送回。
          Future<void>.delayed(delay).then((_) => _beginFinishReturn());
        } else if (!flying) {
          _beginFinishReturn();
        }
        // flying：停靠 spring 仍在途（刷新极快完成）/ 手指按住时不打断——
        // 飞抵停靠位（follow 分支撤 hold）后，当前活动结束时自带的
        // goBallistic 以撤掉外扩的新鲜 metrics 接力送回，速度全程连续。
      } else {
        // clamping（安卓原地缩小消失）/ 未接线 / 无间隙：定时收起补间。
        _finishFollowsContent = false;
        _animatePulledTo(0.0, duration: widget.refresher.finishDuration);
        _publish();
      }
    });
  }

  /// 完成态停留结束（或无停留）后的送回启动：撤停靠外扩，把内容交还弹簧。
  /// 停留被用户打断（follow 分支已撤 hold）或已收场时幂等退出。
  void _beginFinishReturn() {
    if (!mounted || _status != RefreshIndicatorStatus.done || !_finishFollowsContent) return;
    if (!_finishDockHold) return;
    _finishDockHold = false;
    _publish();
    final pos = widget.link?.position?.call();
    if (pos == null || !pos.hasPixels || !pos.hasContentDimensions) return;
    if (_outOfRange(pos) <= precisionErrorTolerance) return;
    if (pos is ScrollActivityDelegate && !pos.isScrollingNotifier.value) {
      (pos as ScrollActivityDelegate).goBallistic(0.0);
    }
  }

  /// bouncing 停靠开口（程序化 requestRefresh / 释放行程不足的兜底）：
  /// 内容尚未到达停靠位时，主动把内容送到指示器下方；已经拉到停靠位
  /// 之外的手势释放交给 spring 自然停靠，此处不介入。
  void _settleContentToDock({required bool byGesture}) {
    if (!_dockable) return;
    if (widget.link?.preservesInwardMomentum ?? false) return;
    final pos = widget.link?.position?.call();
    if (pos == null || !pos.hasPixels || !pos.hasContentDimensions) return;
    // 快速反甩首帧可能已经穿过停靠点，不能另起定位动画打断用户仍在运行的惯性。
    if (byGesture && pos.isScrollingNotifier.value) return;
    final dock = widget.refresher.refreshingExtent;
    if (_outOfRange(pos) >= dock - precisionErrorTolerance) return;
    final target = switch (widget.edge) {
      ElRefreshEdge.leading => pos.minScrollExtent - dock,
      ElRefreshEdge.trailing => pos.maxScrollExtent + dock,
    };
    pos.animateTo(target, duration: widget.refresher.settleDuration, curve: widget.refresher.settleCurve);
  }

  void _requestRefresh() {
    if (_status != null) return;
    _startRefresh(byGesture: false);
  }

  // ---- 通知解析 ----

  /// 当前 metrics 在本 host 关注边缘的越界距离（bouncing 物理为正值）。
  double _outOfRange(ScrollMetrics metrics) {
    if (!metrics.hasContentDimensions || !metrics.hasPixels) return 0.0;
    return switch (widget.edge) {
      ElRefreshEdge.leading => metrics.minScrollExtent - metrics.pixels,
      ElRefreshEdge.trailing => metrics.pixels - metrics.maxScrollExtent,
    };
  }

  /// 悬浮式刷新器的拉出、回收与释放统一走输入消费，避免按内容越界重复计数。
  bool get _interceptsPull => widget.link != null && !_dockable;

  /// 内容位移让出的真实间隙（bouncing 越界像素）；未接线返回 null。
  /// [RefreshGapClip] 用它对 pulled 取 min——裁剪条带决不越入内容区。
  double? _contentGap() {
    final pos = widget.link?.position?.call();
    if (pos == null || !pos.hasPixels || !pos.hasContentDimensions) return null;
    return _outOfRange(pos);
  }

  bool _handleNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      widget.link?.preservesInwardMomentum = false;
    }
    if (notification is ScrollEndNotification && !notification.metrics.outOfRange) {
      widget.link?.preservesInwardMomentum = false;
    }
    // 指示器在场时内容每帧位移都可能改变裁剪条带（尤其 refreshing/finishing
    // 期状态机早退、快照不动的帧），踢一脚裁剪层重绘；idle 常规滚动不踢。
    if (_pulled > precisionErrorTolerance ||
        _status == RefreshIndicatorStatus.refresh ||
        _status == RefreshIndicatorStatus.done) {
      _gapTick.value++;
    }
    // finishing 弹簧送回：指示器逐帧跟随真实间隙塌缩，间隙归零即 idle 收场。
    // 跟随分两档：弹道帧只减不增（快速完成时 pulled 落后于间隙，原地等间隙
    // 缩到 pulled 以下再跟随，防向下跳变）；用户拖拽帧双向跟手（按住再拖大
    // 间隙时文案必须继续居中——单向钳制会把文案钉死在打断位，即用户报告的
    // "锁定滚动后文案卡在那里"）。
    if (_status == RefreshIndicatorStatus.done && _finishFollowsContent) {
      switch (notification) {
        case ScrollStartNotification(:final dragDetails):
          // finishing 中用户重新触摸：维护 _dragging，让收场后（如拖回界内
          // 立即 idle）接续的普通状态机能正确检测本手势的松手时刻。
          _dragging = dragDetails != null;
        case ScrollUpdateNotification(:final dragDetails, :final metrics):
          if (dragDetails != null) _dragging = true;
          final out = _outOfRange(metrics);
          _lastOut = out;
          // 内容飞抵停靠位附近：撤外扩（下方 _setPulled → _publish 生效），
          // 飞行中的 sim 收束到停靠位后自带的 goBallistic 以新鲜 metrics
          // 从近静止接力送回真实边界。
          if (_finishDockHold && out <= widget.refresher.refreshingExtent + precisionErrorTolerance) {
            _finishDockHold = false;
          }
          if (out <= precisionErrorTolerance) {
            _finishFollowsContent = false;
            _finishDockHold = false;
            widget.link?.finishBallisticDocking = false;
            _status = null;
            _setPulled(0.0);
          } else if (dragDetails != null) {
            _setPulled(out);
          } else {
            _setPulled(math.min(_pulled, out));
          }
        case ScrollEndNotification(:final metrics):
          // 弹簧在 tolerance 内提前收束的兜底：间隙已尽则归零收场；仍有
          // 间隙（停靠 spring 接力间的空档 / 手指按住）则等下一段 ballistic。
          if (_outOfRange(metrics) <= precisionErrorTolerance) {
            _finishFollowsContent = false;
            _finishDockHold = false;
            widget.link?.finishBallisticDocking = false;
            _status = null;
            _setPulled(0.0);
          }
        default:
          break;
      }
      return false;
    }
    // refreshing 停靠段：松手弹簧把内容送往停靠位时，pulled 逐帧跟随真实
    // 间隙塌缩（与内容同速）——不再让独立 220ms 补间抢跑。文字行先蹿到
    // 停靠位、内容还在半路的双速分叉，就是"释放→刷新中回弹生硬"的主观
    // 来源。间隙在停靠位以内（requestRefresh 展开段 / 已停靠）不干预，
    // 交给 _animatePulledTo 的展开补间。
    if (_status == RefreshIndicatorStatus.refresh && _dockable) {
      if (notification case ScrollUpdateNotification(:final metrics)) {
        final out = _outOfRange(metrics);
        _lastOut = out;
        if (out > widget.refresher.refreshingExtent + precisionErrorTolerance) {
          _settle.stop();
          _setPulled(out);
        } else if (!_settle.isAnimating &&
            (_pulled - widget.refresher.refreshingExtent).abs() > precisionErrorTolerance) {
          // 跟随收尾：间隙抵达停靠位后钉住。
          _setPulled(widget.refresher.refreshingExtent);
        }
      }
      return false;
    }
    if (_status == RefreshIndicatorStatus.refresh || _status == RefreshIndicatorStatus.done) return false;

    switch (notification) {
      case ScrollStartNotification(:final dragDetails):
        _dragging = dragDetails != null;
      case OverscrollNotification(:final dragDetails, :final overscroll):
        // clamping 物理：位置钉在边界，越界量只出现在 overscroll 字段。
        // link + 悬浮式刷新器的拉出走拦截器路径（delta 不进 position），
        // 此累计仅为独立挂载兜底——双路径同时生效会重复计数。
        if (_dragging && dragDetails != null && !_interceptsPull) {
          final toward = switch (widget.edge) {
            ElRefreshEdge.leading => -overscroll,
            ElRefreshEdge.trailing => overscroll,
          };
          if (toward > 0) {
            _settle.stop();
            _resumeDraggingIfCanceling();
            _setPulled(_pulled + toward);
          }
        }
      case ScrollUpdateNotification(:final dragDetails, :final metrics, :final scrollDelta):
        // 松手判定必须在这里做，不能只等 ScrollEnd：bouncing 物理松手后是
        // 弹道回弹，ScrollEnd 要回弹飞完才派发，途中回弹帧会把 pulled 拉
        // 回阈值以下、armed 丢失。第一个 dragDetails == null 的 update 即
        // 松手瞬间。
        if (_dragging && dragDetails == null) {
          _dragging = false;
          if (_status == RefreshIndicatorStatus.armed) {
            _startRefresh();
            return false;
          }
          // 未达阈值松手（bouncing 弹道回弹起点）：即刻 canceling，弧与
          // 箭头本帧清空（官方 finishSpinner 取消分支）。
          if (_status == RefreshIndicatorStatus.drag && _pulled > 0) {
            _status = RefreshIndicatorStatus.canceled;
            _publish();
          }
        }
        final out = _outOfRange(metrics);
        _lastOut = out;
        if (_dockable && out > 0 && dragDetails != null) {
          // bouncing 物理：拖拽期间越界像素即拉出距离，直接跟随。
          _settle.stop();
          _resumeDraggingIfCanceling();
          _setPulled(out);
        } else if (_dockable && out <= 0 && dragDetails != null && _pulled > 0) {
          // 同一手势已经回到正文：旧拉距与 armed 必须当帧撤销，不能在松手时吞掉惯性。
          _settle.stop();
          _setPulled(0);
        } else if (_dockable && out > 0 && _pulled > 0 && !_settle.isAnimating) {
          // 未达阈值松手后的弹道回弹：跟随回弹衰减。
          _setPulled(out);
        } else if (_pulled > 0 && dragDetails != null && widget.link == null) {
          // clamping 物理下反向拖回（无 link 的独立挂载兜底）：按滚动增量
          // 消耗已拉出距离。有 link 时回收在拦截器层先于 position 完成
          // （官方 onNestedPreScroll 语义），不会走到这里。
          final consumed = switch (widget.edge) {
            ElRefreshEdge.leading => scrollDelta ?? 0.0,
            ElRefreshEdge.trailing => -(scrollDelta ?? 0.0),
          };
          if (consumed > 0) _setPulled(_pulled - consumed);
        } else if (_dockable && out <= 0 && _pulled > 0 && dragDetails == null && !_settle.isAnimating) {
          // 回弹结束帧 / 非拖拽回位：归零收尾。
          _setPulled(0.0);
        }
      case ScrollEndNotification():
        _dragging = false;
        if (_status == RefreshIndicatorStatus.armed) {
          _startRefresh();
        } else if (_pulled > 0 && !_settle.isAnimating) {
          if (_status == RefreshIndicatorStatus.drag) _status = RefreshIndicatorStatus.canceled;
          _animatePulledTo(0.0);
          _publish();
        }
      default:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: widget.refresher.build(context, _details, widget.child),
    );
  }
}

final class _RefreshDetails implements ElRefreshDetails {
  _RefreshDetails({
    required VoidCallback requestRefresh,
    required this.repaint,
    required ScrollPhysics Function() physicsOf,
    required double? Function() contentGapOf,
  }) : _requestRefresh = requestRefresh,
       _physicsOf = physicsOf,
       _contentGapOf = contentGapOf;

  final VoidCallback _requestRefresh;
  final ScrollPhysics Function() _physicsOf;
  final double? Function() _contentGapOf;

  @override
  Rect? get contentViewportRect => null;

  @override
  Listenable? get contentLayoutChanges => null;

  @override
  final Listenable repaint;

  final ValueNotifier<ElRefreshSnapshot> _snapshot = ValueNotifier<ElRefreshSnapshot>(
    const ElRefreshSnapshot(
      status: null,
      pulledExtent: 0.0,
      triggerExtent: 0.0,
      edge: ElRefreshEdge.leading,
      axisDirection: AxisDirection.down,
    ),
  );

  @override
  ValueListenable<ElRefreshSnapshot> get snapshot => _snapshot;

  @override
  ScrollPhysics get physics => _physicsOf();

  @override
  double? get contentGap => _contentGapOf();

  @override
  void requestRefresh() => _requestRefresh();

  void update(ElRefreshSnapshot next) {
    if (_snapshot.value == next) return;
    _snapshot.value = next;
  }

  void dispose() => _snapshot.dispose();
}
